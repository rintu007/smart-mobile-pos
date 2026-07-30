# API Principles

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer / CTO
> **Approved by:** _pending_

The conventions every endpoint document in [endpoints/](endpoints/) and [sync-api.md](sync-api.md)
follows, stated once here rather than repeated per resource — the same discipline
[schema-server.md](../07-database/schema-server.md) applied to its column conventions.

---

## 1. Versioning

`/api/v1/*`, per [ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md) and
[backend-structure.md](../08-folder-structure/backend-structure.md). The version is in the URL, not
a header — a header-based version is invisible in logs, proxies, and debugging tools; a URL-based
one is not. **A breaking change ships as `/api/v2/*` alongside `/api/v1/*`, never as a mutation of
`v1`'s contract** — per this phase's rule, old app versions stay in the field and cannot be forced
to update mid-trading-day. `v1` is retired only once telemetry shows no client has called it in a
defined trailing window (set in Phase 18 once real usage data exists to set that window sensibly).

## 2. Resource naming

- Plural nouns, kebab-case for multi-word resources: `/stock-movements`, `/sale-payments`, not
  `/stockMovements` or `/stock_movement`.
- **Aggregates are returned whole, not fragmented into paginated sub-resources.** A sale's line
  items and payments are embedded directly in the `GET /sales/{id}` response body, never exposed as
  `/sales/{id}/line-items` with its own pagination — a sale is bounded (at most a few dozen lines by
  construction; nobody scans 500 barcodes into one basket) and is always read as a whole document
  ([sales.md](endpoints/sales.md)). This is a deliberate distinction from `/sales` itself (the
  *list* of a store's sales), which is genuinely unbounded and therefore paginated per §4.
- One level of nesting maximum. `/returns/{id}/approve` (an action on a resource) is acceptable;
  `/stores/{id}/sales/{id}/line-items/{id}` is not — resources are looked up by their own ID with
  tenant/store scoping applied via the auth context (§ [authentication.md](authentication.md)), not
  via the URL path.

## 3. Idempotency — two mechanisms, matched to two kinds of mutation

Per this phase's exit criterion, **every mutating endpoint is idempotent via a client-supplied key**.
[identifiers.md §5](../07-database/identifiers.md#5-edge-case--idempotency-keys-are-identifiers-too)
already established that the client-generated entity ID doubles as the idempotency key for
creations. This document extends that into the two concrete mechanisms actually used:

| Mutation shape | Mechanism | Example |
| --- | --- | --- |
| **Entity creation** (the request's outcome is a new row) | The client generates the row's `id` (UUIDv4, per [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md)) and includes it in the request body. The server performs `INSERT ... ON CONFLICT (id) DO NOTHING`, then returns the row matching that `id` regardless of whether this call created it or a prior retry did. A retry is therefore indistinguishable from the original at the response level. | `POST /sales` with `"id": "<client-uuid>"` in the body |
| **State transition on an existing entity** (no new row; e.g. approve a return, close a trading day, revoke a device) | The request body includes a `client_operation_id` (a fresh UUIDv4, generated once at the moment of the user action, per [identifiers.md §5](../07-database/identifiers.md#5-edge-case--idempotency-keys-are-identifiers-too)). The server checks it against `idempotency_keys` ([schema-server.md](../07-database/schema-server.md)) before applying the transition; a repeat with the same `client_operation_id` returns the original result without reapplying the transition. | `POST /returns/{id}/approve` with `"client_operation_id": "<uuid>"` |

**A mutation with neither shape does not exist in this API** — every mutating endpoint document in
[endpoints/](endpoints/) states which of the two mechanisms it uses; there is no third "unsafe to
retry" category, because unreliable networks (per this phase's founding rule) make retries certain,
not exceptional.

## 4. Pagination — cursor-only

Every list endpoint accepts `?cursor=<opaque>&limit=<n, default 50, max 200>` and returns:

```json
{ "data": [ /* up to `limit` items */ ], "next_cursor": "<opaque>|null" }
```

The cursor encodes a stable `(sort_column, id)` tuple (typically `(created_at, id)` for Tier 2
append-only tables, `(updated_at, id)` for Tier 1 tables — matching
[schema-server.md](../07-database/schema-server.md)'s own per-table indexing), base64-encoded and
opaque to the client. **Offset pagination (`?page=2`) is not used anywhere in this API** — per this
phase's exit criterion, offset pagination breaks under concurrent inserts, which
[device-and-context.md](../05-personas/device-and-context.md) and the sales volume this product is
built for make the normal condition, not an edge case.

## 5. Filtering

Filters are plain query parameters scoped to the endpoint's own resource (e.g.
`GET /products?category_id=<uuid>&search=<text>`) — documented per endpoint in
[endpoints/](endpoints/), not a generic cross-resource filter language. A generic filter DSL is
speculative generality this API does not need; every V1 filter need is already known from
[functional-requirements.md](../03-functional-requirements/functional-requirements.md) and can be
named explicitly.

## 6. Error envelope

One shape, every error, every endpoint:

```json
{
  "error": {
    "code": "STOCK_MOVEMENT_REJECTED",
    "message": "A short, English, log-facing description — not shown to the Cashier verbatim.",
    "details": { }
  }
}
```

- `code` is a **stable, machine-readable string** from the single flat namespace in
  [error-catalogue.md](error-catalogue.md) — per this phase's exit criterion, **clients never parse
  `message`**; they switch on `code` and select the actual on-screen copy from
  [voice-and-tone.md](../10-design-system/voice-and-tone.md)'s rules. This is what lets copy be
  changed, translated, or reworded without a client release.
- `details` is optional, structured, and code-specific (e.g. which field failed validation) — never
  free text that a client would need to parse.
- The HTTP status code is meaningful and consistent per [error-catalogue.md](error-catalogue.md)
  (e.g. `409` for a state conflict, `422` for a validation failure) — `code` is authoritative for
  client branching, but the HTTP status still matters for generic tooling (proxies, monitoring).

## 7. The server recomputes; it never trusts a client figure

Restated from this phase's founding rule because it constrains every mutating endpoint's design,
not just sales: **no request body field representing a price, tax, total, or stock quantity is
used as submitted.** The server recomputes it from authoritative data (current
`products.price_minor_units`, `shop_settings.tax_mode`, the ledger balance in
`stock_movements`) and compares. A mismatch does not silently correct itself — it is rejected with
`PRICE_MISMATCH` or `STOCK_ANOMALY` (see [error-catalogue.md](error-catalogue.md)) and, if
discovered after the fact during sync, recorded in `sync_rejections`
([sync-api.md](sync-api.md)) rather than the sale/return being force-corrected server-side. A
client that submits its own subtotal only ever does so to let the server verify agreement, never as
a source of truth.

## 8. Every response is bounded, paginated, and tenant-scoped by construction

Per this phase's exit criterion, this is enforced structurally, not by convention someone might
forget: every Route Handler resolves its Prisma query through a module's `repository.ts`
([backend-structure.md](../08-folder-structure/backend-structure.md)), and every repository method
for a tenant-owned table takes the authenticated request's `tenant_id` as a mandatory first
parameter with no default — there is no code path that queries a tenant-owned table without it.
Row Level Security ([tenancy-model.md](../07-database/tenancy-model.md)) is the independent second
enforcement layer behind this, exactly as [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md)
requires — API-level scoping is not treated as sufficient on its own.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial principles: versioning, naming, two idempotency mechanisms, cursor pagination, error envelope, server-recomputes rule. |
