# ADR-0009 — Soft Delete for Reference Data; No Delete Path at All for Ledger/Event Data

> **Status:** 🟢 Accepted
> **Date:** 2026-07-30
> **Phase:** 07 — Database Design
> **Deciders:** CTO / PostgreSQL Architect
> **Supersedes:** _none_

---

## Context

Two different kinds of tables need two different answers to "what happens when a row is no longer
wanted?" A product a shop stops selling still needs to exist for every historical sale that
referenced it. A stock movement or a completed sale must never disappear at all, per
[ADR-0005](ADR-0005-append-only-stock-ledger.md) and
[BR-030](../02-business-requirements/business-requirements.md). Treating every table's "deletion"
the same way is wrong in both directions: hard-deleting a product breaks historical invoices; soft
"deleting" a stock movement implies it could conceivably be un-deleted, which misstates what
append-only actually means.

## Decision drivers

- Historical sales, invoices, and reports must remain accurate even after a product, category, or
  customer is no longer active — a hard-deleted `products` row would leave `sale_line_items.product_id`
  dangling or force a cascade that corrupts history.
- Ledger/event tables (`stock_movements`, `sales`, `sale_line_items`, `sale_payments`, `returns`,
  `return_line_items`, `audit_log`) are already governed by
  [ADR-0005](ADR-0005-append-only-stock-ledger.md)'s no-update-no-delete rule — this ADR states that
  explicitly as a delete-strategy decision too, so it isn't accidentally treated as a "soft delete
  candidate" by someone reading only this document.
- Financial and regulatory retention requirements ([regulatory-requirements.md](../02-business-requirements/regulatory-requirements.md))
  mean nothing resembling a sale or its tax record can ever be purged on a schedule shorter than the
  legal retention period, once confirmed.

## Options considered

### Option A — Hard delete everywhere
| Pros | Cons |
| --- | --- |
| Simplest to reason about in isolation | Breaks referential integrity for historical records the moment any referenced entity is removed; incompatible with audit and tax retention requirements outright |

### Option B — Soft delete everywhere (a `deleted_at`/`deactivated_at` column on every table)
| Pros | Cons |
| --- | --- |
| One uniform pattern | Applying it to ledger/event tables implies those rows are ever expected to be "deleted" at all, which contradicts the append-only invariant those tables already have — a soft-delete column on `stock_movements` would be actively misleading about what the table guarantees |

### Option C — Two-tier: soft delete (`deactivated_at`) for reference/catalogue data; no delete path whatsoever for ledger/event data
| Pros | Cons |
| --- | --- |
| Each table's delete behaviour matches what that table actually is | Requires classifying every table correctly, and reviewers must know which tier a new table belongs to |

## Decision

We will adopt **Option C**.

**Tier 1 — Reference/catalogue data** (`products`, `categories`, `units`, `customers`,
`product_variants`, `batches`): soft delete via a nullable `deactivated_at TIMESTAMPTZ` column.
"Deleting" one of these sets `deactivated_at`; it is excluded from active-selection UI (new sales,
new catalogue entries) but remains fully queryable for historical reporting and is never physically
removed.

**Tier 2 — Ledger/event data** (`stock_movements`, `sales`, `sale_line_items`, `sale_payments`,
`returns`, `return_line_items`, `audit_log`, `trading_days`): **no delete path exists at all, soft
or hard.** These tables have no `deactivated_at`/`deleted_at` column, because the concept does not
apply — a completed sale is not "deactivated," it is a permanent fact. This restates
[ADR-0005](ADR-0005-append-only-stock-ledger.md)'s rule explicitly as a delete-strategy decision so
it cannot be mistaken for a soft-delete candidate by anyone reviewing tables tier-by-tier.

Tenants and stores themselves (`tenants`, `stores`) follow Tier 1 (soft delete) — a closed shop's
historical data must remain intact for as long as retention rules require, even after the tenant
itself is deactivated.

## Consequences

**Positive**
- Historical sales, invoices, and reports remain accurate indefinitely, regardless of what happens
  to the catalogue or customer list later.
- The two-tier split makes each table's actual guarantee legible from its own schema — a table with
  a `deactivated_at` column soft-deletes; a table without one, from the ledger/event set, cannot be
  deleted at all, and that absence is itself the documentation.

**Negative — accepted costs**
- Every query against Tier 1 tables for "active" records must remember to filter
  `WHERE deactivated_at IS NULL` — a discipline cost, mitigated by a database view
  (`active_products`, etc.) that encodes the filter once rather than repeating it everywhere.
- Tier 1 data accumulates indefinitely just as Tier 2 does, since nothing is ever purged — accepted
  as consistent with the retention posture already priced into
  [cost-model.md](../02-business-requirements/cost-model.md).

**Neutral**
- This ADR does not set the actual retention *period* after which even soft-deleted or ledger data
  might eventually be archived — that is a regulatory question owned by
  [regulatory-requirements.md](../02-business-requirements/regulatory-requirements.md)'s open items,
  not a schema-shape question.

## Compliance

- Migration review checklist: a new table is explicitly classified Tier 1 or Tier 2 before it is
  approved; Tier 1 gets `deactivated_at`, Tier 2 gets no delete-related column and has its
  `UPDATE`/`DELETE` grants revoked per [ADR-0005](ADR-0005-append-only-stock-ledger.md).
- Automated test per Tier 2 table: attempt `DELETE` through every code path with database access;
  assert rejection.

## Revisit when

A specific, confirmed legal retention period (from the pending regulatory review) requires archiving
old Tier 2 data out of the primary tables — at that point this ADR is extended to describe an
archival strategy, not superseded, since the no-delete invariant on the *primary* record is not what
would change.
