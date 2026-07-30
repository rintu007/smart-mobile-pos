# PostgreSQL Server Schema

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** PostgreSQL Architect
> **Approved by:** _pending_

22 tables across 7 bounded contexts. Every table states its purpose, owning module, tenant scoping,
columns, foreign-key delete behaviour, indexes (each tied to a named query from
[06-workflows](../06-workflows/README.md)), and Row Level Security stance — satisfying this phase's
exit criteria directly, not by cross-reference. Conventions applied uniformly, stated once here
rather than repeated per table:

- **Every table** has `id UUID PRIMARY KEY` (client-generated per [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md)),
  `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `created_by UUID NOT NULL REFERENCES users(id)`,
  and — except for the append-only Tier 2 tables listed in
  [ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md) —
  `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`. These are omitted from the column tables below to
  avoid repeating them 22 times; assume their presence unless a table is explicitly Tier 2.
- **Every tenant-owned table** has `tenant_id UUID NOT NULL REFERENCES tenants(id)` and RLS enabled
  per [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md); stated per table as "RLS: tenant-scoped."
- Money columns are `BIGINT` (minor units); tax rates are `INTEGER` (basis points) — [ADR-0006](../adr/ADR-0006-money-as-integer-minor-units.md).
- Quantity columns are `NUMERIC(14,3)` — fixed-point, not floating binary, to correctly represent
  fractional units (kilograms, litres) without money's minor-unit convention, which doesn't fit a
  continuously-measured good.

---

## Context 1 — Identity & Tenancy

### `tenants`
**Purpose:** the top-level isolation boundary; one row per business account. **Module:** Company &
Store Setup. **Tenant scoping:** is the tenant — not itself tenant-scoped.

| Column | Type | Constraint |
| --- | --- | --- |
| `name` | `TEXT` | `NOT NULL` |
| `deactivated_at` | `TIMESTAMPTZ` | nullable — Tier 1 soft delete |

**Indexes:** none beyond the primary key — this table is looked up by ID only.
**RLS:** a user may only read the tenant row matching their own `tenant_id` claim.

### `stores`
**Purpose:** a physical outlet; V1 creates exactly one per tenant, never shown in UI —
[ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md). **Module:** Company & Store
Setup. **Tenant scoping:** tenant-scoped.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` — a tenant with stores cannot be hard-deleted (moot in practice since tenants are soft-deleted, per ADR-0009, but stated for defence in depth) |
| `name` | `TEXT` | `NOT NULL` |
| `address` | `TEXT` | nullable |
| `deactivated_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(tenant_id)` — every "list this tenant's stores" query (onboarding, settings).
**RLS:** tenant-scoped.

### `users`
**Purpose:** an application user, linked to a Supabase Auth identity. **Module:** Authentication.
**Tenant scoping:** tenant-scoped — a user belongs to exactly one tenant in V1 (no cross-tenant
staff sharing).

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `auth_user_id` | `UUID` | `NOT NULL UNIQUE` — Supabase Auth's own user ID |
| `display_name` | `TEXT` | `NOT NULL` |
| `deactivated_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(auth_user_id)` unique — session token → user resolution on every authenticated
request (TB-1, TB-4). `(tenant_id)` — user-management list ([permission matrix](../05-personas/permission-matrix.md)).
**RLS:** tenant-scoped; a user always sees their own row regardless via `auth_user_id = auth.uid()`.

### `user_store_roles`
**Purpose:** assigns a role (Cashier/Manager/Owner) to a user at a store —
[DR-019](../03-functional-requirements/business-rules.md)–[DR-021](../03-functional-requirements/business-rules.md).
**Module:** Roles & Permissions. **Tenant scoping:** tenant-scoped (via `user_id`/`store_id`, both
already tenant-scoped).

| Column | Type | Constraint |
| --- | --- | --- |
| `user_id` | `UUID` | `NOT NULL REFERENCES users(id) ON DELETE CASCADE` — a deleted user's role rows are meaningless without the user; but users are soft-deleted in practice (Tier 1), so this cascade is a safety net, not the primary path |
| `store_id` | `UUID` | `NOT NULL REFERENCES stores(id) ON DELETE CASCADE` |
| `role` | `TEXT` | `NOT NULL CHECK (role IN ('cashier','manager','owner'))` |
| `assigned_by` | `UUID` | `NOT NULL REFERENCES users(id) ON DELETE RESTRICT` — attribution must survive even if the assigner is later deactivated |
| `revoked_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(user_id, store_id) WHERE revoked_at IS NULL` — the "what can this user currently do
here" check on every authenticated request (TB-1, DR-017).
**RLS:** tenant-scoped. **This table is server-authoritative** per the sync classification in
[13-offline-sync/README.md](../13-offline-sync/README.md) — never client-writable.

