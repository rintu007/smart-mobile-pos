# PostgreSQL Server Schema

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.5
> **Last updated:** 2026-08-25
> **Owner:** PostgreSQL Architect
> **Approved by:** _pending_

25 tables across 7 bounded contexts — the original 22-table design plus 3 tables added during
implementation and never in the original Phase 07 design (`invoice_sequences`, Sprint 24;
`customer_field_conflicts`, Sprint 35; `rate_limit_buckets`, Sprint 45; see the Change Log's dated
correction). 21 of the 25 are actually built, matching the live schema exactly — the other 4
(`product_variants`, `batches`, `idempotency_keys`, `sync_rejections`) are named, deferred stubs with
no V1 write path, unchanged since the original design. Every table states its purpose, owning
module, tenant scoping, columns, foreign-key delete behaviour, indexes (each tied to a named query
from [06-workflows](../06-workflows/README.md)), and Row Level Security stance — satisfying this
phase's exit criteria directly, not by cross-reference. Conventions applied uniformly, stated once
here rather than repeated per table:

- **Every table** has `id UUID PRIMARY KEY` (client-generated per [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md)),
  `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `created_by UUID NOT NULL REFERENCES users(id)`,
  and — except for the append-only Tier 2 tables listed in
  [ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md) —
  `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`. These are omitted from the column tables below to
  avoid repeating them across every table; assume their presence unless a table is explicitly Tier 2.
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
**Built, Sprint 55** — flagged as a real, unaddressed gap by Sprint 43's OWASP checklist review;
built exactly as designed below, plus `id` confirmed server-generated (`randomUUID()` at
register-device time, matching `invoice_sequences`' own precedent for a row a client never directly
writes) rather than the blanket "client-generated per ADR-0007" convention this document states for
every table — a deliberate, reasoned exception for this one table, not an oversight.
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
| `category_id` | `UUID` | nullable `REFERENCES categories(id) ON DELETE RESTRICT` — corrected from `NOT NULL` in a Phase 07 documentation audit (2026-08-25): Sprint 19 built it optional, matching `unit_id`/`sku`/`barcode`/`hsn_sac_code`'s own already-correctly-documented nullability, not held to a stricter rule than the rest of the row |
| `unit_id` | `UUID` | nullable `REFERENCES units(id) ON DELETE RESTRICT` — same correction as `category_id` |
| `name` | `TEXT` | `NOT NULL` |
| `sku` | `TEXT` | nullable, unique per tenant |
| `barcode` | `TEXT` | nullable, unique per tenant |
| `hsn_sac_code` | `TEXT` | nullable — flagged, not blocked, if missing under standard GST regime ([FR-033](../03-functional-requirements/functional-requirements.md)) |
| `price_minor_units` | `BIGINT` | `NOT NULL` |
| `deactivated_at` | `TIMESTAMPTZ` | nullable |

**Indexes:** `(tenant_id, barcode)` unique, serving barcode scan resolution
([FR-022](../03-functional-requirements/functional-requirements.md)/[FR-023](../03-functional-requirements/functional-requirements.md)),
the single most latency-sensitive query in the system (NFR-002) — built as a plain unique
constraint, not the partial (`WHERE deactivated_at IS NULL`) form originally documented here. The
`(tenant_id, name text_pattern_ops)` text-search index ([FR-025](../03-functional-requirements/functional-requirements.md))
and `(tenant_id, category_id)` category-filter index ([FR-036](../03-functional-requirements/functional-requirements.md))
were never actually built, despite `GET /api/v1/products` genuinely supporting both `search` and
`category_id` filters server-side — found in the same audit and named as real, deferred follow-up
work rather than fixed speculatively in a documentation-only pass.
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

No separate `client_operation_id` column — the idempotency key ([DR-022](../03-functional-requirements/business-rules.md))
is the `id` column itself (client-generated per [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md)),
the same real mechanism `returns` below (Context 6) documents explicitly; corrected here to
match rather than imply a second, separate column that was never built.

**Correction, found in a Phase 07 documentation audit (2026-08-25):** `device_id` was never actually
built into this table. This table was built in Sprint 11, 44 sprints before `devices` existed at all
(Sprint 55) — it was never retrofitted afterward, and this document was never corrected to match.
No live code or query has ever depended on it. `quantity_delta` is `INTEGER` in the real build, not
`NUMERIC(14,3)` as stated above — the same fractional-quantity deferral `sale_line_items.quantity`
already established (no quantity field anywhere in this schema is fractional-aware yet), named and
dated in [inventory/specification.md §3](../modules/inventory/specification.md#3-database-tables-and-relationships).

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
| `erased_at` | `TIMESTAMPTZ` | nullable — added Sprint 46 ([privacy.md §4](../12-security/privacy.md)), never listed here until this correction; marks the row anonymised (`name`/`phone` overwritten with `NULL`) rather than deleted, so historical `sales.customer_id` FKs stay valid |
| `updated_by` | `UUID` | nullable `REFERENCES users(id) ON DELETE SET NULL` — added Sprint 35 (backlog.md M3 item 5); the actor of the most recent successful field edit, feeding `customer_field_conflicts.current_set_by` below |

**Indexes:** `(tenant_id, phone) WHERE deactivated_at IS NULL` — the return-by-phone-number lookup
([FR-062](../03-functional-requirements/functional-requirements.md)) and inline checkout search
([FR-052](../03-functional-requirements/functional-requirements.md)).
**RLS:** tenant-scoped.

### `customer_field_conflicts`
**Not in the original Phase 07 design** — added Sprint 35 (backlog.md M3 item 5), found and
documented here for the first time in a Phase 07 documentation audit (2026-08-25). The original
design's `conflict-resolution.md §3` framed a field-level 3-way merge around a `base_updated_at`
comparison, which cannot by itself support field-level conflict detection since the server keeps no
field-level edit history — resolved during implementation by having the client send each field's own
base value alongside its new value, computed entirely from request data with no new server-side
history mechanism, and this table recording the collision when the base value doesn't match current.
**Purpose:** a field-edit collision awaiting a Manager/Owner decision — currently-applied value vs.
a later-arriving edit's attempted value, each attributed to its own actor.
**Module:** Customers. **Tenant scoping:** tenant-scoped.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `customer_id` | `UUID` | `NOT NULL REFERENCES customers(id) ON DELETE CASCADE` |
| `field` | `TEXT` | `NOT NULL` — `'name'` or `'phone'`, application-enforced, not a `CHECK` constraint |
| `current_value` | `TEXT` | nullable — mirrors `customers.name`/`phone`'s own nullability |
| `current_set_by` | `UUID` | `NOT NULL REFERENCES users(id) ON DELETE RESTRICT` |
| `attempted_value` | `TEXT` | nullable |
| `attempted_set_by` | `UUID` | `NOT NULL REFERENCES users(id) ON DELETE RESTRICT` |
| `resolved_at` | `TIMESTAMPTZ` | nullable |
| `resolved_value` | `TEXT` | nullable |
| `resolved_by` | `UUID` | nullable `REFERENCES users(id) ON DELETE SET NULL` |

No `updated_at` — resolution is recorded via the explicit `resolved_at`/`resolved_value`/
`resolved_by` triple, not an in-place update to the conflict's own defining fields.
**Indexes:** `(tenant_id, resolved_at)` — the Manager/Owner-facing unresolved-conflicts queue,
[`GET /customers/conflicts`](../modules/customers/specification.md#4-api-contract).
**RLS:** tenant-scoped.

---

## Context 5 — Sales

### `trading_days` — Tier 1 for the row lifecycle, but reconciliation fields are never altered post-close except via a new reopen event
**Purpose:** cash-drawer reconciliation state — [state-machines.md](../06-workflows/state-machines.md).
**Module:** Cash Drawer / Day Close. **Tenant scoping:** tenant- and store-scoped.

**Correction, found in a Phase 07 documentation audit (2026-08-25):** the paragraph below described
this table as scoped per `device_id`. Sprint 26 (backlog.md M2 item 2) built it scoped by
`(tenant_id, store_id)` instead and named that as a genuine, dated deviation from this exact
paragraph in [trading-day/specification.md §1](../modules/trading-day/specification.md#1-purpose-and-business-context)
— but the correction was never carried back here, this document's own stated source of truth,
leaving this paragraph wrong for 42 sprints. The real reasoning, from the module spec: no `devices`
table existed until Sprint 55, 29 sprints after this table was built; offline-workflows.md's own
Finding 2 text says "a single physical cash drawer suggests one shared day-state," making per-device
the less physically correct model, not the more correct one; and V1's target shop is overwhelmingly
single-device ([personas.md](../05-personas/personas.md)), so store-level scoping already delivers
"one open day per device" for the single-device case that matters most in V1, without inventing a
second, unused scoping dimension for the multi-device case V1 doesn't target. Multi-till reconciliation remains deferred to whenever multi-outlet/multi-till is
actually built, alongside [ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md)'s
deferred store selector — unchanged by this correction.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `store_id` | `UUID` | `NOT NULL REFERENCES stores(id) ON DELETE RESTRICT` |
| `status` | `TEXT` | `NOT NULL CHECK (status IN ('open','closed'))` |
| `starting_float_minor_units` | `BIGINT` | `NOT NULL` |
| `counted_cash_minor_units` | `BIGINT` | nullable until closed |
| `expected_cash_minor_units` | `BIGINT` | nullable until closed |
| `variance_minor_units` | `BIGINT` | nullable until closed |
| `closed_at` | `TIMESTAMPTZ` | nullable |
| `reopened_at` | `TIMESTAMPTZ` | nullable |
| `reopened_by` | `UUID` | nullable `REFERENCES users(id) ON DELETE SET NULL` |

**Indexes:** `(tenant_id, store_id, status)` — "is there an open day at this store right now" check
on every sale attempt.
**RLS:** tenant-scoped.

### `sales` — Tier 2 (no update, no delete once `status = 'completed'`)
**Purpose:** the immutable sale record — [BR-030](../02-business-requirements/business-requirements.md).
**Module:** Sales & Invoices. **Tenant/store scoped.**

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `store_id` | `UUID` | `NOT NULL REFERENCES stores(id) ON DELETE RESTRICT` |
| `trading_day_id` | `UUID` | nullable `REFERENCES trading_days(id) ON DELETE RESTRICT` — corrected from `NOT NULL` in a Phase 07 documentation audit (2026-08-25): Sprint 26 (backlog.md M2 item 2) deliberately did not gate `POST /sales` on an open trading day, to avoid regressing the one live, working end-to-end sale flow this project had (Sprint 16) ahead of the mobile till screen that opens one — see [trading-day/specification.md §1](../modules/trading-day/specification.md#1-purpose-and-business-context) |
| `customer_id` | `UUID` | nullable `REFERENCES customers(id) ON DELETE SET NULL` — a sale outlives a customer record being deactivated; the historical sale should not be blocked from existing, but losing the specific customer link on hard removal is acceptable since customers are Tier 1 (soft delete in the normal path anyway) |
| `provisional_invoice_number` | `TEXT` | `NOT NULL`, immutable after creation — [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) |
| `canonical_invoice_number` | `BIGINT` | nullable, unique per `(tenant_id, financial_year)` when present |
| `financial_year` | `TEXT` | nullable — the financial year `canonical_invoice_number` is scoped within ([identifiers.md §3](identifiers.md)), derived from `completed_at` at assignment time; added Sprint 24, never listed here until this correction |
| `tax_registration_type_at_sale` | `TEXT` | `NOT NULL` — snapshot, not a live join to settings, since a shop's tax status can change after old sales exist |
| `status` | `TEXT` | `NOT NULL CHECK (status IN ('draft','held','completed','cancelled'))` |
| `subtotal_minor_units`, `tax_total_minor_units`, `discount_total_minor_units`, `grand_total_minor_units` | `BIGINT` | `NOT NULL` |
| `completed_at` | `TIMESTAMPTZ` | nullable |

No separate `client_operation_id` column — corrected in the same Phase 07 documentation audit
(2026-08-25) as `device_id` above: `id` alone is this table's idempotency key, the same real
mechanism `returns` below (Context 6) documents explicitly.

**Indexes:** `(tenant_id, store_id, completed_at)` — daily sales report
([FR-071](../03-functional-requirements/functional-requirements.md)). `(tenant_id, provisional_invoice_number)` unique —
lookup for returns ([FR-062](../03-functional-requirements/functional-requirements.md)). `(tenant_id, canonical_invoice_number)` —
export/report ordering. `(customer_id) WHERE customer_id IS NOT NULL` — customer purchase history
([FR-051](../03-functional-requirements/functional-requirements.md)) — **named here but never actually
built; see the Change Log's dated correction**, found in the same audit and left as real, deferred
follow-up work rather than fixed speculatively in a documentation-only pass.
**RLS:** tenant-scoped. **No `UPDATE`/`DELETE` once `status = 'completed'`** — enforced by a
trigger rejecting any write attempt against a completed row, not merely by omitting an endpoint.

### `invoice_sequences`
**Not in the original Phase 07 design** — added Sprint 24 (backlog.md M1 item 8), found and
documented here for the first time in a Phase 07 documentation audit (2026-08-25). The original
design only said `canonical_invoice_number` is "unique per `(tenant_id, financial_year)`," leaving
the assignment mechanism open ("via a database sequence or an equivalent atomic counter"). A
per-tenant Postgres `SEQUENCE` object isn't practical for an unbounded number of tenants; this
table-based counter is the actual, ADR-0008-sanctioned mechanism, incremented atomically in the same
transaction as the `sales` row it numbers.
**Purpose:** the atomic counter backing [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md)'s
canonical invoice-number assignment. **Module:** Sales & Invoices. **Tenant scoping:** tenant-scoped.

| Column | Type | Constraint |
| --- | --- | --- |
| `tenant_id` | `UUID` | `NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` |
| `financial_year` | `TEXT` | `NOT NULL` |
| `next_value` | `BIGINT` | `NOT NULL` |

No `created_at`/`created_by`/`updated_at` — this table is a pure counter, not an entity with its own
audit trail; each row is mutated in place by the same transaction that reads and increments it.
**Indexes:** `(tenant_id, financial_year)` unique — the atomic upsert-and-increment this table exists
to make possible.
**RLS:** tenant-scoped.

### `sale_line_items` — Tier 2
**Module:** Sales & Invoices.

| Column | Type | Constraint |
| --- | --- | --- |
| `sale_id` | `UUID` | `NOT NULL REFERENCES sales(id) ON DELETE RESTRICT` |
| `product_id` | `UUID` | `NOT NULL REFERENCES products(id) ON DELETE RESTRICT` |
| `variant_id` | `UUID` | nullable `REFERENCES product_variants(id) ON DELETE RESTRICT` |
| `quantity` | `NUMERIC(14,3)` | `NOT NULL` — `INTEGER` in the real build, the same fractional-quantity deferral named on `stock_movements` above ([inventory/specification.md §3](../modules/inventory/specification.md#3-database-tables-and-relationships)) |
| `unit_price_minor_units` | `BIGINT` | `NOT NULL` — snapshot at sale time, independent of later price changes |
| `tax_rate_basis_points` | `INTEGER` | `NOT NULL` |
| `line_discount_minor_units` | `BIGINT` | `NOT NULL DEFAULT 0` |
| `line_tax_minor_units` | `BIGINT` | `NOT NULL` — [DR-008](../03-functional-requirements/business-rules.md) |
| `line_total_minor_units` | `BIGINT` | `NOT NULL` |

**Correction, found in a Phase 07 documentation audit (2026-08-25):** `hsn_sac_code_at_sale` was
never actually built — no such column exists on this table; only `products.hsn_sac_code` (Context 2)
does, unsnapshotted. Named as a real, deferred gap rather than removed silently: RR-003's per-line
snapshot requirement is not met today, the same open item Sprint 39's own receipt-template work
already named for GSTIN specifically (`receipt_template_config`'s row note, Context 7 below).

No independent `tenant_id`/RLS — access is via `sale_id` join; a line item is never queried
directly across tenants.
**Indexes:** `(sale_id)` — assembling a sale/invoice. The `(product_id)` index this document
previously claimed for top/slow product reports ([FR-073](../03-functional-requirements/functional-requirements.md))
was never actually built — named as real, deferred follow-up work in the same audit, not fixed
speculatively in a documentation-only pass.

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
| `completed_at` | `TIMESTAMPTZ` | nullable |

**Correction, found in a Phase 07 documentation audit (2026-08-25):** no separate `client_operation_id`
column — `id` alone is this table's idempotency key, matching every other client-generated-id
table's actual mechanism (`sales`, `trading_days`, `customers`), corrected in the same pass as
`sales`/`stock_movements` above. Also gains `created_at`/`created_by` (already implied by this
document's own blanket per-table convention, not previously stated explicitly for this table) —
`GET /returns`'s Cashier "own device only" scope is unimplementable without a column recording who
filed the return, per [returns/specification.md §1](../modules/returns/specification.md#1-purpose-and-business-context).

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
| `tax_rate_basis_points` | `INTEGER` | `NOT NULL DEFAULT 0` — a single shop-wide flat rate, applied when `tax_mode = 'standard'` and forced to `0` for `composition`/`unregistered`; see the M2 correction below for why this isn't a per-product/per-HSN rate table |
| `pricing_mode` | `TEXT` | `NOT NULL CHECK (pricing_mode IN ('inclusive','exclusive'))` |
| `rounding_rule` | `TEXT` | `NOT NULL` |
| `currency_code` | `TEXT` | `NOT NULL DEFAULT 'INR'` |
| `discount_auto_approval_threshold_minor_units` | `BIGINT` | `NOT NULL` |
| `return_auto_approval_threshold_minor_units` | `BIGINT` | `NOT NULL` |
| `low_stock_threshold_quantity` | `INTEGER` | `NOT NULL DEFAULT 5` — added Sprint 37 ([backlog.md M4 item 2](../17-sprints/backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point)): a real, blocking gap found starting Reports — [BR-024](../02-business-requirements/business-requirements.md)/[BR-045](../02-business-requirements/business-requirements.md) require the low-stock report's threshold to be configurable, and no such field existed anywhere in this schema. A single shop-wide value, matching `tax_rate_basis_points`' own V1-simplification precedent (per-product granularity deferred, named) |
| `printer_config` | `JSONB` | nullable — unused (Sprint 39, backlog.md M4 item 4): "which printer is paired" is per-device data, resolved as a mobile-local-only table instead, never written here — see [settings/specification.md §1](../modules/settings/specification.md#1-purpose-and-business-context) |
| `receipt_template_config` | `JSONB` | nullable — cannot disable mandatory fields, enforced at the service layer, not here ([BR-049](../02-business-requirements/business-requirements.md)); shape since Sprint 39 is `{ footer_message: string }` only, the one field this column actually holds |

**Indexes:** none beyond the primary key. **RLS:** tenant-scoped.

**Correction, found decomposing M2 to item grain (2026-08-14, [backlog.md §3](../17-sprints/backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point)):**
this table never actually named where [DR-008](../03-functional-requirements/business-rules.md)'s
`tax_rate` comes from — `tax_mode` only distinguishes registration status, not a rate. The fully
correct V1 shape would be a per-product or per-HSN-code slab-rate table (0/5/12/18/28% under GST),
but no such table exists and building one is real, undiscussed scope. Resolved here as a single
shop-wide `tax_rate_basis_points`, applied uniformly to every line — an honest simplification for
the overwhelmingly single-rate small shops this product targets in V1, matching `products.hsn_sac_code`'s
own precedent of staying informational rather than load-bearing. Per-product/per-HSN rates are a
named, deferred gap (V2+), not silently assumed already solved.

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

### `rate_limit_buckets`
**Not in the original Phase 07 design** — added Sprint 45 ([rate-limiting.md §1](../11-api/rate-limiting.md#1-limits-by-endpoint-class)),
found and documented here for the first time in a Phase 07 documentation audit (2026-08-25).
**Purpose:** a fixed-window request counter, one row per `(scope, window)` pair, backing the three
enforceable rate-limit classes (mutating/read/sync-push). **Module:** none — this is cross-cutting
API infrastructure, not owned by any bounded context above; placed here as the closest fit among the
existing contexts rather than inventing an eighth. **Tenant scoping: deliberately none** — this is
the one genuine exception to this document's own blanket "every tenant-owned table" convention
stated at the top, the same class of stated exception `devices`' server-generated `id` already is.
`key` already embeds whichever scope it protects (`read:tenant:<id>`, `mutating:user:<id>`,
`sync-push:user:<id>`) as an opaque string this table itself never interprets, so it carries no
`tenant_id` column and needs no RLS policy — nothing outside `core/rate-limit/` ever queries it, and
every value baked into `key` was already resolved from an authenticated session before this table is
touched.

| Column | Type | Constraint |
| --- | --- | --- |
| `key` | `TEXT` | `PRIMARY KEY` — not a client-generated UUID, the other genuine exception to this document's blanket per-table convention |
| `count` | `INTEGER` | `NOT NULL DEFAULT 1` |
| `window_end` | `TIMESTAMPTZ` | `NOT NULL` |

No `id`/`tenant_id`/`created_at`/`created_by`/`updated_at` — this table opts out of every one of this
document's own blanket per-table conventions, stated explicitly rather than left as an unexplained
omission.
**Indexes:** `(window_end)` — expired-bucket cleanup.
**RLS:** none — see above.

---

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 22-table schema across 7 bounded contexts. Trading Day scoped per-device, resolving the Phase 06 Finding 2 open question. |
| 0.1.1 | 2026-08-14 | Correction found decomposing M2 (backlog.md): `shop_settings` never named where DR-008's `tax_rate` comes from. Added `tax_rate_basis_points` — a single shop-wide flat rate, not a per-product/per-HSN table (named, deferred to V2+). |
| 0.1.2 | 2026-08-16 | Correction found starting Reports, Sprint 37 (backlog.md M4 item 2): BR-024/BR-045 require a configurable low-stock threshold and none existed anywhere. Added `shop_settings.low_stock_threshold_quantity` — a single shop-wide value, not per-product (named, deferred). |
| 0.1.3 | 2026-08-17 | Sprint 39 (backlog.md M4 item 4): `receipt_template_config`'s row note now names its actual shape (`{ footer_message: string }`, the only field the module accepts); `printer_config`'s row note now names why it stays unused — a paired printer is per-device data, resolved as a new mobile-local-only table instead of a write to this column. |
| 0.1.4 | 2026-08-20 | Sprint 55: `devices` built, exactly as designed. `id` confirmed server-generated (`randomUUID()`), a deliberate exception to this document's blanket client-generated-id convention for a table no offline client write ever creates directly. |
| 0.1.5 | 2026-08-25 | Sprint 69 (Phase 07 documentation audit, no code change): the first line-by-line reconciliation of this document against the live schema since it was written. Found `device_id` documented as a real, `NOT NULL` column on `stock_movements`/`trading_days`/`sales` — none of the three ever actually got it, `devices` (Sprint 55) having been built many sprints after all three, and never retrofitted; `trading_days`' whole per-device scoping paragraph was corrected to the real `(tenant_id, store_id)` scoping Sprint 26 built and already named as a dated deviation in `trading-day/specification.md §1`, just never carried back here — this document's own stated source-of-truth rule. Found `client_operation_id` documented as a real column on `stock_movements`/`sales`/`returns`; none of the three built it — `id` alone is the idempotency key on all three, already correctly reasoned in `returns`' own Prisma model comment but never corrected here. Found and added three tables built during implementation, never in the original design: `invoice_sequences` (Sprint 24), `customer_field_conflicts` (Sprint 35), `rate_limit_buckets` (Sprint 45) — the intro's table count corrected from 22 to 25 (21 actually built, 4 named stubs unchanged). Found and corrected: `sales.trading_day_id` (`NOT NULL`, actually nullable per Sprint 26), `sales.financial_year` (missing from the column list entirely), `products.category_id`/`unit_id` (`NOT NULL`, actually nullable per Sprint 19), `customers.erased_at`/`updated_by` (missing, Sprints 46/35), `sale_line_items.quantity`/`stock_movements.quantity_delta` type (`NUMERIC(14,3)`, actually `INTEGER`). Found and **named as real, deferred gaps rather than fixed speculatively** (a documentation-only pass should not add production migrations without their own dedicated verification): four indexes this document claims but that were never actually built — `sales(customer_id)` (customer purchase history), `sale_line_items(product_id)` (top/slow product reports), `products(tenant_id, name text_pattern_ops)` and `products(tenant_id, category_id)` (both genuinely used by `GET /api/v1/products`'s real `search`/`category_id` filters); and one column, `sale_line_items.hsn_sac_code_at_sale`, documented but never built (only the unsnapshotted `products.hsn_sac_code` exists). This audit was bounded deliberately — it does not claim to be exhaustive across all 25 tables, only that every discrepancy found while working through Context 2 (Catalogue), 3 (Inventory), 4 (Customers), 5 (Sales), and 6 (Returns) in detail was corrected or named; Context 1 (Identity & Tenancy) and 7 (Settings & Sync) were checked only for the specific issues this pass was already tracking, not re-audited from scratch. |
