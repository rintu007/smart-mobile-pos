# ADR-0007 — Client-Generated UUIDv4 Primary Keys

> **Status:** 🟢 Accepted
> **Date:** 2026-07-30
> **Phase:** 07 — Database Design
> **Deciders:** CTO / PostgreSQL Architect
> **Supersedes:** _none_

---

## Context

A sale, a stock movement, a held cart — all must be creatable **offline**, with an ID that is
permanent from the moment of creation, never a temporary local placeholder later swapped for a
"real" server-assigned one. A server-assigned auto-incrementing integer ID cannot exist until the
server has seen the row, which is incompatible with [FR-009](../03-functional-requirements/functional-requirements.md)
(a sale executes correctly with zero connectivity) — the ID has to be real *before* the server has
any chance to assign one.

## Decision drivers

- IDs must be generatable entirely offline, with no coordination, and be globally unique the moment
  they're created — this is also what makes idempotency keys work
  ([DR-022](../03-functional-requirements/business-rules.md)): the same client-generated ID doubling
  as the idempotency key for that row's creation is the simplest correct design.
- Two different devices must never be able to generate a colliding ID for two different real-world
  entities.
- Whatever is chosen must have mature, unsurprising support in Postgres, TypeScript, and Dart —
  boring technology, per [project-vision.md §8](../01-vision/project-vision.md) Principle 7.

## Options considered

### Option A — Server-assigned auto-incrementing integer
| Pros | Cons |
| --- | --- |
| Compact, human-readable | Cannot be assigned offline at all — categorically incompatible with the offline-first requirement; ruled out, not merely disfavoured |

### Option B — Client-generated UUIDv4 (random)
| Pros | Cons |
| --- | --- |
| Universally supported, zero ambiguity, in Postgres (`uuid` type), TypeScript, and Dart today | Randomly distributed values fragment B-tree index locality on high-insert-volume tables like `stock_movements`, a real if manageable performance cost at scale |
| Simple to reason about and implement correctly on the first attempt | Not sortable by creation time without a separate timestamp column (which every table already has, per this phase's `created_at` rule) |

### Option C — Client-generated UUIDv7 (time-ordered)
| Pros | Cons |
| --- | --- |
| Better index locality than v4 for high-insert append-only tables, since IDs sort roughly by creation time | Newer; ecosystem support across Postgres, TypeScript, and Dart tooling is less universally battle-tested than v4 as of this writing — not confidently verified as uniformly mature across all three layers in this research pass |

## Decision

We will adopt **Option B: client-generated UUIDv4** as the primary key strategy for every table,
**with UUIDv7 explicitly left open as a straightforward future optimisation**, not adopted now.

Rationale: the performance difference matters most for `stock_movements`, which
[ADR-0005](ADR-0005-append-only-stock-ledger.md) already flags as the long-run dominant cost/scale
driver — but that is a scale problem, not a V1 problem, and UUIDv4's universal, unambiguous support
across Postgres/TypeScript/Dart removes a category of "did we implement this consistently across
three languages" risk that a small team building its first version should not be carrying. Per
[project-vision.md §8](../01-vision/project-vision.md) Principle 7 (boring, proven technology), the
safer default wins now; the optimisation is revisited with real insert-volume data, not guessed at
in advance.

**The same client-generated ID serves double duty as the idempotency key** for that entity's
creation ([DR-022](../03-functional-requirements/business-rules.md)) — a retried creation request
carrying the same UUID is recognised as the same operation, not a new one, with no separate
idempotency-key scheme needed for creation events specifically.

## Consequences

**Positive**
- Every entity is creatable offline with a permanent ID from the first instant, with no
  reconciliation step to swap a temporary ID for a real one later.
- One ID generation strategy across the whole system — no special-cased tables.
- Doubles as the natural idempotency key for creation, simplifying
  [DR-022](../03-functional-requirements/business-rules.md)'s implementation.

**Negative — accepted costs**
- `stock_movements` (and other high-volume append-only tables) will have somewhat worse B-tree
  index locality than a sequential or time-ordered key would give — accepted now, revisited if
  measured performance at real scale demands it.
- UUIDs are 16 bytes versus 4/8 for an integer — a modest, accepted storage cost, already reflected
  in the estimates in [cost-model.md](../02-business-requirements/cost-model.md).

**Neutral**
- Every table still carries `created_at` (this phase's own rule), so time-ordering a table's rows
  never actually depends on the primary key's sort order — mitigating the index-locality concern
  for anything that needs chronological queries.

## Compliance

- Every table's primary key column is `UUID`, generated client-side at creation (mobile) or
  server-side using the same UUIDv4 generation (for server-originated rows, e.g. `tenants`) — never
  a `SERIAL`/`BIGSERIAL`/`IDENTITY` column.
- Creation endpoints treat the client-supplied ID as the idempotency key for that creation, per
  [DR-022](../03-functional-requirements/business-rules.md).

## Revisit when

Measured insert-volume performance on `stock_movements` (or any comparably high-volume table) shows
UUIDv4's index fragmentation is a real, not theoretical, bottleneck — and UUIDv7 tooling maturity
across Postgres/TypeScript/Dart is reconfirmed at that time, not assumed from this ADR's date.
