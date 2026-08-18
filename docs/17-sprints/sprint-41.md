# Sprint 41

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (backlog item 6 — offline adversarial
> suite, CI-enforced)
> **Status:** Closed — M4 item 6 done. M4 now has items 7–9 remaining.

## Goal

Build the automated, CI-enforced adversarial sync-engine suite
[test-plan.md](../13-offline-sync/test-plan.md) has specified since Phase 13 but never had running
code: idempotent-replay, concurrent-composition, and the 10 named failure scenarios, wired into
`pr.yml` as a blocking stage for the fast, deterministic subset — the same "not by inspection"
instrument Sprint 40 built for cross-tenant isolation, applied here to sync-engine correctness.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Idempotent-replay + 2-device concurrent-composition as a fast `pr.yml`-blocking stage; N-device fuzzed composition + the 10 named failure scenarios as the slower, nightly-gated subset | Cross-cutting (Sync Engine, CI/DevOps) | 4 | — |

## Design decisions, found while writing the spec

1. **No toxiproxy or new CI infrastructure was actually needed for the PR-gated fast subset.**
   Replay-safety, order-independence, and per-operation partial-failure isolation are all
   server-observable properties — provable by calling `pushOperations`/`pullX`
   (`sync/service.ts`) in-process against a real database, the same functions every entity's own
   direct endpoint already calls. Reused Sprint 40's `fast-integration` job/`postgres:15` container
   rather than standing up a fault-injecting proxy or a live HTTP server — a fault-injecting proxy
   remains the right tool for a *client's* retry/backoff behaviour after a genuinely severed
   connection, which is mobile SyncEngine territory, not this suite.
2. **A real, previously-unverified concurrency gap, found by the first suite in this project's
   history to test genuinely overlapping requests, not sequential ones.** `pos/service.ts`'s
   `createSale` and `returns/service.ts`'s `createReturn`/`approveReturn` each had a read-then-write
   idempotent-replay check — correct for a sequential retry, but a real race under `Promise.all`
   concurrency: two overlapping pushes of the same id could both pass the existence check before
   either committed, and the losing call threw a raw Postgres unique-violation instead of the
   idempotent result. `sale.create`/`return.create`/`return.approve`'s own code comments explicitly
   assumed this couldn't happen ("this function itself is only ever called once... so no upsert is
   needed here") — an assumption the new suite disproved live. Fixed by catching the specific
   violation and re-fetching, the same catch-and-translate shape already established for
   `PHONE_ALREADY_ASSIGNED`/`BARCODE_ALREADY_ASSIGNED`. `product.create`/`customer.create` never had
   this gap — both already used an id-keyed `upsert`.
3. **`seed-tenant.ts` (Sprint 40) never exposed the seeded owner's `authUserId`** — only `userId`
   (the internal `users.id`), so no test built on it could call any service function needing a real
   session identity (`pushOperations` and everything it dispatches to). Never noticed in Sprint 40,
   whose suite only ever queried raw SQL directly. Fixed additively (a new field on the returned
   fixture, no removal) — the first sprint to actually need it.
4. **`test-plan.md §3`'s "one test per row" (10 named failure scenarios) conflated three different
   test venues**, only discovered while actually trying to build all 10 against real infrastructure:
   server-testable (1 row — "server rejects one item in a batch," built), mobile-only (`outbound_queue`/
   Drift/app-process lifecycle — app killed, device rebooted, storage full, schema version mismatch),
   needing the full local Supabase CLI stack (token expiry, the same gap Sprint 40 named for
   Realtime), and already resolved on paper with no code test needed (device clock wrong, same
   account on two devices, queue older than retention). Reclassified in `test-plan.md §3`, not
   silently built as fakes or silently dropped.
5. **`idempotency.md §2`'s "`idempotency_keys` lookup" mechanism was aspirational, not built** —
   confirmed by cross-checking `schema.prisma` (no such table) and Sprint 33's own dated correction
   (the one column that could have backed it, `client_operation_id`, was dropped in favour of `id`
   alone). Corrected to describe the real, built mechanism: id-keyed upsert for creations, a plain
   status check for state transitions.
