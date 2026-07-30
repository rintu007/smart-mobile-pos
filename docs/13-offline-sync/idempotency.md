# Idempotency

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
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

## 2. Server-side deduplication — the two mechanisms, restated

Per [api-principles.md §3](../11-api/api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation):
`INSERT ... ON CONFLICT (id) DO NOTHING` for creations, and an `idempotency_keys` lookup for state
transitions. Both share the same property that makes this document's proof possible: **applying the
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
| 2nd (full replay) | `return.approve` (`client_operation_id` `A1`) | `idempotency_keys` lookup finds `A1` already applied — the approval is **not** reapplied a second time; the already-`approved` state is simply returned |

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

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Consolidated key-generation/deduplication reference; formal induction proof plus a worked 3-operation batch showing full-queue replay produces identical state — closing this phase's idempotency exit criterion. |
