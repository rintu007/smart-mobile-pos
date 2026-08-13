# Sprint 20

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M1 — Full Catalogue & Inventory, Multi-Role (backlog item 4)
> **Status:** Closed

## Goal

Build the mobile catalogue UI: `/catalogue/categories` and `/catalogue/units` (list + create), and
update `/catalogue/add` to require picking one of each. The last piece the founder needs to
actually organise real products by category/unit on-device, now that the server (Sprint 17–19)
and the schema (Sprint 19) both support it.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Mobile: categories/units local tables + CRUD screens, `/catalogue/add` requires a category/unit selection | Categories, Units, Products | 2.0 | 1, 2, 3 |

## Capacity check

2.0 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `categories/specification.md` §7/§9, `units/specification.md`
      §7/§9, `products/specification.md` §9, `route-map.md`, `schema-local.md`, backlog.md, module
      registry, implementation-log, README bumps.

## Design decision, found before writing code

The sync engine (`sync-api.md`) has exactly two push operation types — `product.create`,
`sale.create`. No `category.create`/`unit.create` exists, and building one is real backend scope
this sprint didn't budget for. Rather than either (a) silently building an offline queue path that
doesn't actually reach the server, or (b) quietly deciding not to build these screens at all, this
sprint follows an **already-approved precedent in this exact codebase**: `schema-local.md`'s own
`shop_settings` row already documents "full local read cache, but the write path is not
offline-capable — submitted directly when connected." Categories/units creation now works the same
way: a direct `POST /api/v1/categories`/`/units` call, cached locally only on success. Reads are
offline-capable (the cache); writes are not. Named as a dated correction in `categories/units/
specification.md §7`, `schema-local.md`, and `route-map.md` — not silently narrowed.

## Risks

- **First-ever local schema migration.** Every prior sprint shipped `schemaVersion: 1`; the
  founder's own device already has real local data (Sprint 16's end-to-end proof). Handled via an
  explicit `MigrationStrategy.onUpgrade` (`m.createTable`/`m.addColumn`), not a destructive
  recreate — verified by `flutter test`'s existing `database_test.dart` still passing unmodified.
- **`/catalogue/add`'s new required fields could strand a fresh tenant** with zero categories/units
  (an empty dropdown, no way to proceed). Named in `products/specification.md §9` as a real, minor
  UX gap rather than silently absorbed — no inline "create one now" shortcut was built this sprint.

## Definition of Done

- [x] Local `Categories`/`Units` Drift tables (read cache); `Products` gains nullable
      `category_id`/`unit_id` columns — migration `onUpgrade` from schema version 1 to 2.
- [x] `CategoryRepository`/`UnitRepository` (domain interfaces) + `DriftCategoryRepository`/
      `DriftUnitRepository` (online-only create, cache-on-success, local-cache reads).
- [x] `/catalogue/categories`, `/catalogue/units` — list + create-dialog screens, reachable from
      the home screen.
- [x] `/catalogue/add` — Category/Unit dropdowns, both required by client-side validation; the
      `product.create` sync payload now carries real `category_id`/`unit_id` values.
- [x] Unit tests: both new Drift repositories (create-then-cache, no-cache-on-server-failure,
      list ordering, refresh); `drift_product_repository_test.dart` updated for the new fields.
- [x] Widget tests: both new screens (empty state, create-via-dialog, validation) and
      `add_product_screen_test.dart` updated for the new required dropdowns.
- [x] `flutter analyze` clean, `flutter test` — 89/89 passing.
- [x] `categories/specification.md`, `units/specification.md`, `products/specification.md`,
      `route-map.md`, `schema-local.md` all corrected/updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** a `category.create`/`unit.create` sync-push
operation type (backend scope, not budgeted here), `PATCH`/`DELETE` for either entity, an inline
"create a category/unit from the add-product screen" shortcut, barcode/SKU search (backlog item 5).

## Demo script

Run 2026-08-14 via `flutter analyze` (clean) and `flutter test` (89/89 passing, including the two
new repository test files and two new screen test files, plus the updated
`drift_product_repository_test.dart`/`add_product_screen_test.dart`). No physical-device run this
sprint — matching Sprint 07/09's own precedent that `flutter test`'s real, file-backed Drift proof
is this project's mobile equivalent of "at least one real request," reserved for milestone-level
end-to-end proofs (Sprint 16) rather than every incremental UI sprint.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the first sprint to
hit a real, load-bearing gap between what `schema-local.md`'s design intended (full offline
read/write for categories/units) and what the sync engine actually supports (two operation types,
neither of them these) — found by checking, not assumed, and resolved by reusing an already-approved
pattern (`shop_settings`) rather than inventing a new one or silently overclaiming offline support.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 20 planned and built same-day: mobile `/catalogue/categories`/`/catalogue/units` (list+create), `/catalogue/add` now requires a category/unit selection. First-ever local schema migration (non-destructive). Found and corrected a real design gap: categories/units creation is online-only, not the offline-queued shape `schema-local.md` originally claimed — resolved via `shop_settings`' own existing precedent. `flutter analyze`/`flutter test` (89/89) clean. |
