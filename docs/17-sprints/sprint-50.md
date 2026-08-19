# Sprint 50

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item, and not a re-opening of item 6 — item 6 itself is still fully done)
> **Status:** Closed.

## Goal

`test-plan.md §3`'s own Sprint 41 finding classified two of the nine still-unverified offline
failure scenarios ("App killed mid-sync," "Device rebooted with a full queue") as "Mobile-only" —
grouped alongside genuinely infrastructure-blocked rows (needing a mobile `integration_test` +
fault-injecting proxy, or the full local Supabase CLI stack) without actually being attempted.
Checked directly: both are fully reproducible with the same `flutter test`/Drift infrastructure this
project's mobile test suite already uses, no new tooling required — closing 2 of the 9 real gaps
`release-checklist.md §2` has been carrying since Sprint 44.

## What was found while actually writing the test, not assumed beforehand

**`SyncRepository` never writes the `Syncing` status `state-machines.md`'s own Sync Item diagram
specifies.** That diagram names a `Queued → Syncing` transition ("connectivity available, attempt
begins") specifically so a process kill mid-attempt leaves an observably distinct row behind. Real
code (`_pushQueuedOperations`) does something simpler: it selects `queued`/`failed_retrying` rows,
sends them in one batch, and only writes a new status once a real per-operation server result is
known. If the push call itself throws — a network drop, a killed process, a rebooted device — no
row's status is ever touched; the same `queued`/`failed_retrying` selection query picks it up again
on the very next sync attempt, no different from its first attempt. The `outbound_queue` table's own
docstring claimed all 5 state-machine values were live in practice; only 4 actually are.

This is not a correctness gap — the safety property `state-machines.md` exists to protect (an
interrupted attempt is never lost, never silently corrupted, never double-applied) holds regardless,
via a simpler real mechanism than the one documented: the row is left exactly as it was, and
duplicate-safety comes entirely from the server's own id-keyed upsert (`idempotency.md`), not a
client-side pre-retry check. But it is a real doc-vs-code gap that would have made a test written
against the *documented* mechanism (assert a row reaches `Syncing`, then simulate detecting it as
stale) assert something that never happens. Found before writing the wrong test, not after.

## Design decisions

1. **One test proves both scenarios, matching `failure-scenarios.md §1`'s own reasoning.** That
   document already states device-reboot is "no different from an app kill, from the queue's
   perspective — durability is at the database-file level, unaffected by a reboot." A `flutter test`
   simulating an interrupted `SyncRepository.syncNow()` call proves the mechanism both scenarios
   actually depend on; a second, separate "reboot" test would exercise identical code for no
   additional coverage.
2. **The interruption is simulated by making the push function throw, not by killing a real
   process.** `AppDatabase`'s durability is Drift/SQLite's own well-tested guarantee, not something
   this project needs to re-prove; what was actually unverified is the *application logic* — does
   an interrupted attempt leave the queue in a state the next cycle recovers from correctly? A
   throwing fake push function isolates exactly that question without needing a real device,
   process-kill tooling, or an `integration_test` harness.
3. **Two cases, not one: a never-attempted row and an already-retrying row.** The first proves the
   base case (a fresh `queued` row survives an interruption untouched). The second proves
   `attemptCount` isn't incorrectly bumped by an interruption that never reached the code path that
   increments it — a real, previously-unverified distinction, since only a *completed* rejected
   attempt increments `attemptCount` today.
4. **Corrected the documentation to describe the mechanism that's actually there, not the one that
   isn't.** `state-machines.md`, `failure-scenarios.md §1`, `test-plan.md §3`, and the
   `outbound_queue` table's own docstring all referenced or implied a `Syncing` write that doesn't
   happen — each corrected with the real mechanism and a pointer to the new test, the same
   "found while building, corrected in the same pass" pattern this project has used throughout.

## Capacity check

No estimate carried in the backlog — a same-day gap closure, not a planned backlog line, the same
shape Sprints 45–48 all took.

## Reserved capacity

- [x] Defect capacity reserved: this closes 2 of the real, previously-named gaps from
      `test-plan.md §3`/`release-checklist.md §2`, not new discretionary scope.

## Risks

None for production data — purely additive test coverage plus documentation corrections; no
production code path changed behaviour (the `_pushQueuedOperations` selection/update logic itself
is untouched, only its docstring and the design docs describing it).

## Definition of Done

- [x] `apps/mobile/test/core/sync/sync_repository_test.dart` — new "a push call interrupted
      mid-flight" group, 2 cases: a fresh `queued` row and an already-`failed_retrying` row, both
      proving the row survives an interrupted push untouched and is correctly resent next cycle.
- [x] `apps/mobile/lib/core/database/tables/outbound_queue.dart` — docstring corrected: `syncing`
      is a documented value, not a written one in current code.
- [x] `docs/06-workflows/state-machines.md` — Sync Item's `Queued → Syncing` transition annotated
      with the real mechanism, found and corrected in this sprint.
- [x] `docs/13-offline-sync/failure-scenarios.md §1` — the two affected rows corrected to describe
      the real recovery mechanism and cite the new test.
- [x] `docs/13-offline-sync/test-plan.md §3` — both rows flipped from Deferred to Built.
- [x] `docs/14-testing/release-checklist.md §2` — the failure-scenarios row narrowed (5 of 10 still
      genuinely unverified, down from 9); row itself still unresolved, so the overall "not
      pilot-ready today" bottom line is unchanged.
- [x] Verified locally: `flutter analyze` clean; `flutter test` full suite green with the 2 new
      cases (254/254 — 252 pre-existing + 2 new).
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-19:**

1. `flutter test test/core/sync/sync_repository_test.dart` — both new cases pass, confirming a
   queued/failed_retrying row survives an interrupted push untouched and is safely resent. ✅
2. `flutter analyze` — 0 issues. ✅
3. `flutter test` (full suite) — 254/254 (252 pre-existing + 2 new). ✅

No live-device verification needed — this scenario is, by its own nature, entirely reproducible
without a real device or process kill; the durability guarantee it depends on (Drift/SQLite writing
to a real file) is a well-established platform guarantee this project relies on elsewhere too
(data-protection.md §3's own reasoning), not something this sprint needed to re-prove.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: `test-plan.md §3`'s Sprint 41 classification
of these two rows as "Mobile-only" was correct about *where* the test would live, but conflated
"mobile-only" with "needs new infrastructure" — the two rows that actually needed a mobile
`integration_test` + fault-injecting proxy (the client half of connectivity-lost) or the full
Supabase CLI stack (token expiry) are a different, larger scope than these two, which needed neither.
A classification made under time pressure while building a different suite (Sprint 41's own
adversarial-suite work) is worth re-checking on its own once there's room to, rather than trusted
indefinitely — the same lesson Sprint 49 applied to `release-checklist.md` itself.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 50: "App killed mid-sync"/"Device rebooted with a full queue" failure scenarios built, closing 2 of the 9 real gaps named in test-plan.md §3. Found and corrected a real doc/code gap along the way: the mobile client never persists the `Syncing` transitional status state-machines.md's Sync Item diagram specifies — corrected there, in failure-scenarios.md §1, and in the outbound_queue table's own docstring. 254/254 mobile tests (252 pre-existing + 2 new), `flutter analyze` clean. |
