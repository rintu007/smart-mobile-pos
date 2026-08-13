# Sprint 22

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M1 — Full Catalogue & Inventory, Multi-Role (backlog item 6)
> **Status:** Closed

## Goal

Full stock-movement types: the `adjustment` movement + `reason_code`, and the public
`POST`/`GET /stock-movements`, `GET /products/{id}/stock-balance` endpoints — the three
capabilities [inventory/specification.md §1](../modules/inventory/specification.md#1-purpose-and-business-context)
named as deliberately deferred past Sprint 11.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `adjustment` movement + `reason_code`, `POST`/`GET /api/v1/stock-movements`, `GET /api/v1/products/{id}/stock-balance` | Inventory | 2.0 | 3 |

## Design decision, found while writing the spec

Every product already receives exactly one `opening` movement automatically, in the same
transaction as its own creation (Sprint 11). `POST /stock-movements` therefore does **not** accept
`movement_type: 'opening'` — a deviation from inventory.md's own original documented contract
("reachable by a client only for `opening` and `adjustment`"). There is no live workflow that needs
a *second*, client-initiated `opening` write, and DR-006 ("distinct from an adjustment, never used
to correct one... exactly one, at creation") would otherwise need new guarding this sprint has no
real caller to justify. A mis-recorded opening quantity is corrected the way WF-009 itself already
says: via a stock adjustment, never edited in place — already fully supported by this sprint's own
`reason_code: 'count_correction'`. `opening` is excluded at the request-schema layer (`422
VALIDATION_FAILED`), not rejected with `DIRECT_SALE_MOVEMENT_FORBIDDEN` like `sale`/`return` are —
unlike those two, `opening` was never a real target of this endpoint, just an unexamined artefact
of listing all four schema-level `movement_type` values together. Full reasoning:
[inventory/specification.md §1](../modules/inventory/specification.md#1-purpose-and-business-context).

## Capacity check

2.0 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `inventory/specification.md` (all 11 sections),
      `inventory.md` (implementation note + Change Log), backlog.md, module registry,
      implementation-log, README bump.

## Risks

- **No mobile UI this sprint.** Same position `GET /products` was left in after Sprint 21 — a
  documented, tested, live-verified server capability with no built consumer yet. WF-009's own
  dedicated opening-stock screen and any adjustment/balance mobile UI remain future scope.
- **`reason_code` has no Postgres `CHECK` constraint**, matching `movement_type`'s own existing
  precedent on this table (relying on application code, not a hand-edited migration) — a
  consistency choice, not a new gap.

## Definition of Done

- [x] `stock_movements` gains `reason_code` (nullable `TEXT`) via its own migration; new
      `(tenant_id, store_id, created_at)` index for the date-range list query.
- [x] `POST /api/v1/stock-movements` — creates one `adjustment` movement; `sale`/`return` rejected
      with `DIRECT_SALE_MOVEMENT_FORBIDDEN`; `opening` excluded at the schema layer; missing
      `reason_code` on an adjustment rejected with `ADJUSTMENT_REASON_REQUIRED`; unknown
      `product_id` rejected with `NOT_FOUND`; idempotent (upsert-on-id).
- [x] `GET /api/v1/stock-movements` — `product_id`/`movement_type`/`date_from`/`date_to` filters,
      cursor-paginated on `(created_at, id)`.
- [x] `GET /api/v1/products/{id}/stock-balance` — server-computed `SUM(quantity_delta)`, `404
      NOT_FOUND` for an unknown product.
- [x] Unit tests (`stock-movements/service.test.ts`, 11 tests): every rejection path, the
      server-side `store_id`/`created_by` resolution, filter pass-through, peek-and-trim
      pagination, malformed-cursor rejection.
- [x] `tsc --noEmit`/`eslint`/`vitest` (66 tests total across the web app) all clean.
- [x] Live verification against the real database, throwaway tenants deleted after — 9/9 checks.
- [x] `inventory/specification.md` (all 11 sections), `inventory.md`, backlog.md, module registry,
      implementation-log, README all updated in this PR.

**Explicitly not in this sprint's DoD subset:** WF-009's own dedicated opening-stock screen, any
mobile UI for adjustments or balance viewing, `device_id` attribution, Roles & Permissions
enforcement (item 7, deliberately last).

## Demo script

**Server, run 2026-08-14** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. `POST /stock-movements` with `movement_type: 'adjustment'`, `reason_code: 'damage'`,
   `quantity_delta: -2` → `201`, correct `store_id`, `reason_code` persisted. ✅
2. The same request replayed (identical `id`) → still exactly one row (idempotent). ✅
3. `movement_type: 'adjustment'` with no `reason_code` → `422 ADJUSTMENT_REASON_REQUIRED`. ✅
4. `movement_type: 'sale'` → `403 DIRECT_SALE_MOVEMENT_FORBIDDEN`. ✅
5. `movement_type: 'opening'` → `422 VALIDATION_FAILED` (excluded at the schema layer). ✅
6. `GET /products/{id}/stock-balance` after opening (10) + the adjustment above (-2) → `balance: 8`. ✅
7. `GET /stock-movements?movement_type=adjustment` → returns exactly the adjustment row, not the
   product's own `opening` row. ✅
8. `GET /stock-movements?product_id=<other product>` → returns only that product's own rows. ✅
9. Cross-tenant RLS: tenant B's session reads zero of tenant A's `stock_movements` rows, and
   `POST /stock-movements` against tenant A's `product_id` from tenant B's session → `404
   NOT_FOUND`. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the third sprint
running (after Sprint 20, Sprint 21) where writing the module spec *before* code surfaced a real
gap between a backlog item's literal wording (or, this time, this document's own prior wording in
inventory.md) and what the actual system already does — here, `opening`'s "reachable by a client"
claim, made before Sprint 11 ever existed, quietly went stale the moment Sprint 11 made every
product's `opening` movement automatic. Worth treating "write the spec first" as still finding real
value at this project's current size, not a formality.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 22 planned and built same-day: `adjustment`/`reason_code`, `POST`/`GET /api/v1/stock-movements`, `GET /api/v1/products/{id}/stock-balance` all built and live-verified (9/9). Found while writing the spec: the create endpoint excludes `movement_type: 'opening'` entirely — a named, dated deviation from inventory.md's own original documented contract. |
