import { afterAll } from "vitest";
import { pool } from "../src/db/pool.ts";

// Close the database connections when a test file is done, so it can exit.
afterAll(async () => {
  await pool.end();
});
