# Sprint 27

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M2 — Full POS Loop (backlog item 3 — Discount)
> **Status:** Closed — M2 item 3 done. M2 now has items 4–6 remaining.

## Goal

Discount: per-line `discount_percent_basis_points`/`discount_amount_minor_units` in `POST /sales`
(mutually exclusive, [DR-011](../03-functional-requirements/business-rules.md)), server-computed
`line_discount_minor_units`/`discount_total_minor_units`, and the Manager+-approval gate above
threshold ([DR-012](../03-functional-requirements/business-rules.md)) — a workflow
([WF-003](../06-workflows/sales-workflows.md#wf-003--complete-a-sale-with-a-discount)) already
fully designed in Phase 06, this sprint's job is to build it, not invent it.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Per-line discount, `DISCOUNT_REQUIRES_APPROVAL` gate | POS | 2.0 | 1 (Settings) |

## Design decisions, found while writing the spec

Full detail in [pos/specification.md §1/§2](../modules/pos/specification.md#1-purpose-and-business-context).

1. **Approval authority resolved fresh at request time, matching Finding 1's own integrity model,
   not a stronger one.** `WF-003`'s failure table already states the approval "blocked at the
   client and re-checked server-side at sync" — the same shape
   [Finding 1](../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux)
   already established for return approvals. `discount_approved_by` is accepted as a plain user id,
   verified server-side against `user_store_roles` at the moment the sale is processed — if that
   named user isn't an active Manager/Owner at this store right now, the sale is rejected outright,
   whether or not some real-world approval conversation happened. No new authentication mechanism
   (PIN entry, a second bearer token) was invented; none is needed given this project's own
   already-documented approval model.
2. **A real semantic correction, found writing this section, not by inspection**:
   [money-and-tax.md](../07-database/money-and-tax.md) has always defined
   `invoice.subtotal_minor_units` as **post-discount, pre-tax** — this implementation's
   `subtotal_minor_units` silently meant "pre-discount raw sum" since Sprint 05, invisible only
   because no discount existed yet to make the two values diverge. Corrected in the same PR:
   `grand_total_minor_units` now equals `subtotal_minor_units` exactly (no tax yet, M2 item 4), both
   computed from the post-discount per-line totals.
3. **The caller's own role satisfies DR-012 without a separate `discount_approved_by`.** DR-020
   already grants Manager/Owner "discount... approval above threshold" as part of their own
   permission set — when a Manager or Owner is the one operating the till and applying the
   discount, no second approver identity is needed; `discount_approved_by` exists only for the
   Cashier-initiated case.

## Capacity check

2.0 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — used (see Risks below).
- [x] Documentation capacity reserved: `pos/specification.md` (§1–§2, §3–§6, §10–§11 all touched),
      `sales.md`, `error-catalogue.md`, module registry, backlog.md, implementation-log, README
      bumps.

## Risks

- **A test-infrastructure gap found live, not sprint-specific but exposed by this sprint's own
  change**: `pos/service.ts`'s new import of `roles/service.ts` (for the approver-role check)
  transitively evaluates `core/auth/admin-client.ts`'s real `createClient(...)` call at
  module-load time — even under Vitest's auto-mocking, which still loads the real module once to
  derive its shape. This broke two unrelated test files (`sales-invoices`, `sync`) that had never
  needed protection from it before. Fixed with a global `vitest.setup.ts` mock rather than patching
  each affected file individually, since any future module joining this import chain (Tax
  computation next, plausibly) would hit the same failure otherwise.
- **The rounding helper (`roundFraction`) is new, BigInt-exact arithmetic** — unit-tested directly
  via the percent-discount test case (10% of 5600 → exactly 560, no floating-point risk), and will
  be reused as-is by Tax computation (M2 item 4) rather than reimplemented.

## Definition of Done

- [x] `sales.discount_total_minor_units`, `sale_line_items.line_discount_minor_units` (new
      migration, both `DEFAULT 0`, no RLS change needed — existing tables).
- [x] `POST /api/v1/sales` accepts `line_items[].discount_percent_basis_points` XOR
      `line_items[].discount_amount_minor_units` (Zod `.refine`), computes
      `line_discount_minor_units`/`discount_total_minor_units` server-side.
- [x] `discount_amount_minor_units` exceeding its own line's subtotal → `422 VALIDATION_FAILED`.
- [x] `DISCOUNT_REQUIRES_APPROVAL` (409) when `discount_total_minor_units` exceeds
      `shop_settings.discount_auto_approval_threshold_minor_units` and neither the caller nor
      `discount_approved_by` resolves to an active Manager/Owner at this store.
- [x] `subtotal_minor_units` corrected to post-discount, pre-tax (design decision 2).
- [x] Unit tests: `pos/service.test.ts` extended (8 new discount tests).
- [x] `tsc --noEmit`/`eslint`/`vitest` (120 tests total across the web app) all clean; production
      build verified locally with CI-style placeholder env before pushing.
- [x] Live verification against the real database, throwaway tenant deleted after — 17/17 checks.
- [x] `pos/specification.md`, `sales.md`, `error-catalogue.md` all updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** tax (M2 item 4), split payment (M2 item 5),
hold/resume (M2 item 6), any mobile UI for applying a discount or a Manager-approval override,
offline queuing nuances beyond what `POST /sales` already had (discount fields ride the same
request shape, no new sync-operation type needed).

## Demo script

**Server, run 2026-08-14** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenant deleted after (threshold lowered to ₹5.00 via
`PATCH /settings` first, to exercise both sides of it without needing large sale amounts):

1. A 10% discount (under threshold) as Cashier → `201`; `discount_total_minor_units`,
   `subtotal_minor_units`, `grand_total_minor_units`, and the line's own `discount_minor_units` all
   correct. ✅
2. A flat discount over threshold, Cashier, no approver → `409 DISCOUNT_REQUIRES_APPROVAL`. ✅
3. The identical discount, called by the Owner directly → `201` (self-authority, DR-020). ✅
4. The identical discount, Cashier + `discount_approved_by` = the Owner's id → `201`. ✅
5. The identical discount, Cashier + `discount_approved_by` = another Cashier's id → `409
   DISCOUNT_REQUIRES_APPROVAL` (an invalid approver is rejected exactly like a missing one). ✅
6. A flat discount exceeding its own line's subtotal → `422 VALIDATION_FAILED`. ✅
7. A line carrying both `discount_percent_basis_points` and `discount_amount_minor_units` → `422
   VALIDATION_FAILED` (Zod `.refine`). ✅

**Unit tests, run 2026-08-14**: `vitest run` — 120/120 passing.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the third M2 sprint
running where a Phase 06 workflow document (WF-003 this time, matching Finding 1/Finding 2's own
role in Sprints 25/26) turned out to already contain the exact design decision the sprint needed —
worth continuing to check workflows docs *before* inventing a mechanism, not after. Also the second
sprint running (after Sprint 26's `meta.target` bug) where a live-verification pass or test run
caught a real bug in supporting infrastructure — this time the test suite's own module-loading
behavior — rather than in the feature code itself.

M2 — Full POS Loop now has items 4–6 remaining: Tax computation, Split Payment, Hold/Resume, per
[backlog.md §3](backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 27 planned and built same-day: per-line Discount built and live-verified (17/17). Corrected `sales.subtotal_minor_units` to its always-documented post-discount, pre-tax meaning. Fixed a general test-infrastructure gap (global `vitest.setup.ts` mock for `core/auth/admin-client.ts`) found live when this sprint's new `pos/service.ts` → `roles/service.ts` import broke two unrelated test files. |
