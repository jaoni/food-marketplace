import { readdir, readFile } from "node:fs/promises";
import { Client } from "pg";

const MIGRATIONS_DIR = new URL("../../migrations/", import.meta.url);

// Runs every migrations/*.sql file that hasn't been applied yet, in filename
// order, and records it in schema_migrations. Each file runs in a transaction,
// so a failing migration leaves nothing half-applied.
// Returns the filenames that were applied.
export async function runMigrations(databaseUrl: string): Promise<string[]> {
  const client = new Client({ connectionString: databaseUrl });
  await client.connect();

  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename   text PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      )
    `);

    const { rows } = await client.query<{ filename: string }>(
      "SELECT filename FROM schema_migrations",
    );
    const alreadyApplied = new Set(rows.map((row) => row.filename));

    const files = (await readdir(MIGRATIONS_DIR)).filter((f) => f.endsWith(".sql")).sort();
    const applied: string[] = [];

    for (const file of files) {
      if (alreadyApplied.has(file)) continue;

      const sql = await readFile(new URL(file, MIGRATIONS_DIR), "utf8");
      try {
        await client.query("BEGIN");
        await client.query(sql);
        await client.query("INSERT INTO schema_migrations (filename) VALUES ($1)", [file]);
        await client.query("COMMIT");
      } catch (err) {
        await client.query("ROLLBACK");
        throw new Error(`Migration ${file} failed`, { cause: err });
      }
      applied.push(file);
    }

    return applied;
  } finally {
    await client.end();
  }
}
