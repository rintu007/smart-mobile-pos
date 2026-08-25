# Entity Classification

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.2.0
> **Last updated:** 2026-08-26
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
| `trading_days` | Client-editable, but **conflict-limited by a real database constraint, not "conflict-free by construction"** | **Corrected 2026-08-26 — see §3 below.** Scoped per-*store*, not per-device (Sprint 26 built it this way; no `devices` table existed until Sprint 55, 29 sprints later) — two devices at the same store genuinely can race to open the same day, and a hand-edited partial unique index (`trading_days_one_open_per_store`) is the real, database-level guard preventing it, not an absence of the collision case. |
| `tenants`, `stores` | Server-authoritative | Practically static in V1 (one store per tenant, never shown in UI — [ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)) |
| Stock balance, cash-drawer expected-cash, customer purchase totals | Derived | Never a row anywhere, local or server — computed live from `stock_movements`/`sale_payments`, per [ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md) |
| `outbound_queue`, `local_provisional_sequence` (local-only, no server equivalent) | N/A — these are the sync mechanism itself, not synced entities | [outbound-queue.md](outbound-queue.md), [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) |
| `idempotency_keys`, `sync_rejections` | **Corrected 2026-08-26:** neither was ever built, on either side — not "server-only" | Both remain purely designed, per `schema-server.md`'s own Context 7 entries; `idempotency_keys`' real-world substitute (client-generated `id` alone as the dedup key) was found and named Sprint 41, never carried back to this document until now |
| `invoice_sequences` | Server-authoritative | **Not in the original 22-table design** — added Sprint 24, found missing from this classification entirely during Sprint 76's audit. A pure atomic counter, mutated as a side effect of sale creation; never synced to mobile, no local write path of any kind. |
| `customer_field_conflicts` | Server-authoritative (with a dedicated pull/resolve path, not a generic sync operation) | **Not in the original design** — added Sprint 35, found missing here too. Server-generated only, when a `customer.update` push detects a genuine field conflict; read by mobile via `GET /customers/conflicts` and acted on via `POST /customers/conflicts/{id}/resolve` (Owner/Manager, online-only) — pulled and resolved, but never client-created or client-edited directly. |
| `rate_limit_buckets` | N/A — pure API infrastructure, outside this phase's own scope | **Not in the original design** — added Sprint 45. Never synced, never read by any client, no role ever "edits" it — the same category as `outbound_queue` above (the sync/API mechanism itself, not a synced business entity), found missing here during Sprint 76's audit. |

**Correction (2026-08-26):** the claim below originally said all 22 tables from the *original*
`schema-server.md` design appeared above exactly once — true as far as it went, but that design has
since grown to 25 real tables (Sprint 69's own audit), 3 of which (`invoice_sequences`,
`customer_field_conflicts`, `rate_limit_buckets`) were never added here, silently leaving this
document's own "no entity is unclassified" exit criterion actually unmet since each table was
built (Sprints 24, 35, and 45 respectively — dozens of sprints ago in every case). All three are
added above now. **All 25 real tables in `schema-server.md`, plus the 2
local-only tables, now appear above exactly once.**

## 3. Finding 2 — corrected, 2026-08-26 (this section's original reasoning was wrong)

[offline-workflows.md — Finding 2](../06-workflows/offline-workflows.md#finding-2--trading-day-is-a-shared-store-level-concept-and-multi-device-shops-need-a-rule)
asked whether Trading Day needs a cross-device conflict policy. **This section originally said Phase
07 resolved it by scoping `trading_days` per *device*, making concurrent writes to the same row
structurally impossible.** That was never actually true: `schema-server.md` documented a `device_id`
column here, but Sprint 26 — the sprint that actually built this table — scoped it by
`(tenant_id, store_id)` instead, a real, deliberate deviation named at the time in
`trading-day/specification.md §1`, corrected in `schema-server.md` itself during Sprint 69's own
audit, but never carried back to this document until now.

**The real resolution, stated correctly:** two devices at the same store genuinely *can* attempt to
write the same `trading_days` row — specifically, both racing to open a new trading day at the same
time. This is not "structurally impossible," it's a real concurrency case that Sprint 26 closed with
an actual database-level guard: a hand-edited partial unique index,
`CREATE UNIQUE INDEX trading_days_one_open_per_store ON trading_days(tenant_id, store_id) WHERE
status = 'open'` — the second of two concurrent `POST /trading-days/open` calls at the same store
fails outright rather than creating a duplicate open day. This is genuinely conflict-*resolved*, the
same practical outcome this section originally claimed, but by an enforced constraint against a real
race, not by the race being impossible in the first place — a materially different, and more
accurate, thing to tell a reader relying on this document to understand what actually prevents a
collision.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Authoritative classification of all 22 server tables + 2 local-only tables; corrected the categories/units/products misclassification found while producing this document; confirmed Finding 2's per-device resolution closes the Trading Day conflict question structurally. |
| 0.2.0 | 2026-08-26 | Sprint 76 (offline-sync staleness audit): found and corrected a real, load-bearing error, not just staleness — §3's "trading_days is conflict-free by construction because it's scoped per-device" was never true; the real (Sprint 26) scoping is per-store, and a real database-level partial unique index prevents the genuine concurrent-open race, not an absent collision case. Also corrected `idempotency_keys`/`sync_rejections` (mischaracterized as "server-only" when neither was ever built at all) and added 3 real tables missing from this document's own "every entity classified, no exceptions" list since each was built (`invoice_sequences`, `customer_field_conflicts`, `rate_limit_buckets`) — the exit criterion this document claims to satisfy had quietly stopped being true. |
