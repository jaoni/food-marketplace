// SQL only. No HTTP and no business rules here.
import { pool } from "../db/pool.ts";
import type { Restaurant } from "../types.ts";

export async function findAll(): Promise<Restaurant[]> {
  const { rows } = await pool.query<Restaurant>(
    `SELECT id, name, is_open AS "isOpen" FROM restaurants ORDER BY id`,
  );
  return rows;
}

export async function findById(id: number): Promise<Restaurant | null> {
  const { rows } = await pool.query<Restaurant>(
    `SELECT id, name, is_open AS "isOpen" FROM restaurants WHERE id = $1`,
    [id],
  );
  return rows[0] ?? null;
}
