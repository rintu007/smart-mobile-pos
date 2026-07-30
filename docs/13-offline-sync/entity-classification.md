# Entity Classification

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO / Principal Flutter Engineer
> **Approved by:** _pending_

Every entity, classified by sync behaviour, per this phase's charter — **the foundation everything
else in this phase builds on.** This document is now the **authoritative** source for entity
classification; [schema-local.md](../07-database/schema-local.md) provisionally classified entities
during Phase 07 and is corrected to match this document (see its own v0.1.1 changelog entry) rather
than the reverse.

---

## 1. The four classes, restated with the test that assigns an entity to one

| Class | Test | Sync mechanism |
| --- | --- | --- |
| **Immutable event** | Is it created once, client-originated, and never edited again? | Queued outbound, deduplicated by `client_operation_id`, never pulled-and-merged — only ever pulled to populate a read cache of *other* devices' events |
| **Server-authoritative** | Does editing it require connectivity by design, regardless of role? | Pull-only on mobile; no local write path exists |
| **Client-editable** | Can it be created/edited offline, by at least one role, in a way that could genuinely collide with another device's concurrent edit? | Bidirectional; needs the explicit policy in [conflict-resolution.md](conflict-resolution.md) |
| **Derived** | Is its value always computable from other already-synced data? | Never synced at all — recomputed locally |

## 2. Full classification — every table, no exceptions

| Entity | Class | Notes |
| --- | --- | --- |
| `sales`, `sale_line_items`, `sale_payments` | Immutable event | [sales.md](../11-api/endpoints/sales.md) |
| `stock_movements` | Immutable event | Correctness proven in [stock-ledger.md](../07-database/stock-ledger.md) |
| `returns`, `return_line_items` | Immutable event | [returns.md](../11-api/endpoints/returns.md) |
| `audit_log` | Immutable event | Written locally, queued outbound, **never pulled back down** ([schema-local.md](../07-database/schema-local.md)) |
| `users`, `user_store_roles`, `devices` | Server-authoritative | Role/device changes require connectivity — the risk Finding 1 (below) is specifically about |
| `product_variants`, `batches` | Server-authoritative (V1 stub) | No write path for anyone yet, per [schema-server.md](../07-database/schema-server.md) |
| `categories`, `units`, `products` | Client-editable | **Corrected classification** — see [schema-local.md](../07-database/schema-local.md)'s v0.1.1 changelog; matches [catalogue.md](../11-api/endpoints/catalogue.md)'s offline-write endpoints |
| `customers` | Client-editable | Cashier-creatable offline, per [customers.md](../11-api/endpoints/customers.md) |
| `shop_settings` | Client-editable | Bidirectional in principle, but **not offline-writable** ([settings.md](../11-api/endpoints/settings.md)'s deliberate exception) — classified client-editable because it is read-write and reconciled across devices, not because it is offline-editable; see [conflict-resolution.md](conflict-resolution.md) for why this narrows its actual conflict surface almost to zero |
| `trading_days` | Client-editable, but **conflict-free by construction** | Scoped per-device ([schema-server.md](../07-database/schema-server.md)) — resolves **Finding 2** (§3 below); no merge policy is needed because no two devices ever write the same row |
| `tenants`, `stores` | Server-authoritative | Practically static in V1 (one store per tenant, never shown in UI — [ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)) |
| Stock balance, cash-drawer expected-cash, customer purchase totals | Derived | Never a row anywhere, local or server — computed live from `stock_movements`/`sale_payments`, per [ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md) |
| `outbound_queue`, `local_provisional_sequence` (local-only, no server equivalent) | N/A — these are the sync mechanism itself, not synced entities | [outbound-queue.md](outbound-queue.md), [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) |
| `idempotency_keys`, `sync_rejections` | Server-only | Never present on-device at all, per [schema-local.md](../07-database/schema-local.md) |

**Every one of the 22 tables in [schema-server.md](../07-database/schema-server.md), plus the 2
local-only tables, appears above exactly once.** No entity is unclassified — this phase's own
blocking exit criterion.

## 3. Finding 2, resolved — restated here as this phase's own record, not just Phase 07's

[offline-workflows.md — Finding 2](../06-workflows/offline-workflows.md#finding-2--trading-day-is-a-shared-store-level-concept-and-multi-device-shops-need-a-rule)
asked whether Trading Day needs a cross-device conflict policy. It was already resolved in Phase 07
by scoping `trading_days` **per device**, not per store
([schema-server.md](../07-database/schema-server.md)) — this document confirms that resolution
holds up under this phase's own classification test: because no two devices ever write the *same*
`trading_days` row (each device's `device_id` is part of what identifies its own day), there is
structurally no concurrent-edit case to design a policy for. This is the entity-classification
system correctly routing an apparent "client-editable, needs a policy" case into "conflict-free by
construction" once the underlying scoping decision is accounted for — not a special case bolted on.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Authoritative classification of all 22 server tables + 2 local-only tables; corrected the categories/units/products misclassification found while producing this document; confirmed Finding 2's per-device resolution closes the Trading Day conflict question structurally. |
