# ADR-0005 — Stock Is an Append-Only Ledger of Signed Deltas; Balance Is Always Derived

> **Status:** 🟢 Accepted
> **Date:** 2026-07-30
> **Phase:** 07 — Database Design
> **Deciders:** CTO / PostgreSQL Architect
> **Supersedes:** _none_

---

## Context

[project-vision.md §9](../01-vision/project-vision.md) and
[DR-001](../03-functional-requirements/business-rules.md)/[DR-002](../03-functional-requirements/business-rules.md)
already establish the *direction*: stock is append-only, balances are derived. This ADR is the
formal ratification the decision backlog in [docs/adr/README.md](README.md) called for, now that
the actual schema is being designed and the mechanism has to be concrete, not just a principle.

**The concurrency problem this solves, stated precisely:** two offline devices for the same store
both sell the last recorded unit of a product. If stock were a mutable `quantity` column, both
devices would locally compute `quantity = 0` and both would sync a write of `quantity = 0` — the
second sale's effect is silently lost; the true state (two units sold, balance −1) is never
represented anywhere. If stock is a signed-delta ledger, both devices sync a row of `quantity_delta
= -1`; the balance is `SUM(quantity_delta)`, which correctly composes to −1 regardless of sync
order. This is not a performance optimisation — it is the only representation under which
concurrent offline writes compose correctly at all.

## Decision drivers

- [BR-026](../02-business-requirements/business-requirements.md)/[DR-005](../03-functional-requirements/business-rules.md)
  require a sale to complete even when it oversells — the ledger model is what makes "oversold, but
  correctly recorded" representable at all; a mutable quantity model has no way to express it.
- [FR-082](../03-functional-requirements/functional-requirements.md) requires concurrent offline
  stock changes to compose correctly without manual conflict resolution.
- Auditability ([BR-009](../02-business-requirements/business-requirements.md)) requires every stock
  change to be individually attributable — a mutable balance destroys the history of how it got
  there.

## Options considered

### Option A — Mutable `quantity` column on `products` (or a per-store stock row)
| Pros | Cons |
| --- | --- |
| Trivial to read (`SELECT quantity`) | Concurrent offline writes silently overwrite each other's effect — the exact failure mode this ADR exists to prevent |
| | No audit trail of *why* the balance is what it is |

### Option B — Append-only `stock_movements` ledger, balance derived by `SUM(quantity_delta)`
| Pros | Cons |
| --- | --- |
| Concurrent offline deltas compose correctly regardless of arrival order | Reading a balance requires an aggregation, not a single-row lookup |
| Every change is individually attributable, satisfying the audit requirement for free | The ledger grows without bound (accepted — [cost-model.md §3](../02-business-requirements/cost-model.md) already prices this in as the dominant long-run cost driver) |

## Decision

We will adopt **Option B**. The `stock_movements` table (full schema in
[schema-server.md](../07-database/schema-server.md)) is **append-only**: no `UPDATE` or `DELETE`
grant exists on it for any application role, enforced at the database permission level, not merely
by convention or by omitting it from the API. A correction is always a new row (per
[DR-002](../03-functional-requirements/business-rules.md)), referencing what it corrects via
`reference_type`/`reference_id`, never a modification of the row being corrected.

**A read-optimised balance cache is permitted, but only as a cache, never as a second source of
truth.** A materialised or regularly-refreshed `product_stock_balances` view may exist purely for
query performance at scale; it must always be re-derivable by re-running `SUM(quantity_delta)` over
`stock_movements`, and no code path may write to it independently of that derivation. If the cache
and the ledger ever disagree, the ledger is correct by definition — this is stated explicitly so a
future performance optimisation doesn't accidentally reintroduce Option A through the back door.

## Consequences

**Positive**
- Concurrent offline selling is representable and correct by construction, not by a merge algorithm
  that has to guess the right answer.
- Every balance is fully explained by its movement history — the audit trail is a side effect of the
  data model, not a separate thing to maintain.
- Overselling ([BR-026](../02-business-requirements/business-requirements.md)) is just a balance
  that happens to be negative — no special-case representation needed.

**Negative — accepted costs**
- Computing a balance is an aggregation over a growing table, not a single-row read — the design
  must plan for this from the start (indexing per query, see
  [schema-server.md](../07-database/schema-server.md); optional cache per above).
- The table's unbounded growth is a real, already-quantified cost driver (
  [cost-model.md §3](../02-business-requirements/cost-model.md) shows it dominates infrastructure
  cost at scale) — accepted now as the cost of correctness, with a data-retention/archival strategy
  flagged as a future lever, not a V1 concern.

**Neutral**
- This ADR governs the *shape* of stock representation; it does not by itself resolve overselling
  UX (already handled — [FR-047](../03-functional-requirements/functional-requirements.md)/[FR-048](../03-functional-requirements/functional-requirements.md))
  or the conflict-classification work still owned by
  [13-offline-sync](../13-offline-sync/README.md).

## Compliance

- The `stock_movements` table's `UPDATE`/`DELETE` privileges are revoked from every application
  database role in the same migration that creates the table — not added later, not left to
  convention.
- An automated test attempts an `UPDATE` and a `DELETE` against the table through every code path
  with database access (API service role included) and asserts both are rejected — this is the
  concrete instrument for [DR-002](../03-functional-requirements/business-rules.md) and
  [FR-046](../03-functional-requirements/functional-requirements.md).
- Any balance-cache table, if introduced, is reviewed against: "is this ever written to except by
  re-deriving from `stock_movements`?" — a "no" blocks the change.

## Revisit when

Never, for the append-only property itself — this is meant to be a permanent architectural
invariant. The *performance* strategy around it (indexing, caching, archival) is revisited as scale
demands, without touching the invariant.
