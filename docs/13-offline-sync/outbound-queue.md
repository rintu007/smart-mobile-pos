# Outbound Queue

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** Principal Flutter Engineer
> **Approved by:** _pending_

Durability, ordering, batching, retry, backoff, and poison-message handling for `outbound_queue`
([schema-local.md](../07-database/schema-local.md)) — the local realisation of the Sync Item state
machine ([state-machines.md](../06-workflows/state-machines.md#sync-item)).

---

## 1. Durability

`outbound_queue` is a table in the same encrypted SQLite database
([data-protection.md §3](../12-security/data-protection.md#3-on-device-storage-encryption)) as every
other local entity, written in the **same transaction** as the entity it represents
([sync-architecture.md §1](sync-architecture.md#1-components)). A queued operation therefore
survives an app crash, an OS kill, or a device reboot exactly as durably as the sale/movement/return
it represents — there is no separate, less-durable queue mechanism (an in-memory list, a
lighter-weight key-value store) that could lose an operation the entity table itself retained.

## 2. Ordering and batching

Drained in the dependency-ordered groups fixed by
[sync-api.md §2](../11-api/sync-api.md#2-ordering--dependency-groups-not-raw-client-order), FIFO by
`created_at` within a group (local device time, display/ordering-within-this-device only — never
compared across devices, per [clock-and-ordering.md](clock-and-ordering.md)). Batch size caps at
[rate-limiting.md](../11-api/rate-limiting.md)'s 500-operation limit; a queue larger than that drains
across multiple push cycles, oldest group first, rather than one oversized request.

## 3. Retry and backoff

| Attempt | Backoff before retry |
| --- | --- |
| 1st retry | 5 seconds |
| 2nd retry | 30 seconds |
| 3rd retry | 2 minutes |
| 4th+ retry | 10 minutes, capped — not exponential-without-bound, since an operation stuck for hours needs to be visible to the user ([sync-ui.md](sync-ui.md)) well before it needs a longer wait between attempts |

Backoff resets to the first tier the moment connectivity is regained (a fresh network path is not
"the same failure," so it doesn't inherit the prior failure's wait) — but the `attempt_count` column
([schema-local.md](../07-database/schema-local.md)) is never reset, since it also drives the
poison-message threshold in §5.

**Per this phase's rule, a failed operation is never silently dropped** — every retry is visible in
`outbound_queue.status = 'failed_retrying'`, which [sync-ui.md](sync-ui.md) surfaces as part of the
unsynced count, not hidden internal state.

## 4. Retry safety — the FailedRetrying → Syncing transition

Per [state-machines.md](../06-workflows/state-machines.md#sync-item)'s own rule, a retry **must**
check the idempotency key against the server before assuming the prior attempt failed outright — an
ambiguous outcome (request sent, acknowledgement lost) is not a confirmed failure. Concretely: the
retry simply **resends the identical operation** (same `client_operation_id`, same payload) through
the normal push path; per [sync-api.md §5](../11-api/sync-api.md#5-duplicate-detection--replays-are-free),
the server's own idempotent-creation/state-transition mechanism makes this safe without the client
needing to first perform a separate "did this already land?" check — the resend *is* the check, by
construction. This is why [idempotency.md](idempotency.md) is a prerequisite this document leans on
rather than duplicates.

## 5. Poison-message handling

An operation is not retried indefinitely if the failure is not connectivity-shaped. Two distinct
poison conditions, handled differently:

| Condition | Detection | Handling |
| --- | --- | --- |
| **Server-side rejection** (a definite, non-transient answer — `RETURN_QUANTITY_EXCEEDS_SOLD`, `SALE_IMMUTABLE`, a permission revoked per Finding 1) | The server's per-operation result explicitly says `rejected` with a terminal error code, not `DEPENDENCY_NOT_FOUND` (which is retryable, per [sync-api.md §4](../11-api/sync-api.md#4-why-dependency_not_found-is-not-not_found)) | Transitions straight to `Rejected` ([state-machines.md](../06-workflows/state-machines.md#sync-item)), **not** retried again — surfaced to the user with the specific reason, per [BR-053](../02-business-requirements/business-requirements.md), never resubmitted blindly |
| **Repeated transient failure with no server answer at all** (network errors specifically, not rejections) | `attempt_count` exceeds a threshold (20 attempts) while never once reaching the server (distinguished from repeated `DEPENDENCY_NOT_FOUND` rejections, which **are** server answers and don't count toward this threshold) | Does **not** get discarded — per this phase's rule, nothing is silently dropped. Instead it is flagged in [sync-ui.md](sync-ui.md) as "stuck," inviting the user to check connectivity or contact support, while remaining queued and still eligible for automatic retry in the background |

**The one thing that never happens in this design:** an operation reaching a state where it is
simply forgotten. Every path above ends in either `Synced`, `Rejected` (with a visible reason), or
an indefinitely-retried-but-visibly-flagged `FailedRetrying` — matching
[state-machines.md](../06-workflows/state-machines.md#sync-item)'s exhaustive transition table
exactly, with no fifth, undocumented outcome.

## 6. Cleanup

A `Synced` row is deleted from `outbound_queue` promptly after confirmation — it is not retained
indefinitely as a local audit trail (the entity's own table, and the server's `audit_log`, already
serve that purpose). This keeps the queue's steady-state size proportional to *unsynced* work only,
which matters directly for the storage-pressure scenario in
[failure-scenarios.md](failure-scenarios.md).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Durability via same-transaction writes; dependency-ordered draining; 4-tier capped backoff; retry-is-the-idempotency-check design; two-condition poison-message handling with no silent-drop path. |
