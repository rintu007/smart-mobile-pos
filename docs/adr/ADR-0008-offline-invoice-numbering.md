# ADR-0008 — Provisional Device-Scoped Invoice Numbers, Preserved Permanently; Canonical Numbers Assigned at Sync

> **Status:** 🟢 Accepted
> **Date:** 2026-07-30
> **Phase:** 07 — Database Design
> **Deciders:** CTO / Business Analyst
> **Supersedes:** _none_

---

## Context

[RR-002](../02-business-requirements/regulatory-requirements.md) states the legal constraint: GST
tax invoices require sequential, gapless numbering per financial year. [BR-032](../02-business-requirements/business-requirements.md)/[FR-057](../03-functional-requirements/functional-requirements.md)/[FR-058](../03-functional-requirements/functional-requirements.md)
already commit to a provisional-number-first, never-renumbered approach at the requirement level.
This ADR makes that concrete enough to write a migration against, and is explicitly flagged — like
everything downstream of [RR-002](../02-business-requirements/regulatory-requirements.md) — as
**provisional pending the standing GST-practitioner review** (see
[regulatory-requirements.md — open items](../02-business-requirements/regulatory-requirements.md#open-items-before-this-document-can-be-finalised-blocks--approval)).

The core tension: a gapless sequence is only knowable once every device's sales for that period are
known — impossible to guarantee across multiple offline devices selling concurrently.

## Decision drivers

- The legal requirement is a **gapless sequence in the issued/registered record**, not necessarily
  strict real-world chronological order — an assumption this ADR states explicitly rather than
  silently, because it is exactly the kind of interpretation the pending practitioner review must
  confirm or correct.
- [BR-030](../02-business-requirements/business-requirements.md) — a sale, once completed, is
  immutable. Whatever numbering scheme is chosen cannot require rewriting a sale's identity later.
- A Cashier must see *some* reference number on the printed/shared receipt at the moment of sale —
  it cannot wait for a server round-trip.

## Options considered

### Option A — No number until sync; receipt shows only a temporary marker
| Pros | Cons |
| --- | --- |
| Avoids any provisional/canonical distinction | Violates [FR-005](../03-functional-requirements/functional-requirements.md) (first sale needs a real receipt within the 10-minute onboarding window) and general usability — a customer holding a receipt with no usable reference number is a real product defect |

### Option B — Provisional device-scoped number at creation; a canonical sequential number assigned server-side at successful sync
| Pros | Cons |
| --- | --- |
| Receipt always has a usable reference at the moment of sale | Two numbers to reason about; the canonical number's assignment order is **sync-arrival order, not real-world chronological order** — an interpretation of "sequential" that needs legal confirmation |
| Canonical numbering is gapless by construction (assigned atomically, per tenant, per financial year, only on successful sync) | A sale that is later rejected at sync (per [offline-workflows.md — Finding 1](../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux)) never receives a canonical number — its provisional number must not silently disappear either |

## Decision

We will adopt **Option B**.

- At creation (online or offline), a sale is assigned a **provisional invoice number**:
  `{device_short_id}-{financial_year}-{device_local_sequence}`, generated entirely locally from a
  per-device counter. This number is shown on the receipt immediately and is **permanent** — never
  edited, never removed, regardless of what happens at sync.
- At successful sync, the server assigns a **canonical invoice number**: a plain sequential integer,
  scoped to `(tenant_id, financial_year)`, assigned atomically in strict sync-arrival order via a
  database sequence or an equivalent atomic counter, stored alongside (never in place of) the
  provisional number.
- A sale rejected at sync (per [DR-018](../03-functional-requirements/business-rules.md)) never
  receives a canonical number. Its provisional number and local record remain, flagged via the
  `sync_rejections` mechanism (see [audit-model.md](../07-database/audit-model.md)) for Owner
  review — it is not deleted, per [ADR-0009](ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md).

**This ADR's central, explicitly flagged assumption:** assigning canonical numbers in sync-arrival
order (not underlying-transaction-time order) satisfies "sequential, gapless" because the canonical
number represents the moment of registration in the authoritative ledger, not the moment of sale.
**This has not been confirmed by the pending GST-practitioner review** — it is the single most
important open question that review must answer, and no compliance claim is made on this scheme
until it does.

## Consequences

**Positive**
- Every sale has a usable, permanent reference number from the instant it's created, satisfying
  the ten-minute onboarding promise and ordinary receipt usability.
- The canonical sequence is gapless by construction — it is only ever incremented, atomically, for
  sales that actually reach the server successfully.
- A rejected sale doesn't corrupt the canonical sequence — it simply never enters it.

**Negative — accepted costs**
- Two numbers exist per sale, which is genuinely more complex than a single number, and that
  complexity must be reflected correctly on every receipt and report, not hidden.
- The canonical number's assignment order can diverge from real-world sale order across
  multi-device shops with uneven connectivity — accepted as a necessary consequence of offline-first
  operation, pending legal confirmation that this divergence is compliant.
- A sale rejected at sync leaves a permanent provisional number attached to a sale that was never
  legally "issued" in the canonical sequence — this state must be clearly distinguishable on any
  report or export, not silently conflated with a normal completed sale.

**Neutral**
- This ADR does not resolve what happens to the goods/payment already exchanged for a rejected
  sale — that is the business-process question flagged in
  [offline-workflows.md — Finding 1](../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux),
  owned by [13-offline-sync](../13-offline-sync/README.md).

## Compliance

- `sales.provisional_invoice_number` is `NOT NULL`, assigned at creation, and never updated after
  creation — enforced by a database trigger or equivalent constraint, not convention.
- `sales.canonical_invoice_number` is nullable, unique per `(tenant_id, financial_year)` when
  present, assigned exactly once via an atomic sequence at first successful sync.
- Automated test: replaying a sync of the same sale twice must not assign a second canonical number
  — ties directly to [DR-022](../03-functional-requirements/business-rules.md).
- **This scheme is reviewed by a qualified GST practitioner before any compliance claim is made**,
  per the standing item in [regulatory-requirements.md](../02-business-requirements/regulatory-requirements.md).

## Implementation note (Sprint 24, non-normative — does not amend the decision above)

Built via `invoice_sequences`, a per-`(tenant_id, financial_year)` counter row incremented
atomically in the same transaction as the sale itself (an ordinary Prisma `upsert` with
`nextValue: { increment: 1 }`, relying on Postgres's own row-level locking — no `SELECT ... FOR
UPDATE` needed). Because `POST /sales` and `POST /sync/push`'s `sale.create` operation both call
the same `pos/service.ts#createSale`, and because this server never persists a `sales` row until
it has already "arrived," canonical-number assignment always happens at the moment of the row's own
creation — the "assigned later, at sync" framing above is still correct, it just collapses to "at
creation" for every code path that currently exists, since none of them create a row before it
syncs. Live-verified: sequential assignment across two sales, per-tenant isolation (a second
tenant's first sale also gets `1`), and the idempotent-replay compliance test this ADR's own
Compliance section names. See
[sales-invoices/specification.md](../modules/sales-invoices/specification.md) for the full record.

## Revisit when

The GST-practitioner review returns a finding that sync-arrival-order canonical numbering is not
legally sufficient — at which point this ADR is superseded, not amended, by a new numbering scheme.
