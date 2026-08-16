# Endpoints — Sales

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.4.0
> **Last updated:** 2026-08-14
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
| `POST /trading-days/open` | Cashier, Manager, Owner | Online-only this sprint (queuing deferred, see implementation note) | Creation | Scoped per-**store**, not per-device — a named deviation from this row's original "per-device" wording, see the Sprint 26 implementation note below. Rejected with `TRADING_DAY_ALREADY_OPEN` if this store already has an open day. **Built Sprint 26.** |
| `POST /trading-days/{id}/close` | Cashier, Manager, Owner | Online-only this sprint | State-transition | Body carries `counted_cash_minor_units`; server computes `expected_cash_minor_units` (sum of this day's cash `sale_payments`) and `variance_minor_units` — the client never submits the expected or variance figures, per [api-principles.md §7](../api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure). Idempotent: replaying a close on an already-closed day returns the existing state unchanged. **Built Sprint 26.** |
| `POST /trading-days/{id}/reopen` | Manager, Owner only ([DR-020](../../03-functional-requirements/business-rules.md)) | Online-only | State-transition | **New this sprint** — named in state-machines.md/audit-model.md but never listed here until now, a real gap found writing trading-day/specification.md §1. No request body. |
| `GET /trading-days/current` | Cashier, Manager, Owner | Read cached | N/A | "Is there an open day at this **store** right now" (per-device wording corrected, see below) — returns `{ "trading_day": null }` when none is open, not an error. **Built Sprint 26.** |

## Sales

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `POST /sales` | Cashier, Manager, Owner | **Yes — queued** | Creation | The core POS write. Full shape below. **Sprint 24: now also assigns `canonical_invoice_number`/`financial_year` in the same transaction** (see the implementation note below). |
| `GET /sales/{id}` | Cashier, Manager, Owner | Read cached | N/A | Returns the sale **with `line_items` and `payments` embedded** — per [api-principles.md §2](../api-principles.md#2-resource-naming), never as separate paginated sub-resources. **Built Sprint 24**, no ownership restriction — any role, any sale in the tenant, matching this row's own wording exactly (no "own device" qualifier, unlike the list row below). |
| `GET /sales` | Cashier (own device's trading day only — [permission-matrix.md](../../05-personas/permission-matrix.md)), Manager, Owner (store-wide) | Read cached | N/A | Filters: `trading_day_id`, `date_from`, `date_to`, `customer_id`. Cursor-paginated on `(completed_at, id)`. **Built Sprint 24** — see the implementation note below for how the Cashier restriction is actually implemented, and which filters are live. |
| `GET /sales/lookup` | Cashier, Manager, Owner | Read cached | N/A | Filter: `provisional_invoice_number` (exact) or `canonical_invoice_number` (exact) — the returns-flow lookup, [FR-062](../../03-functional-requirements/functional-requirements.md); distinct route from `/sales` per [route-map.md](../../09-navigation/route-map.md)'s split by permission and purpose. **Built Sprint 24**; Zod requires exactly one of the two identifiers. |

## Implementation note (Sprint 24, [sales-invoices/specification.md](../../modules/sales-invoices/specification.md))

`GET /sales`'s "Cashier: own device's trading day only" is unimplementable as literally worded —
neither `devices` nor `trading_days` exists in code (both continuing, separately-named gaps). The
closest faithful adaptation actually built: **a Cashier sees only sales they themselves created**
(`created_by` = their own user id); Manager/Owner see every sale, store-wide. `trading_day_id` and
`customer_id` filters are not implemented — neither Trading Day nor Customers exists yet; only
`date_from`/`date_to` are live. `GET /sales` returns **summary fields only** (no embedded
`line_items`/`payments`) — a deliberate choice to keep a list response bounded regardless of how
many line items each sale has; `GET /sales/{id}` is where the full embedded shape lives.

**There is no `PATCH` or `DELETE` on `/sales/{id}` once `status = 'completed'`** — matching the
schema trigger in [schema-server.md](../../07-database/schema-server.md). A `draft`/`held` sale
(the in-progress or explicitly-held cart, per [navigation-model.md](../../09-navigation/navigation-model.md))
is mutated only on the client until the moment it completes; a held/draft cart is not itself synced
to the server as a partial row — see [sync-api.md](../sync-api.md) for exactly what crosses the
wire and when.

## Implementation note (Sprint 27, [pos/specification.md](../../modules/pos/specification.md))

**Discount is built as a per-line request field pair, not shown in this section's own worked
example above** (which predates it): `line_items[].discount_percent_basis_points` or
`line_items[].discount_amount_minor_units` (mutually exclusive, DR-011), plus an optional
top-level `discount_approved_by`. The server computes `line_discount_minor_units` per line,
`discount_total_minor_units` for the sale, and rejects with `DISCOUNT_REQUIRES_APPROVAL` (409) if
the total exceeds `shop_settings.discount_auto_approval_threshold_minor_units` and neither the
caller nor the named approver resolves to an active Manager/Owner at this store (DR-012).

**A real semantic correction, found implementing this**: `subtotal_minor_units` now means what
[money-and-tax.md](../../07-database/money-and-tax.md) always specified — post-discount, pre-tax —
not the pre-discount raw sum this implementation silently computed before Discount existed to
make the two values diverge. `grand_total_minor_units` equals `subtotal_minor_units` exactly until
Tax computation (M2 item 4) adds a `tax_total_minor_units` on top.

## Implementation note (Sprint 26, [trading-day/specification.md](../../modules/trading-day/specification.md))

**Trading Day is scoped per-`(tenant_id, store_id)` in this implementation, not per-`device_id`** —
a named, dated deviation from this document's and schema-server.md's original per-device wording.
No `devices` table exists in code, and [offline-workflows.md — Finding 2](../../06-workflows/offline-workflows.md#finding-2--trading-day-is-a-shared-store-level-concept-and-multi-device-shops-need-a-rule)'s
own text already frames per-device as a sidestep of the real "one physical drawer" model, not the
more-correct one — store-level scoping is the more faithful substitution for V1's single-device
target, and avoids a real correctness bug per-user scoping would introduce (two Cashiers on one
physical till both holding an "open day" simultaneously). See trading-day/specification.md §1 for
the full reasoning.

**`POST /sales` gains an optional `trading_day_id`, but `TRADING_DAY_NOT_OPEN` is not yet enforced
when the field is omitted** — a deliberate, dated deferral. When supplied, an invalid/closed/foreign
value is still rejected with `TRADING_DAY_NOT_OPEN`; only the *omission* case is unenforced. This
reverses backlog.md's own pre-sprint planning note for this item, to avoid regressing the one live,
working end-to-end sale flow this project has (Sprint 16) ahead of the matching mobile till change
that must ship alongside the hard gate. Also **not built this sprint**: offline queuing for
`open`/`close`/`reopen` (no `sync/push` operation type exists for any of the three yet) — all three
are online-only for now, named as a continuing gap rather than claimed done.

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
  "canonical_invoice_number": 118,
  "financial_year": "2026",
  "subtotal_minor_units": 2800,
  "tax_total_minor_units": 324,
  "discount_total_minor_units": 140,
  "grand_total_minor_units": 6784,
  "line_items": [ { "product_id": "<uuid>", "quantity": "1.000", "unit_price_minor_units": 2800, "line_tax_minor_units": 324, "line_total_minor_units": 2984 } ],
  "payments": [ { "method": "cash", "amount_minor_units": 7000 } ],
  "completed_at": "2026-07-30T09:30:00Z"
}
```

**Corrected Sprint 24, found while implementing this:** `canonical_invoice_number` is assigned at
sync-order time ([ADR-0008](../../adr/ADR-0008-offline-invoice-numbering.md)) — when this sale was
created directly online (device already connected), assignment happens in the same request; when
queued offline, it is assigned during [sync-api.md](../sync-api.md)'s push and the client picks it
up on the next pull. **In this implementation, that means it is never actually `null` for a stored
sale**: `POST /sales` and `POST /sync/push`'s `sale.create` operation call the exact same
`pos/service.ts#createSale`, and this server never persists a `sales` row until the moment it
"arrives" — the provisional-only, not-yet-synced state exists only on the mobile device's own
local database, never as a partial server row. The column remains nullable to match
schema-server.md's approved design, but every code path that creates a `sales` row assigns a
canonical number in the same transaction — see
[sales-invoices/specification.md §1](../../modules/sales-invoices/specification.md#1-purpose-and-business-context)
for the full reasoning.

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
| `TRADING_DAY_NOT_OPEN` | 409 | `POST /sales` supplied a `trading_day_id` that doesn't resolve to an open day at this store. **Only reachable when the field is supplied and invalid this sprint** — omitting the field entirely raises nothing yet (Sprint 26's named, deliberate deferral). |
| `TRADING_DAY_ALREADY_OPEN` | 409 | `POST /trading-days/open` (or `/reopen`) attempted while one is already open at this store. Built Sprint 26. |
| `TRADING_DAY_NOT_CLOSED` | 409 | **New, Sprint 26.** `POST /trading-days/{id}/reopen` targets a day that is neither open nor closed — unreachable given only two statuses exist, named defensively. |
| `PRICE_MISMATCH` | 409 | See above — connected-device case only; the offline case does not produce this error at all. |
| `PAYMENT_AMOUNT_MISMATCH` | 409 | A submitted payment's total does not equal the server-recomputed `grand_total_minor_units` — added in M0's minimal implementation (Sprint 05), which has no discount/tax yet so this simplifies to "payment must equal the sum of line totals." |
| `SALE_IMMUTABLE` | 409 | Any write attempt against a `completed` sale. |
| `DISCOUNT_REQUIRES_APPROVAL` | 409 | **New, Sprint 27.** `discount_total_minor_units` exceeds `shop_settings.discount_auto_approval_threshold_minor_units` and neither the caller nor `discount_approved_by` resolves to an active Manager/Owner at this store. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial sales/trading-day endpoint set; server-recompute behaviour and the connected-vs-offline price-mismatch distinction specified in full. |
| 0.1.1 | 2026-08-01 | Correction found planning Sprint 05: this document's `POST /sales` shape is the full V1 contract, but backlog.md scopes M0 to cash-only/no-discount/no-tax and defers Trading Day (M2) and device registration (Authentication, not yet built) — noted inline rather than narrowing this section. |
| 0.2.0 | 2026-08-14 | Sprint 24 (backlog item 8): `GET /sales/{id}`, `GET /sales`, `GET /sales/lookup` built and live-verified (7/7); `POST /sales` now assigns `canonical_invoice_number`/`financial_year` atomically. Corrected: `canonical_invoice_number` is never actually `null` for a stored sale in this implementation (see the new implementation note). `GET /sales`'s "own device's trading day only" Cashier restriction adapted to "own sales they personally created," since neither `devices` nor `trading_days` exists in code. |
| 0.3.0 | 2026-08-14 | Sprint 26 (backlog.md M2 item 2): `POST /trading-days/open`, `POST /trading-days/{id}/close`, `POST /trading-days/{id}/reopen` (new), `GET /trading-days/current` all built and live-verified (26/26). Trading Day re-scoped per-store, not per-device (a named, dated deviation — see the new implementation note). `POST /sales` gains an optional `trading_day_id`; the `TRADING_DAY_NOT_OPEN` hard gate is deliberately deferred to the sprint pairing this with the mobile till's own open-day flow. Added `TRADING_DAY_NOT_CLOSED`. |
| 0.4.0 | 2026-08-14 | Sprint 27 (backlog.md M2 item 3): per-line Discount built and live-verified — `discount_percent_basis_points`/`discount_amount_minor_units` (DR-011), `discount_approved_by` (DR-012), `DISCOUNT_REQUIRES_APPROVAL`. Corrected `subtotal_minor_units` to money-and-tax.md's always-specified post-discount, pre-tax meaning. |
