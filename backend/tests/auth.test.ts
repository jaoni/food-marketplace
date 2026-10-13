import jwt from "jsonwebtoken";
import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";
import { config } from "../src/config.ts";
import { pool } from "../src/db/pool.ts";
import { app, resetDb } from "./helpers.ts";

const register = (body: object) => request(app).post("/auth/register").send(body);
const login = (body: object) => request(app).post("/auth/login").send(body);
const me = (token?: string) => {
  const req = request(app).get("/auth/me");
  return token ? req.set("Authorization", `Bearer ${token}`) : req;
};

const dana = { email: "dana@example.com", password: "secret123", name: "Dana" };

describe("auth", () => {
  beforeEach(resetDb);

  it("registers a customer and returns a token and the user", async () => {
    const res = await register({ ...dana, email: "Dana@Example.com" });

    expect(res.status).toBe(201);
    expect(res.body.token).toEqual(expect.any(String));
    expect(res.body.user).toEqual({
      id: expect.any(Number),
      email: "dana@example.com", // lower-cased
      name: "Dana",
      role: "customer", // the default
      createdAt: expect.any(String),
    });
  });

  it("stores a bcrypt hash, never the password itself", async () => {
    await register(dana);

    const { rows } = await pool.query("SELECT password_hash FROM users WHERE email = $1", [dana.email]);
    expect(rows[0].password_hash).toMatch(/^\$2b\$/);
    expect(rows[0].password_hash).not.toContain(dana.password);
  });

  it("lets restaurant owners and couriers sign up, but not admins", async () => {
    expect((await register({ ...dana, email: "o@example.com", role: "restaurant_owner" })).status).toBe(201);
    expect((await register({ ...dana, email: "c@example.com", role: "courier" })).status).toBe(201);

    const res = await register({ ...dana, email: "a@example.com", role: "admin" });
    expect(res.status).toBe(403);
    expect(res.body.error).toBe("You can't register as admin");
  });

  it("rejects an email that is already registered, ignoring case", async () => {
    await register(dana);
    const res = await register({ ...dana, email: "DANA@example.com" });

    expect(res.status).toBe(409);
    expect(res.body.error).toBe("Email is already registered");
  });

  it("validates the request body", async () => {
    const res = await register({ email: "not-an-email", password: "short", role: "chef" });

    expect(res.status).toBe(400);
    expect(res.body.details.map((d: { path: string }) => d.path)).toEqual(["email", "password", "name", "role"]);
  });

  it("rejects malformed JSON", async () => {
    const res = await request(app)
      .post("/auth/login")
      .set("Content-Type", "application/json")
      .send('{"email": oops');

    expect(res.status).toBe(400);
  });

  it("logs in, and the token works for /auth/me", async () => {
    await register(dana);
    const res = await login({ email: "DANA@example.com", password: dana.password });

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe(dana.email);

    const meRes = await me(res.body.token);
    expect(meRes.status).toBe(200);
    expect(meRes.body).toMatchObject({ email: dana.email, role: "customer" });
  });

  it("gives the same 401 for a wrong password and an unknown email", async () => {
    await register(dana);
    const wrongPassword = await login({ email: dana.email, password: "wrong-password" });
    const unknownEmail = await login({ email: "nobody@example.com", password: dana.password });

    for (const res of [wrongPassword, unknownEmail]) {
      expect(res.status).toBe(401);
      expect(res.body.error).toBe("Invalid email or password");
    }
  });

  it("rejects missing, forged and expired tokens", async () => {
    const { body } = await register(dana);
    const userId = String(body.user.id);

    const forged = jwt.sign({ role: "admin" }, "not-the-real-secret", { subject: userId });
    const expired = jwt.sign({ role: "customer" }, config.jwtSecret, { subject: userId, expiresIn: -10 });

    expect((await me()).status).toBe(401);
    expect((await me("garbage")).status).toBe(401);
    expect((await me(forged)).status).toBe(401);
    expect((await me(expired)).status).toBe(401);
  });
});
