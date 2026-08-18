# Sprint 42

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (backlog item 7 — nightly CI pipeline)
> **Status:** Closed — M4 item 7 done. M4 now has items 8–9 remaining.

## Goal

Build [ci-pipeline.md §3](../14-testing/ci-pipeline.md#3-nightly-pipeline)'s nightly tier for the
first time: wire items 5/6's slow, deferred subsets into a new `nightly.yml`, plus a
Dependabot-based dependency audit.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `nightly.yml` wiring items 5/6's slow subsets, Dependabot dependency audit | Cross-cutting (CI/DevOps) | 1 | 5, 6 |

## Design decisions, found while writing the spec

1. **Item 5 (cross-tenant isolation) has no distinct "slow subset" ready to wire at all.** Its only
   deferred piece — the Realtime-channel extension, `tenant-isolation.md §4` — needs the full local
   Supabase CLI stack Sprint 40 already named and deferred; nothing changed since then. Item 6's own
   slow subset (the N-device fuzzed test, `sync-concurrent-composition.nightly.test.ts`, written and
   locally verified Sprint 41) is `nightly.yml`'s entire real integration-test content this sprint.
2. **`ci-pipeline.md §3`'s "full failure-scenario suite" row has no code to run, on any tier.**
   `test-plan.md §3`'s Sprint 41 correction already found only 1 of the 10 named failure scenarios
   is server-testable, and that one already gates every PR (`fast-integration`) — there is no
   separate, larger "full" version of it waiting for a nightly slot. The other 9 need mobile
   `integration_test` infrastructure or the full Supabase CLI stack, neither built. Named as a real,
   tracked gap in `ci-pipeline.md §3`, not stubbed as an empty job.
3. **`ci-pipeline.md §3`'s "extended property-based tests" row was never built at all — on any
   tier, not just nightly.** Confirmed by grep: no property-based testing library (`fast-check` or
   equivalent) exists anywhere in `apps/web`. This is a real, previously-unnoticed gap in
   `test-strategy.md §1`'s own traceability table, which had been citing this suite as covering
   DR-008/DR-013 since that document's first version — corrected in the same PR to the real unit-test
   coverage that does exist, rather than continuing to claim coverage from code that was never
   written. The stock-order-independence half of this section's original intent **is** separately
   covered — Sprint 41's fuzzed sync-engine test proves the same invariant, just not via a
   property-based suite here. The money-invariant half (tax + subtotal − discount = grand total,
   across randomised inputs) remains genuinely unbuilt.
4. **Dependabot needs no CI job at all** — `.github/dependabot.yml` alone is sufficient;
   vulnerability alerts run automatically once the file exists, and its weekly
   `open-pull-requests-limit` (npm/pub/github-actions ecosystems) is the version-currency half,
   independent of any workflow run.
5. **No `release-candidate.yml` exists to actually gate on a nightly failure** — `ci-pipeline.md
   §3`'s own rule ("does block the next release candidate from being cut") has nothing to block yet;
   that pipeline is real, separate, larger scope, not part of this item. Built `nightly.yml`'s own
   issue-on-failure step (opens or updates a standing GitHub issue) as the actual, working substitute
   for that rule's intent on a solo-founder project with no release pipeline yet — a nightly
   regression is visible without anyone checking a dashboard, even though nothing yet enforces it as
   a release gate.
6. **`type:defect`/`priority:P0` (`project-board.md §3`'s label taxonomy) don't exist in this
   repository** — found live running the new failure-notification step for the first time; only
   GitHub's stock default label set does (`bug`, `documentation`, `enhancement`, etc.). Substituted
   the stock `bug` label plus a newly-created `nightly-failure` label (created idempotently by the
   workflow itself on first use) rather than failing the notification step on labels that don't
   exist. Creating the full label taxonomy `project-board.md` envisions is that document's own
   separate setup gap, out of this item's scope.

## Capacity check

1 person-day against estimate — landed on it, once the found gaps above narrowed the item to what
was actually buildable (a much smaller real footprint than `ci-pipeline.md §3`'s full 4-row table
originally implied).

## Reserved capacity

- [x] Documentation capacity reserved: `ci-pipeline.md`, `ci-workflows.md`, `test-strategy.md`,
      backlog.md, this sprint doc, implementation-log, README bumps.

## Risks

- **None new for production data** — `nightly.yml` runs against the same ephemeral, per-run
  `postgres:15` container the PR-gated suite already uses.
- **Genuinely deferred, not silently dropped**: the full failure-scenario suite and the
  property-based money/stock suite (design decisions #2/#3) — both real, tracked gaps needing
  infrastructure or engineering effort materially beyond this item's own 1-person-day estimate.

## Definition of Done

- [x] `.github/workflows/nightly.yml` — scheduled (`cron`) + `workflow_dispatch`, a `postgres:15`
      service container matching `fast-integration`'s own mechanism, running
      `test:integration:nightly` against the fuzzed sync-engine suite.
- [x] `apps/web/vitest.integration.nightly.config.ts` + `test:integration:nightly` script — a
      separate config from both the default unit suite and the PR-gated integration suite, picking
      up exactly `*.nightly.test.ts`.
- [x] `.github/dependabot.yml` — npm (root, pnpm workspace), pub (`apps/mobile`), github-actions,
      all weekly.
- [x] Nightly-failure-issue step — opens or updates a labelled GitHub issue on failure, verified the
      label-creation path works against this repository's real (stock-only) label set.
- [x] Verified locally: fresh `postgres:15` container → migrations → RLS → `test:integration:nightly`
      → 100/100 fuzzed runs passing (~65s); `test:integration` (the default PR-gated script)
      re-confirmed to still exclude the nightly file (84/84, unaffected).
- [x] `ci-pipeline.md §3`, `ci-workflows.md §2`, `test-strategy.md §1`/§4 all corrected to match what
      was actually found and built, not left implying broader coverage than exists.
- [x] backlog.md, implementation-log, READMEs updated in the same PR.

## Demo script

**Local, run 2026-08-19**, mirroring `nightly.yml` exactly:

1. Fresh `postgres:15` container, `prisma generate` + `migrate deploy` → 19 tables. ✅
2. `apply-sql.mjs` → auth stub + all 18 `supabase/sql/*.sql` files applied. ✅
3. `pnpm --filter @smart-pos/web test:integration:nightly` → 100/100 fuzzed runs passing, ~65s. ✅
4. `pnpm --filter @smart-pos/web test:integration` (the default, PR-gated script) → 84/84, confirming
   the nightly file stays excluded from the fast path. ✅

**Full existing suites, run 2026-08-19**: `tsc --noEmit` — clean; `eslint` — clean; `vitest run`
(default/mocked suite) — 209/209 passing, unaffected; production build — succeeded.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the third sprint in a
row (after Sprint 40, Sprint 41) to find that a Phase 12–14 document's own claimed coverage didn't
match reality once someone actually tried to wire the claimed content into working CI — here, twice
in the same sprint (the failure-scenario row and the property-based-testing row). The pattern is
now well-established enough to name directly: this documentation set's own cross-references are only
as reliable as the last time someone actually built against them, and each of the last three sprints
has been the first time anyone did, for these specific claims.

M4 — Reports, Settings, and Release Readiness now has items 8–9 remaining, per
[backlog.md §5](backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 42 planned and built same-day: `nightly.yml` + `dependabot.yml` built and locally verified; two real documentation-vs-reality gaps found and corrected (the failure-scenario "full suite" and the property-based test suite both had no code behind them, on any tier); the nightly-failure notification mechanism built as a working substitute for a release-candidate gate that doesn't exist yet. M4 item 7 done, items 8–9 remain. |
