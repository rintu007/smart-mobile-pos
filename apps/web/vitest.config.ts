import { defineConfig } from "vitest/config";
import path from "node:path";

export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    environment: "node",
    setupFiles: ["./vitest.setup.ts"],
    // `integration-tests/` needs a real Postgres connection (docker `services:` in CI) and is run
    // separately via `test:integration` (vitest.integration.config.ts) — never by this default
    // config, which every other unit test (fully mocked, no DB) already relies on running without
    // one. Sprint 40 (backlog.md M4 item 5).
    exclude: ["**/node_modules/**", "integration-tests/**"],
  },
});
