# Endpoints — Catalogue

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
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
| `UNIT_FRACTIONAL_FLAG_LOCKED` | 409 | `allows_fractional` change attempted on a unit already referenced by a product. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial catalogue endpoint set: categories, units, products. product_variants deliberately has no endpoint yet. |
