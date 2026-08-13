# Endpoints — Catalogue

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.3
> **Last updated:** 2026-08-14
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Covers `categories`, `units`, `products`
([schema-server.md](../../07-database/schema-server.md)'s Context 2). `product_variants` has **no
V1 endpoint** — the table is a schema stub only ([schema-server.md](../../07-database/schema-server.md)),
and an endpoint for it would be exactly the kind of premature surface this documentation set avoids
building ahead of need.

---

## Categories & units

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /categories` | Any authenticated role | Read cached | N/A | Unpaginated in practice (a shop has dozens, not thousands, of categories) but still shaped as a cursor list per [api-principles.md §4](../api-principles.md#4-pagination--cursor-only) for consistency — no endpoint is a documented exception to the pagination rule. |
| `POST /categories` | Manager, Owner | **Yes — queued** | Creation | A Cashier never creates categories, but Managers commonly do so from the floor while setting up a new product line; this is why it's offline-capable despite being "back-office." |
| `PATCH /categories/{id}` | Manager, Owner | Yes — queued | State-transition | |
| `DELETE /categories/{id}` | Manager, Owner | Yes — queued | State-transition | Soft delete (`deactivated_at`); rejected with `CATEGORY_IN_USE` if active products reference it — [schema-server.md](../../07-database/schema-server.md)'s `ON DELETE RESTRICT` intent expressed at the API layer before it ever reaches a database constraint. |
| `GET /units` · `POST /units` · `PATCH /units/{id}` · `DELETE /units/{id}` | Same as categories | Same as categories | Same as categories | Identical shape; `allows_fractional` is immutable after creation if any product already references the unit — changing it retroactively would silently reinterpret historical `sale_line_items.quantity` values. |

## Products

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `GET /products` | Any authenticated role | Read cached | N/A | Filters: `category_id`, `search` (matches `name`, `sku`), `barcode` (exact match — the latency-critical scan-resolution path, [NFR-002](../../03-functional-requirements/non-functional-requirements.md)). Cursor-paginated on `(updated_at, id)`. |
| `GET /products/{id}` | Any authenticated role | Read cached | N/A | |
| `POST /products` | Manager, Owner | Yes — queued | Creation | See §"Products created offline" in [sync-api.md](../sync-api.md) for the dependency-ordering consequence of this being offline-capable. |
| `PATCH /products/{id}` | Manager, Owner | Yes — queued | State-transition | Changing `price_minor_units` does **not** retroactively touch any `sale_line_items.unit_price_minor_units` — those are immutable snapshots, per [schema-server.md](../../07-database/schema-server.md). |
| `DELETE /products/{id}` | Manager, Owner | Yes — queued | State-transition | Soft delete; a product with `stock_movements` history is never hard-deletable, matching the `ON DELETE RESTRICT` at the schema layer. |

### M0's actual first implementation is smaller than this section's full shape

**Correction, found while planning Sprint 04 (2026-08-01):** [backlog.md item 5](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)
scopes M0's `POST /products` to "name, price only — no barcode/category yet," and
[backlog.md's M1 row](../../17-sprints/backlog.md#2-m1m4--module-grain-only-decomposed-when-reached)
lists Categories and Units as M1 scope, not M0 — meaning `category_id`/`unit_id` can't be required
inputs yet either, since neither table exists until M1 builds them. This section below describes the
full V1 endpoint shape (still the correct target, and still what `PATCH`/later milestones grow into),
not what Sprint 04 actually builds. M0's real request/response is documented in
[products/specification.md](../../modules/products/specification.md) instead — only
`name`/`price_minor_units`, no `category_id`/`unit_id`/`sku`/`barcode`/`hsn_sac_code`. Those fields
become required/accepted once M1 lands; this endpoint's shape grows in place then, the same pattern
already used for `stores`' `PATCH` deferral in Sprint 02.

### `GET /products` implemented Sprint 21 (backlog.md item 5)

`GET /api/v1/products` now exists exactly as documented above:
[products/specification.md §4](../../modules/products/specification.md#4-api-contract). One
clarification found while building it: the till screen's own barcode-scan/search/category-filter
UX (FR-034/FR-036, both "Fully offline") does **not** call this endpoint — it resolves entirely
against the mobile local cache, since NFR-002's p95 ≤ 800 ms budget and the "Fully offline"
classification both rule out a network round trip on that path. This endpoint exists for any
future non-offline-critical consumer (e.g. a `/catalogue` list/admin screen, not yet built), per
this document's own original design intent — the two were never meant to be the same call.

### Request/response shape — `POST /products` (representative; others follow the same field set)

**Request**

```json
{
  "id": "<client-generated UUIDv4>",
  "category_id": "<uuid>",
  "unit_id": "<uuid>",
  "name": "Amul Milk 500ml",
  "sku": "AML-500",
  "barcode": "8901234567890",
  "hsn_sac_code": "0401",
  "price_minor_units": 2800
}
```

**Response `201`**

```json
{
  "id": "<uuid>",
  "category_id": "<uuid>",
  "unit_id": "<uuid>",
  "name": "Amul Milk 500ml",
  "sku": "AML-500",
  "barcode": "8901234567890",
  "hsn_sac_code": "0401",
  "price_minor_units": 2800,
  "created_at": "2026-07-30T09:12:00Z",
  "updated_at": "2026-07-30T09:12:00Z"
}
```

`price_minor_units` is an integer in minor currency units, never a decimal — per
[ADR-0006](../../adr/ADR-0006-money-as-integer-minor-units.md); this convention is not repeated in
every subsequent endpoint document, only its one deviation (if any) is called out.

## Errors specific to this module

| Code | HTTP | Cause |
| --- | --- | --- |
| `CATEGORY_IN_USE` | 409 | Delete attempted on a category with active products. |
| `BARCODE_ALREADY_ASSIGNED` | 409 | `barcode` collides with another active product in the same tenant. |
| `SKU_ALREADY_ASSIGNED` | 409 | `sku` collides with another product in the same tenant — the natural sibling of `BARCODE_ALREADY_ASSIGNED`, added Sprint 19 alongside `sku`'s own `(tenant_id, sku)` unique constraint rather than left as an unhandled 500. |
| `UNIT_FRACTIONAL_FLAG_LOCKED` | 409 | `allows_fractional` change attempted on a unit already referenced by a product. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial catalogue endpoint set: categories, units, products. product_variants deliberately has no endpoint yet. |
| 0.1.1 | 2026-08-01 | Correction found planning Sprint 04: this document's `POST /products` shape is the full V1 contract, but backlog.md scopes M0 to name/price only and defers Categories/Units to M1 — noted inline rather than narrowing this section, since it's still the correct eventual shape. |
| 0.1.2 | 2026-08-14 | Sprint 19: `category_id`/`unit_id`/`sku`/`barcode`/`hsn_sac_code` added to `POST /api/v1/products`, all optional rather than this document's own `NOT NULL` shape — see [products/specification.md §1](../../modules/products/specification.md#1-purpose-and-business-context)'s dated correction. Added `SKU_ALREADY_ASSIGNED`, the sibling of `BARCODE_ALREADY_ASSIGNED` this sprint's own `(tenant_id, sku)` unique constraint needed. |
| 0.1.3 | 2026-08-14 | Sprint 21: `GET /products` implemented exactly as this document already specified — no shape change. Added a note clarifying the till's own barcode/search/category-filter UX resolves locally, not via this endpoint (FR-034/FR-036 are "Fully offline"). |
