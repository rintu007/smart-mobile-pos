# Sprint 21

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M1 — Full Catalogue & Inventory, Multi-Role (backlog item 5)
> **Status:** Closed

## Goal

Full barcode/SKU search: `GET /api/v1/products` (server) plus the till's own barcode scan
(FR-034/FR-036, NFR-002) — the last M1 item that depends only on Products/Categories/Units
already existing (items 1–3), not on Roles & Permissions (item 7, deliberately last).

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `GET /api/v1/products?search=&category_id=&barcode=` (server) + mobile barcode scan wired into the till's product picker | Products, POS | 2.0 | 3, 4 |

## Design decision, found before writing code

[FR-034](../03-functional-requirements/functional-requirements.md)/[FR-036](../03-functional-requirements/functional-requirements.md)
are both explicitly marked **"Fully offline"** in functional-requirements.md, and
[NFR-002](../03-functional-requirements/non-functional-requirements.md) sets a p95 ≤ 800 ms budget
for barcode scan → item on screen. Together these rule out the till's own scan/search/category-
filter calling the new server endpoint directly — a network round trip cannot meet either
constraint, and doesn't need to: the mobile local `products`/`categories` cache (already
pull-synced) has everything needed. So this sprint builds two genuinely separate things under one
backlog item: `GET /api/v1/products` as its own documented, tested, server capability (not yet
consumed by any built mobile screen — named, not silently skipped), and the till's actual
scan/search/filter UX, entirely local.

## A related gap found and fixed in the same pass

Extending the sync pull response for the barcode feature surfaced a real Sprint 20 gap: `category_id`/
`unit_id`/`sku`/`barcode` were added to both the server and local `products` tables, but the pull
mapping (`sync/service.ts`'s `pullProducts`, and the mobile parsing/upsert) never carried any of
them down. Only a product's own *creating* device ever had real values — a product created on
another device, or directly against the server, pulled down with all four `null` regardless of
what the server actually held. Fixed in the same PR, not left for a later sprint to rediscover.

## Capacity check

2.0 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `products/specification.md` §4/§6/§7/§9/§10/§11,
      `catalogue.md`, `route-map.md` (`/pos/scan` correction), backlog.md, module registry,
      implementation-log, README bumps.

## Risks

- **Camera hardware is untestable in this environment.** `BarcodeScanScreen` (a thin
  `mobile_scanner` view) is not unit/widget tested — the same boundary this project already drew
  for Bluetooth printing (`printer_picker_dialog.dart` has no test file either). The till's own
  half of the contract (button present, `findByBarcode` wired) is tested; the camera itself is a
  founder-device action, same as MTS-01.
- **Second local schema migration** (schemaVersion 2 → 3, `sku`/`barcode` on `products`) —
  same non-destructive discipline as Sprint 20's first one.

## Definition of Done

- [x] `GET /api/v1/products` — `search`/`category_id`/`barcode` filters, cursor-paginated on
      `(updated_at, id)`, live-verified.
- [x] Local `Products` table gains nullable `sku`/`barcode` (schema v2→v3, non-destructive
      `onUpgrade`).
- [x] Sync pull now carries `category_id`/`unit_id`/`sku`/`barcode` down to devices (server
      response and mobile parsing/upsert both fixed).
- [x] `/pos` (till screen): search field, category filter chips, "scan barcode" button; `/pos/scan`
      route + screen.
- [x] `ProductRepository.findByBarcode` (domain interface + Drift implementation), local-only.
- [x] Unit tests: server `listProducts` (search/category/barcode filters, pagination, cursor
      rejection); mobile `findByBarcode`; sync pull/upsert carrying the four fields; till search
      filter; till scan-button wiring.
- [x] `tsc --noEmit`/`eslint`/`vitest` (web) and `flutter analyze`/`flutter test` (mobile) all clean.
- [x] Live verification against the real database for `GET /products`, throwaway tenants deleted
      after — 7/7 checks.
- [x] `products/specification.md`, `catalogue.md`, `route-map.md` all updated/corrected in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** a `/catalogue` product-list screen (the only future
consumer of `GET /products` itself), `PATCH`/`DELETE /products`, Roles & Permissions (item 7).

## Demo script

**Server, run 2026-08-14** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. `search=milk` returns exactly the two milk-named products, not an unrelated one. ✅
2. `search=<sku>` matches on `sku`, not just `name`. ✅
3. `category_id=` returns only products in that category. ✅
4. `barcode=` returns exactly the matching product. ✅
5. Cursor pagination: `limit=2` across 3 products — page 1 has `next_cursor`, page 2 is the
   remainder with `next_cursor: null`. ✅
6. Tenant B's session returns zero of tenant A's products. ✅
7. A malformed cursor returns `422 VALIDATION_FAILED`. ✅

**Mobile, run 2026-08-14** via `flutter analyze` (clean) and `flutter test` (94/94 passing,
including the new `findByBarcode`/pull-fix/search/scan-button tests). No physical-device camera
test this sprint — see Risks.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the second sprint
in a row (after Sprint 20) where a Fully-offline FR forced a real design split between "what the
backlog item's wording suggests" (one endpoint, one feature) and "what the actual requirements
demand" (two independent capabilities, one local-only). Also the second time in two sprints that
extending one feature (pull-sync, for barcode) surfaced an unrelated gap left by the immediately
preceding sprint — worth watching whether this is a pattern (schema-extension sprints tend to leave
a companion sync-mapping gap) or a coincidence.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 21 planned and built same-day: `GET /api/v1/products` built and live-verified (7/7); till screen gains search/category-filter/barcode-scan, all local per FR-034/FR-036's "Fully offline" classification; found and fixed a real Sprint 20 gap (sync pull never carried category_id/unit_id/sku/barcode down to devices). `flutter test` 94/94, web suites clean. |
