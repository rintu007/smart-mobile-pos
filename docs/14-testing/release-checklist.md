# Release Checklist

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.7.0
> **Last updated:** 2026-08-20
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

**Corrected Sprint 44 (backlog.md M4, cross-cutting closeout) — two rows below no longer matched what
was actually built, found while checking this checklist itself against Sprints 40–43's real
results, the same document-vs-code verification discipline those sprints established elsewhere.
Neither correction made the gate easier to satisfy — both made an already-unsatisfied box more
honestly unsatisfied, per §5's own no-partial-credit rule.**

**Re-checked Sprint 49 (not a numbered M4 item — a cross-cutting closeout, same shape as Sprint 44
itself), now that Sprints 45–48 have closed four more of Sprint 43's OWASP findings: one row
genuinely flips to satisfied (the nightly suite has now really fired on its own schedule, not just
locally), one row's wording is corrected to reflect what's actually still open (general rate
limiting is built; only the sign-in-specific gap remains), and the rest are re-confirmed unchanged
rather than assumed still accurate.**

**Updated Sprint 50 (not a numbered M4 item — a cross-cutting fix, not a re-opening of backlog item
6): the failure-scenarios row narrows further. "App killed mid-sync" and "Device rebooted with a
full queue" turned out to be buildable with existing `flutter test` infrastructure alone, once
actually attempted rather than assumed to need the same infra as the genuinely-deferred rows — both
now have real automated coverage. The row as a whole is still unresolved (5 of the 10 named
scenarios remain genuinely unverified), so this does not flip the row, the same way Sprint 49's
OWASP-row narrowing didn't flip that row either.**

**Updated further, Sprint 51 (cross-cutting fix): "Schema version mismatch" also turned out to be
buildable the same way, and writing it found a real, previously-undetected bug — a table created in
one migration step and altered in a later one broke with an unhandled duplicate-column error for any
device that jumped both steps in a single update, permanently losing access to its own local
database (see schema-local.md for the full account). Fixed. The failure-scenarios row narrows again
(4 of 10 now genuinely unverified, down from 5) but is still unresolved, so this does not flip it
either.**

**Updated once more, Sprint 52 (cross-cutting fix): the client half of "Connectivity lost
mid-batch" — the one row this document had specifically said needed a live server + fault-injecting
proxy — also turned out not to need either. Found and corrected a third instance of the same
doc-vs-code gap Sprints 50/51 both found: failure-scenarios.md's "operations not yet acknowledged
return to FailedRetrying" is not literally what the code does — an unacknowledged row is simply left
untouched, which still delivers the same practical safety guarantee. The failure-scenarios row
narrows again (3 of 10 now genuinely unverified, down from 4) but remains unresolved.**

**Updated once more, Sprint 54 (cross-cutting fix, founder-confirmed to build storage-full
handling): "Storage full" is now built — real free-disk-space detection (`disk_space_2`, a 100 MB
threshold, fails open on a probe error) plus the exact designed warning, shown persistently on
`HomeScreen`, both unit- and widget-tested. Of the 10 named failure scenarios, only "Token expired
while queued" remains genuinely unverified (needs the full local Supabase CLI stack). The row still
does not flip — one real gap is still one unresolved row — but it is now the narrowest it has been
across this entire run of sprints.**

