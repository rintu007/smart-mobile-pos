# Sync API

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.2.0
> **Last updated:** 2026-08-16
> **Owner:** Principal Next.js Engineer / CTO
> **Approved by:** _pending_

Push, pull, cursors, batching, and partial-failure semantics — the concrete API surface behind
every "Yes — queued" row across [endpoints/](endpoints/), and the mechanism that resolves the
open questions [offline-workflows.md](../06-workflows/offline-workflows.md) flagged for this phase.
This is not a new subsystem bolted onto the rest of the API — it reuses the same idempotency
mechanism from [api-principles.md §3](api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation)
and the same error envelope, applied to batches instead of single requests.

---

## 1. Push — `POST /sync/push`

The device sends every operation accumulated in its local outbound queue
([schema-local.md](../07-database/schema-local.md)'s `outbound_queue`) since its last successful
push, as a single batch:

```json
{
  "operations": [
    { "type": "product.create", "client_operation_id": "<uuid>", "payload": { } },
    { "type": "stock_movement.create", "client_operation_id": "<uuid>", "payload": { } },
    { "type": "sale.create", "client_operation_id": "<uuid>", "payload": { } },
    { "type": "return.approve", "client_operation_id": "<uuid>", "payload": { } }
  ]
}
```

Each `payload` is exactly the request body the equivalent direct endpoint in
[endpoints/](endpoints/) would accept — **push does not define a second, parallel request schema**;
it is a batch envelope around the same per-operation contracts, so a service method written for
`POST /sales` is the same service method the sync push handler calls per operation. This is a
direct consequence of [backend-structure.md](../08-folder-structure/backend-structure.md)'s
layering: Route Handlers are thin, so both the direct endpoint and the sync-push handler can call
the identical `service.ts` function.

## 2. Ordering — dependency groups, not raw client order

Per this phase's exit criterion, the sync API must handle partial batch failure **without losing or
duplicating any operation**. Doing that safely requires processing operations in an order that
respects their real dependencies (a `sale.create` referencing a `product_id` a Manager created
offline, on the same or a different device, must not be evaluated before that product exists
server-side). The server processes a batch in fixed **type-ordered groups**, preserving the
client's original order *within* each group:

```
1. catalogue.*      (categories, units, products)
2. customer.*
3. stock_movement.* (opening, adjustment only — sale/return movements are generated server-side)
4. trading_day.*
5. sale.*
6. return.*
```

This ordering is not a heuristic — it mirrors [backend-structure.md](../08-folder-structure/backend-structure.md)'s
module dependency direction exactly (`sales`/`returns` depend on `catalogue`/`inventory`, never the
reverse), so no new dependency logic is invented here that the module architecture doesn't already
express.

## 3. Partial failure semantics — every operation gets its own verdict

The response mirrors the request, one result per operation, in the same order submitted:

```json
{
  "results": [
    { "client_operation_id": "<uuid>", "status": "accepted", "entity_id": "<uuid>" },
    { "client_operation_id": "<uuid>", "status": "accepted", "entity_id": "<uuid>" },
    { "client_operation_id": "<uuid>", "status": "rejected", "error": { "code": "DEPENDENCY_NOT_FOUND", "message": "product_id not found at sync time" } },
    { "client_operation_id": "<uuid>", "status": "accepted", "entity_id": "<uuid>" }
  ]
}
```

**One operation's rejection never fails the batch, and never blocks independent operations after
it in the same batch** — the whole point of per-operation idempotency keys is that each operation
is its own atomic unit of work. A `DEPENDENCY_NOT_FOUND` rejection (§4) is not a permanent failure:
the client leaves that operation in its local outbound queue, unresolved, and resubmits it on the
**next** push — by which point the dependency (created earlier in a prior batch, per the group
ordering in §2) will exist. This is what "never loses" means concretely: nothing is removed from
the local queue until its result is `accepted`.

## 4. Why `DEPENDENCY_NOT_FOUND` is not `NOT_FOUND`

A direct endpoint's `404` (see [error-catalogue.md](error-catalogue.md)) means "this genuinely does
not exist." A sync-push rejection for a missing dependency means "this may exist, just not on this
server yet, from this device's point of view" — a strictly weaker, retryable claim. Giving it a
distinct code is what lets the client know to leave the operation queued rather than discard it as
a permanent client-side data error — conflating the two would either cause the client to silently
drop a good operation or retry a genuinely invalid one forever.

## 5. Duplicate detection — replays are free

If a push request itself fails partway (connection drop mid-response), the client does not know
which operations were actually committed. It simply resubmits the **same** unresolved operations
(same `client_operation_id`s) on the next attempt. Every operation type's idempotency mechanism
([api-principles.md §3](api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation))
makes this safe by construction — a replayed `sale.create` with the same `client_operation_id`
returns the already-created sale rather than creating a second one. This is the same guarantee
[stock-ledger.md](../07-database/stock-ledger.md) already proved for the retried-sync case; this
document is where that proof becomes an actual API behaviour.

## 6. Pull — `GET /sync/pull`

```
GET /sync/pull?entity_type=products&cursor=<opaque>&limit=200
```

One call per entity type the device needs to stay current on:
`products`, `categories`, `units`, `customers`, `user_store_roles` (permission changes — server-
authoritative, per [schema-server.md](../07-database/schema-server.md)), `shop_settings`,
`sync_rejections` (filtered to this device/store), and — for reporting parity across devices in a
future multi-device store — `stock_movements` and `sales` from **other** devices. Cursor semantics
match [api-principles.md §4](api-principles.md#4-pagination--cursor-only) exactly: `(updated_at, id)`
for Tier 1 tables, `(created_at, id)` for Tier 2 tables (`(completed_at, id)` for `sales` specifically
— every synced sale is `status: 'completed'`, so `completed_at` is as reliable a monotonic key as
`created_at`, and it is the cursor field `GET /sales` already established, docs/modules/
sales-invoices/specification.md). The client loops pulling pages until `next_cursor` is `null`, then
stores that final cursor as its new starting point for the next sync cycle — an incremental,
resumable feed, never a full re-download.

**Correction, found implementing `stock_movements`/`sales` (Sprint 36, backlog.md M4 item 1):** the
paragraph above conflates two things a `next_cursor` of `null` was being asked to signal at once —
"no more pages in this pull run" and "nothing to persist as next cycle's resume point." Those are the
same signal only for an entity type whose pull cursor is never persisted between sync cycles in the
first place (`products`, per [sync-engine/specification.md §2](../modules/sync-engine/specification.md#2-business-rules)'s
own named trade-off — its near-static catalogue makes a full re-pull cheap enough not to bother). For
`stock_movements`/`sales`, an ever-growing transaction history, a full re-pull every cycle is real,
avoidable cost — but resuming needs a durable cursor, and "the last page had no next page" is not the
same fact as "here is the position to resume from." These two entity types' pull response therefore
carries **two** fields instead of one: `next_cursor` (always the last row actually returned, even on
the final page — a stable resume point) and `has_more` (`true`/`false`, "keep paging within this run
right now"). An empty page (no new rows since the caller's own cursor) echoes that cursor back
unchanged rather than `null`, so a quiet sync cycle never resets an established resume point back to
the start. `products`' existing single-field `next_cursor` contract is unchanged — this is additive
to two specific entity types' own response shape, not a retroactive change to an already-working one.

## 7. What triggers a sync cycle

Opportunistic and connectivity-driven, not fixed-interval polling: on regaining connectivity, on
app foreground, and on a coarse background timer as a backstop — the exact timer value is a Phase
18/Phase 14 performance-tuning question (battery vs. staleness trade-off), not an architectural one
fixed here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial sync API: batch push reusing per-operation service methods, dependency-ordered groups, per-operation partial-failure results, `DEPENDENCY_NOT_FOUND` as a distinct retryable code, cursor-based pull per entity type. |
| 0.2.0 | 2026-08-16 | Sprint 36 (backlog.md M4 item 1): `stock_movements`/`sales` pull implemented — the "reporting parity across devices" this section named since Phase 11 (§6). Corrected §6's own conflated `next_cursor` semantics: these two entity types now carry `has_more` as a distinct field alongside `next_cursor` (always the last row seen, a durable resume point), since an ever-growing transaction history can't afford `products`' own "no persisted cursor, full re-pull every cycle" trade-off. `products` unchanged. |
