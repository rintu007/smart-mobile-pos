# Release Checklist

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.2.0
> **Last updated:** 2026-08-19
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

**Corrected Sprint 44 (backlog.md M4, cross-cutting closeout) — two rows below no longer match what
was actually built, found while checking this checklist itself against Sprints 40–43's real
results, the same document-vs-code verification discipline those sprints established elsewhere.
Neither correction makes the gate easier to satisfy — both make an already-unsatisfied box more
honestly unsatisfied, per §5's own no-partial-credit rule.**

| Item | Source | Status, as of 2026-08-19 |
| --- | --- | --- |
| ☐ All PR-gated CI checks green on the release commit | [ci-pipeline.md §2](ci-pipeline.md#2-pipeline-stages--every-pull-request) | ✅ Satisfied — confirmed on every merge through Sprint 43. |
| ☐ Nightly suite green on the release commit (or any failure explicitly triaged and accepted by the CTO, not silently ignored) | [ci-pipeline.md §3](ci-pipeline.md#3-nightly-pipeline) | ⬜ **Not yet satisfiable.** `nightly.yml` (Sprint 42) has never actually run on its own schedule yet — its first scheduled fire is still pending as of this correction. Verified locally only (100/100 fuzzed runs). |
| ☐ Cross-tenant isolation suite green — all **19** tables (corrected from 22, tenant-isolation.md §2's Sprint 40 finding); the Realtime extension is explicitly **out of pilot-ready scope** — it needs the full local Supabase CLI stack, named and deferred, not required for a pilot cohort | [tenant-isolation.md](../12-security/tenant-isolation.md) | ✅ Satisfied for the 19 real tables (76/76, every PR since Sprint 40). Realtime extension knowingly excluded from this gate, not silently dropped — a pilot's real risk from an unrevoked Realtime subscription is bounded (≤60 min token lifetime, identity-and-sessions.md §5), judged acceptable for a small, consenting cohort. |
| ☐ Server-testable failure scenarios passing (**corrected from "all 10 offline failure scenarios passing"** — test-plan.md §3's Sprint 41 finding: only 1 of the 10 named scenarios in failure-scenarios.md §1 is actually a server-side, automatable case; the other 9 are mobile-app-process behaviours, need the full Supabase CLI stack, or are already resolved as "not applicable"/"not a failure" with nothing to test) | [failure-scenarios.md](../13-offline-sync/failure-scenarios.md) | ⬜ **Not satisfied — a real, material pilot risk, not a documentation nicety.** The 1 server-testable scenario passes (`fast-integration`, every PR). Of the other 9: **zero have any automated OR manual verification on record** — grepped every sprint doc and the implementation log; the closest is Sprint 16's own airplane-mode end-to-end proof, which verifies general offline-sync recovery, not the specific provoked scenarios (app killed mid-sync, device rebooted with a full queue, a clock skewed by +36 hours, a token expired mid-queue, etc.). A real pilot shop's Cashier *will* eventually have their phone die mid-shift or reboot with a full queue — this is exactly the "hard to reproduce, easy to skip" failure class Phase 13's own charter exists to catch, currently unverified by any mechanism. |
| ☐ Manual test scripts MTS-01, MTS-02, MTS-03 executed and evidenced within the current release cycle | [manual-test-scripts.md](manual-test-scripts.md) | ⬜ **Not satisfied — founder-blocked.** No printer or reference low-end device owned yet (backlog.md M4 item 9, device-matrix.md §3). |
| ☐ **A full simulated trading day, on real hardware, with a real printer, evidenced** | MTS-03 — this phase's own explicit exit criterion, satisfied by name | ⬜ Same blocker as the row above. |
| ☐ OWASP checklist reviewed against the actual release build, **with no unresolved critical/high-severity finding** (corrected from bare "reviewed" — a review that finds and does not resolve a critical gap should not silently satisfy this gate just because the review itself happened) | [owasp-checklist.md](../12-security/owasp-checklist.md) | ⬜ **Not satisfied.** The review happened (Sprint 43) and found two unresolved findings with real production risk: row-level security is very likely inert for all real traffic (owasp-checklist.md's top-flagged finding), and rate limiting on sign-in is entirely unimplemented. Both need resolution — or a CTO-accepted, explicitly-documented risk exception, per this section's own §5 rule — before this box can honestly be checked. |
| ☐ Pilot cohort is informed, consenting participants — not the general public | Ties to [privacy.md](../12-security/privacy.md)'s lawful-basis framing; a pilot's data handling is still subject to the same DPDPA-provisional obligations, not exempted by being "just a pilot" | ⬜ Not yet assessed — pilot recruitment (M5) hasn't started. |

**Honest bottom line, stated plainly per §5's no-partial-credit rule: this product is not pilot-ready
today.** M4's 8 engineering backlog items are all done, but the actual release gate above has four
unresolved rows, only one of which (MTS execution) was already known to be founder-blocked. The
other three — the nightly suite's first real run, the 9 unverified failure scenarios, and the two
unresolved OWASP findings — are new information from this same round of verification, not previously
tracked as open risks against this specific checklist.

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
| 0.2.0 | 2026-08-19 | Sprint 44 — §2 checked against Sprints 40–43's real results, the first time since this document was written. Two rows corrected to match reality (19 tables not 22, Realtime out of pilot scope; "server-testable failure scenarios" not "all 10," since 9 of 10 have zero automated *or* manual verification on record); the OWASP row's wording tightened so a review that finds unresolved critical findings can't silently satisfy the gate. Explicit status column added per row, concluding honestly: this product is not pilot-ready today, with four unresolved rows, three of them newly surfaced by this same correction pass. |
