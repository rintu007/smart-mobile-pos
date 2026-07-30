# Phase 14 — Testing Strategy

> **Status:** 🔵 In review — all 9 deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** QA Lead / CTO

## Charter

| | |
| --- | --- |
| **Objective** | Define what we test, at which level, on which devices, and what evidence is required before a release. |
| **Inputs** | Phases 03, 12 and 13 (all 🔵 In review). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`test-strategy.md`](test-strategy.md) | Full 26-rule DR traceability table; 90%-on-domain-logic coverage target; property-based testing scope | 🔵 In review |
| [`test-pyramid.md`](test-pyramid.md) | 60/20/15/5 proportions justified against this project's own risk profile, not a generic ratio | 🔵 In review |
| [`device-matrix.md`](device-matrix.md) | Reference-device selection criteria; physical acquisition flagged as a founder action | 🔵 In review |
| [`offline-test-suite.md`](offline-test-suite.md) | CI wiring for Phase 13's adversarial suite — PR-vs-nightly split by cost, not importance | 🔵 In review |
| [`security-test-plan.md`](security-test-plan.md) | Execution plan for Phase 12's 4 control areas; fixture-based self-test for the SQL-injection lint rule | 🔵 In review |
| [`performance-test-plan.md`](performance-test-plan.md) | Every success-metrics.md budget turned into an asserted CI check | 🔵 In review |
| [`manual-test-scripts.md`](manual-test-scripts.md) | 3 scripted suites: printer, scanning, full real-hardware trading day, each with evidence requirements | 🔵 In review |
| [`ci-pipeline.md`](ci-pipeline.md) | 3-tier pipeline (PR/nightly/release-candidate) sized against the ≤10-min budget | 🔵 In review |
| [`release-checklist.md`](release-checklist.md) | Two-tier (pilot vs. commercial-launch) checklist assembled from every prior gate | 🔵 In review |

## Exit criteria

- [x] Every business rule from Phase 03 maps to at least one automated test —
      [test-strategy.md §1](test-strategy.md#1-business-rule-traceability--the-exit-criterion-made-checkable),
      all 26 DR-NNN rules, each named individually.
- [~] The reference low-end device is named and physically available — **named by concrete
      selection criteria**, not a specific model (deliberately, per
      [device-matrix.md §2](device-matrix.md#2-reference-low-end-device--selection-criteria-named-concretely)'s
      fast-moving-market reasoning); **physical acquisition is a founder action**, tracked like
      OD-06 rather than claimed done.
- [x] Cross-tenant isolation tests run on every migration, automatically —
      [ci-pipeline.md §2](ci-pipeline.md#2-pipeline-stages--every-pull-request), PR-gated, not
      merely nightly.
- [x] The offline adversarial suite runs in CI, not only by hand —
      [offline-test-suite.md](offline-test-suite.md)'s full PR/nightly placement.
- [x] Performance budgets are asserted, not merely observed —
      [performance-test-plan.md](performance-test-plan.md), every [success-metrics.md](../01-vision/success-metrics.md)
      figure turned into a hard CI threshold.
- [x] The release checklist includes a full simulated trading day on real hardware with a real
      printer — [manual-test-scripts.md — MTS-03](manual-test-scripts.md#mts-03--a-full-simulated-trading-day-on-real-hardware-with-a-real-printer),
      named explicitly in [release-checklist.md §2](release-checklist.md#2-pilot-ready-checklist).

Five of six exit criteria are fully closed. The reference-device criterion is closed **as far as
documentation can close it** — the physical purchase itself is outside any phase's ability to
execute, the same honest treatment already given to OD-06 (time capacity) and every other
founder-only action this documentation set has surfaced rather than silently assumed.

**A cross-phase inconsistency was found and corrected while producing this phase's traceability
table:** [audit-logging.md](../12-security/audit-logging.md) had understated DR-025's requirement
(logging only adjustment stock movements, not every movement) — corrected in place, not merely
footnoted here.

## Rules

- **Business logic is tested exhaustively, including failure branches.** Interface tests cover the
  state matrix. We do not chase a global coverage percentage — 90% branch coverage on domain logic
  is worth more than 90% overall achieved by testing getters.
- **Every defect found in the field gets a regression test before it gets a fix.** Otherwise it
  returns.
- **Money and stock calculations get property-based tests**, not only worked examples. Hand-picked
  examples test the cases we already thought of, which are the cases we already got right.
- Manual testing is scripted and evidenced. "I tried it and it seemed fine" is not a test result.