### `devices`
**Purpose:** tracks a device/session for remote revocation — [BR-005](../02-business-requirements/business-requirements.md)/[FR-014](../03-functional-requirements/functional-requirements.md).
**Module:** Authentication. **Tenant scoping:** tenant-scoped (via `user_id`).

| Column | Type | Constraint |
| --- | --- | --- |
| `user_id` | `UUID` | `NOT NULL REFERENCES users(id) ON DELETE CASCADE` |
| `client_device_id` | `TEXT` | `NOT NULL` — client-generated, stable per install |
| `last_seen_at` | `TIMESTAMPTZ` | nullable |
| `revoked_at` | `TIMESTAMPTZ` | nullable |
| `revoked_by` | `UUID` | nullable, `REFERENCES users(id) ON DELETE SET NULL` — the revocation fact matters more than preserving a hard link to the revoker if that user is later removed |

**Indexes:** `(user_id)` — device list for the revocation UI ([permission matrix](../05-personas/permission-matrix.md), Owner-only). `(client_device_id)` unique per user — device re-registration lookup.
**RLS:** tenant-scoped via `user_id` join.

### `audit_log` — Tier 2 (no delete, no update; see [ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md))
**Purpose:** append-only record of every money/stock/permission-affecting action —
[BR-009](../02-business-requirements/business-requirements.md). **Module:** Audit Log. **Tenant
scoping:** tenant-scoped.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `store_id` | `UUID` | nullable `REFERENCES stores(id) ON DELETE RESTRICT` — some audited actions (e.g. user management) aren't store-scoped |
| `actor_user_id` | `UUID` | `NOT NULL REFERENCES users(id) ON DELETE RESTRICT` |
| `action` | `TEXT` | `NOT NULL` |
| `entity_type` | `TEXT` | `NOT NULL` |
| `entity_id` | `UUID` | `NOT NULL` |
| `before_state` | `JSONB` | nullable |
| `after_state` | `JSONB` | nullable |

No `updated_at` — this table is never updated. **Indexes:** `(tenant_id, entity_type, entity_id)` —
"show me this entity's history" ([audit-model.md](audit-model.md)). `(tenant_id, created_at)` —
audit log browsing, newest first.
**RLS:** tenant-scoped. **No `UPDATE`/`DELETE` grant exists on this table for any role**, including
the API's own service-role connection — enforced identically to `stock_movements` per
[ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md)'s pattern, applied here too since audit
integrity has the same "must never be alterable" requirement.

---

## Context 2 — Catalogue

**Design call, stated explicitly:** catalogue tables (`categories`, `units`, `products`) are
**tenant-scoped, not store-scoped** — one shared catalogue across a tenant's stores (even though V1
has only one store per tenant). This matches how multi-outlet retail actually works: the same
product exists across outlets; only its *stock* is per-store. Stated here because
[ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md) mandated store-scoping for
"stock, sales and store-scoped user records" specifically — it did not mandate it for catalogue
data, and this document makes that boundary explicit rather than leaving it implicit.

### `categories` — Tier 1 (soft delete)
**Module:** Categories.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `name` | `TEXT` | `NOT NULL` |
| `deactivated_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(tenant_id) WHERE deactivated_at IS NULL` — category picker in product setup and POS
filtering ([FR-036](../03-functional-requirements/functional-requirements.md)).
**RLS:** tenant-scoped.

### `units` — Tier 1
**Module:** Units.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `name` | `TEXT` | `NOT NULL` |
| `symbol` | `TEXT` | `NOT NULL` |
| `allows_fractional` | `BOOLEAN` | `NOT NULL DEFAULT false` — drives [FR-037](../03-functional-requirements/functional-requirements.md)/[FR-038](../03-functional-requirements/functional-requirements.md) |
| `deactivated_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(tenant_id) WHERE deactivated_at IS NULL`.
**RLS:** tenant-scoped.

