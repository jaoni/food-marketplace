// SQL only. No HTTP and no business rules here.
import type { PoolClient } from "pg";
import { pool } from "../db/pool.ts";
import type { Order, OrderItem, OrderStatus, OrderStatusEvent } from "../types.ts";

// The columns of the Order type. A fixed piece of SQL (not user input), so
// it's safe to put into the query strings below.
const ORDER_COLUMNS = `
  o.id, o.customer_id AS "customerId", o.restaurant_id AS "restaurantId",
  r.name AS "restaurantName", o.status, o.delivery_address AS "deliveryAddress",
  o.total_cents AS "totalCents", o.created_at AS "createdAt", o.updated_at AS "updatedAt"`;

// The insert functions take `tx` because they must run inside a transaction.

// Returns the new order's id, or null if this customer already has an order
// with this idempotency key (ON CONFLICT DO NOTHING then inserts nothing).
export async function insertOrder(
  tx: PoolClient,
  order: {
    customerId: number;
    restaurantId: number;
    status: OrderStatus;
    deliveryAddress: string;
    totalCents: number;
    idempotencyKey: string;
    requestHash: string;
  },
): Promise<number | null> {
  const { rows } = await tx.query<{ id: number }>(
    `INSERT INTO orders
       (customer_id, restaurant_id, status, delivery_address, total_cents, idempotency_key, request_hash)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (customer_id, idempotency_key) DO NOTHING
     RETURNING id`,
    [
      order.customerId,
      order.restaurantId,
      order.status,
      order.deliveryAddress,
      order.totalCents,
      order.idempotencyKey,
      order.requestHash,
    ],
  );
  return rows[0]?.id ?? null;
}

export async function findByIdempotencyKey(
  customerId: number,
  idempotencyKey: string,
): Promise<{ id: number; requestHash: string } | null> {
  const { rows } = await pool.query<{ id: number; requestHash: string }>(
    `SELECT id, request_hash AS "requestHash"
     FROM orders
     WHERE customer_id = $1 AND idempotency_key = $2`,
    [customerId, idempotencyKey],
  );
  return rows[0] ?? null;
}

export async function insertItem(tx: PoolClient, orderId: number, item: OrderItem): Promise<void> {
  await tx.query(
    `INSERT INTO order_items (order_id, menu_item_id, name, unit_price_cents, quantity, line_total_cents)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [orderId, item.menuItemId, item.name, item.unitPriceCents, item.quantity, item.lineTotalCents],
  );
}

export async function insertStatusEvent(
  tx: PoolClient,
  event: {
    orderId: number;
    fromStatus: OrderStatus | null;
    toStatus: OrderStatus;
    changedBy: number;
  },
): Promise<void> {
  await tx.query(
    `INSERT INTO order_status_events (order_id, from_status, to_status, changed_by)
     VALUES ($1, $2, $3, $4)`,
    [event.orderId, event.fromStatus, event.toStatus, event.changedBy],
  );
}

export async function findById(id: number): Promise<Order | null> {
  const { rows } = await pool.query<Order>(
    `SELECT ${ORDER_COLUMNS}
     FROM orders o
     JOIN restaurants r ON r.id = o.restaurant_id
     WHERE o.id = $1`,
    [id],
  );
  return rows[0] ?? null;
}

// One page of orders, newest first. A null filter means "don't filter on it".
// beforeId is the cursor: only orders with a smaller id (= older) come back.
export async function list(filter: {
  customerId: number | null;
  restaurantOwnerId: number | null;
  beforeId: number | null;
  limit: number;
}): Promise<Order[]> {
  const { rows } = await pool.query<Order>(
    `SELECT ${ORDER_COLUMNS}
     FROM orders o
     JOIN restaurants r ON r.id = o.restaurant_id
     WHERE ($1::bigint IS NULL OR o.customer_id = $1)
       AND ($2::bigint IS NULL OR r.owner_id = $2)
       AND ($3::bigint IS NULL OR o.id < $3)
     ORDER BY o.id DESC
     LIMIT $4`,
    [filter.customerId, filter.restaurantOwnerId, filter.beforeId, filter.limit],
  );
  return rows;
}

// The fields needed to decide who may see or change an order.
export async function findAccessInfo(orderId: number): Promise<{
  status: OrderStatus;
  customerId: number;
  restaurantOwnerId: number;
} | null> {
  const { rows } = await pool.query<{
    status: OrderStatus;
    customerId: number;
    restaurantOwnerId: number;
  }>(
    `SELECT o.status, o.customer_id AS "customerId", r.owner_id AS "restaurantOwnerId"
     FROM orders o
     JOIN restaurants r ON r.id = o.restaurant_id
     WHERE o.id = $1`,
    [orderId],
  );
  return rows[0] ?? null;
}

// Changes the status only if it is still `from`. If someone else changed it
// in the meantime, no row matches, nothing is updated, and this returns false.
// (Postgres locks the row during an UPDATE, so of two simultaneous updates
// from the same status, only the first one can match.)
export async function updateStatus(
  tx: PoolClient,
  orderId: number,
  from: OrderStatus,
  to: OrderStatus,
): Promise<boolean> {
  const result = await tx.query(
    `UPDATE orders
     SET status = $3, updated_at = now()
     WHERE id = $1 AND status = $2`,
    [orderId, from, to],
  );
  return result.rowCount === 1;
}

export async function findItems(orderId: number): Promise<OrderItem[]> {
  const { rows } = await pool.query<OrderItem>(
    `SELECT menu_item_id AS "menuItemId", name, unit_price_cents AS "unitPriceCents",
            quantity, line_total_cents AS "lineTotalCents"
     FROM order_items
     WHERE order_id = $1
     ORDER BY id`,
    [orderId],
  );
  return rows;
}

export async function findStatusHistory(orderId: number): Promise<OrderStatusEvent[]> {
  const { rows } = await pool.query<OrderStatusEvent>(
    `SELECT from_status AS "fromStatus", to_status AS "toStatus",
            changed_by AS "changedBy", created_at AS "createdAt"
     FROM order_status_events
     WHERE order_id = $1
     ORDER BY id`,
    [orderId],
  );
  return rows;
}
