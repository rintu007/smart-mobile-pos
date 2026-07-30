# Sprint Template

> **Status:** 🔵 In review
> **Phase:** 17 — Sprint Planning
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

Goal, scope, Definition-of-Done reference, risks, demo script — the exact shape every
`sprint-NN.md` document uses, so a sprint is defined by filling in a form, not improvised fresh each
time.

---

## Template content

```markdown
# Sprint NN

> **Dates:** <start> – <end> (2 weeks, per sprint-cadence.md)
> **Milestone:** <M0–M5, per milestones.md>
> **Status:** Planned / In Progress / Closed

## Goal

<One sentence. If it takes two sentences, it is two goals — split the sprint.>

## Scope

<At most 2 modules, per this phase's exit criterion. List the specific backlog items
(from backlog.md) included, each with its person-day estimate and dependency status.>

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| | | | |

## Capacity check

<Sum of estimates above, checked against sprint-cadence.md's ~3.75 person-day sprint budget at the
midpoint pace. If the sum exceeds budget, cut scope now, not at review.>

## Reserved capacity

- [ ] Defect capacity reserved: <at least 1 person-day, per this phase's exit criterion>
- [ ] Documentation capacity reserved: <updating the relevant docs/ files as part of this sprint,
      not after it, per this phase's rule>

## Risks

<Named upfront, not discovered at review. Tie to risks-constraints-assumptions.md's R-NNN register
where applicable.>

## Definition of Done

<Link to the specific boxes from definition-of-done.md this sprint's scope must satisfy — not the
full checklist if this sprint only completes part of a module, but never silently narrowed either.>

## Demo script

<Numbered steps, in the style of manual-test-scripts.md, that prove this sprint's goal — executed
at review, not described in the past tense from memory.>

## Retrospective (filled in at close, only if held per sprint-cadence.md §2)

<What surprised us. What we'd change. Logged in retrospective-log.md if it's a concrete change, not
just sentiment.>
```

## Why "capacity check" is its own section, not implicit

A sprint whose listed items sum to more than the realistic 2-week budget is not a planning detail to
notice at review — it's the single most common way "unfinished work silently rolls forward"
happens, which this phase's own rule explicitly prohibits. Making the arithmetic visible at planning
time is what lets scope be cut *before* the sprint starts, not discovered as a shortfall after.

## Why Defect and Documentation capacity are checkboxes, not a percentage

A percentage ("20% of sprint capacity") invites rounding to zero on a sprint that "doesn't need it"
— exactly the failure mode this phase's rule warns against ("reserving zero does not make them
disappear"). A checkbox that must be explicitly ticked, naming a concrete reserved amount, is harder
to silently skip than a formula that quietly evaluates to nothing.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Template fixed with an explicit capacity-check section and checkbox-based (not percentage-based) defect/documentation reservation. |
