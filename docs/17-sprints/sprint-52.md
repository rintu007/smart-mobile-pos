# Sprint 52

> **Dates:** 2026-08-20 – 2026-08-20 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item)
> **Status:** Closed.

## Goal

`test-plan.md §3` had specifically named the client half of "Connectivity lost mid-batch" as needing
"a live server + fault-injecting proxy in front of it" — the one row in the whole failure-scenario
list with an infrastructure justification stated explicitly, not just implied. Checked directly,
following the exact pattern Sprints 50 and 51 already established (test the actual property, not the
literal fault-injection mechanism first assumed necessary): the property this scenario cares about —
an operation missing from an otherwise well-formed push response is left safely untouched, never
lost or corrupted — is entirely reproducible with a fake push function returning an incomplete
result set. No live server, no proxy, no severed connection required.

## What was found while writing the test, not assumed beforehand

**A third instance of the same doc-vs-code gap Sprints 50 and 51 both found.**
`failure-scenarios.md §1` describes this scenario as "operations not yet acknowledged return to
`FailedRetrying`." The real code (`SyncRepository._pushQueuedOperations`) does not do this: when an
operation's result is missing from the response, the loop simply does `continue` — no write happens
at all. A row that started `Queued` and never receives a result stays exactly `Queued`, never
explicitly becoming `FailedRetrying`. The practical guarantee the design cares about (nothing lost,
safely resent next cycle) holds regardless, via this simpler mechanism — but the specific wording
"return to FailedRetrying" describes a transition that has never actually happened in this codebase.

Sprint 50's own retrospective flagged this exact pattern — a design doc's claim about how something
works is not the same claim as a test proving it — as "recurred twice in two consecutive sprints...
worth naming as a pattern worth deliberately checking for elsewhere." This sprint is that check
paying off a third time, in the very next candidate row.

## Design decisions

1. **Two cases, matching Sprint 50's own shape for the same reason.** The first proves the base
   property (an operation missing from the response is left untouched while a present one is
   applied normally, within the same batch). The second proves the end-to-end recovery (the
   untouched operation is correctly resent, and succeeds, on the very next sync cycle) — distinct
   from the first because "left untouched" alone doesn't prove it isn't also silently abandoned.
2. **No new test infrastructure, deliberately.** `test-plan.md`'s own framing ("scheduling the retry
   itself after a real severed connection") described a literal fault-injection mechanism, not the
   property that actually needed proving. Sync-api.md §3's own contract already guarantees a
   *complete* response carries a verdict for every operation submitted — a response missing one is
   exactly what a real dropped connection would produce from the client's point of view, and
   simulating that shape directly is a faithful, much simpler test than actually severing a
   connection would be.
3. **Corrected `failure-scenarios.md §1`'s wording to match the real mechanism, not left as an
   approximation.** The same "found and corrected in the same pass" discipline Sprints 50/51 both
   applied.

## Capacity check

No estimate carried in the backlog — a same-day gap closure, not a planned backlog line.

## Reserved capacity

- [x] Defect capacity reserved: this closes a real, previously-named test gap (test-plan.md §3's
      "Connectivity lost mid-batch" client-half row), not new discretionary scope.

## Risks

None — purely additive test coverage plus a documentation wording correction; no production code
path changed (the `continue`-on-missing-result behaviour itself was already correct, just untested
and inaccurately described).

## Definition of Done

- [x] `apps/mobile/test/core/sync/sync_repository_test.dart` — new "a partial batch response" group,
      2 cases: an operation missing from the response left untouched while a present one applies
      normally, and that untouched operation correctly resent on the next cycle.
- [x] `docs/13-offline-sync/failure-scenarios.md §1` — the "Connectivity lost mid-batch" row
      corrected to describe the real mechanism (left untouched, not explicitly `FailedRetrying`).
- [x] `docs/13-offline-sync/test-plan.md §3` — the client-half row flipped from Deferred to Built.
- [x] `docs/14-testing/release-checklist.md §2` — the failure-scenarios row narrowed further (3 of
      10 scenarios now genuinely unverified, down from 4); row itself still unresolved.
- [x] Verified locally: `flutter analyze` clean; `flutter test` full suite green (258/258 — 256
      pre-existing + 2 new).
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-20:**

1. `flutter test test/core/sync/sync_repository_test.dart` — both new cases pass. ✅
2. `flutter analyze` — 0 issues. ✅
3. `flutter test` (full suite) — 258/258 (256 pre-existing + 2 new). ✅

No live-device or live-server verification needed — the property under test is a pure client-side
concern (how the queue's state machine responds to a given, already-parsed response shape), the same
class of test Sprints 50/51 both established as sufficient for their own scenarios.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) — the pattern first named in Sprint 50's
own retrospective ("worth naming... not just twice-coincidental") has now held a third time,
including on the one row this project's own documentation had explicitly flagged as needing
infrastructure that doesn't exist. Worth stating as a settled lesson rather than a recurring
surprise: **when a failure-scenario row's stated blocker is "needs infrastructure X," the first
real step is checking whether the actual guarantee can be exercised without X, before accepting the
row as blocked.** Of the original 9 unverified scenarios, only "Storage full" (genuinely unbuilt, no
code path to test at all) and "Token expired while queued" (genuinely needs the full Supabase CLI
stack — GoTrue token issuance can't be faked at the mobile-repository layer the way a push response
can) remain, alongside "Device clock wrong," which was always correctly classified as
proven-by-design rather than deferred.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-20 | Sprint 52: the client half of "Connectivity lost mid-batch" built (`sync_repository_test.dart`), closing a 4th of the 9 gaps test-plan.md §3 named — and found, for a third consecutive sprint, that a design doc's claimed mechanism (`failure-scenarios.md`'s "return to FailedRetrying") isn't literally what the code does; corrected. 258/258 mobile tests (256 pre-existing + 2 new), `flutter analyze` clean. |
