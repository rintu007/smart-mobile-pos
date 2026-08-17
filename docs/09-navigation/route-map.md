# Route Map

> **Status:** 🔵 In review
> **Phase:** 09 — Navigation
> **Version:** 0.1.6
> **Last updated:** 2026-08-17
> **Owner:** UI-UX Lead / Principal Flutter Engineer
> **Approved by:** _pending_

Every V1 route: path, required permission, and offline availability. Built against the shell in
[navigation-model.md](navigation-model.md). Permission values reference the
[permission matrix](../05-personas/permission-matrix.md) directly — a route's permission is never
invented fresh here.

---

## Pre-shell (unauthenticated / setup)

| Route | Permission | Offline | Notes |
| --- | --- | --- | --- |
| `/auth/login` | None | No — requires connectivity for the initial credential check ([FR-001](../03-functional-requirements/functional-requirements.md)) | |
| `/auth/verify` | None | No | Account verification step |
| `/onboarding/business-type` | None (new Owner, mid-signup) | Yes | Loads bundled defaults ([FR-002](../03-functional-requirements/functional-requirements.md)) |
| `/onboarding/shop-identity` | None | Yes | Name, currency, address ([FR-003](../03-functional-requirements/functional-requirements.md)) |
| `/onboarding/first-products` | None | Yes | Starter catalogue or manual entry ([FR-004](../03-functional-requirements/functional-requirements.md)) |
| `/onboarding/first-sale` | None | Yes | Guided first sale ([FR-005](../03-functional-requirements/functional-requirements.md)) |

## Till (default landing tab)

