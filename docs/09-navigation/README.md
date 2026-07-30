# Phase 09 — Navigation

> **Status:** 🔵 In review — all 6 deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead / Principal Flutter Engineer

## Charter

| | |
| --- | --- |
| **Objective** | Define the complete route map, navigation model and deep-link scheme so that tap-count budgets are provably achievable. |
| **Inputs** | Phases 05 (🟡, hard-blocked on real validation), 06 and 08 (both 🔵 In review). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`route-map.md`](route-map.md) | 6 pre-shell + 35 shell routes (41 total), every one with permission and offline value stated | 🔵 In review |
| [`navigation-model.md`](navigation-model.md) | 4-tab persistent shell, Till app-bar quick actions, mid-sale-interruption gap closed | 🔵 In review |
| [`deep-links.md`](deep-links.md) | 1 real V1 deep link (account verification); rest deferred with reasoning | 🔵 In review |
| [`guards-and-redirects.md`](guards-and-redirects.md) | 4 guards; subscription guard explicitly ruled out and why | 🔵 In review |
| [`tap-count-audit.md`](tap-count-audit.md) | 14 workflows audited; 1 over-budget finding, fixed in this phase, not deferred | 🔵 In review |
| [`web-routes.md`](web-routes.md) | V1 web surface confirmed minimal — API plus one fallback page | 🔵 In review |

## Exit criteria

- [x] Every screen in the design system has exactly one canonical route — [route-map.md](route-map.md)
      defines the full route set Phase 10 designs against; none share a path.
- [x] Every route declares its required permission and its offline availability — no blank cells in
      [route-map.md](route-map.md).
- [x] The tap-count audit shows every primary workflow inside its budget. **One workflow was found
      over budget** (WF-005, resuming with 2+ carts held) — **fixed by navigation redesign within
      this phase** (auto-resume when unambiguous), not deferred as a note, per this exit criterion's
      own instruction.
- [x] The back-stack behaviour of a mid-sale interruption is defined and does not lose the cart —
      [navigation-model.md §4](navigation-model.md#4-resolving-the-mid-sale-interruption-requirement)
      extends cart persistence to the draft state itself, closing a gap Phase 03/06 left open.
- [x] Deep links are authenticated and tenant-scoped — [deep-links.md §3](deep-links.md#3-the-standing-rule-for-when-these-arrive)
      states the rule now, binding on the V3 features that will actually need it.

All five exit criteria are met, including the one that explicitly required fixing a problem rather
than noting it.

## Rules

- The POS screen is reachable in **one tap from app launch**, always, from any state.
- Navigation never blocks on a network call. A route that cannot render offline shows cached data
  with an honest staleness indicator, or an explicit offline state — never an indefinite spinner.
