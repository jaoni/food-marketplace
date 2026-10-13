import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";
import { pool } from "../src/db/pool.ts";
import {
  app,
  auth,
  countRows,
  createRestaurant,
  createUser,
  postOrder,
  resetDb,
  type TestRestaurant,
  type TestUser,
} from "./helpers.ts";

let customer: TestUser;
let pizzeria: TestRestaurant;
let otherPlace: TestRestaurant;
let closedPlace: TestRestaurant;

beforeEach(async () => {
  await resetDb();
  customer = await createUser("customer");
  const owner = await createUser("restaurant_owner");
  pizzeria = await createRestaurant(owner.id);
  otherPlace = await createRestaurant(owner.id, { name: "Other Place" });
  closedPlace = await createRestaurant(owner.id, { name: "Closed Place", isOpen: false });
});

const onePizza = () => ({
  restaurantId: pizzeria.id,
  items: [{ menuItemId: pizzeria.pizzaId, quantity: 1 }],
  deliveryAddress: "1 Test Street",
});

describe("POST /orders", () => {
  it("prices the order on the server and ignores prices sent by the app", async () => {
    const res = await postOrder(customer, {
      restaurantId: pizzeria.id,
      items: [
        { menuItemId: pizzeria.pizzaId, quantity: 2, priceCents: 1 },
        { menuItemId: pizzeria.soupId, quantity: 1 },
      ],
      deliveryAddress: "  1 Test Street  ",
      totalCents: 1,
    });

    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({
      customerId: customer.id,
      restaurantId: pizzeria.id,
      restaurantName: "Test Pizzeria",
      status: "pending",
      deliveryAddress: "1 Test Street",
      totalCents: 2 * 1000 + 450,
    });
    expect(res.body.items).toEqual([
      { menuItemId: pizzeria.pizzaId, name: "Pizza", unitPriceCents: 1000, quantity: 2, lineTotalCents: 2000 },
      { menuItemId: pizzeria.soupId, name: "Soup", unitPriceCents: 450, quantity: 1, lineTotalCents: 450 },
    ]);
    expect(res.body.statusHistory).toEqual([
      { fromStatus: null, toStatus: "pending", changedBy: customer.id, createdAt: expect.any(String) },
    ]);
  });

  it("keeps the copied name and price when the menu changes later", async () => {
    const created = await postOrder(customer, onePizza());
    await pool.query("UPDATE menu_items SET name = 'Renamed', price_cents = 9999 WHERE id = $1", [
      pizzeria.pizzaId,
    ]);

    const res = await request(app).get(`/orders/${created.body.id}`).set(auth(customer));

    expect(res.body.items[0]).toMatchObject({ name: "Pizza", unitPriceCents: 1000 });
    expect(res.body.totalCents).toBe(1000);
  });

  // Sends an order that must be rejected, and checks that nothing was saved.
  async function expectRejected(body: object, status: number, error: string | RegExp) {
    const res = await postOrder(customer, body);
    expect(res.status).toBe(status);
    expect(res.body.error).toMatch(error);
    expect(await countRows("orders")).toBe(0);
    expect(await countRows("order_items")).toBe(0);
    expect(await countRows("order_status_events")).toBe(0);
  }

  it("rejects orders the restaurant can't fulfil (422)", async () => {
    const address = { deliveryAddress: "1 Test Street" };
    await expectRejected(
      { restaurantId: closedPlace.id, items: [{ menuItemId: closedPlace.pizzaId, quantity: 1 }], ...address },
      422,
      "Closed Place is closed",
    );
    await expectRejected(
      { restaurantId: pizzeria.id, items: [{ menuItemId: pizzeria.soldOutId, quantity: 1 }], ...address },
      422,
      "Sold Out Special is not available right now",
    );
    await expectRejected(
      { restaurantId: pizzeria.id, items: [{ menuItemId: otherPlace.pizzaId, quantity: 1 }], ...address },
      422,
      "is not on Test Pizzeria's menu",
    );
    await expectRejected(
      { restaurantId: 999, items: [{ menuItemId: pizzeria.pizzaId, quantity: 1 }], ...address },
      422,
      "Restaurant not found",
    );
  });

  it("rejects malformed orders (400)", async () => {
    const pizza = { menuItemId: pizzeria.pizzaId, quantity: 1 };
    await expectRejected({ ...onePizza(), items: [pizza, pizza] }, 400, "Each menu item can only appear once");
    await expectRejected({ ...onePizza(), items: [] }, 400, "Invalid request");
    await expectRejected({ ...onePizza(), items: [{ ...pizza, quantity: 0 }] }, 400, "Invalid request");
    await expectRejected({ ...onePizza(), items: [{ ...pizza, quantity: 100 }] }, 400, "Invalid request");
    await expectRejected({ ...onePizza(), deliveryAddress: "   " }, 400, "Invalid request");
    await expectRejected({ ...onePizza(), restaurantId: String(pizzeria.id) }, 400, "Invalid request");
  });

  it("only lets logged-in customers order", async () => {
    const noToken = await request(app).post("/orders").set("Idempotency-Key", "k").send(onePizza());
    expect(noToken.status).toBe(401);

    for (const role of ["restaurant_owner", "courier", "admin"] as const) {
      const res = await postOrder(await createUser(role), onePizza());
      expect(res.status).toBe(403);
    }
    expect(await countRows("orders")).toBe(0);
  });
});

