# Release Checklist

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.15.0
> **Last updated:** 2026-08-21
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

**Flips, Sprint 57 (cross-cutting fix): "Token expired while queued" is built.** This row's own
"needs the full Supabase CLI stack" reasoning turned out not to hold either — the fifth time in this
document's own sprint-by-sprint history that an infra-needed excuse was checked directly and found
not to. The real gap was that no reactive refresh-and-retry code existed in the mobile client at
all: `docs/11-api/authentication.md §3` already implied both proactive and reactive refresh existed,
but only the proactive half (the Supabase SDK's own background timer) did. Built the missing
`api_client.dart` interceptor (one `refreshSession()` call, one retry, on any `401 UNAUTHENTICATED`
— no distinct `TOKEN_EXPIRED` code was ever implementable server-side, corrected in
`error-catalogue.md`); unit-tested the decision logic that drives it. **All 10 named failure
scenarios now have real coverage or are resolved-by-design/not-applicable — this row flips to
satisfied.**

**Corrected, Sprint 58 — a real finding fell through a crack between two documents.**
`owasp-checklist.md`'s own "4 real gaps remain" list has always named **Android release signing**
(M8 — the release build signs with the debug keystore) as a real, unresolved, founder-blocked
finding, alongside RLS and sign-in rate limiting. It was never carried into this checklist's OWASP
row at all — neither counted among the row's "critical/high-severity" findings nor named in the
parenthetical listing the other, lower-severity gaps. Investigated directly rather than assumed
non-critical: `cd-workflows.md §2`'s own designed distribution path for **pilot** builds specifically
is Google Play Console's **Internal Testing track**, which requires a real upload key — a
debug-signed build cannot reach even a pilot cohort through the mechanism this project's own docs
already designed for it. This is a pilot-ready blocker, not only a commercial-launch one. Also found
while checking this: the entire build→sign→upload pipeline `cd-workflows.md §2` describes
(`release-candidate.yml`) was never actually built — no such workflow file exists in
`.github/workflows/`, the same "designed but not built" gap Sprint 55/PR #79 already found and
named for this same document's §1 (the RLS-SQL deployment path). Corrected in both documents; added
as a new row below rather than folded into the OWASP row, since it's really two compounding gaps
(a missing credential, and a missing pipeline to use it) rather than one.

| Item | Source | Status, as of 2026-08-21 |
| --- | --- | --- |
| ☐ All PR-gated CI checks green on the release commit | [ci-pipeline.md §2](ci-pipeline.md#2-pipeline-stages--every-pull-request) | ✅ Satisfied — confirmed on every merge through Sprint 43. |
| ☐ Nightly suite green on the release commit (or any failure explicitly triaged and accepted by the CTO, not silently ignored) | [ci-pipeline.md §3](ci-pipeline.md#3-nightly-pipeline) | ✅ **Satisfied, confirmed Sprint 49.** `nightly.yml` (Sprint 42) has now genuinely fired on its own `schedule` trigger (not just `workflow_dispatch`) and passed — verified directly against `gh run list --workflow=nightly.yml`, not assumed from the workflow file existing. Sprint 44's "not yet satisfiable" status is now stale; corrected here. |
| ☐ Cross-tenant isolation suite green — all **19** tables (corrected from 22, tenant-isolation.md §2's Sprint 40 finding); the Realtime extension is explicitly **out of pilot-ready scope** — it needs the full local Supabase CLI stack, named and deferred, not required for a pilot cohort | [tenant-isolation.md](../12-security/tenant-isolation.md) | ✅ Satisfied for the 19 real tables (76/76, every PR since Sprint 40). Realtime extension knowingly excluded from this gate, not silently dropped — a pilot's real risk from an unrevoked Realtime subscription is bounded (≤60 min token lifetime, identity-and-sessions.md §5), judged acceptable for a small, consenting cohort. |
| ☐ Server-testable and mobile-testable failure scenarios passing (**corrected from "all 10 offline failure scenarios passing"** — test-plan.md §3's Sprint 41 finding: only 1 of the 10 named scenarios in failure-scenarios.md §1 is a server-side, automatable case; **updated Sprints 50–54** — 5 more are mobile-testable with existing `flutter test` infrastructure, found once actually attempted; **built in full, Sprint 57**) | [failure-scenarios.md](../13-offline-sync/failure-scenarios.md) | ✅ **Satisfied, Sprint 57.** All 10 named scenarios now have real coverage or are resolved-by-design/not-applicable: 7 with real automated verification (the 1 server-testable case, "App killed mid-sync"/"Device rebooted with a full queue"/Sprint 50, "Schema version mismatch"/Sprint 51, the client half of "Connectivity lost mid-batch"/Sprint 52, "Storage full"/Sprint 54, and "Token expired while queued"/Sprint 57), 2 resolved with nothing to test (already-not-a-failure/not-applicable, per failure-scenarios.md §1 itself), and 1 proven correct by design (a clock skewed by +36 hours, per clock-and-ordering.md §4). |
| ☐ Manual test scripts MTS-01, MTS-02, MTS-03 executed and evidenced within the current release cycle | [manual-test-scripts.md](manual-test-scripts.md) | ⬜ **Not satisfied — founder-blocked.** No printer or reference low-end device owned yet (backlog.md M4 item 9, device-matrix.md §3). |
| ☐ **A full simulated trading day, on real hardware, with a real printer, evidenced** | MTS-03 — this phase's own explicit exit criterion, satisfied by name | ⬜ Same blocker as the row above. |
| ☐ OWASP checklist reviewed against the actual release build, **with no unresolved critical/high-severity finding** (corrected from bare "reviewed" — a review that finds and does not resolve a critical gap should not silently satisfy this gate just because the review itself happened) | [owasp-checklist.md](../12-security/owasp-checklist.md) | ⬜ **Not satisfied — narrowed, corrected Sprint 49, corrected again Sprints 58/59.** The review happened (Sprint 43) and originally found two unresolved findings with real production risk (RLS, sign-in rate limiting) — see [error-catalogue.md](../11-api/error-catalogue.md)'s own sibling narrowing for rate limiting generally, since fixed Sprint 45 for every class but sign-in. **A third finding, Android release signing (M8), is corrected onto this row Sprint 58** — it was always in `owasp-checklist.md`'s own "4 real gaps remain" list but had never been threaded into this checklist at all, an omission found and fixed in the same pass the new distribution-pipeline row below was added. General rate limiting (mutating/read/sync-push) was built Sprint 45; what remains open on the server side is specifically **sign-in rate limiting**, architecturally unreachable from this codebase (sign-in never touches an `apps/web` Route Handler) and needing a Supabase-side platform configuration check this session cannot perform, not code — **Sprint 64 built the client-side half instead** (`SignInController`'s exponential cooldown on repeated failed attempts, resetting on success), real defense-in-depth that narrows but doesn't close this finding, since the server-side control is what actually stops a distributed or multi-device attack. **Row-level security's likely-inert defence-in-depth layer** grew a second, more severe dimension Sprint 59: beyond needing founder confirmation of the real production database role, this session found no documentary confirmation that `supabase/sql/017_rls_sale_line_items_sale_payments.sql`, `018_rls_return_line_items.sql`, or `019_rls_devices.sql` were ever actually applied to the real production database at all — see `owasp-checklist.md`'s finding #1 and `cd-workflows.md §1`'s own corrected account for the full reasoning. Confirming this for those three files is now a precondition for the FORCE/role question, not a parallel, equally-weighted concern. **Sprint 62 added a ready-to-run diagnostic for both this and the FORCE/role question in one pass** — [supabase/sql/diagnostics/check_rls_status.sql](../../supabase/sql/diagnostics/check_rls_status.sql), a read-only script the founder can paste directly into the Supabase Dashboard's SQL Editor. **Android release signing** needs real, founder-provisioned production signing credentials this session cannot generate. All three need resolution — or a CTO-accepted, explicitly-documented risk exception, per this section's own §5 rule — before this box can honestly be checked. (Security alerting/monitoring (A09) remains unbuilt too, consistent with `incident-response.md`'s own already-stated Phase 18 deferral, but was never counted toward this row's severity bar, the same as before; mobile secure token storage, on-device database encryption, and customer-erasure anonymisation are all built, Sprints 46–48.) |
| ☐ A properly-signed (non-debug) release APK exists and can be sideloaded directly onto a pilot shop's device (**narrowed from "Google Play Console's Internal Testing track," Sprint 61** — see `cd-workflows.md §2`'s own correction: Play Console is this project's designed mechanism for scaling *past* founder-personal visits, not a requirement for the specific 2–3-shop, founder-visited first pilot `pilot-plan.md` actually describes) | [cd-workflows.md §2](../15-github-project/cd-workflows.md#2-android-build-signing-and-distribution), [pilot-plan.md](../16-milestones/pilot-plan.md) | ⬜ **Narrowed twice — Sprint 61, then Sprint 63.** Sprint 61 found the actual requirement was smaller than Sprint 58 first framed it: a real, founder-provisioned signing keystore, then direct sideload during the founder's own day-one visit — no CI pipeline, GitHub secret, or Play Console access required for *this* box. **Sprint 63 closed the code side of that entirely**: `apps/mobile/android/app/build.gradle.kts` now reads real signing credentials from a gitignored `key.properties` if present (`apps/mobile/android/key.properties.example` names the exact `keytool` command and the four values needed), falling back to the debug keystore unchanged when absent — verified with a clean `flutter build apk --debug`. Still not satisfied — this session cannot generate a real production keystore — but the founder's own remaining task is now purely "run one `keytool` command and fill in one properties file," with zero code work left. |
| ☐ Pilot cohort is informed, consenting participants — not the general public | Ties to [privacy.md](../12-security/privacy.md)'s lawful-basis framing; a pilot's data handling is still subject to the same DPDPA-provisional obligations, not exempted by being "just a pilot" | ⬜ Not yet assessed — pilot recruitment (M5) hasn't started. |

**Honest bottom line, stated plainly per §5's no-partial-credit rule: this product is not pilot-ready
today** — unchanged since Sprint 44. M4's numbered backlog items **1–8** are done (item 9, MTS
execution, is a founder action, never counted as engineering — a Sprint 57 edit to this line wrongly
said all 9 were "engineering backlog items... done"; corrected here, Sprint 58).

**Row count, stated precisely (corrected Sprint 59, corrected again Sprint 61 — a prior version of
this paragraph said "three unresolved rows" without reconciling that against the table above, an
imprecision worth naming rather than silently tightening):** the table above currently has **5**
rows marked ⬜. Two of them (MTS-01/02/03, and the full-trading-day row that names the same
scripts) share one root blocker — no printer or reference device owned yet — so they are one
distinct concern, not two. One of them (pilot cohort consent) is not "blocked" in the same sense as
the others; it is **not yet assessable**, since M5 pilot recruitment hasn't started — this row
becomes live when M5 begins, not before. Of the remaining two rows, the Android-sideload row and the
OWASP row's Android-signing finding **share the identical root cause** — a missing real signing
keystore — since Sprint 61 narrowed the sideload row away from also needing a CI pipeline; they
resolve together the moment a real keystore exists, so they're one concern from the founder's
perspective, not two, even though they're tracked as separate checklist boxes. That leaves **two
distinct concerns that actually block M4's own closure today**: MTS execution, and the OWASP
review's three findings (RLS, sign-in rate limiting, Android release signing) — **all
founder-blocked or infra-blocked, not open engineering or verification work.** (Down from three as
of Sprint 58/59, now that Sprint 61 found the Android-distribution row had been over-scoped —
Play Console distribution was never actually required for *this* pilot, only for scaling past it;
that full pipeline now lives in §3, commercial-launch scope, where it belongs.) The OWASP row's RLS
finding deepened Sprint 59: this session found no documentary confirmation
that three specific RLS policy files (`017`/`018`/`019` —
`sale_line_items`/`sale_payments`/`return_line_items`/`devices`) were ever actually applied to the
real production database, a distinct and more severe possibility than "present but owner-exempt."
**This is worth the founder's attention before anything else on this list** — it's the one item
here that isn't just "known and blocked," it's "genuinely unknown until checked." The
failure-scenarios row, unresolved since this checklist was first written, is now fully satisfied
(Sprint 57) — all 10 named scenarios
have real coverage. The nightly suite's first real scheduled run, previously its own unresolved row,
is also confirmed genuinely green (Sprint 49).

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
| ☐ Automated Android build→sign→upload pipeline (`release-candidate.yml`) actually built and exercised — real CI-driven signing via a GitHub encrypted secret, a real upload to Google Play Console's Internal Testing track, not a manual local build (**new row, Sprint 61** — moved here from §2's pilot-ready checklist, since scaling distribution past founder-personal, hand-delivered installs is what this pipeline is actually for, not a pilot requirement) | [cd-workflows.md §2](../15-github-project/cd-workflows.md#2-android-build-signing-and-distribution) |

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
| 0.8.0 | 2026-08-21 | Sprint 57 (cross-cutting fix) — failure-scenarios row **flips to satisfied**: "Token expired while queued" built, found this row's own "needs the full Supabase CLI stack" claim didn't hold either (the fifth such correction in this project's history). All 10 named scenarios now have real coverage or are resolved-by-design/not-applicable. Bottom line improves for the first time in this row's history: still not pilot-ready today, but now only **two** unresolved rows (OWASP's RLS/sign-in-rate-limiting findings, MTS execution) instead of three, and both of those are now founder-blocked or infra-blocked rather than open engineering work of any kind. |
| 0.9.0 | 2026-08-21 | Sprint 58 (cross-cutting fix, documentation-accuracy only) — found Android release signing had fallen through a crack between this document and `owasp-checklist.md`: named there as one of "4 real gaps remain" since Sprint 43, but never once threaded into this checklist's OWASP row. Corrected the OWASP row to include it as a third unresolved finding. Also found and added a new, previously-untracked row: the entire Android build→sign→upload pipeline `cd-workflows.md §2` describes (`release-candidate.yml`) was never actually built, and Play Console's Internal Testing track — this project's own designed **pilot** distribution mechanism, not just commercial — cannot accept a debug-signed build regardless. Also corrected this section's own bottom-line wording, introduced in error by the 0.8.0 entry above: M4's numbered backlog items are 1–8 done, not "9... done" — item 9 (MTS execution) is a founder action, never counted as engineering. Bottom line: still not pilot-ready today, now **three** unresolved rows (up from two), all founder-blocked or infra-blocked. |
| 0.10.0 | 2026-08-21 | Sprint 59 (documentation-accuracy only, no code change) — the OWASP row's RLS finding deepened: checked `cd-workflows.md §1`'s own claim that every RLS SQL file was eventually applied to production (citing `implementation-log.md`'s "applied live" entries) file-by-file, and found no confirmation on record for `017`/`018`/`019` (`sale_line_items`/`sale_payments`/`return_line_items`/`devices`) at all — a distinct, more severe possibility than the existing FORCE/role finding, since "the app works in production" can't distinguish "RLS present but owner-exempt" from "RLS never applied for these specific tables." Flagged in the bottom line as the item most worth the founder's immediate attention, since it's genuinely unknown rather than merely blocked. |
| 0.11.0 | 2026-08-21 | Consistency pass, same day: found the bottom line's own "three unresolved rows" claim had never actually been reconciled against the table above, which has 5 rows marked ⬜, not 3 — an imprecision introduced across the rapid Sprint 57–59 edits and caught by a dedicated proofreading pass rather than left standing. Corrected to state both numbers and the reasoning connecting them: 5 rows marked not-satisfied, of which MTS's two rows share one root blocker and the pilot-consent row is not-yet-assessable (M5 hasn't started) rather than blocked in the same sense, netting to 3 distinct concerns that actually block M4's own closure today. Also fixed a repeated off-by-one (6 of 18 RLS files, corrected to 7, matching `sprint-59.md`'s own correct count) that had propagated identically into `cd-workflows.md`, `implementation-log.md`, and `docs/18-implementation/README.md`, and a stale `backlog.md` header version that had drifted 4 versions behind its own Change Log. |
| 0.12.0 | 2026-08-21 | Sprint 61: found the Android-distribution row (added Sprint 58) had never been checked against `pilot-plan.md`'s actual pilot shape — Play Console's Internal Testing track was never really required for a 2–3-shop, founder-visited pilot, only for scaling past founder-personal, hand-delivered installs. Narrowed the §2 row to what's actually needed (a real signing keystore + direct sideload); moved the full CI/Play-Console pipeline to §3 as its own commercial-launch-scope row. This also means the row and the OWASP row's Android-signing finding share one root cause (the missing keystore), not two independent blockers — the bottom line's "distinct concerns" count drops from three to **two** (MTS execution; the OWASP review's three findings). Good news, not a new gap: this is the first correction in this run of sprints that made the founder's remaining task list shorter, not longer. |
| 0.13.0 | 2026-08-21 | Sprint 62: added a pointer to `supabase/sql/diagnostics/check_rls_status.sql`, a new read-only diagnostic that answers both the RLS-application question and the FORCE/role question directly against the real production database, in one five-minute paste-and-read action. |
| 0.14.0 | 2026-08-21 | Sprint 63: §2's Android row narrowed further — the code side of "a real signing keystore" is done (`build.gradle.kts` reads real credentials from a gitignored `key.properties` if present, falls back to debug unchanged otherwise, verified with a clean `flutter build apk --debug`). The founder's remaining task is now purely running one `keytool` command and filling in one properties file — zero code work left on this row. |
| 0.15.0 | 2026-08-21 | Sprint 64: the OWASP row's sign-in rate-limiting language corrected — the server-side gap is unchanged (still needs a Supabase-side check), but `SignInController` now applies client-side attempt throttling, real defense-in-depth this row previously didn't credit at all. |
