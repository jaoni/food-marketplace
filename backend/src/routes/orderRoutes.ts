// HTTP only: read the request, call a service, send the response.
import { Router } from "express";
import { z } from "zod";
import { BadRequestError } from "../errors.ts";
import { requireAuth, requireRole } from "../middleware/auth.ts";
import * as orderService from "../services/orderService.ts";
import { ORDER_STATUSES } from "../types.ts";
import { parseId } from "./params.ts";

export const orderRoutes = Router();

// Every /orders endpoint needs a logged-in user.
orderRoutes.use(requireAuth);

// Note what's NOT here: prices or totals. zod drops any keys that aren't in
// the schema, so a priceCents sent by the app is simply ignored.
const placeOrderBody = z.object({
  restaurantId: z.int().positive(),
  items: z
    .array(
      z.object({
        menuItemId: z.int().positive(),
        quantity: z.int().min(1).max(99),
      }),
    )
    .min(1)
    .max(50),
  deliveryAddress: z.string().trim().min(1).max(500),
});

// The app makes up a new key (e.g. a UUID) for each order attempt and sends
// the same key again when it retries that attempt.
orderRoutes.post("/", requireRole("customer"), async (req, res) => {
  const idempotencyKey = req.get("Idempotency-Key");
  if (!idempotencyKey) {
    throw new BadRequestError("Missing Idempotency-Key header");
  }
  if (idempotencyKey.length > 255) {
    throw new BadRequestError("Idempotency-Key must be at most 255 characters");
  }

  const input = placeOrderBody.parse(req.body);
  const { order, created } = await orderService.placeOrder(req.user!.id, idempotencyKey, input);

  // 201 Created for a new order; 200 OK when a retry returns the existing one.
  res.status(created ? 201 : 200).json(order);
});

// Query string values are always strings; z.coerce turns "5" into 5.
const listOrdersQuery = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(20),
  cursor: z.string().optional(),
});

orderRoutes.get("/", async (req, res) => {
  const page = listOrdersQuery.parse(req.query);
  res.json(await orderService.listOrders(req.user!, page));
});

orderRoutes.get("/:id", async (req, res) => {
  const orderId = parseId(req.params.id, "Order");
  res.json(await orderService.getOrder(req.user!, orderId));
});

const changeStatusBody = z.object({
  status: z.enum(ORDER_STATUSES),
});

orderRoutes.patch("/:id/status", async (req, res) => {
  const orderId = parseId(req.params.id, "Order");
  const { status } = changeStatusBody.parse(req.body);
  res.json(await orderService.changeStatus(req.user!, orderId, status));
});
