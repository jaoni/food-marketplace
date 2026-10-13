// Business rules. Knows nothing about HTTP (req/res) or SQL.
import { createHash } from "node:crypto";
import { withTransaction } from "../db/pool.ts";
import {
  BadRequestError,
  ConflictError,
  ForbiddenError,
  NotFoundError,
  UnprocessableError,
} from "../errors.ts";
import * as menuRepository from "../repositories/menuRepository.ts";
import * as orderRepository from "../repositories/orderRepository.ts";
import * as restaurantRepository from "../repositories/restaurantRepository.ts";
import type { AuthUser, Order, OrderDetail, OrderItem, OrderStatus } from "../types.ts";
import { rolesAllowedToMove } from "./orderStateMachine.ts";

export type PlaceOrderInput = {
  restaurantId: number;
  items: { menuItemId: number; quantity: number }[];
  deliveryAddress: string;
};

// `created` is false when this request was a retry and we returned the order
// that the first attempt created.
export type PlaceOrderResult = { order: OrderDetail; created: boolean };

export async function placeOrder(
  customerId: number,
  idempotencyKey: string,
  input: PlaceOrderInput,
): Promise<PlaceOrderResult> {
  // A fingerprint of what's being ordered, to catch a key reused for a different order.
  const requestHash = createHash("sha256").update(JSON.stringify(input)).digest("hex");

  // 1. Is this a retry of a request we already handled? Then return that order.
  //    This check comes before the menu checks below: if an item became
  //    unavailable since the first attempt, the retry must still return the
  //    order that was already placed, not an error.
  const existing = await orderRepository.findByIdempotencyKey(customerId, idempotencyKey);
  if (existing) {
    return replay(existing, requestHash);
  }

  // 2. Check the order and work out the prices.
  const restaurant = await restaurantRepository.findById(input.restaurantId);
  if (!restaurant) {
    throw new UnprocessableError("Restaurant not found");
  }
  if (!restaurant.isOpen) {
    throw new UnprocessableError(`${restaurant.name} is closed`);
  }

  const menuItemIds = input.items.map((item) => item.menuItemId);
  if (new Set(menuItemIds).size !== menuItemIds.length) {
    throw new BadRequestError("Each menu item can only appear once. Use quantity instead.");
  }

  // Prices come from the database. The app only says *what* it wants.
  const menuItems = await menuRepository.findItemsByIds(restaurant.id, menuItemIds);
  const menuItemsById = new Map(menuItems.map((menuItem) => [menuItem.id, menuItem]));

  const lines: OrderItem[] = input.items.map(({ menuItemId, quantity }) => {
    const menuItem = menuItemsById.get(menuItemId);
    if (!menuItem) {
      throw new UnprocessableError(`Menu item ${menuItemId} is not on ${restaurant.name}'s menu`);
    }
    if (!menuItem.isAvailable) {
      throw new UnprocessableError(`${menuItem.name} is not available right now`);
    }
    return {
      menuItemId,
      name: menuItem.name, // copied, so the order keeps it even if the menu changes
      unitPriceCents: menuItem.priceCents,
      quantity,
      lineTotalCents: menuItem.priceCents * quantity,
    };
  });

  const totalCents = lines.reduce((sum, line) => sum + line.lineTotalCents, 0);

  // 3. One transaction: the order, its items and its first status event are
  //    saved together, or (if anything fails) none of them are.
  const orderId = await withTransaction(async (tx) => {
    const id = await orderRepository.insertOrder(tx, {
      customerId,
      restaurantId: restaurant.id,
      status: "pending",
      deliveryAddress: input.deliveryAddress,
      totalCents,
      idempotencyKey,
      requestHash,
    });
    if (id === null) {
      return null; // another request with the same key got there first
    }

    for (const line of lines) {
      await orderRepository.insertItem(tx, id, line);
    }
    await orderRepository.insertStatusEvent(tx, {
      orderId: id,
      fromStatus: null,
      toStatus: "pending",
      changedBy: customerId,
    });
    return id;
  });

  if (orderId === null) {
    // Two copies of the same request arrived at the same moment and both
    // passed step 1. The unique constraint let only one insert succeed; this
    // copy returns that order. (It must exist: Postgres only reports the
    // conflict after the other transaction has committed.)
    const winner = await orderRepository.findByIdempotencyKey(customerId, idempotencyKey);
    return replay(winner!, requestHash);
  }

  return { order: await getOrderDetail(orderId), created: true };
}

// Answers a retry with the order that the first attempt created.
async function replay(
  existing: { id: number; requestHash: string },
  requestHash: string,
): Promise<PlaceOrderResult> {
  if (existing.requestHash !== requestHash) {
    throw new UnprocessableError("This Idempotency-Key was already used for a different order");
  }
  return { order: await getOrderDetail(existing.id), created: false };
}

