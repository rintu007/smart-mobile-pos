# Sync Architecture

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO / Principal Flutter Engineer
> **Approved by:** _pending_

The overall model, components, data flow, and ordering guarantees — the client-side counterpart to
[sync-api.md](../11-api/sync-api.md), which already specified the server's half of this contract
(batch push reusing per-operation service methods, dependency-ordered groups, cursor-based pull).
This document is where those server guarantees meet an actual mobile architecture.

---

## 1. Components

```mermaid
flowchart TB
    UI["UI layer (Riverpod providers)"] -->|reads| LocalDB[("Local Drift/SQLite DB")]
    UI -->|writes (create sale, adjust stock, ...)| Writer["Local Write Path"]
    Writer -->|1. writes the entity's own table| LocalDB
    Writer -->|2. enqueues| Queue[("outbound_queue")]
    Engine["Sync Engine"] -->|drains, dependency-ordered| Queue
    Engine -->|POST /sync/push| API["Server API"]
    Engine -->|GET /sync/pull, per entity type| API
    API -->|per-operation results| Engine
    Engine -->|updates status, applies pulled rows| LocalDB
    Trigger["Triggers: connectivity regained, app foreground, background timer"] -->|wake| Engine
```

**The Local Write Path is the one and only way any entity is created or changed on-device.** A
Cashier completing a sale, a Manager adjusting stock, an Owner editing a product — every one of
these writes its own table **and** enqueues an outbound operation **in the same local transaction**,
so the two can never diverge (a write that lands in `sales` but never reaches `outbound_queue`, or
vice versa, is structurally impossible, not merely guarded against).

## 2. Why the UI never talks to the network directly

Per [device-and-context.md](../05-personas/device-and-context.md), connectivity is routinely poor —
a screen that awaits a network response to render or to accept an action would violate
[navigation-model.md §6](../09-navigation/navigation-model.md#6-offline-rendering--never-an-indefinite-spinner)'s
"never an indefinite spinner" rule immediately. Every write and every read in this architecture
goes through the local Drift database first: a write completes (locally) before the Sync Engine
ever sees it, and a read is always answered from the local cache, live-updated via Drift's reactive
streams as the Sync Engine applies pulled changes. **The Sync Engine is invisible to the UI layer**
except through the sync-status indicators specified in [sync-ui.md](sync-ui.md) — no screen holds a
reference to the network client directly.

## 3. Ordering guarantees

Two independent ordering guarantees, one per direction:

- **Outbound:** the Sync Engine drains `outbound_queue` in the same dependency-ordered groups
  [sync-api.md §2](../11-api/sync-api.md#2-ordering--dependency-groups-not-raw-client-order)
  defines server-side (catalogue → customer → stock_movement → trading_day → sale → return),
  preserving creation order **within** each group. This is not a second, independently-invented
  ordering scheme — the client orders its batch this way specifically so the server-side grouping
  in [sync-api.md](../11-api/sync-api.md) is never doing more reordering work than necessary, and so
  a human reading the local queue sees operations in the same relative order the server will apply
  them.
- **Inbound:** [sync-api.md §6](../11-api/sync-api.md#6-pull--get-syncpull)'s per-entity-type cursor
  feed is applied to the local cache in the order received, per entity type, independently across
  types — there is no cross-type inbound ordering requirement, because a pulled `product` update and
  a pulled `sales` row from another device have no dependency on each other from the *reading*
  device's point of view (unlike the outbound direction, where a sale genuinely depends on its
  product already existing).

## 4. What "opportunistic, not scheduled" means concretely

Per this phase's founding rule, the Sync Engine is triggered by, in order of how often each actually
fires: (1) a connectivity-regained OS callback, (2) app foreground, (3) immediately after any local
write completes (an optimistic "try now, queue if it fails" attempt — most sales happen with at
least intermittent connectivity, so most operations never sit in `Queued` for long), and (4) a
coarse background timer as a backstop (also the mechanism that closes the Realtime-outage gap — see
[failure-scenarios.md](failure-scenarios.md)). There is no fixed polling interval that is the
*primary* mechanism; the timer exists only to catch what the other three miss.

## 5. Boundary with Phase 11

This document does not repeat [sync-api.md](../11-api/sync-api.md)'s batch envelope, per-operation
result shape, or the server's dependency-group definition — those are already fully specified there
and referenced, not restated. This document's job is everything on the client side of that contract:
the local write path, the queue, the trigger conditions, and how pulled data actually lands in a
UI-visible local cache.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Initial architecture: single local-write-path component diagram, outbound/inbound ordering guarantees, 4 trigger conditions, explicit boundary against Phase 11's server-side contract. |