describe("POST /orders idempotency", () => {
  it("requires an Idempotency-Key header", async () => {
    const res = await request(app).post("/orders").set(auth(customer)).send(onePizza());

    expect(res.status).toBe(400);
    expect(res.body.error).toBe("Missing Idempotency-Key header");
  });

  it("returns the same order when a request is retried with the same key", async () => {
    const first = await postOrder(customer, onePizza(), "key-1");
    const retry = await postOrder(customer, onePizza(), "key-1");

    expect(first.status).toBe(201);
    expect(retry.status).toBe(200);
    expect(retry.body).toEqual(first.body);
    expect(await countRows("orders")).toBe(1);
  });

  it("creates only one order when copies of a request arrive at the same moment", async () => {
    const responses = await Promise.all(
      Array.from({ length: 5 }, () => postOrder(customer, onePizza(), "key-1")),
    );

    expect(responses.map((r) => r.status).sort()).toEqual([200, 200, 200, 200, 201]);
    expect(new Set(responses.map((r) => r.body.id)).size).toBe(1);
    expect(await countRows("orders")).toBe(1);
    expect(await countRows("order_status_events")).toBe(1);
  });

  it("rejects reusing a key for a different order", async () => {
    await postOrder(customer, onePizza(), "key-1");
    const res = await postOrder(
      customer,
      { ...onePizza(), items: [{ menuItemId: pizzeria.soupId, quantity: 3 }] },
      "key-1",
    );

    expect(res.status).toBe(422);
    expect(res.body.error).toBe("This Idempotency-Key was already used for a different order");
    expect(await countRows("orders")).toBe(1);
  });

  it("treats keys per customer", async () => {
    const otherCustomer = await createUser("customer");
    const a = await postOrder(customer, onePizza(), "same-key");
    const b = await postOrder(otherCustomer, onePizza(), "same-key");

    expect([a.status, b.status]).toEqual([201, 201]);
    expect(a.body.id).not.toBe(b.body.id);
  });

  it("still returns the original order if an item became unavailable before the retry", async () => {
    const first = await postOrder(customer, onePizza(), "key-1");
    await pool.query("UPDATE menu_items SET is_available = false WHERE id = $1", [pizzeria.pizzaId]);

    const retry = await postOrder(customer, onePizza(), "key-1");
    expect(retry.status).toBe(200);
    expect(retry.body.id).toBe(first.body.id);

    const newAttempt = await postOrder(customer, onePizza(), "key-2");
    expect(newAttempt.status).toBe(422);
  });
});
