import { Pool, types } from "pg";
import { config } from "../config.ts";

// Postgres bigint values arrive as strings by default because they can exceed
// JavaScript's safe integer range. Our IDs never get that big, so use numbers.
types.setTypeParser(types.builtins.INT8, (value) => Number(value));

// A pool keeps a few open connections and lends one to each query.
export const pool = new Pool({ connectionString: config.databaseUrl });

// Without a listener, an idle connection dropping (e.g. Postgres restarting)
// would crash the whole server.
pool.on("error", (err) => {
  console.error("Postgres pool error:", err);
});
