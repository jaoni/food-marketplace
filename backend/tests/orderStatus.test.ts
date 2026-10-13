import { beforeEach, describe, expect, it } from "vitest";
import { pool, withTransaction } from "../src/db/pool.ts";
import * as orderRepository from "../src/repositories/orderRepository.ts";
import { rolesAllowedToMove } from "../src/services/orderStateMachine.ts";
import {
  countRows,
  createRestaurant,
  createUser,
  patchStatus,
  postOrder,
  resetDb,
  type TestUser,
} from "./helpers.ts";

// Plain function, no database needed.
describe("order state machine rules", () => {
  it("allows the listed moves for the listed roles", () => {
    expect(rolesAllowedToMove("pending", "accepted")).toEqual(["restaurant_owner", "admin"]);
    expect(rolesAllowedToMove("pending", "cancelled")).toContain("customer");
    expect(rolesAllowedToMove("accepted", "cancelled")).not.toContain("customer");
    expect(rolesAllowedToMove("ready", "picked_up")).toEqual(["courier", "admin"]);
  });

  it("allows nothing else", () => {
    expect(rolesAllowedToMove("pending", "ready")).toBeNull();
    expect(rolesAllowedToMove("ready", "cancelled")).toBeNull();
    expect(rolesAllowedToMove("delivered", "cancelled")).toBeNull();
    expect(rolesAllowedToMove("cancelled", "pending")).toBeNull();
    expect(rolesAllowedToMove("pending", "pending")).toBeNull();
  });
});

describe("PATCH /orders/:id/status", () => {
  let customer: TestUser;
  let owner: TestUser;
  let courier: TestUser;
  let admin: TestUser;
  let orderId: number;

  beforeEach(async () => {
    await resetDb();
    customer = await createUser("customer");
    owner = await createUser("restaurant_owner");
    courier = await createUser("courier");
    admin = await createUser("admin");

    const restaurant = await createRestaurant(owner.id);
    const res = await postOrder(customer, {
      restaurantId: restaurant.id,
      items: [{ menuItemId: restaurant.pizzaId, quantity: 1 }],
      deliveryAddress: "1 Test Street",
    });
    orderId = res.body.id;
  });

  async function statusEvents() {
    const { rows } = await pool.query(
      "SELECT from_status, to_status, changed_by FROM order_status_events WHERE order_id = $1 ORDER BY id",
      [orderId],
    );
    return rows;
  }

  it("takes an order from pending to delivered and logs every change", async () => {
    const steps: [TestUser, string][] = [
      [owner, "accepted"],
      [owner, "preparing"],
      [owner, "ready"],
      [courier, "picked_up"],
      [courier, "delivered"],
    ];
    for (const [user, status] of steps) {
      const res = await patchStatus(user, orderId, status);
      expect(res.status).toBe(200);
      expect(res.body.status).toBe(status);
    }

    expect(await statusEvents()).toEqual([
      { from_status: null, to_status: "pending", changed_by: customer.id },
      { from_status: "pending", to_status: "accepted", changed_by: owner.id },
      { from_status: "accepted", to_status: "preparing", changed_by: owner.id },
      { from_status: "preparing", to_status: "ready", changed_by: owner.id },
      { from_status: "ready", to_status: "picked_up", changed_by: courier.id },
      { from_status: "picked_up", to_status: "delivered", changed_by: courier.id },
    ]);

    // delivered is final, even for an admin
    const res = await patchStatus(admin, orderId, "cancelled");
    expect(res.status).toBe(409);
  });

  it("returns 409 for moves that don't exist", async () => {
    const res = await patchStatus(owner, orderId, "ready");

    expect(res.status).toBe(409);
    expect(res.body.error).toBe("Can't change an order from pending to ready");
    expect(await statusEvents()).toHaveLength(1);
  });

  it("returns 403 when the role may not make the move", async () => {
    expect((await patchStatus(customer, orderId, "accepted")).status).toBe(403);
    expect((await patchStatus(courier, orderId, "accepted")).status).toBe(403);
    expect(await statusEvents()).toHaveLength(1);
  });

  it("only lets a restaurant owner change orders at their own restaurant", async () => {
    const otherOwner = await createUser("restaurant_owner");

    expect((await patchStatus(otherOwner, orderId, "accepted")).status).toBe(403);
    expect((await patchStatus(owner, orderId, "accepted")).status).toBe(200);
  });

  it("lets a customer cancel their own order, but only while it's pending", async () => {
    const otherCustomer = await createUser("customer");
    expect((await patchStatus(otherCustomer, orderId, "cancelled")).status).toBe(403);
    expect((await patchStatus(customer, orderId, "cancelled")).status).toBe(200);

    // A second order that the restaurant has already accepted:
    const restaurant = await createRestaurant(owner.id);
    const { body } = await postOrder(customer, {
      restaurantId: restaurant.id,
      items: [{ menuItemId: restaurant.soupId, quantity: 1 }],
      deliveryAddress: "1 Test Street",
    });
    await patchStatus(owner, body.id, "accepted");

    expect((await patchStatus(customer, body.id, "cancelled")).status).toBe(403);
    expect((await patchStatus(admin, body.id, "cancelled")).status).toBe(200);
  });

  it("returns 404 for an unknown order and 400 for an unknown status", async () => {
    expect((await patchStatus(admin, 999999, "accepted")).status).toBe(404);
    expect((await patchStatus(admin, orderId, "eaten")).status).toBe(400);
  });

  it("lets only one of two simultaneous changes win", async () => {
    const results = await Promise.all([
      patchStatus(owner, orderId, "accepted"),
      patchStatus(customer, orderId, "cancelled"),
    ]);

    expect(results.filter((res) => res.status === 200)).toHaveLength(1);
    expect(await statusEvents()).toHaveLength(2); // "created" + exactly one change
  });

  it("updateStatus only updates if the status is still the expected one", async () => {
    const first = await withTransaction((tx) =>
      orderRepository.updateStatus(tx, orderId, "pending", "accepted"),
    );
    const second = await withTransaction((tx) =>
      orderRepository.updateStatus(tx, orderId, "pending", "cancelled"),
    );

    expect(first).toBe(true);
    expect(second).toBe(false);
    const { rows } = await pool.query("SELECT status FROM orders WHERE id = $1", [orderId]);
    expect(rows[0].status).toBe("accepted");
    expect(await countRows("orders")).toBe(1);
  });
});
