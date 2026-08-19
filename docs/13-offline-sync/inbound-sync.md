# Inbound Sync

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.2.0
> **Last updated:** 2026-08-20
> **Owner:** Principal Flutter Engineer
> **Approved by:** _pending_

Pull strategy, cursors, delta transfer, and — the one scenario [sync-api.md](../11-api/sync-api.md)
didn't need to cover but this document must — **initial hydration of a brand-new device**, where
there is no prior cursor at all.

---

## 1. Steady-state pull — delta transfer against a stored cursor

For each pull-eligible entity type (per
[entity-classification.md](entity-classification.md) — every server-authoritative and
client-editable class, plus targeted `sync_rejections` for this device), the local device stores its
own **last successful `next_cursor`** per entity type. A pull cycle resumes exactly from that cursor,
per [sync-api.md §6](../11-api/sync-api.md#6-pull--get-syncpull) — this is a delta, not a snapshot:
a device that pulls every 30 seconds and a device that pulls once a day both receive exactly the set
of changes since their own last cursor, no more and no less.

## 2. Cursor persistence — durability matches the outbound queue's

The stored cursor lives in the local database, not in memory or a preferences file that could be
cleared independently of the data it describes — losing the cursor while keeping the cached data
would make the device believe it's current when it isn't (silently stale, the one failure mode
[state-presentation.md](../10-design-system/state-presentation.md) explicitly designs against), and
losing the cached data while keeping the cursor would mean re-requesting changes for data that no
longer locally exists. Both must be lost or kept together — a single local transaction commits a
pulled page's applied rows and its updated cursor atomically, so a crash mid-pull either applies a
page and advances the cursor, or does neither; it can never do one without the other.

## 3. Initial hydration — a device with no cursor at all

A freshly installed app (after `POST /auth/register-device`,
[authentication.md §2](../11-api/authentication.md#2-issuance-flow)) has no prior state for any
entity type. This is treated as the same pull mechanism with an implicit "beginning of time" cursor
— **not a separate bulk-export endpoint** — for one deliberate reason: a second endpoint would be a
second thing to keep correct and would duplicate [sync-api.md §6](../11-api/sync-api.md#6-pull--get-syncpull)'s
cursor logic rather than reuse it. What differs at hydration time is **scale and prioritisation**,
not mechanism:

| Priority | Entity types | Why first |
| --- | --- | --- |
| 1 | `shop_settings`, own `user`/`user_store_roles`/`devices` row, `categories`, `units` | Small, and needed before the POS screen can render pricing/tax correctly at all |
| 2 | `products` | The single largest pull-eligible table by row count for a real shop, but the one the till cannot usefully operate without — prioritised ahead of history |
| 3 | `customers` | Needed for checkout lookup, but a sale can proceed without it (a walk-in customer can still be captured fresh, per [customers.md](../11-api/endpoints/customers.md)) |
| 4 | Recent `stock_movements` (bounded window, per [schema-local.md](../07-database/schema-local.md)), recent `sales`/`returns` from other devices at this store | Needed for balance accuracy and return lookup, but the till can sell before this finishes — an empty/partial cache here degrades to the offline-stale treatment in [state-presentation.md](../10-design-system/state-presentation.md), not a blocked launch |

**The till is usable (per this phase's own "never stop selling" objective) once Priority 1 and a
first page of Priority 2 have landed** — hydration continues in the background across subsequent
pull cycles rather than blocking first use on a complete download, consistent with
[navigation-model.md §6](../09-navigation/navigation-model.md#6-offline-rendering--never-an-indefinite-spinner)'s
no-indefinite-spinner rule applied to the single largest read operation this product performs.

## 4. Bounded local history, restated as this phase's own decision

[schema-local.md](../07-database/schema-local.md) flagged the exact `stock_movements` retention
window as "a Phase 13 performance decision, not fixed there." **Decided here:** a rolling window
covering the current and prior financial year (aligned with
[identifiers.md §3](../07-database/identifiers.md#3-invoice-numbering--financial-year-rollover)'s
existing financial-year keying, so no new period boundary concept is introduced) is pulled and
retained locally; older movements remain on the server, retrievable if a report genuinely needs them
(a back-office, online concern, per [schema-local.md](../07-database/schema-local.md)'s "not
designed to run entirely offline" scoping) but never bloat the till's local cache indefinitely.

**Built, Sprint 53** — found unbuilt while investigating storage-full handling
([failure-scenarios.md §3](failure-scenarios.md#3-resolving-the-storage-full-open-item)): this
decision had never actually been implemented on either side. `GET /sync/pull`'s
`entity_type=stock_movements` handler pulled every movement ever created, unfiltered, since
Sprint 36; nothing ever removed an already-pulled row from the local cache either. Both are fixed
now: `sync/service.ts`'s `pullStockMovements` bounds its query to `stockMovementsRetentionCutoff`
(server clock, current + prior financial year, UTC — matching `pos/repository.ts`'s own
`financialYearFor`), and `SyncRepository._pruneStaleStockMovements` deletes local rows outside that
same window after every pull. The two sides deliberately use **different clocks**: the server bound
uses the server's own clock (matching this phase's own "server time is authoritative for anything
that matters" rule, [clock-and-ordering.md §3](clock-and-ordering.md#3-what-is-ordered-by-server-time--everything-that-matters-financially-or-causally));
the local prune uses the device's own clock, a deliberate exception since this is a purely local
cache-size decision with no financial or cross-device consequence
([clock-and-ordering.md §2](clock-and-ordering.md#2-what-is-ordered-by-device-time--display-only)'s
"device time is fine for local-only purposes" rule extended here to a new case). One accepted
consequence, named rather than silently risked: a device that hasn't synced across a financial-year
rollover boundary will silently skip forward past whatever it fell behind on, never receiving it —
an acceptable outcome given this cache was never designed to guarantee full history
([schema-local.md](../07-database/schema-local.md)'s own "not designed to run entirely offline"
scoping for tenant-wide reporting already establishes this).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Cursor-persistence atomicity specified; initial hydration designed as the same pull mechanism with a prioritised entity order, not a second endpoint; local stock-movement retention window decided (current + prior financial year). |
| 0.2.0 | 2026-08-20 | Sprint 53 — §4's retention window built: `pullStockMovements`'s server-side query was unfiltered since Sprint 36 despite this decision, and nothing ever pruned an already-pulled row locally. Both fixed — server bound uses server time, local prune uses device time (a deliberate, low-stakes exception, reasoned explicitly). Found while investigating storage-full handling (failure-scenarios.md §3). |
