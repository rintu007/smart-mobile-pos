# Failure Scenarios

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.6.0
> **Last updated:** 2026-08-20
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
| **Connectivity lost mid-batch** | **Corrected, Sprint 52** (test-plan.md §3's client-half row now Built, not Deferred): operations already acknowledged before the connection dropped stay `Synced`; operations not yet acknowledged are simply **left exactly as they were** — the real code (`SyncRepository._pushQueuedOperations`) does not explicitly transition an unacknowledged row to `FailedRetrying`, it just never writes anything for it (`if (result == null) continue`). A row that started `Queued` therefore stays `Queued`, not `FailedRetrying` — the same class of "the doc describes an explicit step the code doesn't take" gap Sprint 50 (the `Syncing` status) and Sprint 51 (the migration bug) both found. The practical guarantee still holds via this simpler mechanism: the per-operation result shape in [sync-api.md §3](../11-api/sync-api.md#3-partial-failure-semantics--every-operation-gets-its-own-verdict) means a partial batch response (if any was received before the drop) is applied per-operation, not discarded wholesale, and an operation left untouched is naturally resent on the very next sync cycle. Proven directly: `apps/mobile/test/core/sync/sync_repository_test.dart`'s "a partial batch response" group — no live server or fault-injecting proxy needed, since the client-side guarantee this row cares about is exercised by simulating a well-formed-but-incomplete push response, the same technique Sprint 50 used for a push call that fails outright. |
| **Server rejects one item in a batch** | The rejected operation moves to `Rejected` (terminal) or stays queued for retry, per [outbound-queue.md §5](outbound-queue.md#5-poison-message-handling)'s two-condition split; every other operation in the same batch is unaffected, per [sync-api.md §3](../11-api/sync-api.md#3-partial-failure-semantics--every-operation-gets-its-own-verdict). |
| **Device clock wrong by hours or days** | No financial or ordering impact — proven in [clock-and-ordering.md §4](clock-and-ordering.md#4-what-this-means-for-a-device-with-a-badly-wrong-clock--the-failure-scenario-itself); the only visible symptom is a cosmetically wrong local timestamp in a list/receipt preview until the next sync corrects the on-screen display context. |
| **Token expired while queued** | The Sync Engine's push/pull attempt receives `TOKEN_EXPIRED` ([error-catalogue.md](../11-api/error-catalogue.md)), silently refreshes via the refresh token ([identity-and-sessions.md](../12-security/identity-and-sessions.md)), and retries the same request — invisible to the Cashier, who is never interrupted mid-sale by this. |
| **Schema version mismatch after an update** | The local Drift schema migrates on app update using Drift's own versioned-migration mechanism before the Sync Engine runs at all — a mismatch never reaches the Sync Engine in a running app. If the *server's* API contract has moved to a new major version the installed app predates, [api-principles.md §1](../11-api/api-principles.md#1-versioning)'s "`v1` stays live" guarantee means the old app keeps working against `v1` until it is updated, rather than breaking on a forced-upgrade day. **Corrected, Sprint 51:** "the schema migrates" was true as an architectural claim but had never been tested against a real upgrade path — the first migration test found the migration itself could fail outright for a real upgrade jump (a table created in one step and altered in a later one, breaking any device that skipped being at the intermediate version), which would have looked exactly like an inaccessible local database, not a clean migration. Fixed; see [schema-local.md](../07-database/schema-local.md#schema-migration-safety--a-real-bug-found-sprint-51-not-a-hypothetical-rule) for the full account. |
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

1. **Proactive pruning, before the device is ever actually full.** The local read cache with a
   defined retention window (`stock_movements`, per [inbound-sync.md §4](inbound-sync.md#4-bounded-local-history-restated-as-this-phases-own-decision))
   is pruned back to that window automatically — this is the one class of local data that can
   shrink without losing anything not already safely on the server. **Built, Sprint 53** — see
   inbound-sync.md §4's own account. Corrected in the same pass: this paragraph originally said
   pruning happens "once free storage drops below a warning threshold" and named "cached product
   images" as a second thing to prune — neither survived contact with what's actually buildable.
   Product image caching was never built as a V1 feature at all (there is no image field anywhere
   in the local or server `products` schema), so there is nothing there to prune. And gating
   pruning on a storage-threshold check would have made it depend on tier 3's not-yet-built
   disk-space detection for no real benefit — there's no reason to keep more than the current +
   prior financial year around even when storage is plentiful, since older data stays retrievable
   from the server on demand. Pruning now runs unconditionally, every sync cycle, decoupled entirely
   from tier 3.
2. **`outbound_queue` is never pruned to make room.** Unsynced operations are the one thing this
   entire phase exists to protect; they are never discarded to free space, even under storage
   pressure — restated from [outbound-queue.md §1](outbound-queue.md#1-durability)'s durability
   guarantee, which storage pressure does not get to override. Confirmed still true after Sprint
   53's changes: `_pruneStaleStockMovements` only ever touches `stock_movements`, never
   `outbound_queue`.
3. **If free storage is still critically low after step 1** (a genuinely full device, not merely an
   uncleaned cache), the product does **not** silently fail to record a sale. Per this phase's
   "never stop selling" objective being physically bounded by real disk space, the honest fallback
   is a clear, visible warning — *"Storage is almost full. Sales may stop saving reliably — free up
   space now."* — surfaced persistently (not a dismiss-and-forget toast) via
   [sync-ui.md](sync-ui.md), rather than the alternative of a sale silently failing to persist with
   no visible cause. A warned, informed Cashier who can still technically lose a sale to a genuinely
   full disk is a materially better outcome than a silent, undetected loss. **Built, Sprint 54** —
   `core/storage/device_storage_probe.dart` (the `disk_space_2` package, chosen over the original,
   14-months-stale `disk_space`/`disk_space_plus` after checking pub.dev directly), a
   `criticallyLowStorageThresholdMb` of 100 MB (a deliberately conservative, round, dated decision —
   this app writes only small text/JSON rows, no media), fails open on a probe error (a false
   alarm shown to every Cashier is judged worse than one delayed real warning), and the exact
   warning copy above rendered persistently on `HomeScreen` — no dismiss action, matching "not a
   dismiss-and-forget toast" literally. `sync-ui.md` itself was never extended with this banner
   (that document describes the sync-status UI specifically, not app-wide device-health banners) —
   named here as a real, minor documentation gap rather than silently left implying a UI home that
   doesn't reflect it.

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
| 0.3.0 | 2026-08-20 | Sprint 51 — "Schema version mismatch after an update" row corrected: writing this project's first migration test found the migration itself could fail outright for a real upgrade path (a table created in one `onUpgrade` step, altered in a later one — any device jumping both at once hit an unhandled duplicate-column error, permanently losing access to its own local database). Fixed; full account in schema-local.md. Closes a 3rd of the 9 previously-unverified failure scenarios. |
| 0.4.0 | 2026-08-20 | Sprint 52 — "Connectivity lost mid-batch" row corrected: the client half doesn't need a live server/fault-injecting proxy after all — it's the same "the doc describes an explicit state transition the code doesn't actually take" gap found twice already this run of sprints. An unacknowledged operation is simply left untouched (not moved to `FailedRetrying`), proven directly with a fake partial push response. Closes a 4th of the 9 previously-unverified failure scenarios. |
| 0.5.0 | 2026-08-20 | Sprint 53 — §3's storage-full tier 1 (proactive pruning) built: `stock_movements` is now genuinely bounded to the current + prior financial year, both server-side (the pull) and locally (a new prune step). Corrected two stale claims in the same pass: pruning was never actually threshold-gated (now deliberately unconditional, decoupled from tier 3), and "cached product images" was never a real feature to prune in the first place. Tier 3 (disk-space detection + warning UI) remains real, separately-scoped future work. |
| 0.6.0 | 2026-08-20 | Sprint 54 — §3's storage-full tier 3 built: `disk_space_2`-backed low-storage detection (100 MB threshold, fails open on a probe error) and the exact designed warning, shown persistently on `HomeScreen`. Storage-full is now the 6th of the 10 named failure scenarios with real automated verification (unit + widget tests); only "Token expired while queued" remains a genuinely unverified real gap. |
