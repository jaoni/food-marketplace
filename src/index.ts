import express from "express";
import { config } from "./config.ts";
import { pool } from "./db/pool.ts";

type Restaurant = {
  id: number;
  name: string;
  isOpen: boolean;
};

type MenuCategory = {
  id: number;
  name: string;
};

type MenuItem = {
  id: number;
  categoryId: number;
  name: string;
  description: string;
  priceCents: number; // money as whole cents: 1050 means 10.50
  isAvailable: boolean;
};

const app = express();

// Route params are strings. Only a positive whole number can be an id; passing
// anything else to a bigint column would make Postgres throw an error.
function parseId(value: string): number | null {
  const id = Number(value);
  return /^\d+$/.test(value) && Number.isSafeInteger(id) && id > 0 ? id : null;
}

async function findRestaurant(idParam: string): Promise<Restaurant | undefined> {
  const id = parseId(idParam);
  if (id === null) return undefined;

  // $1 is a placeholder: pg sends the value separately, which prevents SQL injection.
  const { rows } = await pool.query<Restaurant>(
    `SELECT id, name, is_open AS "isOpen" FROM restaurants WHERE id = $1`,
    [id],
  );
  return rows[0];
}

app.get("/hello", (req, res) => {
  res.json({ message: "Hello from your first server!" });
});

app.get("/restaurants", async (req, res) => {
  const { rows } = await pool.query<Restaurant>(
    `SELECT id, name, is_open AS "isOpen" FROM restaurants ORDER BY id`,
  );
  res.json(rows);
});

app.get("/restaurants/:id", async (req, res) => {
  const restaurant = await findRestaurant(req.params.id);

  if (!restaurant) {
    res.status(404).json({ error: "Restaurant not found" });
    return;
  }

  res.json(restaurant);
});

app.get("/restaurants/:id/menu", async (req, res) => {
  const restaurant = await findRestaurant(req.params.id);

  if (!restaurant) {
    res.status(404).json({ error: "Restaurant not found" });
    return;
  }

  const { rows: categories } = await pool.query<MenuCategory>(
    `SELECT id, name FROM menu_categories
     WHERE restaurant_id = $1
     ORDER BY sort_order, id`,
    [restaurant.id],
  );

  const { rows: items } = await pool.query<MenuItem>(
    `SELECT mi.id, mi.category_id AS "categoryId", mi.name, mi.description,
            mi.price_cents AS "priceCents", mi.is_available AS "isAvailable"
     FROM menu_items mi
     JOIN menu_categories mc ON mc.id = mi.category_id
     WHERE mc.restaurant_id = $1
     ORDER BY mi.sort_order, mi.id`,
    [restaurant.id],
  );

  res.json({
    restaurantId: restaurant.id,
    categories: categories.map((category) => ({
      id: category.id,
      name: category.name,
      items: items.filter((item) => item.categoryId === category.id),
    })),
  });
});

app.listen(config.port, () => {
  console.log(`Server running on http://localhost:${config.port}`);
});
