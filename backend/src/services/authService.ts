// Business rules. Knows nothing about HTTP (req/res) or SQL.
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { config } from "../config.ts";
import { ConflictError, ForbiddenError, UnauthorizedError } from "../errors.ts";
import * as userRepository from "../repositories/userRepository.ts";
import { ROLES, type AuthUser, type Role, type User } from "../types.ts";

const TOKEN_LIFETIME = "1h";

// Admins can't sign themselves up; they are created by the seed script.
const SELF_REGISTER_ROLES: Role[] = ["customer", "restaurant_owner", "courier"];

export type AuthResult = { token: string; user: User };

export function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, config.bcryptRounds);
}

export async function register(input: {
  email: string;
  password: string;
  name: string;
  role: Role;
}): Promise<AuthResult> {
  if (!SELF_REGISTER_ROLES.includes(input.role)) {
    throw new ForbiddenError(`You can't register as ${input.role}`);
  }

  const user = await userRepository.insert({
    email: input.email,
    passwordHash: await hashPassword(input.password),
    name: input.name,
    role: input.role,
  });
  if (!user) {
    throw new ConflictError("Email is already registered");
  }

  return { token: signToken(user), user };
}

export async function login(input: { email: string; password: string }): Promise<AuthResult> {
  const found = await userRepository.findByEmailWithPasswordHash(input.email);

  // Same answer for "no such email" and "wrong password": don't reveal which part was wrong.
  if (!found || !(await bcrypt.compare(input.password, found.passwordHash))) {
    throw new UnauthorizedError("Invalid email or password");
  }

  const { passwordHash, ...user } = found; // never send the hash back
  return { token: signToken(user), user };
}

export async function getUser(id: number): Promise<User> {
  const user = await userRepository.findById(id);
  if (!user) {
    throw new UnauthorizedError("User no longer exists");
  }
  return user;
}

// A JWT is a signed JSON payload. Anyone can read it, but only someone with
// JWT_SECRET can create one that verifyToken accepts.
export function signToken(user: AuthUser): string {
  return jwt.sign({ role: user.role }, config.jwtSecret, {
    subject: String(user.id),
    expiresIn: TOKEN_LIFETIME,
    algorithm: "HS256",
  });
}

const tokenPayload = z.object({
  sub: z.string().regex(/^\d+$/),
  role: z.enum(ROLES),
});

export function verifyToken(token: string): AuthUser {
  let payload: unknown;
  try {
    // Checks the signature and expiry. Fixing the algorithm stops attackers
    // from picking a weaker one.
    payload = jwt.verify(token, config.jwtSecret, { algorithms: ["HS256"] });
  } catch {
    throw new UnauthorizedError("Invalid or expired token");
  }

  const parsed = tokenPayload.safeParse(payload);
  if (!parsed.success) {
    throw new UnauthorizedError("Invalid or expired token");
  }
  return { id: Number(parsed.data.sub), role: parsed.data.role };
}