| Item | Source | Status, as of 2026-08-20 |
| --- | --- | --- |
| ☐ All PR-gated CI checks green on the release commit | [ci-pipeline.md §2](ci-pipeline.md#2-pipeline-stages--every-pull-request) | ✅ Satisfied — confirmed on every merge through Sprint 43. |
| ☐ Nightly suite green on the release commit (or any failure explicitly triaged and accepted by the CTO, not silently ignored) | [ci-pipeline.md §3](ci-pipeline.md#3-nightly-pipeline) | ✅ **Satisfied, confirmed Sprint 49.** `nightly.yml` (Sprint 42) has now genuinely fired on its own `schedule` trigger (not just `workflow_dispatch`) and passed — verified directly against `gh run list --workflow=nightly.yml`, not assumed from the workflow file existing. Sprint 44's "not yet satisfiable" status is now stale; corrected here. |
| ☐ Cross-tenant isolation suite green — all **19** tables (corrected from 22, tenant-isolation.md §2's Sprint 40 finding); the Realtime extension is explicitly **out of pilot-ready scope** — it needs the full local Supabase CLI stack, named and deferred, not required for a pilot cohort | [tenant-isolation.md](../12-security/tenant-isolation.md) | ✅ Satisfied for the 19 real tables (76/76, every PR since Sprint 40). Realtime extension knowingly excluded from this gate, not silently dropped — a pilot's real risk from an unrevoked Realtime subscription is bounded (≤60 min token lifetime, identity-and-sessions.md §5), judged acceptable for a small, consenting cohort. |
| ☐ Server-testable and mobile-testable failure scenarios passing (**corrected from "all 10 offline failure scenarios passing"** — test-plan.md §3's Sprint 41 finding: only 1 of the 10 named scenarios in failure-scenarios.md §1 is a server-side, automatable case; **updated Sprints 50–54** — 5 more are mobile-testable with existing `flutter test` infrastructure, found once actually attempted; only 1 genuinely needs infrastructure this project doesn't have) | [failure-scenarios.md](../13-offline-sync/failure-scenarios.md) | ⬜ **Still not satisfied, but down to the narrowest gap this row has ever had — a real, material pilot risk, not a documentation nicety.** 6 of 10 scenarios now have real automated verification: the 1 server-testable case (`fast-integration`, every PR), "App killed mid-sync"/"Device rebooted with a full queue" (Sprint 50), "Schema version mismatch" (Sprint 51 — which found and fixed a real production bug in the process, see schema-local.md), the client half of "Connectivity lost mid-batch" (Sprint 52), and "Storage full" (Sprint 54 — real disk-space detection plus the designed warning, both unit- and widget-tested). Of the remaining 4: **2 are resolved with nothing to test** (already-not-a-failure/not-applicable, per failure-scenarios.md §1 itself), **1 is proven correct by design rather than by test** (a clock skewed by +36 hours, per clock-and-ordering.md §4), and **only 1 genuinely has zero verification on record** — a token expired mid-queue, needing the full local Supabase CLI stack. Every scenario a real pilot shop's Cashier is actually likely to hit day-to-day (a dead phone mid-shift, a reboot, an update across a schema-migrating release, a dropped connection mid-sale, a nearly-full device) now has real coverage; what remains is the one scenario needing infrastructure genuinely out of this project's current reach. |
| ☐ Manual test scripts MTS-01, MTS-02, MTS-03 executed and evidenced within the current release cycle | [manual-test-scripts.md](manual-test-scripts.md) | ⬜ **Not satisfied — founder-blocked.** No printer or reference low-end device owned yet (backlog.md M4 item 9, device-matrix.md §3). |
| ☐ **A full simulated trading day, on real hardware, with a real printer, evidenced** | MTS-03 — this phase's own explicit exit criterion, satisfied by name | ⬜ Same blocker as the row above. |
| ☐ OWASP checklist reviewed against the actual release build, **with no unresolved critical/high-severity finding** (corrected from bare "reviewed" — a review that finds and does not resolve a critical gap should not silently satisfy this gate just because the review itself happened) | [owasp-checklist.md](../12-security/owasp-checklist.md) | ⬜ **Not satisfied — narrowed, corrected Sprint 49.** The review happened (Sprint 43) and originally found two unresolved findings with real production risk. One is now scoped down to its actual remaining shape: general request rate limiting (mutating/read/sync-push) was built Sprint 45; what remains open is specifically **sign-in rate limiting**, which is architecturally unreachable from this codebase (sign-in never touches an `apps/web` Route Handler) and needs a Supabase-side platform configuration check this session cannot perform, not code. The other — **row-level security's likely-inert defence-in-depth layer** — is unchanged and still needs founder confirmation of the real production database role before any fix is attempted, since a wrong change risks a full outage. Both still need resolution — or a CTO-accepted, explicitly-documented risk exception, per this section's own §5 rule — before this box can honestly be checked. (The four other real gaps Sprint 43 named — mobile secure token storage, on-device database encryption, customer-erasure anonymisation, security alerting/monitoring — were not counted toward this row's "critical/high-severity" bar in the first place; the first three are now built anyway, Sprints 46–48.) |
| ☐ Pilot cohort is informed, consenting participants — not the general public | Ties to [privacy.md](../12-security/privacy.md)'s lawful-basis framing; a pilot's data handling is still subject to the same DPDPA-provisional obligations, not exempted by being "just a pilot" | ⬜ Not yet assessed — pilot recruitment (M5) hasn't started. |

**Honest bottom line, stated plainly per §5's no-partial-credit rule: this product is not pilot-ready
today** — unchanged since Sprint 44, but for a smaller and more honestly-described reason now. M4's
8 engineering backlog items are all done, and the release gate above still has **three** unresolved
rows (down from four since Sprint 44): the failure-scenarios row (1 of 10 named scenarios still
genuinely unverified, down from 9 as of Sprint 54), the OWASP review's two remaining findings (RLS,
sign-in rate limiting), and MTS execution — the last of which remains the only one that's
founder-blocked rather than open engineering or verification work. The nightly suite's first real
scheduled run, previously the fourth unresolved row, is now confirmed genuinely green.

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
| 0.3.0 | 2026-08-19 | Sprint 49 (cross-cutting closeout, not a numbered M4 item) — §2 re-checked against Sprints 45–48's real results. Nightly-suite row flips to satisfied: `nightly.yml` has now genuinely fired on its own `schedule` trigger and passed (confirmed via `gh run list`, not assumed). OWASP row's wording corrected: general rate limiting is built (Sprint 45), narrowing the remaining gap to sign-in specifically (architecturally unreachable, needs a Supabase-side check); RLS is unchanged. Bottom line still "not pilot-ready today," now three unresolved rows instead of four. |
| 0.4.0 | 2026-08-19 | Sprint 50 (cross-cutting fix, not a numbered M4 item, not a re-opening of item 6) — failure-scenarios row narrowed: "App killed mid-sync"/"Device rebooted with a full queue" built with existing `flutter test` infrastructure, no new tooling needed once actually attempted. Row itself still unresolved (5 of 10 scenarios remain genuinely unverified, down from 9). Bottom line unchanged: still not pilot-ready today, still three unresolved rows, each individually narrower than before. |
| 0.5.0 | 2026-08-20 | Sprint 51 (cross-cutting fix) — failure-scenarios row narrowed again: "Schema version mismatch" built (`migration_test.dart`), which found and fixed a real, previously-undetected production bug (a table created in one migration step and altered in a later one broke with an unhandled duplicate-column error for any device jumping both steps in one update — see schema-local.md). Row still unresolved (4 of 10 scenarios remain genuinely unverified, down from 5). Bottom line unchanged: still not pilot-ready today, still three unresolved rows. |
| 0.6.0 | 2026-08-20 | Sprint 52 (cross-cutting fix) — failure-scenarios row narrowed once more: the client half of "Connectivity lost mid-batch" built, found not to need the live server/fault-injecting proxy this document had specifically said it needed. Third instance of the same doc-vs-code gap Sprints 50/51 found (failure-scenarios.md's "return to FailedRetrying" is not literally what the code does). Row still unresolved (3 of 10 scenarios remain genuinely unverified, down from 4). Bottom line unchanged: still not pilot-ready today, still three unresolved rows. |
| 0.7.0 | 2026-08-20 | Sprint 54 (cross-cutting fix, founder-confirmed to build storage-full handling) — failure-scenarios row narrowed to its smallest gap yet: "Storage full" built (`disk_space_2`-backed detection, the designed warning banner, both unit- and widget-tested). Only "Token expired while queued" remains genuinely unverified (1 of 10, down from 3) — needs the full local Supabase CLI stack. Row still unresolved, so the bottom line is unchanged: still not pilot-ready today, still three unresolved rows, one of them now down to a single named gap. |