### `products` — Tier 1
**Module:** Products.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `category_id` | `UUID` | `NOT NULL REFERENCES categories(id) ON DELETE RESTRICT` — a category with products cannot be hard-deleted; deactivate instead |
| `unit_id` | `UUID` | `NOT NULL REFERENCES units(id) ON DELETE RESTRICT` |
| `name` | `TEXT` | `NOT NULL` |
| `sku` | `TEXT` | nullable, unique per tenant |
| `barcode` | `TEXT` | nullable, unique per tenant |
| `hsn_sac_code` | `TEXT` | nullable — flagged, not blocked, if missing under standard GST regime ([FR-033](../03-functional-requirements/functional-requirements.md)) |
| `price_minor_units` | `BIGINT` | `NOT NULL` |
| `deactivated_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(tenant_id, barcode) WHERE deactivated_at IS NULL` — barcode scan resolution
([FR-022](../03-functional-requirements/functional-requirements.md)/[FR-023](../03-functional-requirements/functional-requirements.md)),
the single most latency-sensitive query in the system (NFR-002). `(tenant_id, name text_pattern_ops) WHERE deactivated_at IS NULL` —
text search ([FR-025](../03-functional-requirements/functional-requirements.md)). `(tenant_id, category_id) WHERE deactivated_at IS NULL` —
category filtering ([FR-036](../03-functional-requirements/functional-requirements.md)).
**RLS:** tenant-scoped.

