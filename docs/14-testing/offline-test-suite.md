# Offline Test Suite

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.2.0
> **Last updated:** 2026-08-19
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

## 2. Harness — corrected Sprint 41, now that it's actually built

Building this suite for real (backlog.md M4 item 6) found the fault-injecting-proxy framing above
was only ever needed for *some* of [test-plan.md](../13-offline-sync/test-plan.md)'s cases, not all
of them: replay-safety, order-independence, and per-operation partial-failure isolation are all
**server-observable properties** — does a second push of an already-committed operation return the
same result; does the final state after N devices' operations sync in any order come out identical;
does one rejected operation in a batch leave every other operation in that batch unaffected — none
of which need a real severed network connection to prove. [Sprint 40](../17-sprints/sprint-40.md)'s
own `apps/web/integration-tests/` harness (a real, ephemeral `postgres:15` container, seeded per
run) already provides everything §1's idempotent-replay cases and §2's 2-device-scale
concurrent-composition cases need — `pushOperations`/`pullX` (`sync/service.ts`) called in-process
against that real database, the exact same functions every entity's own direct endpoint calls, no
HTTP layer and **no toxiproxy** required for this subset. `apps/web/integration-tests/setup/`
gained `seed-second-user.ts` (a second identity under the same tenant/store, standing in for a
second device — no `devices` table exists to model against, [tenant-isolation.md
§2](../12-security/tenant-isolation.md#2-what-every-table-means-precisely-restated-as-a-checklist)'s
already-named gap) alongside `seed-tenant.ts`.

A genuine fault-injecting proxy (toxiproxy or equivalent) is still the right tool for the cases this
subset *doesn't* cover: a live client's retry/backoff scheduling after a truly severed connection,
which is mobile SyncEngine behaviour needing a live server + proxy in front of it, not a Vitest
integration test against `apps/web` — see
[test-plan.md §3](../13-offline-sync/test-plan.md#3-the-10-named-failure-scenarios--one-test-per-row-of-failure-scenariosmd-1)'s
Sprint 41 correction for the full per-scenario venue breakdown. That harness remains a real, tracked
gap, not built this sprint — materially larger scope than backlog item 6's own estimate, the same
kind of deferral Sprint 40 named for the Realtime extension.

## 3. CI placement — as actually built

| Test group | Runs | Why |
| --- | --- | --- |
| Idempotent-replay, all 3 cases ([test-plan.md §1](../13-offline-sync/test-plan.md#1-idempotent-replay-tests)) | Every pull request (`fast-integration` job, no path filter — the same reasoning `tenant-isolation.md §3` already gives for the cross-tenant suite) | Fast (seconds), deterministic — cheap enough to run on every relevant change |
| Concurrent-composition, all 4 non-fuzzed cases ([test-plan.md §2](../13-offline-sync/test-plan.md#2-concurrent-composition-tests)) | Every pull request, same job | Also fast and deterministic |
| Server-testable failure-scenario subset (1 of 10 rows — "server rejects one item in a batch") | Every pull request, same job | Fast, deterministic; the other 9 rows are mobile-only, need infra not yet built, or already need no test — [test-plan.md §3](../13-offline-sync/test-plan.md#3-the-10-named-failure-scenarios--one-test-per-row-of-failure-scenariosmd-1)'s Sprint 41 correction |
| Concurrent-composition, N-device fuzzed (100 runs) | Written (`sync-concurrent-composition.nightly.test.ts`), not yet CI-wired — backlog item 7 (Nightly CI pipeline) points a `nightly.yml` at it | Non-deterministic by design (randomised interleaving); locally confirmed 100/100 passing in ~90 seconds, well past the PR-feedback budget [ci-pipeline.md](ci-pipeline.md) sets for every single commit |

This mirrors [tenant-isolation.md §3](../12-security/tenant-isolation.md#3-ci-enforcement--not-a-one-time-proof)'s
precedent exactly: fast, deterministic checks gate every relevant PR (added to the same
`fast-integration` job Sprint 40 built, not a new one); slower, inherently randomised, or
infra-blocked checks gate nightly builds and release candidates, never silently skipped, only
re-timed or explicitly named as deferred.

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
| 0.2.0 | 2026-08-19 | Sprint 41 (backlog.md M4 item 6) built the PR-gated fast subset — idempotent-replay (3/3), concurrent-composition non-fuzzed (4/4), and 1 of the 10 failure-scenario rows — all against a real Postgres connection with no toxiproxy needed, reusing Sprint 40's `fast-integration` job/harness rather than new infra. §2/§3 rewritten to match. N-device fuzzed composition written but not yet CI-wired (item 7); a genuine mobile-side/full-Supabase-stack-dependent gap named, not built, for the remaining failure-scenario rows. |
