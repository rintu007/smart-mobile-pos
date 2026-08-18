import { defineConfig } from "vitest/config";
import path from "node:path";

// Sprint 40 (backlog.md M4 item 5) — a separate config from vitest.config.ts, deliberately: this
// suite needs a real Postgres connection (a `services:` container in CI, per pr.yml's new
// `fast-integration` job) and runs noticeably slower than the fully-mocked unit suite, so it is
// never picked up by the default `pnpm test` / `unit-tests` CI job.
export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    environment: "node",
    include: ["integration-tests/**/*.test.ts"],
    // Sprint 41 (backlog.md M4 item 6) — `*.nightly.test.ts` is deliberately excluded from the
    // default (PR-blocking) run: offline-test-suite.md §3 places non-deterministic, 100-run fuzz
    // suites on the nightly/release-candidate tier, not every PR. Backlog item 7 (Nightly CI
    // pipeline) points a separate nightly config at this same pattern.
    exclude: ["**/node_modules/**", "integration-tests/**/*.nightly.test.ts"],
    // Real network/DB round trips per assertion (19 tables x 3 attempts x 2 directions) — the
    // default 5s per-test timeout is too tight for the full-suite single test this file uses.
    testTimeout: 60_000,
  },
});
