# Sprint 11

> **Dates:** 2026-08-13 – 2026-08-13 (single-day, same pattern as Sprints 02–10)
> **Milestone:** M0 — Walking Skeleton (backlog item 7)
> **Status:** Closed

## Goal

Give every product a stock-ledger baseline at creation and debit it automatically when a sale
completes — [backlog.md item 7](backlog.md#1-m0--walking-skeleton-fully-decomposed), the dependency
both [pos/specification.md §1](../modules/pos/specification.md#1-purpose-and-business-context) and
[products/specification.md](../modules/products/specification.md) already named as unmet.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Stock ledger: `opening` movement on product creation, `sale` movement on sale completion, each atomic with its triggering row | Inventory | 1.5 | 6 (POS core loop, done Sprint 09) |

Backend-only, server side — no mobile UI, matching the alternating backend/mobile-sprint pattern
Sprints 04→07 and 05→09 already established. See
[inventory/specification.md §1](../modules/inventory/specification.md#1-purpose-and-business-context)
for the exact, deliberately narrow cut: no adjustment workflow, no public stock-movement endpoints,
no mobile UI.

## Capacity check

1.5 person-days against the ~3.75 person-day sprint budget — same size class as Sprint 10.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `inventory/specification.md` (new), backlog.md, module
      registry, implementation-log, README bumps, dated notes in `products/specification.md` and
      `pos/specification.md` closing the gaps they each named — inside the estimate above.

## Risks

- **Store resolution for a table that was never store-scoped**: `products` has no `store_id` column
  (M0-minimal, tenant-scoped only), but `stock_movements` is store-scoped by design
  (schema-server.md). Resolved server-side via the tenant's one store (ADR-0003) — named and
  reasoned through in [inventory/specification.md §4](../modules/inventory/specification.md#4-api-contract),
  not silently assumed.
- **Atomicity across two rows with no direct FK relation** (a sale's stock movements reference it
  only via `reference_type`/`reference_id`, never a real foreign key — schema-server.md's own design,
  since a reference can be a sale or a return): Prisma's nested-relation-write sugar doesn't apply,
  so both writes use an explicit `prisma.$transaction` instead — verified live, not just asserted
  (§ Demo script).

## Definition of Done

- [x] `inventory/specification.md` (new), all 11 sections, 🟢 Approved.
- [x] `stock_movements` table (M0-minimal columns), RLS enabled
      (`supabase/sql/006_rls_stock_movements.sql`), applied to the live Supabase database.
- [x] `POST /api/v1/products` accepts optional `initial_quantity`, writes exactly one `opening`
      movement in the same transaction as the product row; idempotent on replay (same id, no
      duplicate movement).
- [x] `POST /api/v1/sales` writes one `sale` movement per line item in the same transaction as the
      sale; a sale that would take a balance negative still succeeds (DR-005).
- [x] Unit tests updated for the new `storeId` resolution path
      (`products/service.test.ts`, `stores/service.test.ts`).
- [x] `tsc --noEmit` / `eslint` clean.
- [x] Live verification against the real database, throwaway tenants deleted after — 16/16 checks
      passed, including a real oversell and a cross-tenant RLS proof on `stock_movements` itself.
- [x] No secret, token, or key written to logs or committed to source.
- [x] Module registry, backlog.md, implementation-log, READMEs, and the two specs whose named gaps
      this closes (`products`, `pos`) updated in the same PR.

**Explicitly not in this sprint's DoD subset:** WF-009's dedicated opening-stock screen/endpoint,
stock adjustments (WF-010), the public `POST`/`GET /stock-movements` and
`GET /products/{id}/stock-balance` endpoints, `device_id` attribution, mobile UI of any kind, M0's
own remaining items (8–11).

## Demo script

**Run 2026-08-13, all 16 checks passed** against the live database, via real HTTP requests to a
local dev server pointed at production Supabase, throwaway tenants deleted after:

1. Onboard tenant A. ✅
2. Onboard tenant B, for the cross-tenant check. ✅
3. `POST /api/v1/products` as tenant A with `initial_quantity: 10` — exactly one `opening` movement,
   `quantity_delta = 10`, correct `store_id`. ✅
4. Replay the identical create request — still exactly one `opening` movement. ✅
5. `POST /api/v1/sales` for 3 units — a `sale` movement, `quantity_delta = -3`,
   `reference_type = 'sale'`, correct `reference_id`; derived balance = 7. ✅
6. A second sale for 20 units against a balance of 7 — succeeds (`201`), derived balance = -13,
   proving DR-005 against a real oversell rather than only asserting it. ✅
7. As tenant B's session, read `stock_movements` filtered to tenant A's product directly via
   PostgREST — zero rows returned. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. One thing worth naming regardless: this is the first
sprint whose live verification queried the database directly (via Prisma/PostgREST) rather than only
through the API's own response bodies — needed here because neither `POST /products` nor
`POST /sales` exposes the stock movement it produced in its response at all.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | Sprint 11 planned and built same-day: `inventory/specification.md` written first, `stock_movements` table + RLS added, `opening`/`sale` movements wired into `POST /products`/`POST /sales` inside explicit transactions, live-verified against the real database (16/16 checks, including a real oversell and a cross-tenant RLS proof), throwaway tenants deleted after. Closes the gap both `products` and `pos` specifications had named since Sprint 04/05. |
