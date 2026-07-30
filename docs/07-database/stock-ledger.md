# Stock Ledger — Correctness Proof

> **Status:** 🔵 In review
> **Phase:** 07 — Database Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** PostgreSQL Architect / CTO
> **Approved by:** _pending_

The *decision* is [ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md). This document is the
**proof, on paper, before any code**, that balance derivation is correct under concurrent offline
writes — this phase's own exit criterion, and arguably the single most important piece of reasoning
in the entire specification, since [R-02](../01-vision/risks-constraints-assumptions.md) rates
getting this wrong at the highest risk priority in the project.

---

## 1. The formal model

For a given `(product_id, store_id)` pair:

```
balance(product, store) = Σ movement.quantity_delta
                           for all movement in stock_movements
                           where movement.product_id = product
                           and movement.store_id = store
```

`quantity_delta` is signed: positive for `opening` and `return`, negative for `sale`. Every movement
carries a unique `client_operation_id` (its own primary key, per
[ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md)).

## 2. The claim

**Claim:** the value of `balance(product, store)` is identical regardless of (a) the order in which
movements are created across different devices, (b) the order in which they arrive at the server,
and (c) how many times a network retry causes a movement to be *resent* — provided each resend
carries the same `client_operation_id` as the original.

## 3. Proof of order-independence

Addition over a finite multiset of real numbers is **commutative and associative**: for any
movements `m₁, m₂, ..., mₙ`, `m₁ + m₂ + ... + mₙ` evaluates to the same value regardless of the
order the terms are summed in. `SUM(quantity_delta)` is exactly this operation. Therefore:

> If the *set* of movements that have been durably recorded for a given `(product, store)` is the
> same, `balance(product, store)` is the same — independent of arrival order, sync order, or which
> device created which movement first.

This is why [ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md) requires **deltas**, not
absolute quantities: a delta is a term in a commutative sum; an absolute value ("set balance to 4")
is not a term in any sum at all — it's an overwrite, and overwrites do not commute (the order in
which two overwrites are applied changes the final result, which is exactly the bug this
architecture exists to avoid).

## 4. Worked example — two devices selling concurrently offline

**Setup:** Product P at Store S has one recorded unit (`balance = 1`), from an opening-stock
movement `m₀ = +1`, already synced.

**Both devices are now offline, simultaneously:**
- Device A sells 1 unit → creates `mₐ = -1` (client_operation_id `A1`).
- Device B, unaware of Device A's sale, also sells 1 unit of the same product → creates `m_b = -1`
  (client_operation_id `B1`).

**Connectivity returns. Two possible sync orders:**

| Sync order | Running balance after each sync | Final balance |
| --- | --- | --- |
| A syncs, then B syncs | `1 + (-1) = 0`, then `0 + (-1) = -1` | **-1** |
| B syncs, then A syncs | `1 + (-1) = 0`, then `0 + (-1) = -1` | **-1** |

**Result: identical, −1, regardless of order.** This is the correct real-world answer — two units
were sold against one recorded unit of stock, so the shop is oversold by one, and the system
reflects that truthfully rather than losing one sale's effect (which a mutable-quantity model would
do — both devices would independently compute "1 − 1 = 0" locally and the second sync would silently
overwrite the first's effect, permanently losing the fact that two units left the shop). This is
exactly the failure mode [ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md) was written to
prevent, now shown numerically rather than asserted.

The negative balance is not an error state — it is correctly handled by
[DR-005](../03-functional-requirements/business-rules.md)/[FR-047](../03-functional-requirements/functional-requirements.md)/[FR-048](../03-functional-requirements/functional-requirements.md):
the sale completes, the balance goes negative, and it is flagged for the owner rather than blocked
or corrected automatically.

## 5. Worked example — a retried sync does not double-count

**Setup:** Device A creates `mₐ = -1` (client_operation_id `A1`) and attempts to sync it. The
network request succeeds server-side, but the acknowledgement is lost before Device A receives it —
an ambiguous outcome from the client's perspective (per
[state-machines.md — Sync Item](../06-workflows/state-machines.md#sync-item), this lands in
`FailedRetrying`, not a confirmed failure).

**Device A retries, resending the same movement with the same `client_operation_id = A1`.**

Because `client_operation_id` is the table's own `PRIMARY KEY`
([schema-server.md](schema-server.md)), the second `INSERT` is rejected by the database's own
uniqueness constraint (or absorbed via an `INSERT ... ON CONFLICT DO NOTHING`, depending on the
exact API implementation chosen in Phase 11 — either way, the *effect* is applied exactly once).
`balance(product, store)` reflects `mₐ` a single time, not twice. This is
[DR-022](../03-functional-requirements/business-rules.md) demonstrated concretely against this
specific table.

## 6. What this proof does not cover

It proves the **ledger arithmetic** is order-independent and retry-safe. It does not resolve:
- **What the Cashier is shown at the moment of an offline oversell** — that's a UX question already
  answered at the requirement level ([FR-048](../03-functional-requirements/functional-requirements.md)),
  not a data-correctness one.
- **How the local device's own balance computation stays fast** as `stock_movements` grows —
  addressed by the indexing in [schema-server.md](schema-server.md) and the optional read-cache
  permitted (never required) by [ADR-0005](../adr/ADR-0005-append-only-stock-ledger.md).
- **Conflict policy for entities that aren't simple deltas** (e.g. `customers`, `shop_settings`) —
  those are client-editable entities with a genuinely different conflict shape, owned by
  [13-offline-sync/conflict-resolution.md](../13-offline-sync/conflict-resolution.md), not this document.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial correctness proof: order-independence via commutativity, two worked examples (concurrent oversell, retried sync). |