| Route | Permission | Offline | Notes |
| --- | --- | --- | --- |
| `/pos` | Cashier+ | Yes | Home route |
| `/pos/scan` | Cashier+ | Yes | Barcode-scan camera view — missing from the original decomposition (found building Sprint 21, same shape as `/catalogue/add`'s own Sprint 07 correction); pops with the scanned code, resolved against the local cache by `/pos` itself, per [FR-034](../03-functional-requirements/functional-requirements.md)/[FR-036](../03-functional-requirements/functional-requirements.md) |
| `/pos/hold` | Cashier+ | Yes | Held-carts list |
| `/pos/discount` | Cashier+ (approval gated inline above threshold) | Yes | [FR-029](../03-functional-requirements/functional-requirements.md) |
| `/pos/split-payment` | Cashier+ | Yes | [FR-028](../03-functional-requirements/functional-requirements.md) |
| `/pos/day/open` | Cashier+ | Yes | [FR-067](../03-functional-requirements/functional-requirements.md) |
| `/pos/day/close` | Cashier+ | Yes | [FR-068](../03-functional-requirements/functional-requirements.md)–[FR-070](../03-functional-requirements/functional-requirements.md) |
| `/pos/day/history` | Manager+ | Yes | Past trading-day reconciliations — judgment call, grouped with Reports' business-sensitivity reasoning rather than Cashier's own-shift-only need |
| `/returns/new` | Cashier+ | Yes, bounded by sync ([Finding 3](../06-workflows/offline-workflows.md#finding-3--return-lookup-is-bounded-by-what-has-synced-to-this-device)) | [FR-062](../03-functional-requirements/functional-requirements.md) |
| `/returns/:id` | Cashier+ | Yes (if locally cached) | Return detail |
| `/returns/approvals` | Manager+ | Yes (against cached role/threshold; re-validated at sync — [offline-workflows.md Finding 1](../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux)) | WF-013 |
| `/sales-history/lookup` | Cashier+ | Yes, bounded by sync | Search by receipt/invoice/phone — needed for returns, distinct from the browse-everything list below |
| `/sales-history` | Manager+ | Yes | Full browsable list — business-sensitive by the same reasoning as Reports |
| `/sales-history/:id` | Cashier+ | Yes (if locally cached) | Individual sale/invoice detail — reachable once a specific sale is known (lookup or receipt), independent of the Manager-only browse list |

## Catalogue

| Route | Permission | Offline | Notes |
| --- | --- | --- | --- |
| `/catalogue` | Cashier+ (view), Manager+ (edit) | Yes | Product list |
| `/catalogue/add` | Manager+ (edit) | Yes | Add a product — omitted from the original route list (added 2026-08-02, Sprint 07 planning); `/catalogue/:id` covered viewing/editing an *existing* product but nothing covered creating a new one |
| `/catalogue/:id` | Cashier+ (view), Manager+ (edit) | Yes | Product detail |
| `/catalogue/categories` | Manager+ | Partially — see 2026-08-14 correction below | Built Sprint 20 |
| `/catalogue/units` | Manager+ | Partially — see 2026-08-14 correction below | Built Sprint 20 |
| `/catalogue/inventory` | Cashier+ (view) | Yes | Stock balance list — [BR-024](../02-business-requirements/business-requirements.md) |
| `/catalogue/inventory/opening-stock` | Manager+ | Yes | [FR-040](../03-functional-requirements/functional-requirements.md) |
| `/catalogue/inventory/:productId/adjust` | Manager+ | Yes | [FR-043](../03-functional-requirements/functional-requirements.md) |
| `/customers` | Cashier+ | Yes | Needed for checkout attach/lookup ([FR-050](../03-functional-requirements/functional-requirements.md)/[FR-052](../03-functional-requirements/functional-requirements.md)) |
| `/customers/:id` | Cashier+ | Yes | Purchase history ([FR-051](../03-functional-requirements/functional-requirements.md)) |

## Reports — entire tab hidden from Cashier

| Route | Permission | Offline | Notes |
| --- | --- | --- | --- |
| `/reports` | Manager+ | Yes | Dashboard |
| `/reports/daily-sales` | Manager+ | Yes | [FR-071](../03-functional-requirements/functional-requirements.md) |
| `/reports/stock-value` | Manager+ | Yes | [FR-072](../03-functional-requirements/functional-requirements.md) |
| `/reports/top-slow-products` | Manager+ | Yes | [FR-073](../03-functional-requirements/functional-requirements.md) |
| `/reports/low-stock` | Manager+ | Yes | [FR-074](../03-functional-requirements/functional-requirements.md) |

## Settings

| Route | Permission | Offline | Notes |
| --- | --- | --- | --- |
| `/settings` | Cashier+ (contents vary), Owner (edit) | No — see 2026-08-16 correction below | Built Sprint 38 — tax mode/rate, pricing mode, rounding rule, currency, low-stock threshold, auto-approval thresholds (Manager/Owner only) |
| `/settings/tax` | — | — | Not built as a separate route — consolidated into `/settings` (see 2026-08-16 correction below) |
| `/settings/currency` | — | — | Not built as a separate route — consolidated into `/settings` (see 2026-08-16 correction below) |
| `/settings/printer` | Cashier+ | Yes | Built Sprint 39 — pairing/test-print, deliberately not Owner-restricted ([permission matrix](../05-personas/permission-matrix.md)); persists the paired printer locally (`PairedPrinterCache`), never sent to the server |
| `/settings/receipt-template` | Cashier+ (view), Owner (edit) | No — see 2026-08-16 correction below | Built Sprint 39 — the one customisable field, `footer_message` ([FR-078](../03-functional-requirements/functional-requirements.md)'s mandatory fields aren't editable here at all, by construction); same Pattern B/no-local-cache shape as `/settings` itself |
| `/settings/users` | Owner | No — role changes are server-authoritative ([FR-019](../03-functional-requirements/functional-requirements.md)) | |
| `/settings/devices` | Owner | No — revocation must reach the server ([FR-014](../03-functional-requirements/functional-requirements.md)) | |
| `/settings/audit-log` | Manager+ | No — not cached locally at all ([schema-local.md](../07-database/schema-local.md)) | |

---

## Coverage check

Every V1 module in [modules/README.md](../modules/README.md) has at least one route above. Every
route states a permission and an offline value — satisfying this phase's exit criterion directly;
none are left blank pending "figure out later."

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial route map: 6 pre-shell + 35 shell routes (13 Till, 9 Catalogue, 5 Reports, 8 Settings) — 41 total. |
| 0.1.1 | 2026-07-31 | **Correction:** the route count was originally miscounted as "4 pre-shell + 34 shell" (38 total); recounting the tables above gives 6 + 35 = 41. No routes were added or removed — the earlier figure simply undercounted what was already here. |
| 0.1.2 | 2026-08-02 | **Correction:** added `/catalogue/add`, missing from the original decomposition — `/catalogue/:id` covered an existing product's detail/edit but nothing covered creating a new one, found while planning Sprint 07's mobile product-creation screen. Total is now 6 pre-shell + 36 shell = 42. |
| 0.1.3 | 2026-08-14 | **Correction, found building Sprint 20:** `/catalogue/categories`/`/catalogue/units` were marked flatly "Offline: Yes," but the sync engine has no `category.create`/`unit.create` push operation type (only `product.create`/`sale.create` exist) — building that is real backend scope this sprint didn't do. Both routes are offline-capable for *reads* (a local cache) but require connectivity to *create* — corrected here rather than left overstated, same reasoning as `categories/specification.md §7`'s identical correction. |
| 0.1.4 | 2026-08-14 | **Correction, found building Sprint 21:** added `/pos/scan`, missing from the original decomposition — the barcode-scan camera view backlog item 5 needed had no route at all until now, same shape as `/catalogue/add`'s own Sprint 07 gap. |
| 0.1.5 | 2026-08-16 | **Correction, found building Sprint 38:** `/settings` was marked flatly "Offline: Yes," but this screen deliberately has no local cache (docs/modules/settings/specification.md §1/§9's own dated decision) — `GET /settings` is a live call with nothing to fall back on offline, same overstatement shape as `/catalogue/units`' own 0.1.3 correction. Also: `/settings/tax`/`/settings/currency` are not built as separate routes — consolidated into the single `/settings` screen, since `PATCH /settings`'s whole-row optimistic concurrency has no natural per-field-group boundary to split routes along. |
| 0.1.6 | 2026-08-17 | Built Sprint 39: `/settings/printer` and `/settings/receipt-template`, per their original rows. `/settings/receipt-template`'s permission corrected from a flat "Owner" to "Cashier+ (view), Owner (edit)," and its "Offline: Yes" corrected the same way 0.1.5 already corrected `/settings` itself — same underlying cause (no local cache for a live `GET /settings` read), not a new mistake. |
