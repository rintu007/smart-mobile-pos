# On-Device Schema (Drift/SQLite)

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.2
> **Last updated:** 2026-07-31
> **Owner:** Principal Flutter Engineer / PostgreSQL Architect
> **Approved by:** _pending_

The on-device schema mirrors [schema-server.md](schema-server.md) field-for-field **except where
explicitly noted below** — this document is the complete list of divergences, not a full repeat of
every column, per this phase's exit criterion for an explicit field-by-field mapping.

**One assumption stated up front:** a device holds exactly one tenant's data in V1 — a shop-issued
phone is used for one shop only. This is why local tables carry no `tenant_id` column at all (unlike
the server, which needs it for RLS-based multi-tenant isolation) — there is nothing to disambiguate
locally. If a future version supports switching tenants on one device (e.g. a consultant helping
multiple shops), this assumption is revisited then, not now.

---

## Entity classification (drives every divergence below)

Per [13-offline-sync/README.md](../13-offline-sync/README.md)'s four sync classes, applied to the
actual V1 tables:

| Class | Tables | What this means locally |
| --- | --- | --- |
| **Immutable event** | `stock_movements`, `sales`, `sale_line_items`, `sale_payments`, `returns`, `return_line_items`, `audit_log` | Created locally, queued outbound, never edited after creation — local copy is identical in shape to the server table. |
| **Server-authoritative** | `users`, `user_store_roles`, `devices` | Read-only cache locally, populated by pull-sync; **no local write path at all** for these — editing them requires connectivity by design ([FR-019](../03-functional-requirements/functional-requirements.md), role changes are a security-sensitive, infrequent, back-office action where an offline-then-revoked change is exactly the risk this classification avoids). |
| **Client-editable, single-writer** | `trading_days`, `customers`, `shop_settings`, `categories`, `units`, `products` | Editable offline by Manager/Owner ([endpoints/catalogue.md](../11-api/endpoints/catalogue.md)) — **correcting this document's earlier v0.1.0 classification**, which grouped catalogue data with identity data under "server-authoritative" on the mistaken assumption that [FR-019](../03-functional-requirements/functional-requirements.md) (which concerns role changes specifically) justified restricting catalogue edits too. It does not: a Manager setting up a new product line from the shop floor, offline, is a real and valuable V1 capability, distinct from a permission change. `trading_days` has no cross-device conflict risk at all because it is scoped per-device ([schema-server.md](schema-server.md)); `customers`, `shop_settings`, `categories`, `units`, and `products` each need an actual conflict policy, resolved in [13-offline-sync/conflict-resolution.md](../13-offline-sync/conflict-resolution.md). |
| **Server-authoritative, V1 stub (no write path for anyone yet)** | `product_variants`, `batches` | Read-only cache, currently always empty in V1 — these tables have no V1 write path at all, client or server, per [schema-server.md](schema-server.md)'s "V2+/V4 stub" notes. Not the same reason as `users`/`user_store_roles`/`devices` above (security-sensitive) — simply unbuilt. |
| **Derived, never synced** | Stock balance, cash-drawer expected-cash | Never stored as a row anywhere, local or server — always computed live from the local `stock_movements`/`sale_payments` cache, per [ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md). |

---

## Divergences from the server schema

