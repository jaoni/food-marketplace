import { randomUUID } from "node:crypto";
import request from "supertest";
import { createApp } from "../src/app.ts";
import { pool } from "../src/db/pool.ts";
import { hashPassword, signToken } from "../src/services/authService.ts";
import type { Role } from "../src/types.ts";

// supertest sends requests to the app directly, no running server needed.
export const app = createApp();

// Empties every table, so each test starts from a clean database.
export async function resetDb(): Promise<void> {
  const { rows } = await pool.query<{ name: string }>("SELECT current_database() AS name");
  const name = rows[0]?.name ?? "";
  if (!name.endsWith("_test")) {
    throw new Error(`Refusing to wipe "${name}": tests must run against a *_test database`);
  }
  await pool.query(`
    TRUNCATE users, restaurants, menu_categories, menu_items,
             orders, order_items, order_status_events
    RESTART IDENTITY CASCADE
  `);
}

// Runs an INSERT ... RETURNING id and returns the new id.
async function insert(sql: string, params: unknown[]): Promise<number> {
  const { rows } = await pool.query<{ id: number }>(sql, params);
  return rows[0]!.id;
}

export type TestUser = { id: number; email: string; role: Role; token: string };

// Creates a user directly in the database (password "password123"), plus a
// valid token for them.
export async function createUser(role: Role): Promise<TestUser> {
  const email = `${role}-${randomUUID()}@test.com`;
  const id = await insert(
    "INSERT INTO users (email, password_hash, name, role) VALUES ($1, $2, $3, $4) RETURNING id",
    [email, await hashPassword("password123"), `Test ${role}`, role],
  );
  return { id, email, role, token: signToken({ id, role }) };
}

export type TestRestaurant = { id: number; pizzaId: number; soupId: number; soldOutId: number };

// A restaurant with one menu category and three items, one of them sold out.
export async function createRestaurant(
  ownerId: number,
  options: { name?: string; isOpen?: boolean } = {},
): Promise<TestRestaurant> {
  const id = await insert(
    "INSERT INTO restaurants (owner_id, name, is_open) VALUES ($1, $2, $3) RETURNING id",
    [ownerId, options.name ?? "Test Pizzeria", options.isOpen ?? true],
  );
  const categoryId = await insert(
    "INSERT INTO menu_categories (restaurant_id, name) VALUES ($1, 'Mains') RETURNING id",
    [id],
  );
  const addItem = (name: string, priceCents: number, isAvailable = true) =>
    insert(
      `INSERT INTO menu_items (category_id, name, price_cents, is_available)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [categoryId, name, priceCents, isAvailable],
    );

  return {
    id,
    pizzaId: await addItem("Pizza", 1000),
    soupId: await addItem("Soup", 450),
    soldOutId: await addItem("Sold Out Special", 900, false),
  };
}

export function auth(user: TestUser) {
  return { Authorization: `Bearer ${user.token}` };
}

// POST /orders with a fresh Idempotency-Key, unless a key is given.
export function postOrder(customer: TestUser, body: object, idempotencyKey: string = randomUUID()) {
  return request(app)
    .post("/orders")
    .set(auth(customer))
    .set("Idempotency-Key", idempotencyKey)
    .send(body);
}

export function patchStatus(user: TestUser, orderId: number, status: string) {
  return request(app).patch(`/orders/${orderId}/status`).set(auth(user)).send({ status });
}

export async function countRows(table: "orders" | "order_items" | "order_status_events") {
  const { rows } = await pool.query<{ count: number }>(`SELECT count(*) FROM ${table}`);
  return rows[0]!.count;
}
