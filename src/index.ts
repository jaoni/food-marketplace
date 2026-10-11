import express from "express";

type Restaurant = {
  id: number;
  name: string;
  isOpen: boolean;
};

type MenuCategory = {
  id: number;
  restaurantId: number;
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

const restaurants: Restaurant[] = [
  { id: 1, name: "Bella Napoli", isOpen: true },
  { id: 2, name: "Tokyo Bowl", isOpen: true },
  { id: 3, name: "Green Garden", isOpen: false },
];

const menuCategories: MenuCategory[] = [
  { id: 1, restaurantId: 1, name: "Pizza" },
  { id: 2, restaurantId: 1, name: "Drinks" },
  { id: 3, restaurantId: 2, name: "Bowls" },
  { id: 4, restaurantId: 2, name: "Sides" },
  { id: 5, restaurantId: 3, name: "Salads" },
];

const menuItems: MenuItem[] = [
  { id: 1, categoryId: 1, name: "Margherita", description: "Tomato, mozzarella, basil", priceCents: 1050, isAvailable: true },
  { id: 2, categoryId: 1, name: "Diavola", description: "Tomato, mozzarella, spicy salami", priceCents: 1250, isAvailable: true },
  { id: 3, categoryId: 1, name: "Quattro Formaggi", description: "Four cheeses", priceCents: 1350, isAvailable: false },
  { id: 4, categoryId: 2, name: "Lemonade", description: "Homemade", priceCents: 350, isAvailable: true },
  { id: 5, categoryId: 2, name: "Sparkling Water", description: "500 ml", priceCents: 250, isAvailable: true },
  { id: 6, categoryId: 3, name: "Salmon Poke", description: "Salmon, rice, avocado, edamame", priceCents: 1450, isAvailable: true },
  { id: 7, categoryId: 3, name: "Chicken Teriyaki Bowl", description: "Grilled chicken, rice, teriyaki sauce", priceCents: 1295, isAvailable: true },
  { id: 8, categoryId: 3, name: "Tofu Bowl", description: "Crispy tofu, rice, greens", priceCents: 1195, isAvailable: true },
  { id: 9, categoryId: 4, name: "Miso Soup", description: "Tofu, wakame, spring onion", priceCents: 395, isAvailable: true },
  { id: 10, categoryId: 4, name: "Edamame", description: "Sea salt", priceCents: 450, isAvailable: true },
  { id: 11, categoryId: 5, name: "Caesar Salad", description: "Romaine, parmesan, croutons", priceCents: 995, isAvailable: true },
  { id: 12, categoryId: 5, name: "Quinoa Salad", description: "Quinoa, roasted vegetables, feta", priceCents: 1095, isAvailable: true },
];

const app = express();

app.get("/hello", (req, res) => {
  res.json({ message: "Hello from your first server!" });
});

app.get("/restaurants", (req, res) => {
  res.json(restaurants);
});

app.get("/restaurants/:id", (req, res) => {
  const id = Number(req.params.id);
  const restaurant = restaurants.find((r) => r.id === id);

  if (!restaurant) {
    res.status(404).json({ error: "Restaurant not found" });
    return;
  }

  res.json(restaurant);
});

app.get("/restaurants/:id/menu", (req, res) => {
  const id = Number(req.params.id);
  const restaurant = restaurants.find((r) => r.id === id);

  if (!restaurant) {
    res.status(404).json({ error: "Restaurant not found" });
    return;
  }

  const categories = menuCategories
    .filter((category) => category.restaurantId === id)
    .map((category) => ({
      id: category.id,
      name: category.name,
      items: menuItems.filter((item) => item.categoryId === category.id),
    }));

  res.json({ restaurantId: id, categories });
});

const port = Number(process.env.PORT ?? 3000);

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});