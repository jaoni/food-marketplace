import { Pool, types, type PoolClient } from "pg";
import { config } from "../config.ts";

// Postgres bigint values arrive as strings by default because they can exceed
// JavaScript's safe integer range. Our IDs never get that big, so use numbers.
types.setTypeParser(types.builtins.INT8, (value) => Number(value));

// A pool keeps a few open connections and lends one to each query.
export const pool = new Pool({
  connectionString: config.databaseUrl,
  // Give up after 5s if Postgres doesn't answer, instead of hanging forever.
  connectionTimeoutMillis: 5_000,
});

// Without a listener, an idle connection dropping (e.g. Postgres restarting)
// would crash the whole server.
pool.on("error", (err) => {
  console.error("Postgres pool error:", err);
});

// Runs fn inside a transaction: either all of its queries take effect or none
// do. fn must run its queries on the `tx` client it receives, not on the pool,
// because a transaction belongs to one connection.
export async function withTransaction<T>(fn: (tx: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release(); // give the connection back to the pool
  }
}
