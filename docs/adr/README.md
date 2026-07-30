# Architecture Decision Records

> **Status:** 🟢 Approved (foundational)
> **Version:** 1.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO

An ADR records **one** architecturally significant decision: the context that forced it, the
options considered, the option chosen, and the consequences we accept.

## Rules

1. One decision per record. Numbered sequentially, never renumbered.
2. **Immutable once 🟢 Accepted.** To change a decision, write a new ADR that supersedes it.
3. A superseded ADR is marked ⚫ Superseded with a link forward. Never deleted.
4. Consequences must include the **negative** ones. An ADR listing only benefits is marketing.

Use [adr-template.md](adr-template.md).

## Register

| ID | Title | Status | Date | Phase |
| --- | --- | --- | --- | --- |
| [0000](ADR-0000-adopt-architecture-decision-records.md) | Adopt Architecture Decision Records | 🟢 Accepted | 2026-07-28 | 00 |
| [0001](ADR-0001-hybrid-api-and-direct-realtime-access.md) | Mobile client uses API for writes, direct access only for realtime reads and file transfer | 🟢 Accepted | 2026-07-28 | 01 |
| [0002](ADR-0002-hosting-posture-for-commercial-launch.md) | Free tiers for development/pilot, budgeted paid tier at commercial launch | 🟢 Accepted | 2026-07-28 | 01 |
| [0003](ADR-0003-multi-outlet-modelled-from-day-one.md) | Model store-level scoping from the first migration | 🟢 Accepted | 2026-07-28 | 01 |
| [0004](ADR-0004-shared-schema-multi-tenancy.md) | Shared schema with row-level tenant scoping, not schema-per-tenant | 🟢 Accepted | 2026-07-30 | 07 |
| [0005](ADR-0005-append-only-stock-ledger.md) | Stock is an append-only ledger of signed deltas; balance always derived | 🟢 Accepted | 2026-07-30 | 07 |
| [0006](ADR-0006-money-as-integer-minor-units.md) | Money as integer minor units; tax rates as integer basis points | 🟢 Accepted | 2026-07-30 | 07 |
| [0007](ADR-0007-client-generated-uuid-primary-keys.md) | Client-generated UUIDv4 primary keys | 🟢 Accepted | 2026-07-30 | 07 |
| [0008](ADR-0008-offline-invoice-numbering.md) | Provisional device-scoped invoice numbers; canonical numbers assigned at sync | 🟢 Accepted | 2026-07-30 | 07 |
| [0009](ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md) | Soft delete for reference data; no delete path for ledger/event data | 🟢 Accepted | 2026-07-30 | 07 |

## Decision backlog

Decisions we know we must make, with the phase that forces them. Listed here so they are not
discovered late.

| Candidate decision | Forced by phase | Why it is significant | Status |
| --- | --- | --- | --- |
| Multi-tenancy model (shared schema + tenant ID vs schema-per-tenant) | 07 — Database | Effectively irreversible after the first paying customer. | 🟢 [ADR-0004](ADR-0004-shared-schema-multi-tenancy.md) — shared schema, RLS-enforced |
| Where authorisation is enforced: API layer, Row Level Security, or both | 07 / 12 | Two enforcement planes that disagree is a data-leak class of bug. | 🟢 [ADR-0001](ADR-0001-hybrid-api-and-direct-realtime-access.md) — both, independently |
| Whether the mobile client talks to Supabase directly or only through our API | 11 — API | Determines the entire security model and offline design. | 🟢 [ADR-0001](ADR-0001-hybrid-api-and-direct-realtime-access.md) — hybrid, writes via API only |
| Stock representation: mutable quantity column vs append-only movement ledger | 07 — Database | Determines whether offline concurrent selling is correct or corrupting. | 🟢 [ADR-0005](ADR-0005-append-only-stock-ledger.md) — append-only, balance always derived |
| Invoice numbering under offline conditions | 07 / 13 | Tax and legal traceability. Cannot be retrofitted onto historic sales. | 🟢 [ADR-0008](ADR-0008-offline-invoice-numbering.md) — provisional now, canonical at sync; **assumption pending GST-practitioner review** |
| Sync conflict resolution strategy, per entity class | 13 — Offline Sync | Wrong choice silently loses money. | 🔴 Open |
| Money representation (minor-unit integers vs decimal) | 07 — Database | Floating-point money is a defect that appears months later in reconciliation. | 🟢 [ADR-0006](ADR-0006-money-as-integer-minor-units.md) — integer minor units, integer basis points |
| Primary key strategy (client-generatable) | 07 — Database | Offline creation requires IDs assignable without a server. | 🟢 [ADR-0007](ADR-0007-client-generated-uuid-primary-keys.md) — client-generated UUIDv4 |
| Soft delete vs hard delete | 07 — Database | Financial records must not vanish. | 🟢 [ADR-0009](ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md) — two-tier: soft delete for reference data, no delete for ledger/event data |
| Hosting for the API given commercial-use licence terms | 01 / 12 | Licence compliance and cost floor. | 🟢 [ADR-0002](ADR-0002-hosting-posture-for-commercial-launch.md) |
| Store-level scoping in the schema | 07 — Database | Retrofitting onto a live stock ledger is one of the most expensive migrations in this domain. | 🟢 [ADR-0003](ADR-0003-multi-outlet-modelled-from-day-one.md) |
| Payment gateway per launch market | 02 — Business Requirements | Regional; determines checkout flows. | 🔴 Open — blocked on launch market ([OD-01](../01-vision/open-decisions.md), provisional) |
| Push notification provider | 11 / 12 | Introduces a second vendor and a second identity surface. | 🔴 Open |
| Map tile source for delivery tracking | 02 / 11 | Free public tile servers prohibit commercial-scale use. | 🔴 Open — posture set in [ADR-0002](ADR-0002-hosting-posture-for-commercial-launch.md) (commercial-terms provider, not public OSM tiles); specific provider TBD |
| Trading Day scoping: per-store vs per-device for multi-till shops | 07 / 13 | [offline-workflows.md — Finding 2](../06-workflows/offline-workflows.md#finding-2--trading-day-is-a-shared-store-level-concept-and-multi-device-shops-need-a-rule) found this unresolved. | 🟢 Resolved in [schema-server.md](../07-database/schema-server.md) — scoped per-device in V1, sidestepping the multi-till conflict question rather than solving it |
