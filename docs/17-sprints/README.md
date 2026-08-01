# Phase 17 — Sprint Planning

> **Status:** 🔵 In review — all 5 deliverables drafted; Sprint 01 underway (Identity/Auth item done and demoed live; Repository/CI item — branch protection, `pr.yml` actually running — still a founder action)
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
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
| [`sprint-01.md`](sprint-01.md) | Repository scaffold + Auth wiring — Identity/Auth done and demoed live; Repository/CI (branch protection, CI run) still a founder action | 🟡 In progress |
| [`retrospective-log.md`](retrospective-log.md) | Format fixed; deliberately empty pending Sprint 01's actual close | 🔵 In review |

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
  and sprint planning does not get to negotiate with it.
- Unfinished work does not silently roll forward. It is re-estimated and re-prioritised against
  everything else, because circumstances changed.
- Retrospectives change something concrete or they are cancelled. A retrospective that produces
  only sentiment is a meeting.
- Documentation is inside the sprint, never after it. "We will document it later" is how the single
  source of truth stops being true.
