import type { RequestHandler } from "express";
import { ForbiddenError, UnauthorizedError } from "../errors.ts";
import { verifyToken } from "../services/authService.ts";
import type { AuthUser, Role } from "../types.ts";

// Teach TypeScript that Express requests can carry a `user` property
// (this is called "declaration merging").
declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

// Reads "Authorization: Bearer <token>", verifies the token, and sets req.user.
// Routes that run after this middleware can rely on req.user being set.
export const requireAuth: RequestHandler = (req, res, next) => {
  const [scheme, token] = (req.get("Authorization") ?? "").split(" ");
  if (scheme !== "Bearer" || !token) {
    throw new UnauthorizedError("Missing or malformed Authorization header");
  }
  req.user = verifyToken(token);
  next();
};

// Use after requireAuth. Only lets the listed roles through.
export function requireRole(...roles: Role[]): RequestHandler {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      throw new ForbiddenError("Your role is not allowed to do this");
    }
    next();
  };
}
