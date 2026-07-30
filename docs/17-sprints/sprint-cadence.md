# Sprint Cadence

> **Status:** 🔵 In review
> **Phase:** 17 — Sprint Planning
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

Length, ceremonies, and what is deliberately skipped — sized honestly against
[capacity-model.md](../16-milestones/capacity-model.md)'s resolved reality: **solo, 10–20 hrs/week**,
not a multi-person team this cadence would otherwise be designed for.

---

## 1. Sprint length — 2 weeks

At the midpoint pace (1.875 person-days/week, per
[capacity-model.md §2](../16-milestones/capacity-model.md#2-conversion)), a 2-week sprint holds
roughly **3.75 person-days of real work** — a Feature-sized slice
([project-board.md §2](../15-github-project/project-board.md#2-item-types)'s item type), not a
whole Module. A full V1 module (12–25 person-days, per
[roadmap.md §2](../16-milestones/roadmap.md#2-v1-milestones--effort-sized-confidence-rated)) spans
roughly 3–7 sprints, which is exactly why [milestones.md](../16-milestones/milestones.md)'s M0–M4
are the unit of "done," not any single sprint — a sprint is a checkpoint inside a milestone, never
the thing this project reports progress against externally.

## 2. Ceremonies kept — because they serve scope discipline, not coordination

For a solo builder, most Scrum ceremony exists to serve a purpose that doesn't apply here (there is
no second person to synchronise with). What's kept is kept because it still does real work even
alone:

| Ceremony | Kept? | Why |
| --- | --- | --- |
| Sprint planning | **Yes**, ~30–45 min at sprint start | Forces the single-sentence goal and the ≤2-module scope boundary this phase's exit criteria require — writing it down, even alone, is what prevents scope drifting mid-sprint |
| Sprint review / demo | **Yes**, against [sprint-template.md](sprint-template.md)'s demo script | The Definition of Done requires an "Owner-facing workflow completed end-to-end by someone who did not write the code" — for a solo builder this becomes "demoed as if to that person," a deliberate discipline substitute, named as weaker rather than skipped, matching [repository-setup.md §3](../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around)'s precedent for the same kind of solo-team gap |
| Retrospective | **Yes, but only every other sprint** (or immediately after any sprint with a real surprise — a missed estimate, a rejected assumption) | Per this phase's rule, a retrospective that changes nothing is a meeting — for a solo builder running every 2 weeks, most sprints won't surface enough new information to justify one; forcing it anyway would produce exactly the "sentiment-only" retrospective this phase's rule already prohibits |
| Daily standup | **No** | Exists purely to synchronise multiple people; there is no one to synchronise with |
| Story-point estimation / planning poker | **No** | [roadmap.md](../16-milestones/roadmap.md) already estimates in person-days, derived from concrete comparisons to already-specified work (Phases 07–14) — re-estimating in an abstract points system on top of a real unit is a translation step with no added information |
| Cross-team dependency review | **No** | Solo — [dependency-graph.md](../16-milestones/dependency-graph.md)'s critical path already is the dependency review, fixed once at Phase 16, not re-litigated every sprint |

## 3. What changes if a second contributor joins

Per [capacity-model.md §4](../16-milestones/capacity-model.md#4-what-a-founder-might-reasonably-do-with-this-number),
bringing in a second person is a real lever the founder might pull later. If that happens, standup
and cross-dependency review are the two ceremonies to reinstate first — not because this document
predicts it will happen, but so the decision, if made, is "turn two rows back on," not "redesign
sprint cadence from scratch."

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | 2-week sprints sized against the resolved solo/10–20hrs capacity; each ceremony kept or dropped with its reason tied to *why* it exists, not a generic Scrum checklist. |
