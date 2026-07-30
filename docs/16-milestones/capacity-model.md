# Capacity Model

> **Status:** 🟢 Resolved — OD-06 answered 2026-07-31
> **Phase:** 16 — Milestones
> **Version:** 0.2.0
> **Last updated:** 2026-07-31
> **Owner:** Product Manager / CTO
> **Approved by:** Founder, 2026-07-31

Available hours, velocity assumptions, and how they were derived — completed once
[OD-06](../01-vision/open-decisions.md) was actually answered by the founder, rather than guessed at
(this document's earlier draft explained in detail why guessing here specifically would have been
worse than leaving it blocked — that reasoning is preserved in §5 for the record).

---

## 1. The answer

| Input | Value |
| --- | --- |
| Hours per week | **10–20 hrs/week** (a range, not a single point — carried through as a sensitivity band, not collapsed to one number) |
| Contributors | **1 — solo.** No other engineering time to divide effort across. |

## 2. Conversion

Per the formula already fixed before the answer arrived:

```
person-days/week = hours_per_week ÷ 8
  10 hrs/week → 1.25 person-days/week   (slow end)
  20 hrs/week → 2.5  person-days/week   (fast end)
  15 hrs/week → 1.875 person-days/week  (midpoint, used for the single-line schedule in roadmap.md)

calendar_duration(M) = effort(M) ÷ person-days-per-week ÷ 1 (solo)
```

## 3. What this means, stated plainly

At a **solo, 10–20 hrs/week** pace, [roadmap.md §2](roadmap.md#2-v1-milestones--effort-sized-confidence-rated)'s
total V1 effort (84–125 person-days, with buffer) converts to **roughly 44–67 weeks — about
10 to 15 months** — before M5's pilot even begins. This is a real number, not a discouraging one
stated to alarm; it is exactly what this phase's rule ("dates move before scope or quality does")
is for: **the schedule adjusts to this reality, not the other way around.** No scope was cut and no
milestone was resized to make this number look smaller.

## 4. What a founder might reasonably do with this number

Not this document's call to make, but worth naming since it's the obvious next question: at 10–15
months to a pilot-ready V1, a few real levers exist — increasing weekly hours, bringing in a second
contributor for parallelisable work (per [dependency-graph.md §2](dependency-graph.md#2-the-critical-path-named-explicitly),
Customers/Returns/Reports can run in parallel with a second person once `Sales` exists), or accepting
the timeline as-is. This document states the honest number; which lever (if any) to pull is a
founder decision, not an engineering one.

## 5. Why this was worth blocking on, rather than guessing — preserved from the original draft

A provisional country assumption (OD-01) could be swapped for the real one with a bounded, known
rework cost. A provisional capacity number could not have been corrected the same way — once a date
appeared anywhere, it would have started being relied upon in exactly the silent, compounding way
this phase's rules warn against. Waiting the one extra step to ask, rather than estimating a
plausible-sounding number, is why every figure in [roadmap.md](roadmap.md) is now real rather than a
guess wearing a suit.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Documented as genuinely blocked on OD-06; conversion formula specified ahead of the answer. |
| 0.2.0 | 2026-07-31 | OD-06 answered by the founder (10–20 hrs/week, solo) — resolved, converted, and the resulting ~10–15 month V1 timeline stated plainly, without softening or resizing scope to make it look shorter. |
