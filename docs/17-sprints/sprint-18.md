# Sprint 18

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M1 — Full Catalogue & Inventory, Multi-Role (backlog item 2)
> **Status:** Closed

## Goal

Build the second M1 module — `units` — the second of the two prerequisites
[products/specification.md](../modules/products/specification.md) has named as an unmet gap
(FR-032/FR-035/FR-037) since Sprint 04. Direct sibling of [Sprint 17](sprint-17.md) (Categories):
same shape, same scope cut, no dependency between the two.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `units` table + `POST`/`GET /units` (server) | Units | 1.0 | — |

Backend-only, matching Categories' own precedent (Sprint 17). See
[units/specification.md §1](../modules/units/specification.md#1-purpose-and-business-context)
for the exact cut: create+list only, no `PATCH`/`DELETE`, no permission enforcement (Roles &
Permissions is deliberately the last M1 item), no mobile UI.

## Capacity check

1.0 person-day against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `units/specification.md` (new), backlog.md, module
      registry, implementation-log, README bumps.

## Risks

- **`allows_fractional`'s immutability rule (`UNIT_FRACTIONAL_FLAG_LOCKED`) is named, not
  enforced.** Nothing this sprint can violate it yet — `PATCH /units` doesn't exist and
  `products.unit_id` doesn't exist — so there is nothing to protect against. Recorded so the future
  `PATCH` sprint doesn't have to rediscover the rule from scratch.
- **Same state-transition idempotency gap Sprint 17 already named** (`client_operation_id` +
  `idempotency_keys`) still doesn't exist anywhere in this codebase. Not built this sprint either —
  still tracked as future `PATCH`/`DELETE` work, for both Categories and Units together.

## Definition of Done

- [x] `units/specification.md` (new), all 11 sections, 🟢 Approved.
- [x] `units` table (full column list — `id`, `tenant_id`, `name`, `symbol`,
      `allows_fractional`, `created_at`, `created_by`), RLS enabled
      (`supabase/sql/009_rls_units.sql`), applied to the live Supabase database.
- [x] `POST /api/v1/units` — idempotent on client-generated `id`, matching every other creation
      endpoint's mechanism exactly.
- [x] `GET /api/v1/units` — cursor-paginated, tenant-scoped.
- [x] Unit tests for the service layer (creation, idempotent replay, validation, list).
- [x] `tsc --noEmit` / `eslint` clean.
- [x] Live verification against the real database, throwaway tenants deleted after — idempotent
      creation and a cross-tenant RLS proof.
- [x] No secret, token, or key written to logs or committed to source.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** `PATCH`/`DELETE /units`,
`UNIT_FRACTIONAL_FLAG_LOCKED`, `products.unit_id` (backlog.md item 3), mobile UI (item 4),
permission enforcement (item 7).

## Demo script

**Run 2026-08-14** against the live database, via real HTTP requests to a local dev server pointed
at production Supabase, throwaway tenants deleted after:

1. Onboard tenant A and tenant B (cross-tenant check). ✅
2. `POST /api/v1/units` as tenant A — `201`, correct `id`/`name`/`symbol`/`allows_fractional`. ✅
3. Replay the identical request — same row returned, not a duplicate. ✅
4. `GET /api/v1/units` as tenant A — the created unit present. ✅
5. As tenant B, `GET /api/v1/units` — zero of tenant A's units returned. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Second M1 module, and the first sprint of this
project to genuinely reuse a prior sprint's module shape almost verbatim (schema, repository,
service, route, tests) — worth watching whether that reuse holds up once `PATCH`/`DELETE` land for
both Categories and Units at once (backlog.md's own open question, not yet scheduled).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 18 planned and built same-day: `units/specification.md` written first, `POST`/`GET /units` built, live-verified against the real database (idempotent creation, cross-tenant RLS proof). Second M1 module — direct sibling of Categories (Sprint 17). |