### `product_variants` — Tier 1, **V2+ stub, no V1 write path**
**Purpose:** accommodates future variant support (colour, size) without a schema change to
`sale_line_items`/`stock_movements` later — this phase's own exit criterion.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `product_id` | `UUID` | `NOT NULL REFERENCES products(id) ON DELETE CASCADE` |
| `variant_attributes` | `JSONB` | `NOT NULL` |
| `sku` | `TEXT` | nullable |
| `barcode` | `TEXT` | nullable |
| `deactivated_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** none yet — no V1 query touches this table.
**RLS:** tenant-scoped, ready for when it's used.

---

## Context 3 — Inventory

### `stock_movements` — Tier 2 (no update, no delete)
**Purpose:** the append-only ledger — [ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md).
**Module:** Inventory. **Tenant scoping:** tenant-scoped **and** store-scoped.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `store_id` | `UUID` | `NOT NULL REFERENCES stores(id) ON DELETE RESTRICT` |
| `product_id` | `UUID` | `NOT NULL REFERENCES products(id) ON DELETE RESTRICT` — a product with movement history can never be hard-deleted |
| `variant_id` | `UUID` | nullable `REFERENCES product_variants(id) ON DELETE RESTRICT` — V2+ |
| `batch_id` | `UUID` | nullable `REFERENCES batches(id) ON DELETE RESTRICT` — V4 |
| `serial_number` | `TEXT` | nullable — V4 |
| `quantity_delta` | `NUMERIC(14,3)` | `NOT NULL` — signed; positive for opening/return, negative for sale |
| `movement_type` | `TEXT` | `NOT NULL CHECK (movement_type IN ('opening','sale','return','adjustment'))` |
| `reason_code` | `TEXT` | nullable, `NOT NULL` when `movement_type = 'adjustment'` — enforced by a `CHECK` constraint, not application code, per [DR-007](../03-functional-requirements/business-rules.md) |
| `reference_type` | `TEXT` | nullable — `'sale'` or `'return'`, when applicable |
| `reference_id` | `UUID` | nullable — the sale or return this movement resulted from |
| `client_operation_id` | `UUID` | `NOT NULL UNIQUE` — the idempotency key ([DR-022](../03-functional-requirements/business-rules.md)); doubles as this row's own ID per [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md) |
| `device_id` | `UUID` | `NOT NULL REFERENCES devices(id) ON DELETE RESTRICT` |

No `updated_at`. **Indexes:** `(tenant_id, store_id, product_id)` — the balance-derivation query,
`SUM(quantity_delta)`, run constantly ([FR-041](../03-functional-requirements/functional-requirements.md)).
`(reference_type, reference_id)` — "show me the movements this sale/return generated"
([DR-003](../03-functional-requirements/business-rules.md)/[DR-004](../03-functional-requirements/business-rules.md)).
`(tenant_id, store_id, created_at)` — low-stock and stock-value reports scanning recent activity.
**RLS:** tenant-scoped. **`UPDATE`/`DELETE` privileges revoked for every role**, including the API's
service-role connection.

### `batches` — Tier 1, **V4 stub, no V1 write path**
**Purpose:** accommodates future batch/expiry tracking (pharmacy vertical) without a migration
touching live `stock_movements` rows later.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `product_id` | `UUID` | `NOT NULL REFERENCES products(id) ON DELETE RESTRICT` |
| `batch_number` | `TEXT` | `NOT NULL` |
| `expiry_date` | `DATE` | nullable |

**Indexes:** none yet. **RLS:** tenant-scoped.

---

## Context 4 — Customers

### `customers` — Tier 1
**Module:** Customers. **Tenant scoping:** tenant-scoped.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `name` | `TEXT` | nullable |
| `phone` | `TEXT` | nullable |
| `deactivated_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(tenant_id, phone) WHERE deactivated_at IS NULL` — the return-by-phone-number lookup
([FR-062](../03-functional-requirements/functional-requirements.md)) and inline checkout search
([FR-052](../03-functional-requirements/functional-requirements.md)).
**RLS:** tenant-scoped.

---

## Context 5 — Sales

### `trading_days` — Tier 1 for the row lifecycle, but reconciliation fields are never altered post-close except via a new reopen event
**Purpose:** cash-drawer reconciliation state — [state-machines.md](../06-workflows/state-machines.md).
**Module:** Cash Drawer / Day Close. **Tenant scoping:** tenant- and store-scoped. **Scoped per
`device_id`, not shared across a store** — this is the resolution to
[offline-workflows.md — Finding 2](../06-workflows/offline-workflows.md#finding-2--trading-day-is-a-shared-store-level-concept-and-multi-device-shops-need-a-rule),
decided now rather than left open: V1 sidesteps the multi-till shared-day conflict question
entirely by making each device responsible for its own trading day. A store with multiple devices
therefore has multiple concurrent trading days in V1 — acceptable because V1's target shop is
overwhelmingly single-device ([personas.md](../05-personas/personas.md)); multi-till reconciliation
is deferred to whenever multi-outlet/multi-till is actually built, alongside
[ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)'s deferred store selector.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `store_id` | `UUID` | `NOT NULL REFERENCES stores(id) ON DELETE RESTRICT` |
| `device_id` | `UUID` | `NOT NULL REFERENCES devices(id) ON DELETE RESTRICT` |
| `status` | `TEXT` | `NOT NULL CHECK (status IN ('open','closed'))` |
| `starting_float_minor_units` | `BIGINT` | `NOT NULL` |
| `counted_cash_minor_units` | `BIGINT` | nullable until closed |
| `expected_cash_minor_units` | `BIGINT` | nullable until closed |
| `variance_minor_units` | `BIGINT` | nullable until closed |
| `closed_at` | `TIMESTAMPTZ` | nullable |
| `reopened_at` | `TIMESTAMPTZ` | nullable |
| `reopened_by` | `UUID` | nullable `REFERENCES users(id) ON DELETE SET NULL` |

**Indexes:** `(tenant_id, device_id, status) WHERE status = 'open'` — "is there an open day on this
device right now" check on every sale attempt.
**RLS:** tenant-scoped.

### `sales` — Tier 2 (no update, no delete once `status = 'completed'`)
**Purpose:** the immutable sale record — [BR-030](../02-business-requirements/business-requirements.md).
**Module:** Sales & Invoices. **Tenant/store scoped.**

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `store_id` | `UUID` | `NOT NULL REFERENCES stores(id) ON DELETE RESTRICT` |
| `device_id` | `UUID` | `NOT NULL REFERENCES devices(id) ON DELETE RESTRICT` |
| `trading_day_id` | `UUID` | `NOT NULL REFERENCES trading_days(id) ON DELETE RESTRICT` |
| `customer_id` | `UUID` | nullable `REFERENCES customers(id) ON DELETE SET NULL` — a sale outlives a customer record being deactivated; the historical sale should not be blocked from existing, but losing the specific customer link on hard removal is acceptable since customers are Tier 1 (soft delete in the normal path anyway) |
| `provisional_invoice_number` | `TEXT` | `NOT NULL`, immutable after creation — [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) |
| `canonical_invoice_number` | `BIGINT` | nullable, unique per `(tenant_id, financial_year)` when present |
| `tax_registration_type_at_sale` | `TEXT` | `NOT NULL` — snapshot, not a live join to settings, since a shop's tax status can change after old sales exist |
| `status` | `TEXT` | `NOT NULL CHECK (status IN ('draft','held','completed','cancelled'))` |
| `subtotal_minor_units`, `tax_total_minor_units`, `discount_total_minor_units`, `grand_total_minor_units` | `BIGINT` | `NOT NULL` |
| `client_operation_id` | `UUID` | `NOT NULL UNIQUE` |
| `completed_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(tenant_id, store_id, completed_at)` — daily sales report
([FR-071](../03-functional-requirements/functional-requirements.md)). `(tenant_id, provisional_invoice_number)` unique —
lookup for returns ([FR-062](../03-functional-requirements/functional-requirements.md)). `(tenant_id, canonical_invoice_number)` —
export/report ordering. `(customer_id) WHERE customer_id IS NOT NULL` — customer purchase history
([FR-051](../03-functional-requirements/functional-requirements.md)).
**RLS:** tenant-scoped. **No `UPDATE`/`DELETE` once `status = 'completed'`** — enforced by a
trigger rejecting any write attempt against a completed row, not merely by omitting an endpoint.

### `sale_line_items` — Tier 2
**Module:** Sales & Invoices.

| Column | Type | Constraint |
| --- | --- | --- |
| `sale_id` | `UUID` | `NOT NULL REFERENCES sales(id) ON DELETE RESTRICT` |
| `product_id` | `UUID` | `NOT NULL REFERENCES products(id) ON DELETE RESTRICT` |
| `variant_id` | `UUID` | nullable `REFERENCES product_variants(id) ON DELETE RESTRICT` |
| `quantity` | `NUMERIC(14,3)` | `NOT NULL` |
| `unit_price_minor_units` | `BIGINT` | `NOT NULL` — snapshot at sale time, independent of later price changes |
| `hsn_sac_code_at_sale` | `TEXT` | nullable — snapshot, per [RR-003](../02-business-requirements/regulatory-requirements.md) |
| `tax_rate_basis_points` | `INTEGER` | `NOT NULL` |
| `line_discount_minor_units` | `BIGINT` | `NOT NULL DEFAULT 0` |
| `line_tax_minor_units` | `BIGINT` | `NOT NULL` — [DR-008](../03-functional-requirements/business-rules.md) |
| `line_total_minor_units` | `BIGINT` | `NOT NULL` |

No independent `tenant_id`/RLS — access is via `sale_id` join; a line item is never queried
directly across tenants.
**Indexes:** `(sale_id)` — assembling a sale/invoice. `(product_id)` — "which sales included this
product" for top/slow product reports ([FR-073](../03-functional-requirements/functional-requirements.md)).

### `sale_payments` — Tier 2
**Module:** Sales & Invoices (Split Payment, [FR-028](../03-functional-requirements/functional-requirements.md)).

| Column | Type | Constraint |
| --- | --- | --- |
| `sale_id` | `UUID` | `NOT NULL REFERENCES sales(id) ON DELETE RESTRICT` |
| `method` | `TEXT` | `NOT NULL CHECK (method IN ('cash','card','other'))` |
| `amount_minor_units` | `BIGINT` | `NOT NULL` |

**Indexes:** `(sale_id)` — assembling a sale's payment breakdown; cash-only sum feeds
`trading_days.expected_cash_minor_units` ([FR-068](../03-functional-requirements/functional-requirements.md)).

---

## Context 6 — Returns

### `returns` — Tier 2
**Module:** Returns & Refund. **Tenant/store scoped.**

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `store_id` | `UUID` | `NOT NULL REFERENCES stores(id) ON DELETE RESTRICT` |
| `original_sale_id` | `UUID` | `NOT NULL REFERENCES sales(id) ON DELETE RESTRICT` — [DR-016](../03-functional-requirements/business-rules.md), exactly one original sale |
| `status` | `TEXT` | `NOT NULL CHECK (status IN ('initiated','pending_approval','approved','completed','rejected'))` |
| `refund_total_minor_units` | `BIGINT` | `NOT NULL` |
| `approved_by` | `UUID` | nullable `REFERENCES users(id) ON DELETE SET NULL` |
| `client_operation_id` | `UUID` | `NOT NULL UNIQUE` |
| `completed_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(original_sale_id)` — has-this-sale-been-returned check, WF-012.
`(tenant_id, store_id, status) WHERE status = 'pending_approval'` — the Manager approval queue,
WF-013.
**RLS:** tenant-scoped. No `UPDATE`/`DELETE` once `status = 'completed'`, mirroring `sales`.

### `return_line_items` — Tier 2
**Module:** Returns & Refund.

| Column | Type | Constraint |
| --- | --- | --- |
| `return_id` | `UUID` | `NOT NULL REFERENCES returns(id) ON DELETE RESTRICT` |
| `original_sale_line_item_id` | `UUID` | `NOT NULL REFERENCES sale_line_items(id) ON DELETE RESTRICT` |
| `quantity` | `NUMERIC(14,3)` | `NOT NULL` |
| `refund_amount_minor_units` | `BIGINT` | `NOT NULL` — [DR-014](../03-functional-requirements/business-rules.md) |

**Indexes:** `(original_sale_line_item_id)` — the "quantity already returned" check backing
[DR-013](../03-functional-requirements/business-rules.md), computed as
`SUM(quantity) WHERE original_sale_line_item_id = ?` across all non-rejected returns.

---

## Context 7 — Settings & Sync

### `shop_settings` — Tier 1 (one row per tenant; `tenant_id` is itself the primary key)
**Module:** Settings.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE` |
| `tax_mode` | `TEXT` | `NOT NULL CHECK (tax_mode IN ('standard','composition','unregistered'))` — [RR-001](../02-business-requirements/regulatory-requirements.md) |
| `pricing_mode` | `TEXT` | `NOT NULL CHECK (pricing_mode IN ('inclusive','exclusive'))` |
| `rounding_rule` | `TEXT` | `NOT NULL` |
| `currency_code` | `TEXT` | `NOT NULL DEFAULT 'INR'` |
| `discount_auto_approval_threshold_minor_units` | `BIGINT` | `NOT NULL` |
| `return_auto_approval_threshold_minor_units` | `BIGINT` | `NOT NULL` |
| `printer_config` | `JSONB` | nullable |
| `receipt_template_config` | `JSONB` | nullable — cannot disable mandatory fields, enforced at the service layer, not here ([BR-049](../02-business-requirements/business-requirements.md)) |

