# Sprint 61

> **Dates:** 2026-08-21 – 2026-08-21 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness / M5 — First Real Shop
> (cross-cutting fix, not a numbered backlog item — documentation-accuracy only, no code change)
> **Status:** Closed. The first correction in this run of sprints (57–61) that makes the founder's
> remaining task list *shorter*, not longer.

## Goal

Sprints 58–60 each found a real gap by checking whether something known in one document had been
correctly carried into another. This sprint applies the same check in a direction not yet tried:
reading `pilot-plan.md` — the actual specification for what the "first real shop" pilot looks like
— and checking it against `release-checklist.md`'s own Android-distribution requirement (added
Sprint 58), rather than assuming that requirement was correctly scoped in the first place.

## What was found

`release-checklist.md §2`'s Android-distribution row (Sprint 58) required Google Play Console's
Internal Testing track to be a real, working path before M4 could be pilot-ready — following
`cd-workflows.md §2`'s own design, written at Phase 15. That row was never checked against
`pilot-plan.md`, written later at Phase 16, which already commits the actual first pilot to
something much smaller and more specific: **2–3 shops the founder personally knows, recruited for
exactly that reason; the founder physically present for the shop's first real trading day; feedback
captured over a shared WhatsApp thread specifically because building structured in-app feedback
tooling "would be exactly the kind of premature-generality effort this documentation set has
avoided elsewhere."**

That reasoning — pilot-plan.md's own words — applies just as directly to distribution. Setting up
Google Play Console API access, a service account, and an automated CI pipeline to reach 2–3 shops
the founder visits in person and hands a phone to is the same kind of premature generality
`pilot-plan.md §3` already rejects for feedback. What actually gets the app onto a pilot shop's
device is narrower: a properly-signed (non-debug) APK, and a direct sideload install — the
identical mechanism this project has already used, successfully, for every real-device install in
its history (Sprints 10, 16, 48, 54, all founder-device installs via local file share, not Play
Store). `pilot-plan.md` itself never named this step at all, despite its own stated purpose being
exactly "naming **how** the first real shop is recruited and supported" — a real, if smaller, gap
of its own.

## Design decisions

1. **Reconcile in the direction that reduces scope, not the direction that adds a row.** Unlike
   Sprints 58–60, where the correct fix was naming a previously-missed requirement, here the correct
   fix is recognizing an existing requirement was over-scoped. Both are the same underlying
   discipline (check documents against each other rather than trust either in isolation); this one
   just resolves toward less work, which is exactly why it was worth checking rather than assumed
   settled by Sprint 58's own framing.
2. **Move the full CI/Play-Console pipeline to `release-checklist.md §3` (commercial-launch-ready)
   rather than deleting it.** The work described is real and will matter once distribution needs to
   scale past founder-personal visits — it just isn't a pilot blocker, and the checklist's own
   existing two-tier structure (pilot vs. commercial) exists specifically to hold exactly this kind
   of distinction without conflating the two.
3. **Fix `pilot-plan.md`'s own gap in the same pass, not as separate follow-up.** The document's own
   stated purpose commits it to naming exactly this kind of operational detail; leaving it unnamed
   while correcting everything downstream of it would repeat the same "known in one place, not
   threaded elsewhere" pattern this sprint exists to close.
4. **The remaining requirement (a real signing keystore) is not new — it's `owasp-checklist.md`'s
   M8 finding, already tracked since Sprint 43.** This sprint doesn't add a new founder action; it
   removes a *second*, redundant framing of the same one, making the actual remaining ask clearer
   rather than making it seem larger than it is.

## Definition of Done

- [x] `docs/15-github-project/cd-workflows.md §2` — corrected to note Play Console distribution is
      scoped for scaling past founder-personal visits, not a pilot requirement; cross-references
      `pilot-plan.md`.
- [x] `docs/14-testing/release-checklist.md` — §2's Android row narrowed to "a real keystore, a
      sideload-capable build"; a new row added to §3 for the full CI/Play-Console pipeline; bottom
      line corrected to two distinct blocking concerns (down from three).
- [x] `docs/16-milestones/pilot-plan.md` — added the missing "how the app reaches the shop's device"
      step to §2's onboarding table.
- [x] `backlog.md`, `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md`
      updated in the same PR.
- [x] No code change this sprint — verified via `git status` showing only `docs/` files touched.

## Demo script

**Local, run 2026-08-21:**

1. Read `pilot-plan.md` in full for the first time this session — confirmed it names 2–3
   founder-known shops and explicitly rejects "premature generality" for feedback tooling. ✅
2. Grepped `cd-workflows.md` and `pilot-plan.md` for cross-references to each other — confirmed
   neither had ever mentioned the other on the distribution-mechanism question before this sprint. ✅
3. Confirmed every prior real Android install in this project's history (Sprints 10, 16, 48, 54) was
   a direct sideload, never a Play Store/Internal Testing install — the mechanism this sprint
   proposes for the pilot is not new or unproven, it's what has already always been done. ✅

**Not performed, and not yet possible:** actually provisioning a real signing keystore or performing
a real sideload install onto an actual pilot shop's device — both remain real, near-term founder
actions, now more precisely scoped than before.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming: Sprints 58, 59, 60, and 61 form a complete set of the same underlying check — findings
into gates, claims into evidence, milestones into their own exit criteria, and requirements into the
actual scope they were meant to serve — applied four times, in four different document pairs, in one
session. Three found real gaps that added work; one found a real gap that removed it. Both outcomes
are the same discipline working correctly — the goal was never to find more problems, it was to
make what this project's documentation says match what is actually true, in whichever direction
that turns out to point.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-21 | Sprint 61: found `release-checklist.md`'s Android-distribution row (Sprint 58) had never been checked against `pilot-plan.md`'s actual pilot shape — Google Play Console distribution was never really required for a 2–3-shop, founder-visited pilot, only a real signing keystore and direct sideload are. Corrected `cd-workflows.md §2`, `release-checklist.md` (narrowed §2's row, moved the full pipeline to §3), and `pilot-plan.md` (added the missing device-install step). Distinct blocking concerns for M4's pilot-ready closure drop from three to two. No code change. |
