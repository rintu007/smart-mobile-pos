# Phase 13 — Offline Synchronisation

> **Status:** 🔵 In review — all 10 deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO / Principal Flutter Engineer

## Charter

| | |
| --- | --- |
| **Objective** | Design the synchronisation engine that makes "never stop selling" true — and prove it does not lose, duplicate or corrupt data. |
| **Inputs** | Phases 06, 07 and 11 (all 🔵 In review). |

**This phase carries the product's core promise and its largest technical risk (R-02).** The
subsystem appears to work perfectly in every test on a good connection. Its failures surface only
under conditions that are hard to reproduce and easy to skip — which is precisely why they must be
designed for and tested deliberately rather than discovered.

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`sync-architecture.md`](sync-architecture.md) | Single local-write-path component model; outbound/inbound ordering guarantees; 4 trigger conditions | 🔵 In review |
| [`entity-classification.md`](entity-classification.md) | All 22 server tables + 2 local-only tables classified; corrected a Phase 07 misclassification found in the process | 🔵 In review |
| [`outbound-queue.md`](outbound-queue.md) | Durability via same-transaction writes; 4-tier backoff; two-condition poison-message handling, nothing silently dropped | 🔵 In review |
| [`inbound-sync.md`](inbound-sync.md) | Atomic cursor persistence; initial hydration prioritised, not a second endpoint; local history window decided | 🔵 In review |
| [`conflict-resolution.md`](conflict-resolution.md) | Creation vs. field-edit collisions; field-level merge with human resolution only on genuine disagreement | 🔵 In review |
| [`idempotency.md`](idempotency.md) | Formal induction proof + worked 3-operation batch: full-queue replay produces identical state | 🔵 In review |
| [`clock-and-ordering.md`](clock-and-ordering.md) | Device time = display-only; server time/arrival-order = authoritative, applied everywhere it matters | 🔵 In review |
| [`failure-scenarios.md`](failure-scenarios.md) | All 10 named scenarios resolved; Finding 1, the Realtime-outage gap, and storage-full all closed | 🔵 In review |
| [`sync-ui.md`](sync-ui.md) | Glanceable persistent indicator; Finding 3 resolved (not-found vs. not-synced-yet); banned-vocabulary list | 🔵 In review |
| [`test-plan.md`](test-plan.md) | Idempotent-replay and concurrent-composition test cases; all 10 failure scenarios mapped to adversarial tests | 🔵 In review |

## Entity classification

Every entity is assigned one class in `entity-classification.md`. The class determines its entire
sync behaviour. Nothing is unclassified.

| Class | Behaviour | Examples |
| --- | --- | --- |
| **Immutable event** | Client-created, append-only, never conflicts, deduplicated by key | Sale, stock movement, payment, audit entry |
| **Server-authoritative** | Pull-only on mobile; edits require connectivity | Product catalogue, prices, tax rates, users, permissions |
| **Client-editable** | Bidirectional; needs an explicit conflict policy | Customer details, shop settings, draft sales |
| **Derived** | Never synced; recomputed locally from events | Stock balances, report aggregates, customer totals |

## Exit criteria

- [x] Every entity is classified — [entity-classification.md §2](entity-classification.md#2-full-classification--every-table-no-exceptions)
      accounts for all 22 server tables plus 2 local-only tables, with a Phase 07 misclassification
      (categories/units/products) found and corrected in the process, not silently left standing.
- [x] Sales sync is proven idempotent: replaying the entire queue twice produces identical state —
      [idempotency.md §3](idempotency.md#3-proof--replaying-the-entire-queue-twice-produces-identical-state),
      a formal induction proof plus a worked 3-operation batch.
- [x] Concurrent offline stock changes across devices are proven to compose correctly —
      [stock-ledger.md](../07-database/stock-ledger.md)'s commutativity proof, restated as this
      phase's own test requirement in [test-plan.md §2](test-plan.md#2-concurrent-composition-tests)
      (including an N-device fuzzed extension beyond the original two-device hand-worked case).
- [x] Every failure scenario has a defined, tested behaviour — all 10 named scenarios resolved in
      [failure-scenarios.md §1](failure-scenarios.md#1-the-named-scenarios), each mapped to a
      dedicated adversarial test in [test-plan.md §3](test-plan.md#3-the-10-named-failure-scenarios--one-test-per-row-of-failure-scenariosmd-1).
      The three items earlier phases explicitly deferred here — [Finding 1](../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux),
      the Realtime-outage fallback, and storage-full — are all resolved in
      [failure-scenarios.md §§2–4](failure-scenarios.md#2-resolving-finding-1--provisional-approvals-rejected-after-the-fact).
- [x] Conflicts requiring human resolution are presented in business language, never technical —
      [conflict-resolution.md §3](conflict-resolution.md#3-field-edit-collisions--merge-what-doesnt-overlap-ask-about-what-does)
      resolves this exit criterion's own named example ("Two staff edited this customer's phone
      number") verbatim.
- [x] Sync progress and unsynced count are visible without the user seeking them out —
      [sync-ui.md §1](sync-ui.md#1-the-persistent-glanceable-indicator--never-something-you-have-to-go-looking-for),
      a persistent app-bar indicator, not a settings-page detail.
- [x] Sync never blocks the point of sale, never — restated and enforced structurally throughout:
      [sync-architecture.md §2](sync-architecture.md#2-why-the-ui-never-talks-to-the-network-directly)'s
      local-write-path-first design means no screen ever awaits a network response to render or
      accept an action.

All seven exit criteria are met by design and by proof. Per this documentation set's standing
practice, the adversarial suite in [test-plan.md](test-plan.md) still needs to actually **run**
against a real implementation — tracked forward to Phase 14/18 as its own CI gate, not assumed
green from a paper proof alone, the same honest distinction already drawn for Phase 11's load test
and Phase 12's cross-tenant suite.

## Rules

- **Clients send deltas, never absolute values, for anything countable.** "−1" composes; "= 4" collides.
- **Server time is authoritative for ordering.** Device clocks are wrong routinely — timezone
  changes, manual adjustment, dead batteries — and ordering money by an untrusted clock is a defect
  waiting to happen.
- **Sync is opportunistic, not scheduled.** Any connectivity triggers a drain attempt; the window
  may be seconds long.
- **A failed operation is never silently dropped.** It retries with backoff, then surfaces to the
  user with an action they can actually take.
- **Overselling is a business decision, not a merge conflict.** The system records what happened and
  alerts; it does not invent a reconciliation that has no correct answer.
