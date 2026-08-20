# Test Plan — Adversarial Sync Suite

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.7.0
> **Last updated:** 2026-08-21
> **Owner:** CTO / Principal Flutter Engineer
> **Approved by:** _pending_

The adversarial test suite this phase's charter demands — deliberately targeting the conditions
that "appear to work perfectly in every test on a good connection" and fail only under conditions
"hard to reproduce and easy to skip." This document specifies **what** must be tested and the
pass/fail criterion for each; **how** it runs (CI wiring, device farm, harness choice) is
[14-testing](../14-testing/README.md)'s implementation detail, one phase away.

---

## 1. Idempotent-replay tests

| Test | Setup | Assertion |
| --- | --- | --- |
| Full-queue double replay | A queue of ≥10 mixed operations (sales, returns, approvals, catalogue edits) applied once, then the **identical** queue applied a second time | Server state after the second pass is byte-for-byte identical to after the first — the concrete, automated version of [idempotency.md §3](idempotency.md#3-proof--replaying-the-entire-queue-twice-produces-identical-state)'s proof |
| Single-operation N-times replay | One `sale.create` resent 5 times in immediate succession (simulating a tight client retry bug) | Exactly one sale, one set of stock movements, regardless of N |
| Ambiguous-acknowledgement replay | A push whose response is deliberately dropped after the server has already committed | The client's next attempt (same key) returns the already-committed result; no duplicate is created |

## 2. Concurrent-composition tests

| Test | Setup | Assertion |
| --- | --- | --- |
| Two-device concurrent oversell | Two simulated offline devices each sell the last unit of the same product, then sync in both possible orders | Final balance is identical (`-1`) regardless of sync order — the automated form of [stock-ledger.md §4](../07-database/stock-ledger.md#4-worked-example--two-devices-selling-concurrently-offline) |
| N-device fuzzed interleaving | 5 simulated devices each generate a random sequence of opening/sale movements offline, synced in a randomised order across 100 runs | Final balance is identical across all 100 runs — a property-based/fuzz test proving order-independence isn't merely true for the two-device hand-worked case |
| Field-edit non-overlap merge | Two devices edit different fields of the same `customers` row offline | Both edits applied; no conflict surfaced — per [conflict-resolution.md §3](conflict-resolution.md#3-field-edit-collisions--merge-what-doesnt-overlap-ask-about-what-does) |
| Field-edit same-field collision | Two devices edit the *same* field of the same `customers` row to different values, offline | Neither value silently wins; a field-level conflict record is created, retrievable and matching the business-language wording in [conflict-resolution.md §3](conflict-resolution.md#3-field-edit-collisions--merge-what-doesnt-overlap-ask-about-what-does) |
| Creation collision | Two devices create a `customers` row with the same phone number, offline, then both sync | The second to arrive is rejected with `PHONE_ALREADY_ASSIGNED`; the first stands unmodified |

## 3. The 10 named failure scenarios — one test per row of [failure-scenarios.md §1](failure-scenarios.md#1-the-named-scenarios)

Each scenario in that table gets a dedicated adversarial test simulating the fault directly (killing
the app process mid-batch, force-rebooting the test device/emulator with a populated queue, severing
the network connection at a byte offset partway through a batch response, forcing a clock skew of
+36 hours, expiring a token server-side mid-queue, etc.) and asserting the **expected behaviour**
column from that table holds — this document does not repeat those expectations here, only points
at them as the test suite's ten required cases.

**Correction, Sprint 41 (backlog.md M4 item 6):** "one test per row" conflated three genuinely
different test venues, only discovered while actually building the suite against
[14-testing](../14-testing/README.md)'s real infrastructure. Reclassified here, per row:

| Scenario | Venue | Status |
| --- | --- | --- |
| Server rejects one item in a batch | Server — a real Postgres/`pushOperations` integration test, no new infra | **Built**, `apps/web/integration-tests/sync-failure-scenarios.test.ts` |
| Connectivity lost mid-batch | Server half: identical to idempotent-replay's "ambiguous-acknowledgement" case (§1) — already-committed operations stay committed on a retry. Client half: the actual property that matters (sync-api.md §3's "every operation gets its own verdict" contract; an operation missing from the response is left safely untouched, not lost or corrupted) is a pure client-side unit-testable concern — no live server or fault-injecting proxy actually needed, that framing conflated the literal fault-injection mechanism with what's being verified | Server half **built** (§1); client half **Built, Sprint 52** (`sync_repository_test.dart`'s "a partial batch response" group) |
| App killed mid-sync | Mobile-only (`outbound_queue`/Drift, app-process lifecycle) | **Built, Sprint 50.** No server code path involved — a `SyncRepository` test simulating a push call that throws mid-flight, proving the row is left untouched and safely resent by a fresh repository instance on the next cycle, the mobile equivalent of "app relaunched." Found and corrected a real doc/code gap while writing it: the client never persists a distinct `Syncing` status (state-machines.md's own dated correction). |
| Device rebooted with a full queue | Mobile-only, same reasoning | **Built, Sprint 50** — same test, same reasoning failure-scenarios.md §1 itself already gives for treating these two rows identically. |
| Schema version mismatch after an update | Mobile-only (Drift's own versioned-migration mechanism) | **Built, Sprint 51 (`migration_test.dart`) — and found a real, previously-undetected production bug in the same pass.** `Migrator.createTable` builds a table from its *current* Dart shape, not the shape it had when that call was originally written — a table created in one `onUpgrade` step and altered in a later one (`shop_settings_cache`, Sprint 37 creation + Sprint 39 column add) breaks with an unhandled duplicate-column error for any device jumping both steps in one update, permanently locking it out of its own local database. Fixed with a guarded `addColumn`; see [schema-local.md](../07-database/schema-local.md#schema-migration-safety--a-real-bug-found-sprint-51-not-a-hypothetical-rule) for the full account and the standing rule for future migrations. |
| Storage full | Mobile-only (on-device disk pressure), no server involvement whatsoever | **Built, Sprint 54** — `core/storage/device_storage_probe.dart` (unit-tested: threshold boundary, fail-open on a probe error) plus `HomeScreen`'s low-storage banner (widget-tested: shown/hidden per the probe's result) |
| Token expired while queued | Mobile-only — the decision logic (which error shape triggers a refresh-and-retry) is a pure function, unit-tested the same way `isDeviceRevokedError` already is; the actual GoTrue refresh call itself is trusted SDK behaviour, not re-proven against a real Auth server | **Built, Sprint 57** — `apps/mobile/test/core/network/api_client_test.dart`'s `isUnauthenticatedError` group |
| Device clock wrong by hours or days | Already proven by design in [clock-and-ordering.md §4](clock-and-ordering.md#4-what-this-means-for-a-device-with-a-badly-wrong-clock--the-failure-scenario-itself) | No code test needed |
| Same account on two devices | [failure-scenarios.md §1](failure-scenarios.md#1-the-named-scenarios) itself already resolves this as "not a failure at all" | Nothing to test |
| Queue older than server retention | [failure-scenarios.md §1](failure-scenarios.md#1-the-named-scenarios) itself already resolves this as "not applicable... no retention job exists" | Nothing to test |

**Corrected, Sprint 50 (cross-cutting fix, not a re-opening of backlog item 6):** two of the
mobile-only rows above ("App killed mid-sync," "Device rebooted with a full queue") turned out to
be buildable with the same `flutter test`/Drift infrastructure this suite already uses — no
`integration_test` package, toxiproxy, or physical device needed, since both scenarios are fully
reproducible by simulating an interrupted `SyncRepository.syncNow()` call against a real in-memory
database.

**Corrected further, Sprint 51:** "Schema version mismatch" turned out to be buildable the same way
— and writing it found a real, previously-undetected bug that would have permanently locked a real
device out of its own local database for a specific upgrade path (see the row above and
schema-local.md's own account).

**Corrected once more, Sprint 52:** the client half of "Connectivity lost mid-batch" — the one row
this document had specifically named as needing a live server + fault-injecting proxy — also turned
out not to need either. The actual client-side guarantee (an operation missing from an otherwise
well-formed response is left safely untouched) is exercised with a fake push function, the same
technique the two rows above already used; no real severed connection is needed to prove the code
handles a response shaped that way correctly.

**Corrected once more, Sprint 54:** "Storage full" built — real disk-space detection
(`disk_space_2`) plus the designed low-storage warning, both unit- and widget-tested. Of the 10
named scenarios, only **"Token expired while queued"** remains a genuinely unverified real gap,
needing the full local Supabase CLI stack (GoTrue token issuance/expiry) this project doesn't have
— named, not silently dropped, the same way Sprint 40 named the Realtime extension rather than
building a fake stand-in for it.

**Corrected once more, Sprint 57:** this row's own "needs the full Supabase CLI stack" reasoning
turned out not to hold either, the fifth time in a row this document's own infra-needed claims have
been checked directly and found not to (Sprints 50/51/52/54's rows, now this one). Investigation
found the real gap wasn't "no way to test this without a live Auth server" — it was that no
reactive refresh-and-retry code existed in the mobile client *at all*: `docs/11-api/authentication.md
§3`'s own text already claimed the client refreshes "not only reactively on a 401," but nothing did.
Built the missing piece (`api_client.dart`'s `onError` interceptor: one `refreshSession()` call, one
retry, on any `401 UNAUTHENTICATED`) and unit-tested the decision logic that drives it
(`isUnauthenticatedError`), the same seam-tested-not-mocked shape `isDeviceRevokedError` already
established for this exact file. The actual GoTrue refresh call itself remains trusted, untested SDK
behaviour — consistent with how this project already trusts `supabase_flutter`'s proactive-refresh
timer elsewhere, not a new standard being applied selectively.

## 4. Failure-injection tooling

Per this phase's own framing (failures "surface only under conditions hard to reproduce"), these
tests cannot rely on naturally occurring bad networks in a CI environment. The suite runs against a
**fault-injecting proxy** between the test client and a real (test) API instance, capable of:
dropping a response after the server commits (ambiguous-acknowledgement testing), severing a
connection at an arbitrary byte offset (mid-batch connectivity loss), delaying a response
indefinitely (timeout/backoff testing), and returning a scripted sequence of per-operation results
(partial-batch-failure testing) — the exact tool is a Phase 14/18 selection (a free/open-source
proxy such as `toxiproxy` is the leading candidate, confirmed at implementation time per this
documentation set's standing practice of not committing to unverified tooling specifics ahead of
need).

## 5. What "pass" means for this suite specifically

Per this phase's rule that security/correctness findings of this kind block release (mirroring
[Phase 12](../12-security/README.md)'s own stance): **every test in this document is a release
gate for the sync engine specifically, run in CI on every change touching
[sync-architecture.md](sync-architecture.md), [outbound-queue.md](outbound-queue.md), or
[conflict-resolution.md](conflict-resolution.md)'s implementation** — the same treatment
[tenant-isolation.md §3](../12-security/tenant-isolation.md#3-ci-enforcement--not-a-one-time-proof)
already established for the cross-tenant suite, applied here because the failure mode (silent data
loss or duplication) is exactly as invisible-until-it-happens as a tenant-isolation leak.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Idempotent-replay and concurrent-composition test cases specified with assertions; all 10 named failure scenarios mapped to dedicated adversarial tests; fault-injecting proxy approach specified; CI-gate status established matching Phase 12's precedent. |
| 0.2.0 | 2026-08-19 | Sprint 41 (backlog.md M4 item 6) built §1's three idempotent-replay cases and §2's 2-device-scale rows (all 4) plus the N-device fuzzed case (nightly-only) for real, against a real Postgres connection, no toxiproxy needed for any of it — replay/order-independence are server-observable properties. §2's N-device row corrected: no `adjustment` sync-push operation type exists, fuzzed across `opening`/`sale` only. §3 reclassified by actual test venue (server / mobile-only / needs the full Supabase stack / already-proven-no-test-needed) — "one test per row" conflated three different venues; only 1 of the 10 rows was actually buildable as a server integration test this sprint. |
| 0.3.0 | 2026-08-19 | Sprint 50 (cross-cutting fix, not a re-opening of item 6): §3's "App killed mid-sync"/"Device rebooted with a full queue" rows built — both testable with existing `flutter test` infrastructure alone, no new tooling needed, once actually attempted rather than assumed to need the same infra as the genuinely-deferred rows. Found and corrected a real doc/code gap in the same pass: the mobile client never persists the `Syncing` transitional status state-machines.md's Sync Item diagram specifies. |
| 0.4.0 | 2026-08-20 | Sprint 51 (cross-cutting fix): §3's "Schema version mismatch" row built (`migration_test.dart`, this project's first migration test) — and found a real, previously-undetected production bug in the same pass: a table created in one `onUpgrade` step and altered in a later one broke with an unhandled duplicate-column error for any device jumping both steps in one update, permanently losing access to its own local database. Fixed; full account in schema-local.md. |
| 0.5.0 | 2026-08-20 | Sprint 52 (cross-cutting fix): §3's "Connectivity lost mid-batch" client-half row built — it did not need the live server + fault-injecting proxy this document had specifically named for it; the actual client-side guarantee is exercised with a fake partial push response, no different in kind from Sprints 50/51's own technique. Found and corrected a third instance of the same doc-vs-code gap those two sprints found: failure-scenarios.md's "operations not yet acknowledged return to FailedRetrying" is not literally what the code does — an unacknowledged row is simply left untouched. |
| 0.6.0 | 2026-08-20 | Sprint 54 (cross-cutting fix): §3's "Storage full" row built — `disk_space_2`-backed free-disk-space detection plus the designed low-storage warning, both unit- and widget-tested. Of the 10 named failure scenarios, only "Token expired while queued" remains a genuinely unverified real gap. |
| 0.7.0 | 2026-08-21 | Sprint 57 (cross-cutting fix): §3's last row, "Token expired while queued," built — found this row's own "needs the full Supabase CLI stack" claim didn't hold either (the fifth such correction in this document), and that no reactive refresh-and-retry code existed in the mobile client at all despite `authentication.md §3` already implying it did. Built `api_client.dart`'s missing `onError` retry-once-after-refresh logic; unit-tested its decision function. All 10 named failure scenarios now have real coverage or are resolved-by-design/not-applicable. |
