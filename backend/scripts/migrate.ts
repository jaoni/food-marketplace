import { config } from "../src/config.ts";
import { runMigrations } from "../src/db/migrate.ts";

const applied = await runMigrations(config.databaseUrl);

if (applied.length === 0) {
  console.log("Database is up to date.");
} else {
  for (const file of applied) console.log(`Applied ${file}`);
}
