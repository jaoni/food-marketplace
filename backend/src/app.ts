import express from "express";
import { errorHandler, notFoundHandler } from "./middleware/errorHandler.ts";
import { authRoutes } from "./routes/authRoutes.ts";
import { orderRoutes } from "./routes/orderRoutes.ts";
import { restaurantRoutes } from "./routes/restaurantRoutes.ts";

// Builds the app without starting it, so tests can send requests to it directly.
export function createApp() {
  const app = express();

  // Parse JSON request bodies into req.body.
  app.use(express.json());

  app.get("/hello", (req, res) => {
    res.json({ message: "Hello from your first server!" });
  });

  app.use("/auth", authRoutes);
  app.use("/restaurants", restaurantRoutes);
  app.use("/orders", orderRoutes);

  // These two must come after all routes.
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
