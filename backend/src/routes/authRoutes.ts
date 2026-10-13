// HTTP only: read the request, call a service, send the response.
import { Router } from "express";
import { z } from "zod";
import { requireAuth } from "../middleware/auth.ts";
import * as authService from "../services/authService.ts";
import { ROLES } from "../types.ts";

export const authRoutes = Router();

// zod checks the shape of the JSON body. parse() throws a ZodError on bad
// input, which the error handler turns into a 400 response.
const registerBody = z.object({
  email: z.email().toLowerCase(),
  password: z.string().min(8).max(72), // bcrypt only uses the first 72 bytes
  name: z.string().trim().min(1).max(100),
  role: z.enum(ROLES).default("customer"),
});

const loginBody = z.object({
  email: z.email().toLowerCase(),
  password: z.string().min(1),
});

authRoutes.post("/register", async (req, res) => {
  const input = registerBody.parse(req.body);
  res.status(201).json(await authService.register(input));
});

authRoutes.post("/login", async (req, res) => {
  const input = loginBody.parse(req.body);
  res.json(await authService.login(input));
});

authRoutes.get("/me", requireAuth, async (req, res) => {
  res.json(await authService.getUser(req.user!.id));
});
