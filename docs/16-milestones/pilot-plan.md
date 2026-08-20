# Pilot Plan

> **Status:** 🔵 In review
> **Phase:** 16 — Milestones
> **Version:** 0.2.0
> **Last updated:** 2026-08-21
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

Recruiting pilot shops, onboarding, feedback capture, and success criteria — per this phase's exit
criterion, naming **how** the first real shop is recruited and supported, not just that one should
exist.

---

## 1. Recruitment — who, and why these first

Per [device-landscape.md](../reference/device-landscape.md)'s market note that offline/physical
retail dominates smartphone distribution in India and that smartphone retailers ("Mobile Shop") are
themselves a plausible early-adopter channel, and matching the two verticals already fully worked in
[seed-data.md](../07-database/seed-data.md) (Grocery, Mobile Shop): **the first pilot cohort targets
2–3 shops from these two verticals specifically**, not a broad open call. Reasons:

- Both verticals are already fully modelled in seed data — onboarding support, bug triage, and
  support conversations can reference a known, already-tested product shape rather than discovering
  a new vertical's edge cases live with a real paying-adjacent shop.
- Small, single-outlet, single-till shops (per [personas.md](../05-personas/personas.md)) match V1's
  actual scope exactly — a pilot shop with multi-till or multi-outlet needs would immediately surface
  V4-scope gaps this pilot isn't meant to test yet.
- A personal, founder-known relationship (a shop the founder can visit in person) is preferred over
  a cold-recruited shop for the *first* pilot specifically — the ten-minute onboarding promise
  ([project-vision.md](../01-vision/project-vision.md)) and the real-trading-day exit criterion in
  [milestones.md — M5](milestones.md#m5--first-real-shop) both benefit from a founder physically
  present for the first real day, which is only realistic with a shop the founder has direct access
  to.

## 2. Onboarding

**Added, Sprint 61 — a real gap, not a design decision left implicit:** this document never said
how the app actually reaches a pilot shop's device, despite that being squarely within its own
stated purpose ("naming **how** the first real shop is recruited and supported"). Resolved as a
**direct sideload install of a properly-signed (non-debug) release APK**, done by the founder
during the pre-visit or day-one visit — the identical mechanism already proven reliable across
every real-device install this project has done (Sprints 10, 16, 48, 54), needing only a real
signing keystore (`cd-workflows.md §2`'s own corrected account) and no Play Console setup at all.
Google Play Console distribution was this project's originally-designed mechanism (Phase 15,
before this document existed), but standing it up — API access, a service account, an automated
pipeline — for 2–3 shops the founder personally visits is exactly the kind of premature-generality
effort §3 below already argues against for feedback tooling; the same reasoning applies here.

| Step | Detail |
| --- | --- |
| Pre-visit | Product catalogue for the shop entered in advance (by the founder/team, not the shop owner) from a photo or a quick in-person walk of the shelves — the ten-minute onboarding promise is about the *shop owner's* time, not a claim that data entry from zero takes ten minutes |
| Pre-visit or day-one | The release APK sideloaded directly onto the shop's device by the founder — a one-time "allow installs from this source" permission grant on the shop's own device, the same step already handled on the founder's own device every prior real-device install |
| Day-one visit | Founder present in person for the shop's first real trading day — opens the day, observes the first real sale, is available for the first real return, closes the day and reconciles cash together |
| Week-one check-in | A direct conversation (call or in-person), not a survey — matching this document's "known relationship" recruitment stance, a structured NPS-style survey is premature for a 2–3 shop pilot |
| Week-four check-in | Same, plus a direct comparison against the shop's own prior method (a notebook, or a competitor product if already in use) |

## 3. Feedback capture

Given a 2–3 shop pilot, a lightweight, direct channel — a shared WhatsApp thread with the founder,
matching the actual communication channel these shops already use daily, per
[personas.md](../05-personas/personas.md)'s findings — is preferred over building any in-app
feedback mechanism for this stage. Building structured in-app feedback tooling for a 2–3 shop pilot
would be exactly the kind of premature-generality effort this documentation set has avoided
elsewhere (e.g. [labels-and-milestones.md](../15-github-project/labels-and-milestones.md)'s deferred
`good-first-issue` labels) — it is designed once the pilot is large enough that a founder can no
longer personally track every shop's feedback in one thread.

**Every reported issue is triaged through the standing GitHub issue templates**
([issue-templates.md](../15-github-project/issue-templates.md)) — a pilot-shop report becomes a
`type:defect` issue exactly like an internally-found bug, not a separate, less-rigorous feedback
category.

## 4. Success criteria — already defined, reused exactly

Per [success-metrics.md](../01-vision/success-metrics.md)'s own **Pilot target** column, restated
here as this pilot's actual acceptance bar, not re-derived:

| Metric | Pilot target |
| --- | --- |
| Sales lost to system failure | **0** |
| Duplicate sale rate | **0** |
| Sync success rate | ≥ 99.5% |
| Week-1 retention | ≥ 60% (of the pilot cohort actually still transacting) |
| Stock accuracy | ≥ 95% |
| Cash reconciliation variance | ≤ 1% of takings |

**If the first row (sales lost to system failure) is ever non-zero during the pilot, that is not a
metric to track toward a target — it is an immediate, stop-and-fix event**, per
[success-metrics.md](../01-vision/success-metrics.md)'s own veto-power framing for that specific row.

## 5. What this pilot explicitly does not attempt

Per [Phase 05](../05-personas/README.md)'s already-acknowledged gap, this pilot is real-shop usage
data, not a substitute for the structured persona-validation interviews that document flagged as
unmeetable by documentation-phase work alone — a successful pilot narrows that gap usefully but
does not close it outright, and should not be reported as having done so.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Recruitment narrowed to 2–3 known Grocery/Mobile Shop pilots, matching existing seed data; founder-present onboarding; WhatsApp-based feedback deliberately chosen over premature in-app tooling; success criteria reused verbatim from success-metrics.md's Pilot column. |
| 0.2.0 | 2026-08-21 | Sprint 61: added the missing "how does the app actually reach the shop's device" step — a direct sideload of a properly-signed release APK, done by the founder during the visit, rather than Google Play Console distribution. Found this document had never been reconciled against `cd-workflows.md §2`'s Phase-15-era Play Console design, and that reconciling them the other way (correcting `cd-workflows.md`/`release-checklist.md` to match this document's own already-established minimalism) was the right call — the same "avoid premature generality" reasoning this document already applies to feedback tooling in §3. |
