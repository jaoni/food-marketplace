import express from "express";

type Restaurant = {
  id: number;
  name: string;
  isOpen: boolean;
};

const restaurants: Restaurant[] = [
  { id: 1, name: "Bella Napoli", isOpen: true },
  { id: 2, name: "Tokyo Bowl", isOpen: true },
  { id: 3, name: "Green Garden", isOpen: false },
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

const port = Number(process.env.PORT ?? 3000);

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});