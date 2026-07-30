# Endpoints — Inventory

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer
> **Approved by:** _pending_

Covers `stock_movements` ([schema-server.md](../../07-database/schema-server.md)'s Context 3) — the
append-only ledger proven correct in [stock-ledger.md](../../07-database/stock-ledger.md). **There
is no `PATCH` or `DELETE` endpoint for a stock movement, anywhere in this API** — matching the
schema's own revoked `UPDATE`/`DELETE` privileges. A correction is always a **new** movement with an
opposite-signed `quantity_delta` and `movement_type = 'adjustment'`, never an edit.

---

| Method & path | Permission | Offline | Idempotent | Notes |
| --- | --- | --- | --- | --- |
| `POST /stock-movements` | Manager, Owner (Inventory Staff role is a Phase 05 persona, not yet a distinct system role — see [user-stories.md](../../03-functional-requirements/user-stories.md)'s persona-vs-role clarification; access follows Manager permission until a dedicated role ships) | **Yes — queued** | Creation | Records one ledger entry: `opening`, `adjustment` (requires `reason_code`), `sale`, or `return`. **`sale`/`return` movements are never posted via this endpoint directly** — they are created server-side as a side effect of `POST /sales` and `POST /returns` completing, inside the same transaction, so a sale and its stock consequence can never exist independently. This endpoint is reachable by a client only for `opening` and `adjustment`. |
| `GET /stock-movements` | Manager, Owner | Read cached | N/A | Filters: `product_id`, `date_from`, `date_to`, `movement_type`. Cursor-paginated on `(created_at, id)` — Tier 2, no `updated_at`. Used for the movement-history view, not for balance calculation (see below). |
| `GET /products/{id}/stock-balance` | Any authenticated role | Read cached (see note) | N/A | Returns the **current derived balance** — `SUM(quantity_delta)` per [stock-ledger.md](../../07-database/stock-ledger.md) — computed server-side, never by the client summing a locally cached movement list, since a client's local cache may be incomplete relative to other devices' synced movements. Offline, the client shows its own last-known cached balance with the staleness treatment from [state-presentation.md](../../10-design-system/state-presentation.md), explicitly not a live recomputation. |

## Request/response shape — `POST /stock-movements` (adjustment)

**Request**

```json
{
  "id": "<client-generated UUIDv4, doubles as client_operation_id>",
  "product_id": "<uuid>",
  "quantity_delta": "-2.000",
  "movement_type": "adjustment",
  "reason_code": "damaged"
}
```

**Response `201`**

```json
{
  "id": "<uuid>",
  "product_id": "<uuid>",
  "store_id": "<uuid>",
  "quantity_delta": "-2.000",
  "movement_type": "adjustment",
  "reason_code": "damaged",
  "created_at": "2026-07-30T09:20:00Z",
  "created_by": "<user id>",
  "device_id": "<device id>"
}
```

`store_id`, `device_id`, and `created_by` are **never accepted from the request body** — they are
resolved server-side from the authenticated session, per
[api-principles.md §8](../api-principles.md#8-every-response-is-bounded-paginated-and-tenant-scoped-by-construction).
A client claiming a different store or device than its own authenticated context is not a validation
error to correct — it is ignored; the server's own context always wins.

## Why oversell is not an error here

Per [stock-ledger.md](../../07-database/stock-ledger.md)'s worked concurrent-oversell example, a
negative resulting balance is **accepted, not rejected** — two offline devices independently selling
the last unit of a product is a real, expected scenario, and rejecting the second sale outright
would mean refusing a legitimate sale a Cashier has no way to know is a problem at the point of
sale. `POST /sales`'s resulting stock movement never fails with a "stock insufficient" error; it is
reconciled as a business anomaly for the Owner to see (a future stock-report concern, not a Phase 11
endpoint), never blocked at the API layer.

## Errors specific to this module

| Code | HTTP | Cause |
| --- | --- | --- |
| `ADJUSTMENT_REASON_REQUIRED` | 422 | `movement_type = 'adjustment'` submitted without `reason_code` — matches the schema's own `CHECK` constraint ([DR-007](../../03-functional-requirements/business-rules.md)), rejected at the API layer before it would even reach that constraint. |
| `DIRECT_SALE_MOVEMENT_FORBIDDEN` | 403 | An attempt to `POST /stock-movements` with `movement_type` of `sale` or `return` directly — these are only ever created as a side effect of [sales.md](sales.md)/[returns.md](returns.md) endpoints. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial inventory endpoint set: opening/adjustment creation, movement history, derived balance. No update/delete, matching the ledger's schema-level guarantee. |
