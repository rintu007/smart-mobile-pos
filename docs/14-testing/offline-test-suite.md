# Offline Test Suite

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** QA Lead / Principal Flutter Engineer
> **Approved by:** _pending_

The adversarial synchronisation suite from Phase 13 — this document does not redefine its test
cases (fully specified in [13-offline-sync/test-plan.md](../13-offline-sync/test-plan.md)); it
supplies the one thing that document explicitly deferred: **how it actually runs in CI.**

---

## 1. What runs here — a pointer, not a duplicate

Every test case in [test-plan.md §§1–3](../13-offline-sync/test-plan.md#1-idempotent-replay-tests)
(idempotent-replay, concurrent-composition, and the 10 named failure scenarios) is this suite's
content in full. Restating them here would create a second copy that could silently drift from the
original — this document is deliberately just the execution wrapper.

## 2. Harness

Per [test-plan.md §4](../13-offline-sync/test-plan.md#4-failure-injection-tooling), a
fault-injecting proxy sits between the integration-test client and a real test API instance
(confirmed at Phase 18 as **toxiproxy** or an equivalent free/open-source alternative, per this
documentation set's standing practice of confirming specific tooling only when it's about to be
used). The suite runs as **integration-level tests** ([test-pyramid.md §3](test-pyramid.md#3-where-phase-12-and-phase-13s-suites-sit)),
against a real, ephemeral test database seeded per run — never against a shared, stateful test
environment, so a failed run's residue can never cause a false pass or false failure in the next one.

## 3. CI placement

| Test group | Runs | Why |
| --- | --- | --- |
| Idempotent-replay ([test-plan.md §1](../13-offline-sync/test-plan.md#1-idempotent-replay-tests)) | Every pull request touching `sync/*`, `sales/*`, `returns/*`, `inventory/*` modules | Fast (seconds), deterministic — cheap enough to run on every relevant change |
| Concurrent-composition, 2-device case ([test-plan.md §2](../13-offline-sync/test-plan.md#2-concurrent-composition-tests)) | Every pull request touching the same modules | Also fast and deterministic |
| Concurrent-composition, N-device fuzzed (100 runs) | Nightly, and required (blocking) on any release-candidate build | Non-deterministic by design (randomised interleaving) — 100 runs takes materially longer than the PR-feedback budget in [ci-pipeline.md](ci-pipeline.md) should cost every single commit |
| All 10 named failure scenarios ([test-plan.md §3](../13-offline-sync/test-plan.md#3-the-10-named-failure-scenarios--one-test-per-row-of-failure-scenariosmd-1)) | Every pull request touching the Sync Engine itself; nightly in full otherwise | Some scenarios (app-killed-mid-sync, connectivity-lost-mid-batch) are cheap; others (schema-version-mismatch-after-update) are slower to set up — split by cost, not by importance |

This mirrors [tenant-isolation.md §3](../12-security/tenant-isolation.md#3-ci-enforcement--not-a-one-time-proof)'s
precedent exactly: fast, deterministic checks gate every relevant PR; slower or inherently
randomised checks gate nightly builds and release candidates, never silently skipped, only
re-timed.

## 4. What a failure means

Per this phase's own rule (mirroring [Phase 12](../12-security/README.md)'s security stance): a
failure in this suite **blocks a merge to main** (for the PR-gated subset) or **blocks a release**
(for the nightly/release-gated subset) — there is no "known flaky, ignore" allowance for this
specific suite, because the entire premise of [13-offline-sync](../13-offline-sync/README.md) is
that these failure modes are silent and easy to normalise away exactly by being told "it's probably
just flaky."

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Execution wrapper around Phase 13's test-plan.md: toxiproxy-based harness, PR-vs-nightly CI placement split by cost not importance, no flaky-test exception. |
