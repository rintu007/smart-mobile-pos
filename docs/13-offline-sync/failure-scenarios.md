# Failure Scenarios

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.2.0
> **Last updated:** 2026-08-19
> **Owner:** CTO / Principal Flutter Engineer
> **Approved by:** _pending_

The exhaustive catalogue this phase's exit criterion names explicitly, each with a defined,
testable behaviour — plus the three items carried forward from earlier phases specifically to be
resolved here: [Finding 1](../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux)
(provisional approvals), the Realtime-outage fallback, and the storage-full behaviour, both from
[assumptions-and-dependencies.md](../04-srs/assumptions-and-dependencies.md).

---

## 1. The named scenarios

| Scenario | Expected behaviour |
| --- | --- |
| **App killed mid-sync** | **Corrected, Sprint 50** (test-plan.md §3's own row now Built, not Deferred): the in-flight batch's operations are durably persisted in `outbound_queue` (per [outbound-queue.md §1](outbound-queue.md#1-durability)), but not at a distinct `Syncing` status — `SyncRepository` never writes one (see [state-machines.md](../06-workflows/state-machines.md#sync-item)'s matching correction); a row selected for the current attempt simply stays `Queued`/`FailedRetrying` until a real server result is known. On next launch, the Sync Engine's normal queued/failed-retrying selection picks the row up exactly as it would have on the first attempt — no separate "detect a stale Syncing row" step needed — and resends it, safe by the server's own id-keyed upsert ([idempotency.md](idempotency.md)), never duplicated. Proven directly: `apps/mobile/test/core/sync/sync_repository_test.dart`'s "a push call interrupted mid-flight" group. |
| **Device rebooted with a full queue** | No different from an app kill, from the queue's perspective — durability is at the database-file level, unaffected by a reboot. Same corrected mechanism and same test coverage as the row above. |
| **Connectivity lost mid-batch** | Operations not yet acknowledged return to `FailedRetrying` ([state-machines.md](../06-workflows/state-machines.md#sync-item)); operations already acknowledged before the connection dropped stay `Synced` — the per-operation result shape in [sync-api.md §3](../11-api/sync-api.md#3-partial-failure-semantics--every-operation-gets-its-own-verdict) means a partial batch response (if any was received before the drop) is applied per-operation, not discarded wholesale. |
| **Server rejects one item in a batch** | The rejected operation moves to `Rejected` (terminal) or stays queued for retry, per [outbound-queue.md §5](outbound-queue.md#5-poison-message-handling)'s two-condition split; every other operation in the same batch is unaffected, per [sync-api.md §3](../11-api/sync-api.md#3-partial-failure-semantics--every-operation-gets-its-own-verdict). |
| **Device clock wrong by hours or days** | No financial or ordering impact — proven in [clock-and-ordering.md §4](clock-and-ordering.md#4-what-this-means-for-a-device-with-a-badly-wrong-clock--the-failure-scenario-itself); the only visible symptom is a cosmetically wrong local timestamp in a list/receipt preview until the next sync corrects the on-screen display context. |
| **Token expired while queued** | The Sync Engine's push/pull attempt receives `TOKEN_EXPIRED` ([error-catalogue.md](../11-api/error-catalogue.md)), silently refreshes via the refresh token ([identity-and-sessions.md](../12-security/identity-and-sessions.md)), and retries the same request — invisible to the Cashier, who is never interrupted mid-sale by this. |
| **Schema version mismatch after an update** | The local Drift schema migrates on app update using Drift's own versioned-migration mechanism before the Sync Engine runs at all — a mismatch never reaches the Sync Engine in a running app. If the *server's* API contract has moved to a new major version the installed app predates, [api-principles.md §1](../11-api/api-principles.md#1-versioning)'s "`v1` stays live" guarantee means the old app keeps working against `v1` until it is updated, rather than breaking on a forced-upgrade day. |
| **Storage full** | See §3 — resolved here, not deferred further. |
| **Same account on two devices** | Explicitly supported, not a failure at all — per [identity-and-sessions.md §4](../12-security/identity-and-sessions.md#4-multi-device--deliberately-supported-not-an-edge-case); each device has its own session, its own `outbound_queue`, and its own `trading_days` scope, so no cross-device queue interference exists by design. |
| **Queue older than server retention** | Not applicable to mutating operations — `idempotency_keys`/`sync_rejections` retention is indefinite ([schema-server.md](../07-database/schema-server.md), no retention job exists). The one bounded retention in this system is the local `stock_movements` **read cache** window ([inbound-sync.md §4](inbound-sync.md#4-bounded-local-history-restated-as-this-phases-own-decision)), which affects what a device can display, never what it can still successfully push. |

## 2. Resolving Finding 1 — provisional approvals rejected after the fact

Per [DR-017](../03-functional-requirements/business-rules.md)/[DR-018](../03-functional-requirements/business-rules.md),
a sale/return completed at the till on the strength of an offline Manager approval can be rejected
in full at sync if that Manager's role was revoked in the meantime. [offline-workflows.md](../06-workflows/offline-workflows.md)
correctly identified this as a business-process question, not a data one — **resolved as follows:**

- The sale/return itself is **not** retroactively un-completed or deleted — the customer has left,
  the receipt is printed, and per this phase's own rule ("the system records what happened and
  alerts; it does not invent a reconciliation that has no correct answer"), pretending it never
  happened would be a worse fiction than recording the anomaly honestly.
- The rejection is recorded in `sync_rejections` ([schema-server.md](../07-database/schema-server.md))
  against the original sale/return, and surfaced to the **Owner** (never the Cashier, who did
  nothing wrong and has no ability to act on it) as a named, reviewable anomaly:
  *"A discount on sale #A00042 was approved by Anil after his Manager access had already been
  removed. Review this sale."*
- **The actual business resolution (re-bill, write off, or accept) is an Owner decision this
  product surfaces and records, but does not automate** — per this phase's rule about not inventing
  reconciliations with no correct answer, and because it depends on real-world context (the
  customer relationship, the amount involved) this system cannot and should not decide on its own.
- This is the same `sync_rejections`-backed "needs your attention" mechanism already specified for
  the offline-oversell case in [inventory.md](../11-api/endpoints/inventory.md) — Finding 1 is
  resolved by routing it into a mechanism this documentation set already built, not a new one.

## 3. Resolving the storage-full open item

[assumptions-and-dependencies.md](../04-srs/assumptions-and-dependencies.md) left this genuinely
undesigned. **Resolved here, tiered:**

1. **Proactive pruning, before the device is ever actually full.** The local read caches with a
   defined retention window (`stock_movements`, per [inbound-sync.md §4](inbound-sync.md#4-bounded-local-history-restated-as-this-phases-own-decision))
   and cached product images are pruned automatically once free storage drops below a warning
   threshold — this is the one class of local data that can shrink without losing anything not
   already safely on the server.
2. **`outbound_queue` is never pruned to make room.** Unsynced operations are the one thing this
   entire phase exists to protect; they are never discarded to free space, even under storage
   pressure — restated from [outbound-queue.md §1](outbound-queue.md#1-durability)'s durability
   guarantee, which storage pressure does not get to override.
3. **If free storage is still critically low after step 1** (a genuinely full device, not merely an
   uncleaned cache), the product does **not** silently fail to record a sale. Per this phase's
   "never stop selling" objective being physically bounded by real disk space, the honest fallback
   is a clear, visible warning — *"Storage is almost full. Sales may stop saving reliably — free up
   space now."* — surfaced persistently (not a dismiss-and-forget toast) via
   [sync-ui.md](sync-ui.md), rather than the alternative of a sale silently failing to persist with
   no visible cause. A warned, informed Cashier who can still technically lose a sale to a genuinely
   full disk is a materially better outcome than a silent, undetected loss.

## 4. Resolving the Realtime-outage fallback

[assumptions-and-dependencies.md](../04-srs/assumptions-and-dependencies.md) flagged "no defined
periodic-pull fallback if Realtime is down for an extended period" as open. **Resolved:** the
background-timer trigger already specified in
[sync-architecture.md §4](sync-architecture.md#4-what-opportunistic-not-scheduled-means-concretely)
is that fallback — it exists specifically so an extended Realtime outage degrades to "this device
finds out about a change on its next background pull cycle" rather than "this device never finds
out." No new mechanism is introduced; this document simply confirms that trigger closes the
previously-open question, consistent with [realtime.md §4](../11-api/realtime.md#4-what-happens-when-a-message-is-missed)'s
framing that Realtime is a latency optimisation, never a correctness dependency.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | All 10 named failure scenarios given defined behaviour; Finding 1 resolved via sync_rejections-backed Owner review; storage-full resolved with a 3-tier response ending in an honest warning, never silent loss; Realtime-outage fallback confirmed closed by the existing background-timer trigger. |
| 0.2.0 | 2026-08-19 | Sprint 50 — "App killed mid-sync"/"Device rebooted with a full queue" rows corrected: the mobile client never writes a distinct `Syncing` status (found while writing the first test to actually exercise an interrupted push), so the real recovery mechanism is simpler than originally described — an interrupted row is left untouched and naturally re-selected next cycle, not detected as a distinct stale state. Both rows now have real, direct test coverage (`sync_repository_test.dart`), closing 2 of the 9 previously-unverified failure scenarios named in test-plan.md §3/release-checklist.md §2. |
