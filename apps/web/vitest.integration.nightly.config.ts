import { defineConfig } from "vitest/config";
import path from "node:path";

// Sprint 42 (backlog.md M4 item 7) — the nightly-only counterpart to vitest.integration.config.ts,
// deliberately a separate config rather than an `include` flag on the existing one: this file picks
// up exactly `*.nightly.test.ts` (currently just sync-concurrent-composition.nightly.test.ts, the
// N-device fuzzed case Sprint 41 wrote and held back from `pr.yml`), and nothing else — running the
// default suite's ~84 fast cases again nightly would add real minutes for zero new signal, since
// they already gate every PR.
export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    environment: "node",
    include: ["integration-tests/**/*.nightly.test.ts"],
    // The fuzz suite itself sets a 10-minute per-test timeout; this is the outer Vitest default for
    // any future nightly-only case that doesn't set its own.
    testTimeout: 120_000,
  },
});
