import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";
import {
  app,
  auth,
  createRestaurant,
  createUser,
  postOrder,
  resetDb,
  type TestRestaurant,
  type TestUser,
} from "./helpers.ts";

let alice: TestUser;
let bob: TestUser;
let owner: TestUser;
let otherOwner: TestUser;
let courier: TestUser;
let admin: TestUser;
let aliceOrders: number[]; // oldest first
let bobOrders: number[];

async function order(customer: TestUser, restaurant: TestRestaurant): Promise<number> {
  const res = await postOrder(customer, {
    restaurantId: restaurant.id,
    items: [{ menuItemId: restaurant.pizzaId, quantity: 1 }],
    deliveryAddress: "1 Test Street",
  });
  return res.body.id;
}

beforeEach(async () => {
  await resetDb();
  alice = await createUser("customer");
  bob = await createUser("customer");
  owner = await createUser("restaurant_owner");
  otherOwner = await createUser("restaurant_owner");
  courier = await createUser("courier");
  admin = await createUser("admin");

  const pizzeria = await createRestaurant(owner.id);
  const otherPlace = await createRestaurant(otherOwner.id, { name: "Other Place" });

  aliceOrders = [];
  for (let i = 0; i < 5; i++) aliceOrders.push(await order(alice, pizzeria));
  bobOrders = [await order(bob, pizzeria), await order(bob, otherPlace)];
});

const listOrders = (user: TestUser, query: Record<string, string | number> = {}) =>
  request(app).get("/orders").query(query).set(auth(user));

// Follows nextCursor until the last page. Returns the order ids, page by page.
async function allPages(user: TestUser, limit: number): Promise<number[][]> {
  const pages: number[][] = [];
  let cursor: string | null = null;
  do {
    const res = await listOrders(user, cursor ? { limit, cursor } : { limit });
    expect(res.status).toBe(200);
    pages.push(res.body.orders.map((o: { id: number }) => o.id));
    cursor = res.body.nextCursor;
  } while (cursor);
  return pages;
}

describe("GET /orders", () => {
  it("pages through my orders, newest first", async () => {
    const [a1, a2, a3, a4, a5] = aliceOrders;

    expect(await allPages(alice, 2)).toEqual([[a5, a4], [a3, a2], [a1]]);
  });

  it("returns nextCursor null when everything fits on one page", async () => {
    const res = await listOrders(alice);

    expect(res.body.orders).toHaveLength(5);
    expect(res.body.nextCursor).toBeNull();
    expect(res.body.orders[0]).toMatchObject({
      id: aliceOrders[4],
      customerId: alice.id,
      restaurantName: "Test Pizzeria",
      status: "pending",
      totalCents: 1000,
    });
  });

  it("shows each role the right orders", async () => {
    const ids = async (user: TestUser) => (await allPages(user, 100)).flat();
    const newestFirst = (list: number[]) => [...list].sort((x, y) => y - x);

    expect(await ids(bob)).toEqual(newestFirst(bobOrders));
    expect(await ids(owner)).toEqual(newestFirst([...aliceOrders, bobOrders[0]!])); // their restaurant only
    expect(await ids(otherOwner)).toEqual([bobOrders[1]]);
    expect(await ids(admin)).toEqual(newestFirst([...aliceOrders, ...bobOrders]));
    expect((await listOrders(courier)).status).toBe(403);
  });

  it("rejects a bad cursor or limit", async () => {
    const badQueries: Record<string, string | number>[] = [
      { cursor: "garbage" },
      { cursor: "" },
      { limit: 0 },
      { limit: 101 },
      { limit: "abc" },
    ];
    for (const query of badQueries) {
      expect((await listOrders(alice, query)).status).toBe(400);
    }
  });
});

describe("GET /orders/:id", () => {
  it("shows an order only to its customer, its restaurant's owner, and admins", async () => {
    const orderId = aliceOrders[0]!;
    const get = (user: TestUser) => request(app).get(`/orders/${orderId}`).set(auth(user));

    const res = await get(alice);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ id: orderId, items: [{ name: "Pizza" }] });
    expect(res.body.statusHistory).toHaveLength(1);

    expect((await get(owner)).status).toBe(200);
    expect((await get(admin)).status).toBe(200);
    expect((await get(bob)).status).toBe(403);
    expect((await get(otherOwner)).status).toBe(403);
    expect((await get(courier)).status).toBe(403);
  });

  it("returns 404 for an unknown order", async () => {
    for (const id of ["999999", "abc"]) {
      const res = await request(app).get(`/orders/${id}`).set(auth(admin));
      expect(res.status).toBe(404);
    }
  });

  it("requires a token", async () => {
    expect((await request(app).get(`/orders/${aliceOrders[0]}`)).status).toBe(401);
    expect((await request(app).get("/orders")).status).toBe(401);
  });
});
