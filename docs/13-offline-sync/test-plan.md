# Test Plan — Adversarial Sync Suite

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
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
| N-device fuzzed interleaving | 5 simulated devices each generate a random sequence of opening/sale/adjustment movements offline, synced in a randomised order across 100 runs | Final balance is identical across all 100 runs — a property-based/fuzz test proving order-independence isn't merely true for the two-device hand-worked case |
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
