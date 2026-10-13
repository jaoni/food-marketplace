import { Client } from "pg";
import { runMigrations } from "../src/db/migrate.ts";
import { TEST_DATABASE_URL } from "./testDatabase.ts";

// Runs once before all test files: creates the test database if it doesn't
// exist yet, then applies any new migrations to it.
export default async function setup() {
  await createDatabaseIfMissing(TEST_DATABASE_URL);
  await runMigrations(TEST_DATABASE_URL);
}

async function createDatabaseIfMissing(databaseUrl: string) {
  const url = new URL(databaseUrl);
  const name = url.pathname.slice(1);

  // Connect to the built-in "postgres" database to create ours.
  url.pathname = "/postgres";
  const client = new Client({ connectionString: url.toString(), connectionTimeoutMillis: 5_000 });
  await client.connect();

  try {
    const { rowCount } = await client.query("SELECT 1 FROM pg_database WHERE datname = $1", [name]);
    if (rowCount === 0) {
      // A database name can't be a $1 parameter, so escape it instead.
      await client.query(`CREATE DATABASE ${client.escapeIdentifier(name)}`);
    }
  } finally {
    await client.end();
  }
}
