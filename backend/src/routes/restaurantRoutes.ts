// HTTP only: read the request, call a service, send the response.
import { Router } from "express";
import * as restaurantService from "../services/restaurantService.ts";
import { parseId } from "./params.ts";

export const restaurantRoutes = Router();

restaurantRoutes.get("/", async (req, res) => {
  res.json(await restaurantService.listRestaurants());
});

restaurantRoutes.get("/:id", async (req, res) => {
  const id = parseId(req.params.id, "Restaurant");
  res.json(await restaurantService.getRestaurant(id));
});

restaurantRoutes.get("/:id/menu", async (req, res) => {
  const id = parseId(req.params.id, "Restaurant");
  res.json(await restaurantService.getMenu(id));
});
