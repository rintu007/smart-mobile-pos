# Sprint 36

> **Dates:** 2026-08-16 – 2026-08-16 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (backlog item 1 — Sync pull, reporting parity)
> **Status:** Closed — M4 item 1 done. M4 now has items 2–9 remaining.

## Goal

Extend `GET /sync/pull` to `stock_movements`/`sales` — the "reporting parity across devices" pull
[sync-api.md §6](../11-api/sync-api.md#6-pull--getsyncpull) has named since Phase 11 and never
implemented. Reports (M4 item 2, next) reads its four figures entirely from the local caches this
sprint fills; no server endpoint of Reports' own is needed
([sync-engine/specification.md §1](../modules/sync-engine/specification.md#1-purpose-and-business-context)).

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `GET /sync/pull` gains `stock_movements`/`sales`; mobile upsert into existing local tables, resumable per-entity-type cursor | Offline Sync Engine | 2.5 | — |

## Design decisions, found while writing the spec

Full detail in
[sync-engine/specification.md §1](../modules/sync-engine/specification.md#1-purpose-and-business-context)/[§2](../modules/sync-engine/specification.md#2-business-rules).

1. **A single `next_cursor` field can't mean two things at once.** `products`' own pull cursor is
   never persisted between sync cycles (a small, near-static catalogue, unchanged this sprint) — its
   `next_cursor` only ever needs to answer "keep paging within this run?" `stock_movements`/`sales`
   are an ever-growing transaction history; re-pulling the whole thing every sync cycle is real,
   avoidable cost, which means a *durable* resume cursor is needed too. Those are different facts.
   Resolved by adding a second field, `has_more`, to these two entity types' pull response only —
   `next_cursor` becomes always-the-last-row-seen (a stable resume point, echoed back unchanged on an
   empty page rather than reset to `null`), `has_more` carries the "keep paging now" signal instead.
   A dated correction to [sync-api.md §6](../11-api/sync-api.md#6-pull--getsyncpull)'s own text,
   which had conflated the two under one field. `products`' contract is untouched.
2. **Reports' Manager/Owner gate has no server call left to enforce it against.** Once this pull
   exists, every device holds the same shop-wide `stock_movements`/`sales` data regardless of role —
   [permission-matrix.md — Reports](../05-personas/permission-matrix.md#reports)'s restriction will
   necessarily be a client-side presentation control when M4 item 2 builds the actual report screens,
   not a data-access boundary this pull endpoint could add. Named now, not discovered mid-item-2.
3. **A new local-only table, `sync_cursors`**, persists the resume cursor per entity type
   (`stock_movements`/`sales` only — `products` deliberately keeps its existing no-persistence
   trade-off). Schema v6→v7, non-destructive (`CREATE TABLE`, no existing data touched).
4. **Mobile's two new pull functions are optional, trailing constructor params**, defaulting to a
   no-op empty page — the same "avoid a mass test-signature rewrite" precedent Sprint 34's
   `DriftSaleRepository` already set, rather than breaking every existing 3-arg `SyncRepository` test
   call site.

## Capacity check

2.5 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: none used as rework — the `has_more`/persisted-cursor design was
      resolved at spec-writing time, before code; live verification passed on the first attempt
      (24/24 checks).
- [x] Documentation capacity reserved: `sync-engine/specification.md`, `sync-api.md`, module
      registry, backlog.md, this sprint doc, implementation-log, README bumps.

## Risks

- **None new.** No schema change on the server (existing `stock_movements`/`sales` tables, read
  only); the mobile migration is additive (`CREATE TABLE sync_cursors`), the same low-risk shape
  every prior schema-local.md migration in this project has used.

## Definition of Done

- [x] Server: `GET /sync/pull` accepts `entity_type=stock_movements`/`sales`; `sync/repository.ts`
      gains `listSalesForSync` (tenant-scoped, `(completed_at, id)` cursor, includes line items);
      `stock_movements` reuses `stock-movements/repository.ts`'s existing `listStockMovements`
      unfiltered. Both pull functions return `{ data, next_cursor, has_more }`.
- [x] Mobile: local `sync_cursors` table (schema v6→v7); `SyncRepository._pullAllStockMovements`/
      `_pullAllSales` resume from a persisted cursor, upsert into the existing local
      `StockMovements`/`Sales`/`SaleLineItems` tables; `SyncApi.pullStockMovementsPage`/
      `pullSalesPage`; `SyncRunSummary` gains `stockMovementsPulled`/`salesPulled`.
- [x] Unit tests: `sync/service.test.ts` — 12 new cases (`pullStockMovements`/`pullSales`: `has_more`
      + non-null `next_cursor` on a partial page, cursor-echo on an empty page, `null` only when
      truly fresh, malformed-cursor rejection, tenant-scoped/unfiltered query passthrough,
      `created_at` alongside `formatSale`'s own shape). Total 42 sync tests.
- [x] Mobile tests: `sync_repository_test.dart` — 5 new cases (multi-page pull + upsert, persisted
      cursor read back on the next `syncNow()`, idempotent re-pull for both entity types, sale +
      line items pulled together). Every pre-existing 3-arg `SyncRepository(...)` test call site
      needed no changes (optional trailing params, default no-op).
- [x] `tsc --noEmit`/`eslint`/`vitest` (42 sync tests, full suite otherwise unaffected) all clean;
      `flutter analyze`/`flutter test` (193 total mobile tests) all clean.
- [x] Live verification against the real database, throwaway tenants (deleted after) — 24/24 checks:
      pagination + `has_more`/`next_cursor` correctness across 3 stock movements (opening, sale,
      adjustment) at `limit=2`, a completed sale pulled with its line items intact, cross-tenant
      isolation on both entity types, malformed cursor and unsupported `entity_type` both `422`.
- [x] `sync-engine/specification.md`, `sync-api.md` §6 (dated correction) both updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

## Demo script

**Server, run 2026-08-16** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. Create a product with `initial_quantity: 10` (an automatic `opening` movement), complete a sale
   of 3 units (an automatic `sale` movement), record a manual `adjustment` of +5. ✅
2. `GET /sync/pull?entity_type=stock_movements&limit=2` → 2 rows, `has_more: true`, non-null
   `next_cursor`. ✅
3. Same call with that `next_cursor` → the remaining row, `has_more: false`, **still** a non-null
   `next_cursor` (the last row seen, not the old "final page means null" signal). ✅
4. Same call again with *that* cursor (nothing new since) → 0 rows, `next_cursor` unchanged from the
   caller's own, `has_more: false`. ✅
5. `GET /sync/pull?entity_type=sales` → the completed sale, its line item's `product_id`/`quantity`
   intact, `created_at` present. ✅
6. A second, empty tenant's pull of either entity type → 0 rows, cross-tenant isolation held. ✅
7. A malformed cursor and an unsupported `entity_type` both → `422 VALIDATION_FAILED`. ✅

**Unit tests, run 2026-08-16**: `vitest run` — all sync tests passing (42/42); `flutter test` — all
193 mobile tests passing (5 new).

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the first sprint
where a pull entity type's response shape needed to diverge from `products`' own established
contract (`has_more` as a distinct field) — resolved cleanly once the actual conflict
("keep-paging" vs. "durable resume point" are different facts) was named explicitly, rather than
forcing a growing-history entity type through a design that only ever had to serve a small, static
one. M4 — Reports, Settings, and Release Readiness now has items 2–9 remaining, per
[backlog.md §5](backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | Sprint 36 planned and built same-day: `stock_movements`/`sales` sync pull built and live-verified (24/24). M4 item 1 done, items 2–9 remain. |
