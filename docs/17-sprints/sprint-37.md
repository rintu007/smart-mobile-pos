# Sprint 37

> **Dates:** 2026-08-16 – 2026-08-16 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (backlog item 2 — Reports)
> **Status:** Closed — M4 item 2 done. M4 now has items 3–9 remaining.

## Goal

Build the four core reports [FR-071](../03-functional-requirements/functional-requirements.md#group-j--reports-core-four)–[FR-074](../03-functional-requirements/functional-requirements.md#group-j--reports-core-four)
name — daily sales, top products, stock value, low stock — as pure mobile-local Drift aggregation,
no new server report endpoint, per [Sprint 36](sprint-36.md)'s own already-built dependency
(`stock_movements`/`sales` sync pull).

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Four report screens (local aggregation), `shop_settings.low_stock_threshold_quantity`, `shop_settings` sync pull, Reports role probe | Reports | 3 | 1 (Sync pull, reporting parity) |

## Design decisions, found while writing the spec

Full detail in [reports/specification.md §1](../modules/reports/specification.md#1-purpose-and-business-context).

1. **A real, blocking gap: no low-stock threshold configuration existed anywhere.**
   BR-024/BR-045 require it to be "configurable, per-product or shop-wide" — resolved as a single
   shop-wide `shop_settings.low_stock_threshold_quantity` (default `5`), matching
   `tax_rate_basis_points`' own V1-simplification precedent. Per-product granularity explicitly
   deferred, named.
2. **A chained gap: `shop_settings` had never been synced to any device.** Documented as a pull
   entity type since Phase 11, never implemented — added as sync pull's fourth entity type,
   deliberately minimal (only the one field Reports needs) and never paginated (exactly one row per
   tenant).
3. **This codebase's first genuine client-side role-awareness.** Reports' Manager/Owner gate has no
   server call to enforce it against (every device holds the same data regardless of role, per
   Sprint 36's own note) — resolved by reusing the already-existing, already Manager/Owner-only
   `GET /users` endpoint purely as a permission probe, cached locally, fail-closed by default. Not a
   new capability, not a cached JWT claim (role stays resolved fresh server-side for every actual
   authorization decision, per DR-017/018) — used only to decide UI visibility.

## Capacity check

3 person-days against the ~3.75 person-day sprint budget — landed close to estimate despite the two
additional found gaps, since both were small in absolute scope (one column, one trivial pull
endpoint) even though genuinely unanticipated at decomposition time.

## Reserved capacity

- [x] Defect capacity reserved: none used as rework — every design decision above was resolved at
      spec-writing time, before code.
- [x] Documentation capacity reserved: `reports/specification.md` (new), `sync-engine/specification.md`,
      `sync-api.md`, `settings/specification.md` implicitly extended via schema/service changes,
      module registry, backlog.md, this sprint doc, implementation-log, README bumps.

## Risks

- **None new.** The low-stock threshold column is additive with a safe default (existing tenants get
  `5` automatically via the column default, no backfill needed); the `shop_settings` pull is
  read-only, no write path added; the role probe never throws, so it cannot regress any existing
  sync behaviour even if `GET /users` itself changes shape later.

## Definition of Done

- [x] Server: `shop_settings.low_stock_threshold_quantity` (new migration, default `5`); onboarding
      writes it explicitly; `PATCH /settings` accepts it; `GET /settings` returns it to every role;
      `GET /sync/pull?entity_type=shop_settings` (new, minimal, unpaginated).
- [x] Mobile: `ShopSettingsCache` local table (schema v7→v8) — the low-stock threshold plus the
      `canViewReports` role-probe result; `SyncRepository` gains two more optional trailing pull
      functions, refreshing both on every `syncNow()`.
- [x] `ReportsRepository`/`DriftReportsRepository` — pure local Drift aggregation, no injected remote
      function (the first repository in this codebase with none); `/reports` hub plus
      `/reports/daily-sales`, `/reports/top-products`, `/reports/stock-value`, `/reports/low-stock`.
- [x] `HomeScreen` gains a conditionally-rendered Reports entry point, gated by
      `canViewReportsProvider` — hidden (not disabled) for a Cashier, and while the probe is still
      resolving or has never run, fail-closed.
- [x] Unit tests: `settings/service.test.ts` (2 new cases, low-stock threshold passthrough), `sync/service.test.ts`
      (2 new cases, `pullShopSettings`). Total 207 web tests.
- [x] Mobile tests: `drift_reports_repository_test.dart` (11 new cases — daily sales bucketing, stock
      value, top products ranking/date-range/omission, low-stock threshold/sort/default-fallback,
      `canViewReports` fail-closed default), `sync_repository_test.dart` (4 new cases — cache writes,
      swallowed-probe-failure, null-pull-leaves-cache-untouched, unchanged-call-site compatibility),
      `reports_screen_test.dart` (8 new cases across all 5 screens), `widget_test.dart` (3 new cases,
      `HomeScreen`'s Reports button visibility in all three probe states). Total 218 mobile tests.
- [x] `tsc --noEmit`/`eslint`/`vitest` (207 total web tests) all clean; `flutter analyze`/`flutter test`
      (218 total mobile tests) all clean; production build confirmed before pushing.
- [x] Live verification against the real database, throwaway tenants (deleted after) — 11/11 checks,
      covering the server-side additions only (the default value, `PATCH`/`GET /settings` round-trip,
      the new pull entity type, cross-tenant isolation). The mobile-local reports themselves have no
      server call to verify live against, per the module spec's own stated equivalent-rigor position.
- [x] `reports/specification.md` (new), `sync-engine/specification.md`, `sync-api.md` all updated in
      this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

## Demo script

**Server, run 2026-08-16** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. `GET /settings` on a freshly-onboarded tenant → `low_stock_threshold_quantity: 5`. ✅
2. `PATCH /settings` sets it to `12` → reflected immediately. ✅
3. A Cashier's own `GET /settings` still sees the threshold (unlike the two auto-approval
   thresholds, which stay hidden from them). ✅
4. `GET /sync/pull?entity_type=shop_settings` → the one row, `next_cursor`/`has_more` both
   null/false, no other settings fields leaked. ✅
5. A second, untouched tenant's pull sees its own default (`5`), not the first tenant's `12` —
   cross-tenant isolation held. ✅

**Unit/widget tests, run 2026-08-16**: `vitest run` — 207/207 passing; `flutter test` — 218/218
passing.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the third
consecutive sprint (34, 36, 37) where starting the *named* item surfaced a further, previously
invisible gap the backlog's own decomposition couldn't have caught without actually attempting the
work — a low-stock threshold that never existed, `shop_settings` never synced, no client-side role
signal anywhere. Each was small once found and named explicitly at spec-writing time, before code;
the pattern itself is the useful signal, not any one instance of it.

M4 — Reports, Settings, and Release Readiness now has items 3–9 remaining, per
[backlog.md §5](backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | Sprint 37 planned and built same-day: all four core reports built and verified (11/11 server-side live checks; 218/218 mobile tests). M4 item 2 done, items 3–9 remain. |