| Server table | Local divergence |
| --- | --- |
| `tenants`, `stores` | Cached read-only; a device stores exactly one row of each (its own tenant/store), not a list. |
| `products`, `categories`, `units` | Full local read/write copy, matching the server shape (`updated_at` retained, needed both to detect a newer pulled version **and** to know a locally-made edit is pending outbound sync) — see the corrected classification above; this is not a read-only cache. |
| `product_variants`, `batches` | Read-only cache, currently always empty (no V1 write path for anyone — see classification above); no `updated_at`/`created_by` tracking needed locally beyond a single `synced_at` column. |
| `users`, `user_store_roles`, `devices` | Cached **only for the current device's own user** and any names needed for display (e.g. "approved by X") — not a full tenant-wide user list, to avoid syncing other staff's session/device metadata to every phone unnecessarily. |
| `audit_log` | **Not synced to devices as a readable cache at all.** Devices write new audit entries (queued outbound) but never pull audit history down — the audit log is a server/reporting concern, not something a till needs to browse. `audit-model.md` states who *can* read it (via the API, online), which is not the same as it living on-device. |
| `stock_movements` | Local cache is scoped to **this store only** (trivial in V1 — one store per tenant) and to a rolling recent window for balance computation, not necessarily full multi-year history — exact retention window is a Phase 13 performance decision, not fixed here. |
| `sales`, `sale_line_items`, `sale_payments`, `returns`, `return_line_items` | Local device holds sales/returns **it originated**, plus whatever has synced down from other devices at the same store (relevant to the Finding 3 return-lookup gap in [offline-workflows.md](../06-workflows/offline-workflows.md)) — not the tenant's entire historical sales table by default. |
| `trading_days` | Local device holds only **its own** trading days — consistent with the per-device scoping decision in [schema-server.md](schema-server.md). |
| `customers` | Full local read/write copy, same shape as the server (`updated_at` retained for the same newer-pull/pending-edit reasons as `products`/`categories`/`units` above) — client-editable, per the classification above; this was previously missing from this table entirely, added for completeness. |
| `shop_settings` | Full local read copy; **write path exists but is not offline-capable** ([settings.md](../11-api/endpoints/settings.md)'s deliberate exception) — the local row is refreshed on pull like any client-editable entity, but a local edit is never queued in `outbound_queue`, only submitted directly when connected. Also previously missing from this table. |
| `sync_rejections`, `idempotency_keys` | **Server-only** — a device doesn't need to see the idempotency-key table at all (it's a server dedup mechanism), and `sync_rejections` are surfaced to the device that originated them via a targeted pull, not a general sync. |

---

## Local-only tables (no server equivalent)

### `outbound_queue`
**Purpose:** the durable operation queue — the local realisation of the Sync Item state machine in
[state-machines.md](../06-workflows/state-machines.md).

| Column | Type | Notes |
| --- | --- | --- |
| `client_operation_id` | `TEXT` (UUID) | Primary key; matches the eventual server row's ID per [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md) |
| `entity_type` | `TEXT` | e.g. `'sale'`, `'stock_movement'`, `'return'` |
| `payload` | `TEXT` (JSON) | The full operation, serialised |
| `status` | `TEXT` | `queued` / `syncing` / `synced` / `failed_retrying` / `rejected` — mirrors [state-machines.md — Sync Item](../06-workflows/state-machines.md#sync-item) exactly |
| `attempt_count` | `INTEGER` | For backoff calculation |
| `created_at` | `TEXT` (ISO 8601) | Local device time — **display only**, never used for sync ordering ([assumptions-and-dependencies.md](../04-srs/assumptions-and-dependencies.md), device clocks are untrusted) |
| `last_attempted_at` | `TEXT` | nullable |
| `rejection_reason` | `TEXT` | nullable — populated if `status = 'rejected'`, surfaced to the user per [BR-053](../02-business-requirements/business-requirements.md) |

### `local_provisional_sequence`
**Purpose:** the per-device counter backing provisional invoice numbers —
[ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md).

| Column | Type | Notes |
| --- | --- | --- |
| `financial_year` | `TEXT` | Primary key component |
| `next_sequence` | `INTEGER` | Incremented atomically on each sale creation, never decremented or reset except at a financial-year boundary |

---

## What is deliberately not accommodated locally

Full tenant-wide reporting (e.g. "top products across all history") is **not** designed to run
entirely offline against a full local replica — V1 caches recent/relevant data per the divergences
above, and the four core reports ([FR-071](../03-functional-requirements/functional-requirements.md)–[FR-074](../03-functional-requirements/functional-requirements.md))
are scoped to what a single device's cache can answer correctly. If this proves insufficient once
real usage patterns are known, widening the local cache is a Phase 13 tuning decision, not a schema
redesign — the server schema already holds the full history regardless.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial local schema: entity classification, divergence table, 2 local-only tables. |
| 0.1.1 | 2026-07-31 | **Correction, found during Phase 13:** `categories`/`units`/`products` were misclassified as server-authoritative (grouped with identity data under an FR-019 justification that only actually applies to role changes). Reclassified as client-editable, matching [endpoints/catalogue.md](../11-api/endpoints/catalogue.md)'s already-specified offline write path — no design changed, the schema-local.md classification was simply wrong and now matches Phase 11. |
| 0.1.2 | 2026-07-31 | **Correction, found during a pre-Phase-18 documentation audit:** the divergence table omitted `customers` and `shop_settings` entirely, despite both being listed in the entity-classification table above it. Added. |
