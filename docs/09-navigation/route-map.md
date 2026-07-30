# Route Map

> **Status:** 🔵 In review
> **Phase:** 09 — Navigation
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
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
| `/catalogue/:id` | Cashier+ (view), Manager+ (edit) | Yes | Product detail |
| `/catalogue/categories` | Manager+ | Yes | |
| `/catalogue/units` | Manager+ | Yes | |
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
| `/settings` | Cashier+ (contents vary) | Yes | Home |
| `/settings/tax` | Owner | Yes | [FR-075](../03-functional-requirements/functional-requirements.md) |
| `/settings/currency` | Owner | Yes | |
| `/settings/printer` | Cashier+ | Yes | Pairing/test-print — deliberately not Owner-restricted ([permission matrix](../05-personas/permission-matrix.md)) |
| `/settings/receipt-template` | Owner | Yes | Cannot disable mandatory fields ([FR-078](../03-functional-requirements/functional-requirements.md)) |
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
