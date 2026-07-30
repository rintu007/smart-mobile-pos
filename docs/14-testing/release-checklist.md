# Release Checklist

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** QA Lead / CTO
> **Approved by:** _pending_

Everything required before a build reaches a real shop — the single assembly point for every gate
this phase (and Phases 11–13) has already specified. Nothing new is defined here; this is the
checklist a release manager actually reads.

---

## 1. Two tiers, not one — pilot vs. commercial launch

Per [OD-02](../01-vision/open-decisions.md)'s already-established distinction (free tiers for
development/pilot, a budgeted paid tier at commercial launch), this checklist has two gates, not
one — a small, consenting pilot cohort of real shops is not held to the identical bar as a public
commercial launch, and conflating the two would either block a valuable early pilot unnecessarily
or under-protect a paying customer base. Both are stated explicitly so neither is assumed silently.

## 2. Pilot-ready checklist

| Item | Source |
| --- | --- |
| ☐ All PR-gated CI checks green on the release commit | [ci-pipeline.md §2](ci-pipeline.md#2-pipeline-stages--every-pull-request) |
| ☐ Nightly suite green on the release commit (or any failure explicitly triaged and accepted by the CTO, not silently ignored) | [ci-pipeline.md §3](ci-pipeline.md#3-nightly-pipeline) |
| ☐ Cross-tenant isolation suite green — all 22 tables plus the Realtime extension | [tenant-isolation.md](../12-security/tenant-isolation.md) |
| ☐ All 10 offline failure scenarios passing | [failure-scenarios.md](../13-offline-sync/failure-scenarios.md) |
| ☐ Manual test scripts MTS-01, MTS-02, MTS-03 executed and evidenced within the current release cycle | [manual-test-scripts.md](manual-test-scripts.md) |
| ☐ **A full simulated trading day, on real hardware, with a real printer, evidenced** | MTS-03 — this phase's own explicit exit criterion, satisfied by name |
| ☐ OWASP checklist reviewed against the actual release build, not just the design | [owasp-checklist.md](../12-security/owasp-checklist.md) |
| ☐ Pilot cohort is informed, consenting participants — not the general public | Ties to [privacy.md](../12-security/privacy.md)'s lawful-basis framing; a pilot's data handling is still subject to the same DPDPA-provisional obligations, not exempted by being "just a pilot" |

## 3. Commercial-launch-ready checklist — pilot-ready, plus:

| Item | Source |
| --- | --- |
| ☐ 10× connection-pool load test executed and passed | [rate-limiting.md §3](../11-api/rate-limiting.md#3-connection-pooling--the-r-07-mitigation-load-tested-before-ga), closed via [performance-test-plan.md §3](performance-test-plan.md#3-server-side-budgets) |
| ☐ All client performance budgets asserted on the physical reference device | [performance-test-plan.md §1](performance-test-plan.md#1-client-side-budgets--asserted-on-the-reference-device) — requires [device-matrix.md](device-matrix.md)'s hardware to actually be in hand |
| ☐ OD-01 (launch market) confirmed, not provisional | [open-decisions.md](../01-vision/open-decisions.md) |
| ☐ GST-practitioner review of all tax/regulatory content complete | Standing cross-phase item, tracked since Phase 02 |
| ☐ Privacy/legal review of [privacy.md](../12-security/privacy.md)'s DPDPA-provisional content complete | Standing cross-phase item, tracked since Phase 12 |
| ☐ OD-02's hosting-budget ceiling set and a paid production tier actually provisioned | [open-decisions.md](../01-vision/open-decisions.md) |
| ☐ Backup/point-in-time-recovery tier decided and provisioned | [incident-response.md §4](../12-security/incident-response.md#4-recovery) |
| ☐ Secrets rotated onto production-specific values, never reusing development/pilot secrets | [secrets-management.md §4](../12-security/secrets-management.md#4-rotation) |

## 4. What this checklist deliberately does not gate on

Persona validation against real shop interviews ([Phase 05](../05-personas/README.md)'s own
acknowledged gap) and a fully rehearsed incident-response runbook with named on-call staff
([incident-response.md §5](../12-security/incident-response.md#5-what-this-document-does-not-build))
are valuable but are not release gates for either tier — the former because product-market
validation is an ongoing pilot activity this checklist's *purpose* is to enable, not a precondition
for running it; the latter because it is sized to a team that exists once there is one beyond the
founder, not invented in the abstract for a launch that doesn't yet need it.

## 5. Who signs off

Per this phase's rule that security findings block release with no exceptions: the CTO is the
release approver for both tiers, and **any single unresolved item in §2 blocks a pilot release; any
single unresolved item in §3 blocks a commercial-launch release** — there is no partial-credit
release, consistent with [Definition of Done](../00-governance/definition-of-done.md)'s standing
"100% or not counted as delivered" stance applied here to releases rather than modules.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Two-tier checklist (pilot vs. commercial launch) assembled from every gate specified across Phases 11–14; explicit non-gating items stated; single-approver, no-partial-credit sign-off rule. |
