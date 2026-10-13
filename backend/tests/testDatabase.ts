// The tests use their own database, so they never touch your dev data.
// Override with the TEST_DATABASE_URL env var if needed.
export const TEST_DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? "postgres://food:food@localhost:5432/food_test";
