import { defineConfig } from "vitest/config";
import { TEST_DATABASE_URL } from "./tests/testDatabase.ts";

export default defineConfig({
  test: {
    // Runs once before all tests: creates and migrates the test database.
    globalSetup: ["tests/globalSetup.ts"],
    // Runs inside every test file.
    setupFiles: ["tests/setup.ts"],
    // Environment for the code under test. These win over values in .env.
    env: {
      DATABASE_URL: TEST_DATABASE_URL,
      JWT_SECRET: "test-secret",
      BCRYPT_ROUNDS: "4", // the minimum, so hashing in tests is fast
    },
    // All test files share one database, so run them one at a time.
    fileParallelism: false,
  },
});
