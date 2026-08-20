# Sprint 58

> **Dates:** 2026-08-21 – 2026-08-21 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — documentation-accuracy only, no code change)
> **Status:** Closed. Two real, previously-uncorrected gaps found and fixed across
> `owasp-checklist.md`, `cd-workflows.md`, and `release-checklist.md`.

## Goal

With Sprint 57 closing the failure-scenarios release-gate row, `release-checklist.md §2` appeared to
have only two unresolved rows left — both clearly founder-blocked. Before accepting that as the
honest final state, this sprint re-examined the remaining founder-blocked items with the same
scrutiny Sprint 57 applied to "Token expired while queued" — not to find more code to write, but to
check whether the accounting itself was actually complete. It wasn't.

## What was found

1. **Android release signing had fallen through a crack between two documents.**
   `owasp-checklist.md`'s M8 row, and its own "4 real gaps remain" summary, have named this finding
   — the release build signs with the debug keystore — as open since Sprint 43. It was never once
   threaded into `release-checklist.md §2`'s actual release gate: that checklist's OWASP row only
   ever counted RLS and sign-in rate limiting toward its critical-severity bar, and its own
   parenthetical list of "other gaps not counted toward severity" named a *different* four items
   (secure token storage, DB encryption, customer erasure, alerting) — Android signing appeared in
   neither list, in either document.
2. **Checked whether this omission was actually harmless before correcting it, not assumed.** A
   debug-signed build might be a purely commercial-launch concern if a pilot sideloads APKs directly
   — but `cd-workflows.md §2` names Google Play Console's **Internal Testing track** as this
   project's own already-designed distribution mechanism for *pilot* builds specifically, not only
   commercial ones. Internal Testing cannot accept an app signed with the debug keystore. This
   finding genuinely blocks the pilot-ready gate, not only a future commercial one.
3. **A second, compounding gap, found while checking the first:** the entire Android
   build→sign→upload pipeline `cd-workflows.md §2` describes (a `release-candidate.yml` GitHub
   Actions workflow, a signing-keystore secret, an automated Play Console upload) was never actually
   built. Confirmed directly against `.github/workflows/` — only `pr.yml` and `nightly.yml` exist.
   This is the exact same "designed but not built" class of gap Sprint 55/PR #79 already found and
   corrected for this same document's §1 (the RLS-SQL deployment path) — apparently not checked
   again for §2 at the time. Every real Android build this project has produced (Sprints 10, 16, 48,
   54) has been a manual, local, debug-signed `flutter build apk` command, re-served over a local
   network file share for the founder's own device.
4. **A self-introduced accounting error, found and corrected in the same pass.** Sprint 57's own edit
   to `release-checklist.md`'s bottom line said "M4's 9 engineering backlog items are all done" —
   wrong; item 9 (MTS execution) is a founder action, never counted as engineering, and Sprints
   55/56 (device registration) were unnumbered cross-cutting fixes conflated with it in error. A
   near-identical error, in `docs/18-implementation/README.md`, had already been caught and named
   during Sprint 57 itself; this was a second instance of the same slip in a different document.

## Design decisions

1. **Add a new, explicit release-checklist row for the distribution pipeline, rather than folding it
   into the OWASP row.** The missing keystore and the missing pipeline are two independent blockers
   — provisioning a real keystore today still wouldn't get a build to Play Console without the
   pipeline also existing. Naming them as one combined row would understate what's actually missing.
2. **Do not build `release-candidate.yml` itself.** Unlike Sprint 57's `api_client.dart` fix, this
   genuinely cannot be built and verified without founder-provisioned credentials (a real keystore,
   a Play Console service-account key) — this session has no way to test a signing/upload step
   actually working. Building unverifiable CI infrastructure would violate this project's own
   verify-before-claiming-done discipline; named as real, separately-scoped follow-up work instead,
   the same treatment §1's RLS-deploy gap already received.
3. **Correct three documents in one pass, not just the one first noticed.** `owasp-checklist.md`
   (cross-referenced to the checklist that now tracks it), `cd-workflows.md §2` (corrected to match
   §1's own already-corrected honesty), and `release-checklist.md` (the actual release gate) — since
   the whole point of this sprint's finding is that a single-document fix would leave the same class
   of gap in the other two.

## Definition of Done

- [x] `docs/12-security/owasp-checklist.md` — M8's row and the summary's item 4 both cross-reference
      `release-checklist.md §2` for the first time.
- [x] `docs/15-github-project/cd-workflows.md §2` — corrected to state plainly that the described
      pipeline was never built, matching §1's own existing correction.
- [x] `docs/14-testing/release-checklist.md` — OWASP row corrected to a third finding (Android
      signing); new explicit row added for the distribution-pipeline gap; bottom line corrected both
      for the new row count (three, up from two) and the Sprint 57 accounting error (M4 items 1–8
      done, not 9).
- [x] `backlog.md`, `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md`
      updated in the same PR.
- [x] No code change this sprint — verified by `git status` showing only `docs/` files touched.

## Demo script

**Local, run 2026-08-21:**

1. Confirmed `.github/workflows/` contains only `pr.yml` and `nightly.yml` — no `release-candidate.yml`. ✅
2. Confirmed no signing-keystore-shaped GitHub secret reference exists anywhere in the repo's
   workflow files (`grep -r "keystore\|KEYSTORE" .github/`) — nothing found. ✅
3. Re-read `cd-workflows.md §2`'s own distribution description against `apps/mobile/android/app/build.gradle.kts`'s
   real signing config — confirmed the debug-keystore TODO comment `owasp-checklist.md` already
   named is still present, unchanged. ✅

**Not performed this sprint, by design:** building or testing any part of the actual Android
signing/upload pipeline — this remains real engineering work, but it cannot be verified without
founder-provisioned credentials this session doesn't have, so it stays named rather than attempted
speculatively.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming regardless: this sprint didn't find a new engineering gap — every remaining item was
already known and already correctly judged founder-blocked. What it found was an **accounting** gap:
a real finding that existed in one document's memory but had never actually reached the document
that gates a release on it. This is a different failure mode from Sprints 50–54/57's "the doc's
claimed mechanism isn't what the code does" pattern — it's "the doc's claimed *severity accounting*
doesn't match its own source list" — worth distinguishing for future checklist re-checks: verifying
a finding is *correctly resolved* is not the same check as verifying it was *correctly carried
forward* into every place that should track it.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-21 | Sprint 58: found Android release signing (owasp-checklist.md's M8, open since Sprint 43) had never been threaded into release-checklist.md's actual release gate, and — investigated rather than assumed — genuinely blocks the pilot-ready gate specifically, since Play Console's Internal Testing track (this project's own designed pilot-distribution mechanism) cannot accept a debug-signed build. Found a second, compounding gap: the entire Android build→sign→upload CI pipeline was never actually built. Corrected across owasp-checklist.md, cd-workflows.md §2, and release-checklist.md; also corrected a self-introduced accounting error from Sprint 57's own edit. No code change. |
