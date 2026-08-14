# Sprint 25

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M2 — Full POS Loop (backlog item 1 — M2's first item, now decomposed to item grain)
> **Status:** Closed — M2 item 1 done. M2 now has items 2–6 remaining.

## Goal

Decompose M2 to item grain (backlog.md), then build its first item: Settings, minimal slice —
`shop_settings`, a default row at onboarding, `GET`/`PATCH /settings` with the role-shaped read
scope [settings.md](../11-api/endpoints/settings.md) already specified back in Phase 11. A
prerequisite sprint, not a feature in its own right: Discount (M2 item 3) and Tax computation (M2
item 4) both need a real `shop_settings` row to read.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `shop_settings` table, default row at onboarding, `GET`/`PATCH /settings` | Settings | 1.5 | — |

## Design decisions, found while decomposing M2 and writing the spec

Full detail in [settings/specification.md §1](../modules/settings/specification.md#1-purpose-and-business-context).

1. **No `shop_settings` row was ever created anywhere in code.** [dependency-graph.md §4](../16-milestones/dependency-graph.md#4-settings--a-configuration-input-not-a-graph-dependency)
   assumed Settings' fields "simply need sensible defaults present from Setup onward," but
   `identity/repository.ts`'s onboarding transaction never wrote one. Found while decomposing M2,
   not by writing code first — closed by adding it as M2's own first item.
2. **Neither `shop_settings` nor `products` ever named where DR-008's `tax_rate` actually comes
   from.** The fully correct V1 shape would be a per-product/per-HSN slab-rate table; none exists.
   Resolved as a dated correction to [schema-server.md](../07-database/schema-server.md)/[money-and-tax.md](../07-database/money-and-tax.md):
   a single shop-wide `tax_rate_basis_points`, forced to `0` outside `tax_mode: 'standard'`
   ([DR-009](../03-functional-requirements/business-rules.md)). Per-product/per-HSN rates are a
   named, deferred V2+ gap.
3. **Universal defaults, not business-type-based seeding.** [seed-data.md](../07-database/seed-data.md)
   specifies richer per-vertical defaults, but onboarding collects no business-type field. This
   sprint uses seed-data.md's own named "safest universal default" instead (`tax_mode:
   'unregistered'`), with the two auto-approval thresholds set to flat, named starting points
   (₹500/₹1,000) rather than a number seed-data.md never actually fixes.
4. **`printer_config`/`receipt_template_config` deliberately deferred.** Both columns exist (matching
   schema-server.md exactly) but `PATCH /settings` rejects either with `VALIDATION_FAILED` if
   present — no printer-pairing or receipt-template-editing flow exists yet to give either real
   content.

## Capacity check

1.5 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — used (see Risks/Definition of Done below, two real
      bugs found live).
- [x] Documentation capacity reserved: `settings/specification.md` (all 11 sections), `settings.md`,
      `identity.md`, `schema-server.md`, `money-and-tax.md`, `error-catalogue.md`, module registry,
      backlog.md (both the M2 decomposition and item 1's completion), implementation-log, README
      bumps.

## Risks

- **Two real bugs found live, both fixed before merge, neither by inspection:**
  1. Onboarding's response crashed with a real `500` — `NextResponse.json` cannot serialize the new
     `shop_settings` row's two `BIGINT` columns. Fixed by keeping the onboarding response shape
     exactly as it already was (`tenant`/`store`/`user`/`ownerRole`, unchanged), not by adding
     `BigInt`-to-`Number` formatting for a field the documented contract never returned.
  2. The throwaway script applying `012_rls_shop_settings.sql` split the file naively on `;` and
     filtered out any statement whose *chunk* started with a `--` comment — which silently ate the
     `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` statement along with the file's leading comment
     block, leaving the policy created but never enforced. Found by checking
     `pg_class.relrowsecurity` directly rather than trusting the script's own "Done." output; fixed
     by executing the statement directly and re-verifying.
- **Business-type-based default seeding remains unbuilt** — this sprint's universal defaults are a
  named, honest simplification, not the full seed-data.md design.

## Definition of Done

- [x] M2 decomposed to item grain in `backlog.md` (6 items, 12 person-days), same practice M0/M1
      already established.
- [x] `shop_settings` table (new migration + RLS) — `tenant_id` as its own primary key, matching
      schema-server.md, plus this sprint's `tax_rate_basis_points` correction.
- [x] Onboarding (`identity/repository.ts`) writes a default `shop_settings` row in the same
      transaction as `tenants`/`stores`/`users`/the bootstrap role.
- [x] `GET /api/v1/settings` — role-shaped (both auto-approval thresholds omitted for Cashier).
- [x] `PATCH /api/v1/settings` — Owner only, whole-row optimistic concurrency (`base_updated_at`
      vs. `updated_at`), DR-009 cross-field validation (`TAX_RATE_REQUIRES_STANDARD_MODE`),
      `printer_config`/`receipt_template_config` rejected outright.
- [x] Unit tests: `settings/service.test.ts` (11 new tests).
- [x] `tsc --noEmit`/`eslint`/`vitest` (96 tests total across the web app) all clean; production
      build verified locally with CI-style placeholder env before pushing.
- [x] Live verification against the real database, throwaway tenants deleted after — 26/26 checks.
- [x] `settings/specification.md`, `settings.md`, `identity.md`, `schema-server.md`,
      `money-and-tax.md`, `error-catalogue.md` all updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** `printer_config`/`receipt_template_config` (accepted
but content-validated), `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD` (unreachable until the above
lands), business-type-based default seeding, any mobile UI reading settings (nothing yet needs
tax/discount config — those are M2 items 3/4).

## Demo script

**Server, run 2026-08-14** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. Onboarding a fresh tenant → exactly one `shop_settings` row, matching §2's universal defaults
   exactly. ✅
2. `GET /settings` as Owner/Manager → both auto-approval thresholds present. ✅
3. `GET /settings` as a Cashier (seeded directly, Sprint 23's own technique) → both thresholds
   absent from the response entirely, `tax_mode` still visible. ✅
4. `PATCH /settings` as the Cashier → `403 PERMISSION_DENIED`. ✅
5. `PATCH /settings` as Owner, `tax_mode: standard` + `tax_rate_basis_points: 500` → `200`,
   reflected on the next `GET`. ✅
6. `PATCH /settings` again with the now-stale `base_updated_at` → `409 SETTINGS_CONFLICT`. ✅
7. `PATCH /settings` setting `tax_mode: unregistered` while the rate stays nonzero →
   `422 TAX_RATE_REQUIRES_STANDARD_MODE`. ✅
8. `PATCH /settings` with `printer_config` present → `422 VALIDATION_FAILED`. ✅
9. Cross-tenant RLS: tenant B's own `GET /settings` resolves to its own defaults, never tenant A's
   mutated `standard`/500 values. ✅

**Unit tests, run 2026-08-14**: `vitest run` — 96/96 passing.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the first M2 sprint,
and it repeats a pattern every M1 sprint also hit — writing the module spec (and, this time, the
milestone decomposition itself) surfaced two real gaps before any code existed (no `shop_settings`
row anywhere, no named source for the tax rate) rather than either being found later as a live bug.
It's also the first sprint where live verification caught a bug in the *verification tooling itself*
(the RLS-enable statement silently dropped by a naive comment filter) rather than in the product
code — a reminder that "verify live" needs its own verification when the check is a hand-rolled
script, not just a trusted client library call.

M2 — Full POS Loop now has items 2–6 remaining: Cash Drawer/Trading Day, Discount, Tax computation,
Split Payment, Hold/Resume, per [backlog.md §3](backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 25 planned and built same-day: M2 decomposed to item grain (6 items, 12 person-days); item 1 (Settings) built and live-verified (26/26). Two real gaps found decomposing M2 (no `shop_settings` row anywhere in code; DR-008's tax rate had no named source) resolved as dated corrections. Two real bugs found live and fixed (onboarding's BigInt serialization crash; the RLS-enable statement silently dropped by the verification script's own naive comment filter). |
