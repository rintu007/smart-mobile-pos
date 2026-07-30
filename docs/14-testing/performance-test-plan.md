# Performance Test Plan

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** QA Lead / Principal Flutter Engineer
> **Approved by:** _pending_

Every budget [success-metrics.md](../01-vision/success-metrics.md) already set, turned into an
**asserted** automated check — per this phase's exit criterion, "measured, not merely observed"
means a CI job fails the build when a budget is missed, not a dashboard a person has to remember to
look at.

---

## 1. Client-side budgets — asserted on the reference device

| Metric | Pilot budget | GA budget | Assertion mechanism |
| --- | --- | --- | --- |
| Barcode scan → item on screen (p95) | ≤ 800 ms | ≤ 500 ms | Automated integration test on [device-matrix.md](device-matrix.md)'s reference device, instrumented start/end timestamps, asserted against a fixed threshold — not eyeballed from a profiler |
| Product search → result (p95, 5,000-item catalogue) | ≤ 400 ms | ≤ 250 ms | Same mechanism, seeded test catalogue at exactly 5,000 rows |
| POS screen cold start (p95) | ≤ 3 s | ≤ 2 s | Automated cold-start instrumentation (app process launch to scan-ready state) |
| Sale commit (local, payment confirmed → receipt renders) | ≤ 300 ms | ≤ 200 ms | Automated, local-only (no network round-trip involved by design, per [sync-architecture.md §2](../13-offline-sync/sync-architecture.md#2-why-the-ui-never-talks-to-the-network-directly)) |

Every client-side row runs against the **physical** reference device
([device-matrix.md](device-matrix.md)), never an emulator and never a development machine, per
[success-metrics.md](../01-vision/success-metrics.md)'s own explicit instruction — a development
machine or CI-hosted emulator is meaningfully faster than the real target hardware and would let a
regression through undetected.

## 2. Sync budgets

| Metric | Pilot budget | GA budget | Assertion mechanism |
| --- | --- | --- | --- |
| Sync latency (connectivity restored → queue drained, p95) | ≤ 60 s | ≤ 30 s | Automated, within [offline-test-suite.md](offline-test-suite.md)'s harness — a queue of realistic size (a busy day's worth of operations, per [cost-model.md](../02-business-requirements/cost-model.md)'s volume assumptions) timed end to end |
| Duplicate sale rate | **0** | **0** | Already asserted by [idempotency.md](../13-offline-sync/idempotency.md)'s replay tests — a correctness assertion doubling as this performance metric's proof, not a separate measurement |
| Unresolved sync conflicts (per 1,000 operations) | ≤ 1 | ≤ 0.1 | Measured from the N-device fuzzed test in [test-plan.md §2](../13-offline-sync/test-plan.md#2-concurrent-composition-tests) — a rate computed from that suite's own output, not a separate instrument |

## 3. Server-side budgets

| Metric | Target | Assertion mechanism |
| --- | --- | --- |
| API p95 latency | ≤ 400 ms | Load-test tool (k6 or an equivalent free/open-source option, confirmed at Phase 18) against a staging deployment, asserted as a CI gate on release candidates |
| Connection pooling at 10× expected peak | Load-tested, no exhaustion | The test named but not executable in [rate-limiting.md §3](../11-api/rate-limiting.md#3-connection-pooling--the-r-07-mitigation-load-tested-before-ga) — **this is where it actually runs**, closing that forward-tracked item |

## 4. Why "asserted, not merely observed" is a meaningful distinction here

A profiler run once by an engineer, its output eyeballed and judged "looks fine," degrades silently
over many small regressions — exactly the failure mode this phase's rule about manual testing
("I tried it and it seemed fine is not a test result") already rejects for functional behaviour,
applied here to performance specifically. Every row above is a CI assertion with a hard numeric
threshold; a pull request that regresses `POS screen cold start` from 2.4 s to 2.6 s against a
2 s GA budget fails its build, rather than being noticed (if ever) in production weeks later.

## 5. What remains genuinely blocked on hardware

Per [device-matrix.md §3](device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly),
every row in §1 that says "measured on the reference device" cannot be truthfully asserted until
that physical device is acquired — this document's job is to have every assertion **specified and
ready to run** the moment it is, not to claim it has already run.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Every success-metrics.md performance budget turned into a named, asserted CI check; sync/server budgets included; explicit dependency on physical reference-device acquisition stated rather than assumed away. |
