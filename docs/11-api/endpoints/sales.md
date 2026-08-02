# Endpoints — Sales

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Covers `trading_days`, `sales`, `sale_line_items`, `sale_payments`
([schema-server.md](../../07-database/schema-server.md)'s Context 5) — the highest-frequency,
highest-stakes module in the API. Every rule in
[api-principles.md §7](../api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure)
applies most heavily here.

---

## Trading day

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `POST /trading-days/open` | Cashier, Manager, Owner | **Yes — queued** | Creation | Scoped per-device, per [schema-server.md](../../07-database/schema-server.md)'s resolution of the multi-till question. Rejected with `TRADING_DAY_ALREADY_OPEN` if this device already has an open day. |
| `POST /trading-days/{id}/close` | Cashier, Manager, Owner | Yes — queued | State-transition | Body carries `counted_cash_minor_units`; server computes `expected_cash_minor_units` (sum of this day's cash `sale_payments`) and `variance_minor_units` — the client never submits the expected or variance figures, per [api-principles.md §7](../api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure). |
| `GET /trading-days/current` | Cashier, Manager, Owner | Read cached | N/A | "Is there an open day on this device right now" — checked before every `POST /sales`. |

## Sales

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `POST /sales` | Cashier, Manager, Owner | **Yes — queued** | Creation | The core POS write. Full shape below. |
| `GET /sales/{id}` | Cashier, Manager, Owner | Read cached | N/A | Returns the sale **with `line_items` and `payments` embedded** — per [api-principles.md §2](../api-principles.md#2-resource-naming), never as separate paginated sub-resources. |
| `GET /sales` | Cashier (own device's trading day only — [permission-matrix.md](../../05-personas/permission-matrix.md)), Manager, Owner (store-wide) | Read cached | N/A | Filters: `trading_day_id`, `date_from`, `date_to`, `customer_id`. Cursor-paginated on `(completed_at, id)`. |
| `GET /sales/lookup` | Cashier, Manager, Owner | Read cached | N/A | Filter: `provisional_invoice_number` (exact) or `canonical_invoice_number` (exact) — the returns-flow lookup, [FR-062](../../03-functional-requirements/functional-requirements.md); distinct route from `/sales` per [route-map.md](../../09-navigation/route-map.md)'s split by permission and purpose. |

**There is no `PATCH` or `DELETE` on `/sales/{id}` once `status = 'completed'`** — matching the
schema trigger in [schema-server.md](../../07-database/schema-server.md). A `draft`/`held` sale
(the in-progress or explicitly-held cart, per [navigation-model.md](../../09-navigation/navigation-model.md))
is mutated only on the client until the moment it completes; a held/draft cart is not itself synced
to the server as a partial row — see [sync-api.md](../sync-api.md) for exactly what crosses the
wire and when.

## M0's actual first implementation is smaller than this section's full shape

**Correction, found while planning Sprint 05 (2026-08-01):** [backlog.md item 6](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)
scopes M0's `POST /sales` to "manual product add to cart..., cash payment only" — no discount, tax,
split payment, or hold/resume, all explicitly [M1 scope](../../17-sprints/backlog.md#2-m1m4--module-grain-only-decomposed-when-reached).
`trading_day_id` can't be required either: Trading Day is its own M2-scope module (not yet built),
and `device_id` can't be required since `devices` (Authentication's device-registration slice) isn't
built yet either — the same category of gap already named for Authentication's row in the
[module registry](../../modules/README.md) ("device registration/revocation not yet built"). This
section below is still the correct full V1 target; M0's real shape is documented in
[pos/specification.md](../../modules/pos/specification.md) instead — `line_items` and a single
`cash` `payments` entry only, no `trading_day_id`/`device_id`/`customer_id`/tax/discount fields.
Those fields become required/accepted once the modules they depend on land — matching the pattern
already used for `catalogue.md`'s own `POST /products` correction.

## Request/response shape — `POST /sales`

**Request**

```json
{
  "id": "<client-generated UUIDv4>",
  "store_id": "<uuid>",
  "trading_day_id": "<uuid>",
  "customer_id": null,
  "provisional_invoice_number": "DEV042-2026-000118",
  "line_items": [
    {
      "product_id": "<uuid>",
      "quantity": "1.000",
      "client_unit_price_minor_units": 2800
    }
  ],
  "payments": [
    { "method": "cash", "amount_minor_units": 7000 }
  ],
  "client_computed_grand_total_minor_units": 6784
}
```

**What the server recomputes, per [api-principles.md §7](../api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure):**
current `products.price_minor_units` for each line (compared against `client_unit_price_minor_units`
— a mismatch means the device's cached catalogue is stale, not that the client is malicious; see
below), `tax_rate_basis_points` from `shop_settings.tax_mode`, `line_tax_minor_units` per
[money-and-tax.md](../../07-database/money-and-tax.md)'s worked discount-before-tax rule, and
`grand_total_minor_units`. `client_computed_grand_total_minor_units` exists **only** so the server
can detect and log a client/server disagreement (a stale local tax-rate cache, most plausibly) — it
is never the value persisted to `sales.grand_total_minor_units`.

**Response `201`**

```json
{
  "id": "<uuid>",
  "status": "completed",
  "provisional_invoice_number": "DEV042-2026-000118",
  "canonical_invoice_number": null,
  "subtotal_minor_units": 2800,
  "tax_total_minor_units": 324,
  "discount_total_minor_units": 140,
  "grand_total_minor_units": 6784,
  "line_items": [ { "product_id": "<uuid>", "quantity": "1.000", "unit_price_minor_units": 2800, "line_tax_minor_units": 324, "line_total_minor_units": 2984 } ],
  "payments": [ { "method": "cash", "amount_minor_units": 7000 } ],
  "completed_at": "2026-07-30T09:30:00Z"
}
```

`canonical_invoice_number` is `null` until the sale is assigned one at sync-order time
([ADR-0008](../../adr/ADR-0008-offline-invoice-numbering.md)) — when this sale was created directly
online (device already connected), assignment happens in the same request; when queued offline, it
is assigned during [sync-api.md](../sync-api.md)'s push and the client picks it up on the next pull.

## A stale-price mismatch is not the same failure as a fraud attempt

Per [api-principles.md §7](../api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure),
a client-submitted price is never trusted — but this module distinguishes *why* a mismatch happened,
because the two causes need different handling. A **connected** device sending a stale price is
almost certainly a caching bug or a race with a just-changed price — rejected synchronously with
`PRICE_MISMATCH` so the Cashier can retry immediately with the refreshed price, before the customer
has left. An **offline-queued** sale that turns out to have used a since-changed price is a normal,
expected consequence of offline operation, not an error to reject — the sale still completes using
the price the Cashier actually charged the customer (a POS cannot retroactively demand more money
after the fact), and the price discrepancy is logged to `sync_rejections` for the Owner's visibility,
per [sync-api.md](../sync-api.md), rather than blocking the sale.

## Errors specific to this module

| Code | HTTP | Cause |
| --- | --- | --- |
| `TRADING_DAY_NOT_OPEN` | 409 | `POST /sales` attempted with no open trading day on this device. |
| `TRADING_DAY_ALREADY_OPEN` | 409 | `POST /trading-days/open` attempted while one is already open. |
| `PRICE_MISMATCH` | 409 | See above — connected-device case only; the offline case does not produce this error at all. |
| `PAYMENT_AMOUNT_MISMATCH` | 409 | A submitted payment's total does not equal the server-recomputed `grand_total_minor_units` — added in M0's minimal implementation (Sprint 05), which has no discount/tax yet so this simplifies to "payment must equal the sum of line totals." |
| `SALE_IMMUTABLE` | 409 | Any write attempt against a `completed` sale. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial sales/trading-day endpoint set; server-recompute behaviour and the connected-vs-offline price-mismatch distinction specified in full. |
| 0.1.1 | 2026-08-01 | Correction found planning Sprint 05: this document's `POST /sales` shape is the full V1 contract, but backlog.md scopes M0 to cash-only/no-discount/no-tax and defers Trading Day (M2) and device registration (Authentication, not yet built) — noted inline rather than narrowing this section. |
