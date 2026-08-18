# Idempotency

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.2.0
> **Last updated:** 2026-08-19
> **Owner:** CTO / Principal Flutter Engineer
> **Approved by:** _pending_

Key generation, server-side deduplication, and replay safety — consolidating what
[identifiers.md §5](../07-database/identifiers.md#5-edge-case--idempotency-keys-are-identifiers-too),
[api-principles.md §3](../11-api/api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation),
and [sync-api.md §5](../11-api/sync-api.md#5-duplicate-detection--replays-are-free) already
established into one authoritative reference for this phase, plus this phase's own exit-criterion
proof: **replaying the entire outbound queue twice produces identical state.**

---

## 1. Key generation — one rule, no exceptions

Every queued operation's idempotency key (a creation's `id`, or a state-transition's
`client_operation_id`) is generated **once, locally, at the moment of the user action**, and reused
verbatim on every retry of that exact action — never regenerated on retry, per
[identifiers.md §5](../07-database/identifiers.md#5-edge-case--idempotency-keys-are-identifiers-too).
This is a client-side implementation discipline this document restates as binding: the Sync Engine
component ([sync-architecture.md](sync-architecture.md)) never mints a new key when moving an
operation from `FailedRetrying` back to `Syncing` — it resends the row exactly as
`outbound_queue` already holds it.

## 2. Server-side deduplication — the two mechanisms, restated (corrected Sprint 41)

Per [api-principles.md §3](../11-api/api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation):
an id-keyed upsert (`INSERT ... ON CONFLICT (id) DO UPDATE SET` with an empty update — Prisma's own
`upsert({ where: { id }, create: {...}, update: {} })`, which compiles to exactly this) for
creations, and a plain status-check short-circuit for state transitions. **This corrects the
document's original claim of a dedicated `idempotency_keys` lookup table** — no such table exists
anywhere in the built schema (confirmed both by `schema.prisma` and by
[tenant-isolation.md §2](../12-security/tenant-isolation.md#2-what-every-table-means-precisely-restated-as-a-checklist)'s
own already-named gap), and Sprint 33's own dated correction (`sprint-33.md`) already dropped the
one column (`client_operation_id`) that could have backed such a table, in favour of reusing each
entity's own `id`. The real, built mechanism for every operation type:

- **Creations** (`product.create`, `customer.create`, `sale.create`, `return.create`): an id-keyed
  `upsert` (`products/repository.ts`, `customers/repository.ts`) where one exists, or an equivalent
  read-then-write short-circuit (`pos/service.ts`'s `createSale`, `returns/service.ts`'s
  `createReturn`) guarded by a catch on the underlying unique-constraint violation, added Sprint 41
  (backlog.md M4 item 6) after the new adversarial suite found the read-then-write form was not
  atomic under genuine concurrency — see §5 below.
- **State transitions** (`return.approve`/`return.reject`): a plain check of the target row's own
  current `status` (`returns/service.ts`'s `approveReturn`/`rejectReturn`) — idempotent no-op if
  already in the target state, `RETURN_ALREADY_DECIDED` if in neither the source nor target state.
  No separate key or table is consulted; the row's own current state *is* the idempotency record.

Both mechanisms share the same property that makes this document's proof possible: **applying the
same key twice has the same observable effect as applying it once** — the second application is a
no-op that still returns a success-shaped result (the already-created row, or the already-applied
transition's outcome), never an error and never a second effect.

## 3. Proof — replaying the entire queue twice produces identical state

**Claim:** for any sequence of queued operations `[op₁, op₂, ..., opₙ]`, applying that sequence to
server state `S₀` to reach `S₁`, then applying the **identical** sequence again, produces `S₁`
again — not a new state `S₂`.

**Proof, by induction on the queue:**

- *Base case:* an empty queue applied to any state `S` leaves `S` unchanged, trivially.
- *Inductive step:* assume replaying `[op₁, ..., opₖ]` twice leaves state at `Sₖ` both times (i.e.
  the claim holds after `k` operations). Consider `opₖ₊₁`, applied a **third and fourth** time (once
  as the "second pass" of the first `k`, conceptually — more concretely: consider what happens when
  the *entire* n-operation sequence is replayed a second time, operation by operation). For each
  `opᵢ`, by §2, applying it to a state where its key has already been recorded produces the exact
  same resulting state as not applying it again — the second pass's `opᵢ` is a no-op against `Sᵢ`
  (the state already reflecting `opᵢ`'s effect from the first pass). Since every operation in the
  second pass is individually a no-op against the state the first pass already produced, the second
  pass as a whole leaves the state exactly at `S₁` (=`Sₙ` from the first pass) — never advancing it
  further.

**Worked example — a 3-operation sale batch, replayed in full:**

| Pass | Operation | Effect |
| --- | --- | --- |
| 1st | `sale.create` (id `S1`) | Creates the sale, its line items, its payments, and its `stock_movements` rows (server-side side effect, per [inventory.md](../11-api/endpoints/inventory.md)) |
| 1st | `return.create` (id `R1`, against a different, already-synced sale) | Creates the return |
| 1st | `return.approve` (`client_operation_id` `A1`, against `R1`) | Transitions `R1` to `approved` |
| 2nd (full replay) | `sale.create` (id `S1`) | `INSERT ... ON CONFLICT (id) DO NOTHING` — no new sale, no second stock movement; returns the existing `S1` |
| 2nd (full replay) | `return.create` (id `R1`) | Same — no second return created |
| 2nd (full replay) | `return.approve` (`client_operation_id` `A1`) | `R1`'s own `status` is already `completed` — the approval is **not** reapplied a second time; the already-completed state is simply returned |

**Final state after the second pass is identical to after the first** — one sale, one return, one
approval, one set of stock movements. This is the concrete instance of this phase's exit criterion,
and it holds specifically *because* every operation type uses one of the two mechanisms in §2 — a
hypothetical operation type that didn't would break this proof, which is exactly why
[api-principles.md §3](../11-api/api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation)
requires every mutating endpoint to use one of them, no exceptions.

## 4. What this proof depends on, made explicit

This proof assumes the key-generation discipline in §1 holds (a retry never mints a new key) and
that [outbound-queue.md](outbound-queue.md)'s draining never reorders operations relative to their
dependencies mid-replay (a `return.approve` replayed *before* its `return.create` in some
hypothetical reordering would behave differently) — both are already guaranteed by
[sync-architecture.md §3](sync-architecture.md#3-ordering-guarantees)'s ordering rules, not
independently re-derived here.

## 5. A real gap found and closed — replay safety was not atomic under genuine concurrency

Sprint 41 (backlog.md M4 item 6) built the first suite in this project's history to replay the same
operation as **genuinely concurrent** requests (`Promise.all`, not sequential awaits) against a real
database, rather than one at a time. `createSale`/`createReturn`'s read-then-write check (§2) is
correct for sequential replay (a retry after the first call has already returned) but is a
read-then-write **race**, not an atomic guard: two truly overlapping pushes of the identical `id`
could both pass the existence check before either committed, and the losing call then threw a raw
Postgres unique-violation instead of returning the idempotent result — a real, previously-unverified
gap, since no earlier test (mocked or otherwise) ever exercised two writes against the same row at
once. Fixed by catching that specific violation and re-fetching the now-committed row, the same
catch-and-translate shape `customers/service.ts`'s `translatePhoneConflict` and
`products/service.ts`'s `BARCODE_ALREADY_ASSIGNED` handling already established for this class of
race. `product.create`/`customer.create` never had this gap, since both already used an id-keyed
`upsert` rather than find-then-create — the fix brings `sale.create`/`return.create`/
`return.approve` up to that same standard rather than inventing a new mechanism.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Consolidated key-generation/deduplication reference; formal induction proof plus a worked 3-operation batch showing full-queue replay produces identical state — closing this phase's idempotency exit criterion. |
| 0.2.0 | 2026-08-19 | §2 corrected: no `idempotency_keys` table exists anywhere in the built schema (Sprint 33's own dated correction already implied this; never reconciled here until now) — replaced with the real, built mechanism (id-keyed upsert for creations, status-check short-circuit for transitions). §3's worked example corrected to match. New §5: Sprint 41 found and fixed a genuine, previously-unverified concurrency gap in `createSale`/`createReturn`/`approveReturn`'s replay-safety, found by the first suite to test genuinely concurrent (not just sequential) replay against a real database. |
