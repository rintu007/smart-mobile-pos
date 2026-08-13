# Sprint 17

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every M0 sprint)
> **Milestone:** M1 — Full Catalogue & Inventory, Multi-Role (backlog item 1)
> **Status:** Closed

## Goal

Build the first M1 module — `categories` — the prerequisite
[products/specification.md](../modules/products/specification.md) has named as an unmet gap
(FR-032/FR-035) since Sprint 04. First sprint under M1's own governance: Rule 2 ("one module at a
time") applies literally again, no M0-style exception needed.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `categories` table + `POST`/`GET /categories` (server) | Categories | 1.0 | — |

Backend-only, matching the products-module precedent (Sprint 04 backend / Sprint 07 mobile). See
[categories/specification.md §1](../modules/categories/specification.md#1-purpose-and-business-context)
for the exact cut: create+list only, no `PATCH`/`DELETE`, no permission enforcement (Roles &
Permissions is deliberately the last M1 item), no mobile UI.

## Capacity check

1.0 person-day against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `categories/specification.md` (new), backlog.md, module
      registry, implementation-log, README bumps.

## Risks

- **First M1 module — first real test of Rule 2 governing literally again.** No exception needed
  or invoked; this module alone is 🔨 until its own DoD is met, per
  [modules/README.md](../modules/README.md) Rule 2.
- **`PATCH`/`DELETE /categories`'s state-transition idempotency mechanism** (`client_operation_id`
  + an `idempotency_keys` table) doesn't exist anywhere in this codebase yet — every M0 mutation
  was a creation. Deliberately not built this sprint; named as the concrete design work a future
  sprint (adding `PATCH`/`DELETE`) will need to do first.

## Definition of Done

- [x] `categories/specification.md` (new), all 11 sections, 🟢 Approved.
- [x] `categories` table (full column list — `id`, `tenant_id`, `name`, `created_at`,
      `created_by`), RLS enabled (`supabase/sql/008_rls_categories.sql`), applied to the live
      Supabase database.
- [x] `POST /api/v1/categories` — idempotent on client-generated `id`, matching every other M0
      creation endpoint's mechanism exactly.
- [x] `GET /api/v1/categories` — cursor-paginated, tenant-scoped.
- [x] Unit tests for the service layer (creation, idempotent replay, validation, list).
- [x] `tsc --noEmit` / `eslint` clean.
- [x] Live verification against the real database, throwaway tenants deleted after — idempotent
      creation and a cross-tenant RLS proof.
- [x] No secret, token, or key written to logs or committed to source.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** `PATCH`/`DELETE /categories`, `CATEGORY_IN_USE`,
`products.category_id` (backlog.md item 3), mobile UI (item 4), permission enforcement (item 7).

## Demo script

**Run 2026-08-14** against the live database, via real HTTP requests to a local dev server pointed
at production Supabase, throwaway tenants deleted after:

1. Onboard tenant A and tenant B (cross-tenant check). ✅
2. `POST /api/v1/categories` as tenant A — `201`, correct `id`/`name`. ✅
3. Replay the identical request — same row returned, not a duplicate. ✅
4. `GET /api/v1/categories` as tenant A — the created category present. ✅
5. As tenant B, `GET /api/v1/categories` — zero of tenant A's categories returned. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the first sprint
under M1's own governance (Rule 2 literal again), and the first time this project has built a
module with **zero** existing dependency friction — no prior sprint's gap, no cross-cutting
retrofit, just a clean new table. A useful baseline for how much of M0's own per-sprint overhead
was inherent to bootstrapping versus specific to the walking skeleton.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 17 planned and built same-day: `categories/specification.md` written first, `POST`/`GET /categories` built, live-verified against the real database (idempotent creation, cross-tenant RLS proof). First M1 module — Rule 2 governs literally, no exception invoked. |
