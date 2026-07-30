# Phase 16 — Milestones

> **Status:** 🔵 In review — all 5 deliverables complete; OD-06 resolved 2026-07-31
> **Version:** 0.2.0
> **Last updated:** 2026-07-31
> **Owner:** Product Manager / CTO

## Charter

| | |
| --- | --- |
| **Objective** | Convert the release slices into dated milestones with explicit entry and exit criteria, sized against real available capacity. |
| **Inputs** | Phase 01 scope (🟢 Approved) and Phase 15 setup (🔵 In review). [OD-06](../01-vision/open-decisions.md) (capacity) **resolved** — solo, 10–20 hrs/week. |
| **Was blocked by** | OD-06, exactly as this charter warned. Rather than guess, this phase asked the founder directly once it actually reached the gate — see [capacity-model.md §5](capacity-model.md#5-why-this-was-worth-blocking-on-rather-than-guessing--preserved-from-the-original-draft) for why guessing would have been worse than the one-question pause. |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`milestones.md`](milestones.md) | 6 outcome-based V1 milestones (M0 Walking Skeleton → M5 First Real Shop) | 🔵 In review |
| [`dependency-graph.md`](dependency-graph.md) | Full critical path named: Auth→Setup→Catalogue→Inventory→POS→Sales→Receipt; Sync/Roles/Audit confirmed cross-cutting, not sequential | 🔵 In review |
| [`roadmap.md`](roadmap.md) | V1 effort-sized in person-days with confidence levels; explicit 25% buffer; converted to a real ~44–67 week (10–15 month) schedule | 🔵 In review |
| [`pilot-plan.md`](pilot-plan.md) | 2–3 shop recruitment (Grocery/Mobile Shop, matching existing seed data); founder-present onboarding; success criteria reused from success-metrics.md | 🔵 In review |
| [`capacity-model.md`](capacity-model.md) | OD-06 resolved: solo, 10–20 hrs/week — converted into the roadmap's real schedule | 🟢 Resolved |

## Exit criteria

- [x] Every milestone ends in something **demonstrable to a shop owner** —
      [milestones.md](milestones.md), each of M0–M5 states one explicitly.
- [x] Dependencies are mapped; the critical path is identified and named —
      [dependency-graph.md §2](dependency-graph.md#2-the-critical-path-named-explicitly).
- [x] Estimates state a confidence level — [roadmap.md §2](roadmap.md#2-v1-milestones--effort-sized-confidence-rated),
      every V1 milestone rated High/Medium/Low-Medium with its basis stated, not just a label.
- [x] Buffer is explicit, not hidden inside individual estimates —
      [roadmap.md §3](roadmap.md#3-buffer--explicit-per-this-phases-exit-criterion), a flat 25% as
      its own visible line item.
- [x] The pilot plan names how the first real shop is recruited and supported —
      [pilot-plan.md §§1–2](pilot-plan.md#1-recruitment--who-and-why-these-first).

**All five exit criteria are now fully met, including the calendar-date conversion this charter
originally gated on OD-06.** The founder was asked directly rather than having a number guessed on
their behalf — solo, 10–20 hrs/week — and [roadmap.md §4](roadmap.md#4-converting-to-a-date--resolved)
converts that honestly into a real, unflattering-if-that's-what-it-is schedule: roughly 10–15 months
to a pilot-ready V1 at the midpoint pace, stated plainly rather than rounded down to sound better.

## Rules

- Milestones are outcome-based. "Inventory module complete" — not "four weeks of inventory work".
- **The first milestone is a complete, working, narrow vertical slice** — authenticate, add a
  product, make a sale offline, sync it, print a receipt. It exercises every architectural layer
  early, when the cost of discovering a wrong assumption is at its lowest.
- Dates move before scope-per-milestone or quality does. Cutting quality to hold a date is how a
  product that handles money loses the trust it cannot re-earn.