6. **`test-plan.md §2`'s N-device fuzzed row names "opening/sale/adjustment movements," but no
   `adjustment` sync-push operation type exists** — `POST /stock-movements` (the only way to create
   an `adjustment` movement) is a direct, online-only endpoint, never wired into `sync/schema.ts`'s
   operation-type union. Fuzzed across the two movement types that are actually sync-pushable
   (`opening` via `product.create`'s `initial_quantity`, `sale` via `sale.create`) — corrected, not
   silently substituted.

## Capacity check

4 person-days against estimate — landed on it. The concurrency-race fix (#2) and the `seed-tenant.ts`
gap (#3) were both real, unanticipated at decomposition time, resolved within the same pass.

## Reserved capacity

- [x] Defect capacity reserved: the `sale.create`/`return.create`/`return.approve` concurrency race
      (#2 above) was a genuine pre-existing bug, found and fixed in the same pass, not deferred.
- [x] Documentation capacity reserved: `idempotency.md`, `test-plan.md`, `offline-test-suite.md`,
      `ci-pipeline.md`, `ci-workflows.md`, backlog.md, this sprint doc, implementation-log, README
      bumps.

## Risks

- **None new for production data** — the suite runs against the same ephemeral, per-CI-run database
  Sprint 40's suite already uses, never the shared production Supabase project; the two service-layer
  fixes are additive (a catch clause around an existing write, no schema change) and were verified
  against a real database locally before being wired into CI.
- **Genuinely deferred, not silently dropped**: a true toxiproxy-based client-retry harness (mobile
  SyncEngine, needs a live server + proxy in front of it) and the 4 failure-scenario rows needing the
  full local Supabase CLI stack or `apps/mobile` integration_test infrastructure — both materially
  larger scope than this item's own 4-person-day estimate, named as real, tracked gaps in
  `test-plan.md §3`'s Sprint 41 correction rather than faked or skipped.

## Definition of Done

- [x] `apps/web/integration-tests/sync-idempotent-replay.test.ts` — all 3 cases from
      test-plan.md §1, real Postgres, no mocks.
- [x] `apps/web/integration-tests/sync-concurrent-composition.test.ts` — all 4 non-fuzzed cases from
      test-plan.md §2 (two-device oversell, field-merge non-overlap, field-merge same-field
      collision, creation collision).
- [x] `apps/web/integration-tests/sync-failure-scenarios.test.ts` — the 1 server-testable failure
      scenario ("server rejects one item in a batch").
- [x] `apps/web/integration-tests/sync-concurrent-composition.nightly.test.ts` — N-device fuzzed
      composition, 100 runs; excluded from the default `vitest.integration.config.ts` include
      (`*.nightly.test.ts`), ready for backlog item 7's nightly wiring, not stubbed ahead of it.
- [x] `apps/web/integration-tests/setup/seed-second-user.ts` — a second identity under an
      already-seeded tenant/store, standing in for "a second device."
- [x] `apps/web/integration-tests/setup/seed-tenant.ts` — `authUserId` added to the returned
      fixture (the real gap found in design decision #3).
- [x] `pos/service.ts`'s `createSale`, `returns/service.ts`'s `createReturn`/`approveReturn` — the
      concurrency-race fix (design decision #2).
- [x] `.github/workflows/pr.yml`'s `fast-integration` job — Supabase placeholder env vars added (the
      new tests import application service code, unlike Sprint 40's raw-SQL-only suite).
- [x] Verified the fix actually matters: reproduced the race live (`Promise.all` of 5 identical
      `sale.create` pushes) before the fix, confirmed the unhandled Postgres unique-violation, then
      confirmed the fix resolves it cleanly.
- [x] Full local dry run of the exact CI sequence (fresh container → `prisma generate` → `prisma
      migrate deploy` → `apply-sql.mjs` → `pnpm --filter @smart-pos/web test:integration`) — 84/84
      passing (76 cross-tenant + 8 new).
- [x] N-device fuzzed test run standalone, full 100 runs — 100/100 passing, ~90 seconds.
- [x] `tsc --noEmit`/`eslint`/`vitest run` (209 web unit tests, unaffected) all clean; production
      build confirmed before pushing.
- [x] `idempotency.md`, `test-plan.md`, `offline-test-suite.md`, `ci-pipeline.md`, `ci-workflows.md`
      all updated in this PR — every found gap named above, plus a retroactive fix to
      `ci-workflows.md`'s own missing 0.2.0 Change Log row (found while adding this sprint's entry).
- [x] backlog.md, implementation-log, READMEs updated in the same PR.

## Demo script

**Local, run 2026-08-19**, mirroring `pr.yml`'s `fast-integration` job exactly:

1. Fresh `postgres:15` container, `prisma generate` + `migrate deploy` → 19 tables created. ✅
2. `apply-sql.mjs` → auth stub + all 18 `supabase/sql/*.sql` files applied cleanly. ✅
3. `pnpm --filter @smart-pos/web test:integration` → 84/84 passing (76 cross-tenant, 3
   idempotent-replay, 4 concurrent-composition, 1 failure-scenario). ✅
4. Concurrency-race regression check: reverted the `createSale` fix locally, reran the
   single-operation N-times-replay case — it failed with an unhandled unique-constraint error, not a
   clean idempotent result. Restored the fix → passing again. ✅
5. N-device fuzzed suite, run standalone (100 runs, ~90s): 100/100 passing. ✅

**Full existing suites, run 2026-08-19**: `tsc --noEmit` — clean; `eslint` — clean; `vitest run`
(default/mocked suite) — 209/209 passing, unaffected; production build — succeeded.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the second sprint in
a row (after Sprint 40) to find a real, load-bearing correctness gap by building the actual
"not by inspection" instrument a Phase 13/14 document had specified since 2026-07-31 rather than
trusting the existing code comments' own claims — the same pattern, now proven twice, that this
project's documentation-first discipline is not merely producing paper that agrees with itself, but
catching real bugs specifically because the tests it eventually demands get built for real.

M4 — Reports, Settings, and Release Readiness now has items 7–9 remaining, per
[backlog.md §5](backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 41 planned and built same-day: the fast (PR-gated) offline adversarial suite built and CI-wired (84/84 checks), a real concurrency-replay-safety gap found and closed on 3 service functions, the N-device fuzz case written and locally verified (100/100) pending item 7's nightly wiring, `test-plan.md §3`'s scenario-venue conflation corrected. M4 item 6 done, items 7–9 remain. |
