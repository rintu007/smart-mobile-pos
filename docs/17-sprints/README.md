# Phase 17 — Sprint Planning

> **Status:** 🔵 In review — all 5 deliverables drafted; Sprint 01, Sprint 02, and Sprint 03 all closed
> **Version:** 0.5.0
> **Last updated:** 2026-08-01
> **Owner:** Product Manager / CTO

## Charter

| | |
| --- | --- |
| **Objective** | Break milestones into executable sprints, each delivering something complete under the Definition of Done. |
| **Inputs** | Phase 16 (🔵 In review, OD-06 resolved). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`sprint-cadence.md`](sprint-cadence.md) | 2-week sprints; every ceremony kept or dropped with its reason tied to the resolved solo/10–20hrs reality | 🔵 In review |
| [`sprint-template.md`](sprint-template.md) | Explicit capacity-check section; checkbox-based (not %-based) defect/doc reservation | 🔵 In review |
| [`backlog.md`](backlog.md) | M0 fully decomposed into 11 estimated, dependency-ordered items (18.5 person-days, confirming Phase 16's estimate) | 🔵 In review |
| [`sprint-01.md`](sprint-01.md) | Repository scaffold + Auth wiring — both items done, demoed on real infrastructure | 🟢 Done |
| [`sprint-02.md`](sprint-02.md) | `POST /api/v1/onboarding` (Company & Store Setup) — built and demoed live | 🟢 Done |
| [`sprint-03.md`](sprint-03.md) | Flutter SDK installed, `apps/mobile` scaffolded, local Drift database built (backlog.md item 4) | 🟢 Done |
| [`retrospective-log.md`](retrospective-log.md) | Sprint 01/02/03 retrospectives recorded: "verified locally" ≠ "CI-ready" ≠ "the endpoint/database actually works" ≠ "first contact with new tooling won't surprise you" | 🔵 In review |

## Exit criteria

- [x] Each sprint has **one** goal, stated in a single sentence — [sprint-template.md](sprint-template.md)'s
      Goal section, demonstrated concretely in [sprint-01.md](sprint-01.md).
- [x] Each sprint's output is demonstrable and meets the Definition of Done — [sprint-01.md](sprint-01.md)'s
      Demo script and its explicitly scoped-down DoD subset (never claiming boxes a 2-item slice
      can't actually satisfy).
- [x] No sprint mixes more than two modules — [sprint-01.md](sprint-01.md) scopes exactly one
      (Identity/Auth, plus the repository scaffold it depends on).
- [x] Every sprint reserves capacity for defects and documentation —
      [sprint-template.md](sprint-template.md)'s checkbox-based reservation, populated with concrete
      amounts (not left at a defaultable percentage) in [sprint-01.md](sprint-01.md).

All four exit criteria are met, demonstrated concretely rather than only specified abstractly —
Sprint 01 is a real, executable sprint plan, not just a template with no worked example. Per this
phase's own rule against batch-authoring future sprints, Sprint 02 onward are written when Sprint 01
actually closes, not pre-drafted here.

## Rules

- **One module at a time.** A module is complete before the next begins. This is the founding rule
  and sprint planning does not get to negotiate with it — **with the same M0 walking-skeleton
  exception named in [modules/README.md's Rule 2](../modules/README.md#rules)**, not a separate
  looser rule for sprints specifically: during M0, "one module" means M0 itself, since M0 is by
  design a cross-cutting slice through several Registry rows at once.
- Unfinished work does not silently roll forward. It is re-estimated and re-prioritised against
  everything else, because circumstances changed.
- Retrospectives change something concrete or they are cancelled. A retrospective that produces
  only sentiment is a meeting.
- Documentation is inside the sprint, never after it. "We will document it later" is how the single
  source of truth stops being true.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | All 5 deliverables drafted; Sprint 01 planned and ready for Phase 18 kickoff. |
| 0.2.0 | 2026-08-01 | Sprint 01 closed (both backlog items done, demoed live). |
| 0.3.0 | 2026-08-01 | Sprint 02 planned. Found and closed a real gap first: Authentication and Company & Store Setup had no module specifications despite Authentication already having live code, and Phase 11 had never specified the actual signup/onboarding endpoint. Also amended the "one module at a time" rule with the M0 walking-skeleton exception, matching [modules/README.md](../modules/README.md)'s own correction. |
| 0.4.0 | 2026-08-01 | Sprint 02 closed: built and demoed live against the real database, all 6 demo steps passed. Found and fixed a real row-ordering bug (`stores_created_by_fkey`) on first contact with live data. |
| 0.5.0 | 2026-08-01 | Sprint 03 planned and closed same-day: Flutter SDK installed (the founder-blocked item named since Sprint 01), `apps/mobile` scaffolded and reshaped, local Drift database built for backlog.md item 4 and verified via `flutter test`. Two real package-version findings (Riverpod 3.x vs. `riverpod_lint`, `sqlite3_flutter_libs` obsolescence). |
