import { existsSync } from "node:fs";

// Load .env into process.env. Variables that are already set (for example by
// the test runner) are not overwritten.
if (existsSync(".env")) {
  process.loadEnvFile(".env");
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing environment variable ${name}. Copy .env.example to .env.`);
  }
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 3000),
  databaseUrl: requireEnv("DATABASE_URL"),
};
