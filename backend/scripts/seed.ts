// Fills the database with demo data. WARNING: deletes all existing data first.
import { pool } from "../src/db/pool.ts";
import { hashPassword } from "../src/services/authService.ts";

if (process.env.NODE_ENV === "production") {
  throw new Error("Refusing to seed a production database.");
}

const DEMO_PASSWORD = "password123";

const users = [
  { email: "admin@example.com", name: "Ada Admin", role: "admin" },
  { email: "owner1@example.com", name: "Olivia Owner", role: "restaurant_owner" },
  { email: "owner2@example.com", name: "Oscar Owner", role: "restaurant_owner" },
  { email: "alice@example.com", name: "Alice Customer", role: "customer" },
  { email: "bob@example.com", name: "Bob Customer", role: "customer" },
  { email: "courier@example.com", name: "Carl Courier", role: "courier" },
];

type SeedItem = { name: string; description: string; priceCents: number; isAvailable?: boolean };

const restaurants: {
  name: string;
  ownerEmail: string;
  isOpen: boolean;
  menu: { category: string; items: SeedItem[] }[];
}[] = [
  {
    name: "Bella Napoli",
    ownerEmail: "owner1@example.com",
    isOpen: true,
    menu: [
      {
        category: "Pizza",
        items: [
          { name: "Margherita", description: "Tomato, mozzarella, basil", priceCents: 1050 },
          { name: "Diavola", description: "Tomato, mozzarella, spicy salami", priceCents: 1250 },
          { name: "Quattro Formaggi", description: "Four cheeses", priceCents: 1350, isAvailable: false },
        ],
      },
      {
        category: "Drinks",
        items: [
          { name: "Lemonade", description: "Homemade", priceCents: 350 },
          { name: "Sparkling Water", description: "500 ml", priceCents: 250 },
        ],
      },
    ],
  },
  {
    name: "Tokyo Bowl",
    ownerEmail: "owner2@example.com",
    isOpen: true,
    menu: [
      {
        category: "Bowls",
        items: [
          { name: "Salmon Poke", description: "Salmon, rice, avocado, edamame", priceCents: 1450 },
          { name: "Chicken Teriyaki Bowl", description: "Grilled chicken, rice, teriyaki sauce", priceCents: 1295 },
          { name: "Tofu Bowl", description: "Crispy tofu, rice, greens", priceCents: 1195 },
        ],
      },
      {
        category: "Sides",
        items: [
          { name: "Miso Soup", description: "Tofu, wakame, spring onion", priceCents: 395 },
          { name: "Edamame", description: "Sea salt", priceCents: 450 },
        ],
      },
    ],
  },
  {
    name: "Green Garden",
    ownerEmail: "owner1@example.com",
    isOpen: false,
    menu: [
      {
        category: "Salads",
        items: [
          { name: "Caesar Salad", description: "Romaine, parmesan, croutons", priceCents: 995 },
          { name: "Quinoa Salad", description: "Quinoa, roasted vegetables, feta", priceCents: 1095 },
        ],
      },
    ],
  },
];

const client = await pool.connect();

// Runs an INSERT ... RETURNING id and returns the new id.
async function insert(sql: string, params: unknown[]): Promise<number> {
  const { rows } = await client.query<{ id: number }>(sql, params);
  return rows[0]!.id;
}

try {
  await client.query("BEGIN");

  // RESTART IDENTITY resets the id counters, so the demo IDs are always the same.
  await client.query(`
    TRUNCATE users, restaurants, menu_categories, menu_items,
             orders, order_items, order_status_events
    RESTART IDENTITY CASCADE
  `);

  const userIds = new Map<string, number>();
  for (const user of users) {
    const passwordHash = await hashPassword(DEMO_PASSWORD);
    const id = await insert(
      "INSERT INTO users (email, password_hash, name, role) VALUES ($1, $2, $3, $4) RETURNING id",
      [user.email, passwordHash, user.name, user.role],
    );
    userIds.set(user.email, id);
  }

  for (const restaurant of restaurants) {
    const restaurantId = await insert(
      "INSERT INTO restaurants (owner_id, name, is_open) VALUES ($1, $2, $3) RETURNING id",
      [userIds.get(restaurant.ownerEmail), restaurant.name, restaurant.isOpen],
    );

    for (const [categoryIndex, category] of restaurant.menu.entries()) {
      const categoryId = await insert(
        "INSERT INTO menu_categories (restaurant_id, name, sort_order) VALUES ($1, $2, $3) RETURNING id",
        [restaurantId, category.category, categoryIndex],
      );

      for (const [itemIndex, item] of category.items.entries()) {
        await insert(
          `INSERT INTO menu_items (category_id, name, description, price_cents, is_available, sort_order)
           VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
          [categoryId, item.name, item.description, item.priceCents, item.isAvailable ?? true, itemIndex],
        );
      }
    }
  }

  await client.query("COMMIT");
  console.log(`Seeded ${users.length} users and ${restaurants.length} restaurants.`);
  console.log(`Every demo user's password is "${DEMO_PASSWORD}".`);
} catch (err) {
  await client.query("ROLLBACK");
  throw err;
} finally {
  client.release();
  await pool.end();
}
