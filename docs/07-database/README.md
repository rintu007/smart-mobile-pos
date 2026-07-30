# Phase 07 — Database Design

> **Status:** 🔵 In review — all 10 deliverables + 6 required ADRs drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** PostgreSQL Architect / CTO

## Charter

| | |
| --- | --- |
| **Objective** | Design the schema for both the server database and the on-device database, and the relationship between them. |
| **Inputs** | Approved Phase 06 workflows and state machines. Resolved [OD-03](../01-vision/open-decisions.md) and [OD-05](../01-vision/open-decisions.md). |

**This is the highest-stakes phase in the project.** Schema mistakes are the only mistakes that
corrupt data that was never recorded correctly anywhere, and they become near-impossible to fix
once real shops depend on the data.

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`erd.md`](erd.md) | 7 bounded-context ERDs, including 2 forward-accommodation stub tables | 🔵 In review |
| [`schema-server.md`](schema-server.md) | 22 PostgreSQL tables: purpose, module, tenant scoping, columns, FK behaviour, indexes, RLS stance | 🔵 In review |
| [`schema-local.md`](schema-local.md) | On-device Drift schema: entity classification, explicit divergence table, 2 local-only tables | 🔵 In review |
| [`tenancy-model.md`](tenancy-model.md) | JWT claim mechanism, RLS policy template, cross-tenant negative test suite spec | 🔵 In review |
| [`stock-ledger.md`](stock-ledger.md) | Formal correctness proof (commutativity) + 2 worked examples | 🔵 In review |
| [`money-and-tax.md`](money-and-tax.md) | Arithmetic spec + worked exclusive/inclusive examples; discount-before-tax rule fixed | 🔵 In review |
| [`identifiers.md`](identifiers.md) | Primary keys, invoice numbering, 2 resolved edge cases | 🔵 In review |
| [`audit-model.md`](audit-model.md) | Trigger list, stored fields, read access, retention (flagged pending) | 🔵 In review |
| [`migration-strategy.md`](migration-strategy.md) | Expand/migrate/contract pattern, Drift safety rules, migration checklist | 🔵 In review |
| [`seed-data.md`](seed-data.md) | Template structure; Grocery and Mobile Shop fully worked | 🔵 In review |

## Required ADRs from this phase — all six accepted

| Decision | ADR |
| --- | --- |
| Multi-tenancy model | [ADR-0004](../adr/ADR-0004-shared-schema-multi-tenancy.md) — shared schema, RLS-enforced |
| Append-only stock ledger vs mutable quantity | [ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md) |
| Money as integer minor units | [ADR-0006](../adr/ADR-0006-money-as-integer-minor-units.md) |
| Primary key strategy (client-generatable) | [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md) — UUIDv4 |
| Offline invoice numbering | [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) — provisional + canonical, **pending GST-practitioner review** |
| Soft delete vs hard delete | [ADR-0009](../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md) |

## Exit criteria

- [x] Every table has a documented purpose, owner module, and tenant scoping — all 22.
- [x] Every foreign key states its delete behaviour and why — [schema-server.md](schema-server.md).
- [x] Every table carrying tenant data has Row Level Security policies **and** a test is
      *specified* proving a wrong-tenant read fails — [tenancy-model.md §5](tenancy-model.md#5-the-proof-automated-cross-tenant-negative-test-suite).
      The test is designed now; it is *run* in Phase 18, consistent with this project's design-before-code discipline.
- [x] Every index traces to a specific query in a specific workflow — no speculative indexes remain.
- [x] Stock balance derivation is proven correct under concurrent offline writes, on paper —
      [stock-ledger.md](stock-ledger.md), via commutativity of addition plus two worked examples.
- [x] Money precision and rounding are specified to the minor unit, with worked examples —
      [money-and-tax.md](money-and-tax.md), including a previously-unstated rule (discount reduces
      taxable value before tax) fixed explicitly for the first time.
- [x] Local and server schemas have an explicit field-by-field mapping — via an identity-mapping-
      plus-divergence-table approach in [schema-local.md](schema-local.md), rather than repeating
      all 22 tables' columns twice.
- [x] Variants, batch, expiry and serial numbers are accommodated — `product_variants` and
      `batches` stub tables, plus nullable `variant_id`/`batch_id`/`serial_number` columns on
      `stock_movements` and `sale_line_items`.

**Every exit criterion is met at the design level.** What remains is the same standing project-wide
blocker as every phase since 02: [OD-01](../01-vision/open-decisions.md) confirmation and the
GST-practitioner review, which specifically bear on [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md)'s
sync-arrival-order assumption and the tax defaults in [seed-data.md](seed-data.md).

**One real design decision made in this phase, not merely inherited:** [offline-workflows.md — Finding 2](../06-workflows/offline-workflows.md#finding-2--trading-day-is-a-shared-store-level-concept-and-multi-device-shops-need-a-rule)
(is Trading Day per-store or per-device?) is resolved here — `trading_days` is scoped per-device in
V1, sidestepping the multi-till conflict question rather than solving it, recorded in
[schema-server.md](schema-server.md) and the [ADR backlog](../adr/README.md).

## Rules

- No business logic in the database beyond constraints and Row Level Security. Logic lives in the
  service layer where it is testable and versioned with the code.
- Every financial table is append-only. Corrections are new linked rows, never updates.
- `created_at`, `updated_at`, `created_by` on every table without exception.
