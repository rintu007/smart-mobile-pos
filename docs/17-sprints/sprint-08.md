# Sprint 08

> **Dates:** 2026-08-02 – 2026-08-02 (single-day, same pattern as Sprints 02–07)
> **Milestone:** M0 — Walking Skeleton
> **Status:** Closed

## Goal

Build store context — `GET /api/v1/stores` plus a mobile fetch-and-cache step after sign-in —
closing the gap Sprint 08 planning found: the till screen (item 6) cannot create a sale without
knowing its own `store_id`, and nothing built so far gives the device one.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| 13 | Company & Store Setup (`GET /stores`) + Authentication (mobile cache) | 1 | 2, 12 — both done |

Backend: `apps/web/src/modules/stores/` (new folder — `GET /stores` was already documented in
[identity.md](../11-api/endpoints/identity.md#stores) and named in
[company-store-setup/specification.md §4](../modules/company-store-setup/specification.md#4-api-contract)
as "not yet implemented," so no new specification was needed, only reaching what was already
approved). Mobile: `apps/mobile/lib/core/store_context/` and `core/network/` (the first mobile
feature to call this project's own backend directly, not just Supabase Auth) plus a new local
`StoreContext` Drift table (a read cache, never queued to `outbound_queue` — matches
[schema-local.md](../07-database/schema-local.md)'s `shop_settings` precedent).

Found two real gaps while planning, both fixed before/alongside the code that needed them:
- `backlog.md` never decomposed this work as its own item despite item 6 depending on it — added
  as item 13, mirroring Sprint 06's item-12 correction.
- `company-store-setup/specification.md §3` still said "Not yet built: RLS on `stores`" — stale
  since Sprint 02 actually shipped it (`supabase/sql/003_rls_stores.sql` already exists, referenced
  by Sprint 04's own products spec); never corrected after Sprint 02 closed. Fixed in this sprint's
  doc pass.

## Capacity check

1 person-day against [sprint-cadence.md](sprint-cadence.md)'s ~3.75 person-day budget — inside
budget. Deliberately narrow: this sprint does not touch the till screen itself (item 6) — store
context is a prerequisite, built and proven on its own before the much larger till-screen sprint
depends on it.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: this sprint's own doc updates (backlog.md item 13,
      company-store-setup/specification.md's stale-claim fix and `GET /stores` update,
      identity.md if needed, module registry, implementation-log, README bumps) are inside the
      estimate above.

## Risks

- **First mobile call to this project's own backend, not just Supabase Auth** — `core/network/`
  (a bare Dio client with a bearer-token interceptor reading the current Supabase session) is new,
  untested-until-now code. Verified live below.
- **Same device-target gap as Sprints 06/07** (`flutter doctor` — Windows C++ workload and Android
  SDK both still missing) — the mobile-side caching logic is proven via `flutter test` against a
  fake fetch function (no device needed, matching Sprint 07's pattern), while the actual HTTP
  contract is proven via a live backend demo script (matching Sprints 02/04/05's pattern) — neither
  half needs the missing device, so this sprint doesn't hit the same substitute-demo situation
  Sprints 06/07 did.
- **System memory ran low again** (1.78 GB free after this sprint's dev-server/test/build_runner
  work, down from the ~14 GB freed after Sprint 07's Chrome cleanup) — not yet critical, but worth
  naming: this machine's available memory heads downward across a working session and needs
  periodic attention, not just after an acute crash like Sprint 07's.

## Definition of Done

Backend-and-mobile slice — the [Definition of Done](../00-governance/definition-of-done.md) boxes
this sprint's scope can actually satisfy:

- [x] `GET /api/v1/stores` matches [identity.md](../11-api/endpoints/identity.md#stores) and
      [company-store-setup/specification.md §4](../modules/company-store-setup/specification.md#4-api-contract) —
      requires `requireSession`, returns `{ data: [{ id, name, address }], next_cursor: null }`.
- [x] Unit tests for the stores service (2 tests).
- [x] Live verification: a real onboarded tenant's session receives exactly its own store; a
      second tenant's session never sees the first tenant's store (cross-tenant RLS proof) — 9/9
      checks passed.
- [x] Mobile local cache (`StoreContext` Drift table) — write and read proven by 4 repository
      tests against a fake fetch function; cache-first behaviour (a second call doesn't re-fetch)
      explicitly asserted.
- [x] `flutter analyze` / `flutter test` clean; backend `vitest` clean.
- [x] No secret, token, or key written to logs or committed to source.
- [x] Module registry, backlog.md, and both affected module specifications updated.

**Explicitly not in this sprint's DoD subset:** the till screen itself (item 6), `PATCH
/stores/{id}` (still deferred per company-store-setup's own spec), any UI beyond the home screen's
existing loading/error text for the new store-context state.

## Demo script

**Part A — backend, live** (temporary script, deleted after, same pattern as Sprints 02/04/05):
1. Onboard tenant A (real `POST /api/v1/onboarding`), re-sign-in for a fresh `tenant_id`-bearing
   token (the token from before onboarding predates the `users` row the Custom Access Token Hook
   needs). ✅
2. `GET /api/v1/stores` as tenant A — exactly one store, matching what onboarding created,
   `next_cursor: null`. ✅
3. Onboard tenant B, `GET /api/v1/stores` as tenant B — exactly one store, tenant B's own, never
   tenant A's (cross-tenant RLS proof). ✅

**Part B — mobile, local** (`flutter test`, no device needed): `getCachedStoreId` returns `null`
before anything is cached; `ensureStoreContext` fetches once and caches, a second call reads the
cache without fetching again; `refreshFromServer` overwrites a stale cached store; an empty
server response throws rather than caching nothing silently.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-02 | Sprint 08 planned: closes a real gap found while planning the till screen — item 6 needs a `store_id` that nothing before this sprint gave the device. Added backlog item 13. Also found and fixed a stale "RLS on stores not yet built" claim in company-store-setup/specification.md, true as of Sprint 02 but never corrected. |
| 0.2.0 | 2026-08-02 | Sprint 08 closed: `GET /api/v1/stores` built and verified live (cross-tenant RLS proof, 9/9 checks passed), mobile fetch-and-cache built and tested (4 repository tests against a fake fetch function). A real script bug (reusing a pre-onboarding token) found and fixed on the first live attempt. PR pending. |
