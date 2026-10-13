// SQL only. No HTTP and no business rules here.
import { pool } from "../db/pool.ts";
import type { Role, User } from "../types.ts";

// Returns null if the email is already taken (ON CONFLICT DO NOTHING inserts
// nothing and returns no row, instead of throwing a unique-violation error).
export async function insert(user: {
  email: string;
  passwordHash: string;
  name: string;
  role: Role;
}): Promise<User | null> {
  const { rows } = await pool.query<User>(
    `INSERT INTO users (email, password_hash, name, role)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (email) DO NOTHING
     RETURNING id, email, name, role, created_at AS "createdAt"`,
    [user.email, user.passwordHash, user.name, user.role],
  );
  return rows[0] ?? null;
}

export async function findById(id: number): Promise<User | null> {
  const { rows } = await pool.query<User>(
    `SELECT id, email, name, role, created_at AS "createdAt" FROM users WHERE id = $1`,
    [id],
  );
  return rows[0] ?? null;
}

// The only query that reads password_hash. Used for login.
export async function findByEmailWithPasswordHash(
  email: string,
): Promise<(User & { passwordHash: string }) | null> {
  const { rows } = await pool.query<User & { passwordHash: string }>(
    `SELECT id, email, name, role, created_at AS "createdAt", password_hash AS "passwordHash"
     FROM users WHERE email = $1`,
    [email],
  );
  return rows[0] ?? null;
}
