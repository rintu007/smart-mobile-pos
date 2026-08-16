# Sprint 28

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M2 — Full POS Loop (backlog item 4 — Tax computation)
> **Status:** Closed — M2 item 4 done. M2 now has items 5–6 remaining.

## Goal

Tax computation: `tax_mode`/`tax_rate_basis_points`/`rounding_rule`/`pricing_mode` wired into
`POST /sales` per [money-and-tax.md](../07-database/money-and-tax.md)'s already-fixed
discount-before-tax formulas (both exclusive and inclusive worked examples), plus
`tax_registration_type_at_sale` — closing the money-math half of what M1's Sales & Invoices sprint
(Sprint 24) named as deferred M2 scope.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `tax_total_minor_units`, per-line tax fields, both pricing modes | POS | 2.5 | 1 (Settings), 3 (Discount) |

## Design decisions, found while writing the spec

Full detail in [pos/specification.md §1/§2](../modules/pos/specification.md#1-purpose-and-business-context).

1. **A real design gap, not covered by either of money-and-tax.md's own worked examples.** §3
   (exclusive pricing) includes a discount; §4 (inclusive pricing) doesn't — the combination of
   inclusive pricing *and* a discount on the same line was never specified anywhere. Resolved as a
   dated correction to money-and-tax.md §4a: the discount is subtracted from the tax-inclusive
   gross **before** the residual tax split runs — the natural composition of §1's "discount reduces
   the taxable value" with §4's "tax is the gross's residual," not a new rule invented for this
   sprint.
2. **No new request field at all.** `tax_mode`/`tax_rate_basis_points`/`pricing_mode` are read
   straight from `shop_settings`, matching Discount's own reasoning (Sprint 27) that server-derived
   figures are never client-supplied — DR-008 requires this, not a style preference.
3. **`tax_registration_type_at_sale` trusts Settings' own already-enforced invariant rather than
   re-checking it.** `PATCH /settings` (Sprint 25) already forces `tax_rate_basis_points` to `0`
   outside `tax_mode: 'standard'` (DR-009) — this sprint's tax computation reads the rate as-is,
   with no additional composition/unregistered special-casing needed.
4. **FR-055/056's actual invoice-document rendering remains explicitly deferred.** This sprint
   computes the correct tax numbers; GSTIN, per-line HSN/SAC breakup, and Bill-of-Supply vs.
   Tax-Invoice document layout are Receipt & Printing's own scope, and no GSTIN field exists
   anywhere in `shop_settings` yet either — named, not silently implied as covered.

## Capacity check

2.5 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — not used this sprint (no bugs found live; both
      pricing-mode formulas matched hand-computed expected values on the first live run).
- [x] Documentation capacity reserved: `pos/specification.md` (§1–§3, §10–§11 touched),
      `money-and-tax.md` (new §4a), `sales.md`, module registry, backlog.md, implementation-log,
      README bumps.

## Risks

- **The inclusive-pricing residual-method arithmetic is easy to get subtly wrong** (dividing by
  `(1 + rate)` rather than multiplying) — mitigated by hand-computing the exact expected values
  before writing either the unit tests or the live-verification script, then confirming both
  matched on the first run, rather than adjusting the math to whatever the code happened to
  produce.
- **Reused Sprint 27's `roundFraction` helper unchanged** — no new rounding logic was written this
  sprint, only a new caller (`computeLineTaxSplit`) of the existing BigInt-exact primitive,
  minimising the surface area for a new rounding bug.

## Definition of Done

- [x] `sales.tax_total_minor_units`/`tax_registration_type_at_sale`,
      `sale_line_items.tax_rate_basis_points`/`line_tax_minor_units` (new migration, all
      `DEFAULT 0`/nullable for migration safety against pre-existing rows).
- [x] Exclusive pricing: `line_tax_minor_units = ROUND(taxable_value × rate, rounding_rule)`.
- [x] Inclusive pricing: discount subtracted from the tax-inclusive gross first, then the residual
      method splits taxable/tax (design decision 1).
- [x] `sales.subtotal_minor_units = Σ line_taxable_value`, `grand_total_minor_units = subtotal +
      tax_total` — both per money-and-tax.md §1's already-fixed formula.
- [x] `tax_registration_type_at_sale` snapshots `shop_settings.tax_mode` at creation.
- [x] Unit tests: `pos/service.test.ts` extended (3 new tax tests: exclusive-with-discount,
      inclusive-residual, zero-tax-under-unregistered).
- [x] `tsc --noEmit`/`eslint`/`vitest` (123 tests total across the web app) all clean; production
      build verified locally with CI-style placeholder env before pushing.
- [x] Live verification against the real database, throwaway tenant deleted after — 20/20 checks.
- [x] `pos/specification.md`, `money-and-tax.md`, `sales.md` all updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** split payment (M2 item 5), hold/resume (M2 item 6),
FR-055/056's invoice-document rendering (design decision 4), any mobile UI displaying a tax
breakdown.

## Demo script

**Server, run 2026-08-14** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenant deleted after:

1. `tax_mode: standard`, `18%`, exclusive pricing, a 10% discount on a ₹56.00 line → taxable ₹50.40,
   tax ₹9.07, grand total ₹59.47 — matches the hand-computed expected value exactly. ✅
2. `GET /sales/{id}` reflects the identical tax fields (via `pos/service.ts`'s own `formatSale`,
   reused by `sales-invoices/service.ts`). ✅
3. Switched to inclusive pricing, `5%`, no discount, gross ₹56.00 → taxable ₹53.33, tax ₹2.67, grand
   total unchanged at ₹56.00 (residual method, the gross a customer sees never moves). ✅
4. Switched to `tax_mode: unregistered` (rate forced to `0` by `PATCH /settings` itself, per DR-009)
   → the sale carries zero tax and the correct `tax_registration_type_at_sale`. ✅

**Unit tests, run 2026-08-14**: `vitest run` — 123/123 passing.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the fourth M2
sprint running where a real design gap was found and resolved *while writing the spec*, before any
code existed — a pattern now spanning every M2 sprint so far (Settings' missing row and missing tax
rate source, Trading Day's scoping question, Discount's subtotal semantics, and now this sprint's
inclusive-pricing-plus-discount gap). Also the first M2 sprint with **zero bugs found live** —
both Sprint 26 (the `meta.target` shape) and Sprint 27 (the Vitest module-loading chain) had one;
this sprint's arithmetic matched hand-computed expectations on the first run of both the unit tests
and the live-verification script, credited to computing the expected numbers by hand *before*
writing either, rather than treating the code's own output as ground truth.

M2 — Full POS Loop now has items 5–6 remaining: Split Payment, Hold/Resume, per
[backlog.md §3](backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 28 planned and built same-day: Tax computation built and live-verified (20/20), both pricing modes. Resolved a real gap in money-and-tax.md's own worked examples (inclusive pricing + discount, never jointly specified) as a dated correction (§4a). Zero bugs found live. |