export type OrderPage = {
  orders: Order[];
  nextCursor: string | null; // pass as ?cursor=... to get the next page; null = no more
};

// "My orders" depends on who's asking:
//   customer          → the orders they placed
//   restaurant_owner  → the orders at their restaurants
//   admin             → all orders
//   courier           → not allowed (same rule as viewing a single order)
export async function listOrders(
  user: AuthUser,
  page: { limit: number; cursor?: string },
): Promise<OrderPage> {
  if (user.role === "courier") {
    throw new ForbiddenError("Couriers can't list orders");
  }

  // Fetch one row more than asked for: if it exists, there is a next page.
  const rows = await orderRepository.list({
    customerId: user.role === "customer" ? user.id : null,
    restaurantOwnerId: user.role === "restaurant_owner" ? user.id : null,
    beforeId: page.cursor === undefined ? null : decodeCursor(page.cursor),
    limit: page.limit + 1,
  });

  const orders = rows.slice(0, page.limit);
  const hasMore = rows.length > page.limit;
  return {
    orders,
    nextCursor: hasMore ? encodeCursor(orders.at(-1)!.id) : null,
  };
}

// The cursor is the id of the last order on the page. It's base64url-encoded
// so the app treats it as an opaque token; we can change what's inside later
// without breaking the app.
function encodeCursor(lastOrderId: number): string {
  return Buffer.from(String(lastOrderId)).toString("base64url");
}

function decodeCursor(cursor: string): number {
  const id = Number(Buffer.from(cursor, "base64url").toString());
  if (!Number.isSafeInteger(id) || id <= 0) {
    throw new BadRequestError("Invalid cursor");
  }
  return id;
}

export async function getOrder(user: AuthUser, orderId: number): Promise<OrderDetail> {
  const order = await orderRepository.findAccessInfo(orderId);
  if (!order) {
    throw new NotFoundError("Order not found");
  }
  if (!canView(user, order)) {
    throw new ForbiddenError("You can't view this order");
  }
  return getOrderDetail(orderId);
}

// Only the order's customer, the owner of its restaurant, or an admin may see it.
function canView(user: AuthUser, order: { customerId: number; restaurantOwnerId: number }): boolean {
  switch (user.role) {
    case "admin":
      return true;
    case "customer":
      return order.customerId === user.id;
    case "restaurant_owner":
      return order.restaurantOwnerId === user.id;
    case "courier":
      return false;
  }
}

export async function changeStatus(
  user: AuthUser,
  orderId: number,
  newStatus: OrderStatus,
): Promise<OrderDetail> {
  const order = await orderRepository.findAccessInfo(orderId);
  if (!order) {
    throw new NotFoundError("Order not found");
  }

  const allowedRoles = rolesAllowedToMove(order.status, newStatus);
  if (!allowedRoles) {
    throw new ConflictError(`Can't change an order from ${order.status} to ${newStatus}`);
  }
  if (!allowedRoles.includes(user.role) || !isInvolved(user, order)) {
    throw new ForbiddenError(`You can't change this order from ${order.status} to ${newStatus}`);
  }

  const changed = await withTransaction(async (tx) => {
    // Only updates if the status is still the one we read above.
    const updated = await orderRepository.updateStatus(tx, orderId, order.status, newStatus);
    if (!updated) {
      return false;
    }
    await orderRepository.insertStatusEvent(tx, {
      orderId,
      fromStatus: order.status,
      toStatus: newStatus,
      changedBy: user.id,
    });
    return true;
  });

  if (!changed) {
    throw new ConflictError("Someone else just changed this order's status. Reload and try again.");
  }

  return getOrderDetail(orderId);
}

// Customers and restaurant owners may only act on their own orders. Any courier
// may act on any order for now (assigning couriers to orders is a later stage).
function isInvolved(
  user: AuthUser,
  order: { customerId: number; restaurantOwnerId: number },
): boolean {
  switch (user.role) {
    case "admin":
    case "courier":
      return true;
    case "customer":
      return order.customerId === user.id;
    case "restaurant_owner":
      return order.restaurantOwnerId === user.id;
  }
}

// The order plus its items and status history.
async function getOrderDetail(orderId: number): Promise<OrderDetail> {
  const order = await orderRepository.findById(orderId);
  if (!order) {
    throw new NotFoundError("Order not found");
  }

  const [items, statusHistory] = await Promise.all([
    orderRepository.findItems(orderId),
    orderRepository.findStatusHistory(orderId),
  ]);

  return { ...order, items, statusHistory };
}
