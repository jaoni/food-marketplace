import request from "supertest";
import { beforeEach, describe, expect, it } from "vitest";
import { app, createRestaurant, createUser, resetDb, type TestRestaurant } from "./helpers.ts";

describe("restaurants and menus", () => {
  let pizzeria: TestRestaurant;
  let diner: TestRestaurant;

  beforeEach(async () => {
    await resetDb();
    const owner = await createUser("restaurant_owner");
    pizzeria = await createRestaurant(owner.id, { name: "Pizzeria" });
    diner = await createRestaurant(owner.id, { name: "Closed Diner", isOpen: false });
  });

  it("lists all restaurants", async () => {
    const res = await request(app).get("/restaurants");

    expect(res.status).toBe(200);
    expect(res.body).toEqual([
      { id: pizzeria.id, name: "Pizzeria", isOpen: true },
      { id: diner.id, name: "Closed Diner", isOpen: false },
    ]);
  });

  it("returns one restaurant", async () => {
    const res = await request(app).get(`/restaurants/${diner.id}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ id: diner.id, name: "Closed Diner", isOpen: false });
  });

  it("returns 404 for an unknown or malformed id", async () => {
    for (const id of ["999", "abc", "1.5", "-1"]) {
      const res = await request(app).get(`/restaurants/${id}`);
      expect(res.status).toBe(404);
      expect(res.body).toEqual({ error: "Restaurant not found" });
    }
  });

  it("returns the menu grouped by category, including unavailable items", async () => {
    const res = await request(app).get(`/restaurants/${pizzeria.id}/menu`);

    expect(res.status).toBe(200);
    expect(res.body.restaurantId).toBe(pizzeria.id);
    expect(res.body.categories).toHaveLength(1);

    const [mains] = res.body.categories;
    expect(mains.name).toBe("Mains");
    expect(mains.items).toEqual([
      { id: pizzeria.pizzaId, categoryId: mains.id, name: "Pizza", description: "", priceCents: 1000, isAvailable: true },
      { id: pizzeria.soupId, categoryId: mains.id, name: "Soup", description: "", priceCents: 450, isAvailable: true },
      { id: pizzeria.soldOutId, categoryId: mains.id, name: "Sold Out Special", description: "", priceCents: 900, isAvailable: false },
    ]);
  });

  it("returns 404 for the menu of an unknown restaurant", async () => {
    const res = await request(app).get("/restaurants/999/menu");

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: "Restaurant not found" });
  });

  it("returns a JSON 404 for unknown URLs", async () => {
    const res = await request(app).get("/no-such-page");

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: "Not found" });
  });
});
