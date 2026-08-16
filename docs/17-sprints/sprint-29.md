# Sprint 29

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M2 — Full POS Loop (backlog item 5 — Split Payment)
> **Status:** Closed — M2 item 5 done. M2 now has item 6 remaining.

## Goal

Split Payment: `POST /sales` accepts multiple `payments` entries (`cash`/`card`/`other`),
validated against the server-recomputed `grand_total_minor_units` (`PAYMENT_AMOUNT_MISMATCH`
restated for the multi-entry case) — [WF-004](../06-workflows/sales-workflows.md#wf-004--complete-a-sale-with-split-payment),
already fully designed in Phase 06, not invented this sprint.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Multi-entry `payments`, `PAYMENT_AMOUNT_MISMATCH` restated as a sum | POS | 1.5 | 2 (Trading Day), 4 (Tax) |

## Design decisions, found while writing the spec

Full detail in [pos/specification.md §1/§2](../modules/pos/specification.md#1-purpose-and-business-context).

1. **No schema change at all.** `sale_payments` was already a to-many relation from M0 onward —
   the single-`cash`-entry shape was a Zod-schema and business-rule scope choice (backlog.md's own
   M0 scoping), never a structural limit. `schema-server.md`'s `method` `CHECK` already allowed
   `card`/`other`; this sprint is simply the first with a caller that can actually send them.
2. **WF-004's diagram shows exactly two portions; the API accepts N ≥ 1.** The Phase 06 workflow's
   own till-UI target is "cash portion + one other portion" — this implementation generalises to
   any number of entries summing to the total, the natural shape of "sum to the total" rather than
   a narrower one hard-coded to two. Nothing about the till UI needing exactly two changes what the
   API itself must validate.
3. **Trading Day needed zero code changes, confirmed live rather than merely reasoned about.**
   Sprint 26's `expected_cash_minor_units` aggregation (`trading-day/repository.ts`) already sums
   every matching `cash` `sale_payments` row per trading day via a `WHERE method = 'cash'` filter —
   it was never counting "the sale's one payment," so a split sale's card/other portions were
   already excluded by construction. Verified this holds for real in the live-verification script
   rather than assuming it from reading the code.

## Capacity check

1.5 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — not used this sprint (no bugs found live).
- [x] Documentation capacity reserved: `pos/specification.md` (§1–§5, §10–§11 touched), `sales.md`,
      module registry, backlog.md, implementation-log, README bumps.

## Risks

- **None new.** This sprint's change surface was small and well-isolated (Zod schema loosening,
  one validation check, a repository field rename from singular to plural) — the low-risk end of
  this milestone's sprints so far, reflected in the estimate (1.5 person-days, the smallest of M2's
  six items) and in finding zero bugs live for the second sprint running.

## Definition of Done

- [x] `payments` schema loosened from `.length(1)`/`literal("cash")` to `.min(1)`/
      `.enum(["cash","card","other"])`.
- [x] `PAYMENT_AMOUNT_MISMATCH` checks the sum of every `payments[].amount_minor_units` against
      `grand_total_minor_units`, not a single value's equality.
- [x] `pos/repository.ts`'s `CreateSaleInput.payment` (singular) renamed to `payments` (array);
      `tx.sale.create`'s nested write passes the array directly.
- [x] Unit tests: `pos/service.test.ts` extended (4 new split-payment tests: two-way split,
      three-way split, card-only, short-split rejection).
- [x] `tsc --noEmit`/`eslint`/`vitest` (127 tests total across the web app) all clean; production
      build verified locally with CI-style placeholder env before pushing.
- [x] Live verification against the real database, throwaway tenant deleted after — 14/14 checks,
      including the Trading Day cash-exclusion check (design decision 3).
- [x] `pos/specification.md`, `sales.md` both updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** hold/resume (M2 item 6, the milestone's last item),
any mobile UI for choosing split payment or entering multiple amounts, live card-network
authorisation (out of V1 scope entirely, per FR-028/WF-004's own explicit framing).

## Demo script

**Server, run 2026-08-14** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenant deleted after:

1. A trading day opened, then a sale split cash ₹36.00 + card ₹20.00 (grand total ₹56.00) →
   `201`, both payment rows recorded individually with the correct method/amount. ✅
2. A card-only sale (no cash portion at all) → `201` — the loosened schema doesn't silently assume
   cash is always present. ✅
3. A split summing to less than the grand total → `409 PAYMENT_AMOUNT_MISMATCH`. ✅
4. An empty `payments` array → `422 VALIDATION_FAILED` (Zod's own `min(1)`). ✅
5. Closing the trading day after both sales → `expected_cash_minor_units` is exactly ₹36.00 (the
   split sale's cash portion only) — the card-only sale and the split sale's card portion are both
   correctly excluded, with zero code changes to Trading Day itself. `variance_minor_units: 0`. ✅

**Unit tests, run 2026-08-14**: `vitest run` — 127/127 passing.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the smallest and
lowest-risk M2 sprint so far, by design — the estimate (1.5 person-days) correctly anticipated that
Split Payment was mostly validation/wiring against structure that already existed (Sprint 26's
Trading Day aggregation, M0's own `sale_payments` relation), not new capability. Worth treating as
a useful contrast against Sprints 26–28, each of which found a real design gap requiring a dated
correction before code could be written: not every M2 item needs one, and forcing a gap-hunt where
none exists would be its own kind of overreach.

**M2 — Full POS Loop now has only item 6 remaining: Hold/Resume**, per
[backlog.md §3](backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point) —
the milestone's last item.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 29 planned and built same-day: Split Payment built and live-verified (14/14). No schema change; confirmed live that Trading Day's own aggregation needed zero changes. Zero bugs found live, the second sprint running. |