**Indexes:** none beyond the primary key. **RLS:** tenant-scoped.

### `idempotency_keys`
**Purpose:** backs [DR-022](../03-functional-requirements/business-rules.md) for operations that
aren't themselves a row creation with a reusable client ID (e.g. an approval decision).
**Module:** Offline Sync Engine.

| Column | Type | Constraint |
| --- | --- | --- |
| `client_operation_id` | `UUID` | `PRIMARY KEY` |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE CASCADE` |
| `operation_type` | `TEXT` | `NOT NULL` |
| `entity_id` | `UUID` | `NOT NULL` |
| `first_seen_at` | `TIMESTAMPTZ` | `NOT NULL DEFAULT now()` |

**Indexes:** primary key only — this table exists purely for `INSERT ... ON CONFLICT DO NOTHING`
deduplication checks.
**RLS:** tenant-scoped.

### `sync_rejections`
**Purpose:** records an operation rejected at sync after local completion — the schema-level answer
to [offline-workflows.md — Finding 1](../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux).
**Module:** Offline Sync Engine.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `store_id` | `UUID` | nullable `REFERENCES stores(id) ON DELETE RESTRICT` |
| `device_id` | `UUID` | `NOT NULL REFERENCES devices(id) ON DELETE RESTRICT` |
| `entity_type` | `TEXT` | `NOT NULL` |
| `local_entity_id` | `UUID` | `NOT NULL` |
| `client_operation_id` | `UUID` | `NOT NULL` |
| `reason` | `TEXT` | `NOT NULL` |
| `resolved_at` | `TIMESTAMPTZ` | nullable |
| `resolution_note` | `TEXT` | nullable |
| `resolved_by` | `UUID` | nullable `REFERENCES users(id) ON DELETE SET NULL` |

**Indexes:** `(tenant_id, store_id) WHERE resolved_at IS NULL` — the Owner-facing "needs your
attention" list this table exists to power.
**RLS:** tenant-scoped. This table is Tier 1 in spirit (rows are marked resolved, never deleted) —
the resolution itself is an update to `resolved_at`, which is acceptable here because this table
records an *anomaly to be worked*, not a financial fact; the underlying rejected sale/return in
`sales`/`returns` remains untouched and immutable regardless of how this row is annotated.

---

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 22-table schema across 7 bounded contexts. Trading Day scoped per-device, resolving the Phase 06 Finding 2 open question. |
