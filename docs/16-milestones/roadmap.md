# Roadmap

> **Status:** 🟢 Effort-sized and date-converted — OD-06 resolved 2026-07-31
> **Phase:** 16 — Milestones
> **Version:** 0.2.1
> **Last updated:** 2026-07-31
> **Owner:** Product Manager / CTO
> **Approved by:** Founder, 2026-07-31

V1–V4 with target dates and confidence levels. Effort is sized in person-days first (§2), then
converted to calendar time (§4) using [capacity-model.md](capacity-model.md)'s now-resolved OD-06
answer (solo, 10–20 hrs/week) — sized this way, in order, so the effort estimate is never quietly
adjusted to make a hoped-for date fit.

---

## 1. Why effort, not dates, right now

Per this phase's rule, "a single-point date with no confidence is a guess wearing a suit" —
publishing calendar dates without a real capacity number behind them would be exactly that guess,
dressed up by this document's own authority. Effort estimates in **person-days**, independent of
calendar time, are real information; a date derived from them without knowing hours-per-week would
not be.

## 2. V1 milestones — effort-sized, confidence-rated

| Milestone | Effort estimate | Confidence | Basis |
| --- | --- | --- | --- |
| M0 — Walking Skeleton | 15–20 person-days | **Medium** | Narrowest possible slice, but touches every architectural layer for the first time — first-time integration risk (Supabase Auth + Realtime + Sync Engine + Bluetooth printing all wired together at once) keeps this from being High confidence despite the small scope |
| M1 — Full Catalogue & Inventory, Multi-Role | 12–18 person-days | High | Extends M0's already-proven patterns; the main new surface (full stock-movement types, role enforcement) is well-specified in Phases 07/12 with no open design questions |
| M2 — Full POS Loop | 15–22 person-days | High | Tax/discount/split-payment logic is fully specified with worked examples ([money-and-tax.md](../07-database/money-and-tax.md)); the main effort is UI composition against an already-complete design system |
| M3 — Customers & Returns | 10–15 person-days | Medium | The conflict-resolution field-merge mechanism ([conflict-resolution.md](../13-offline-sync/conflict-resolution.md)) is new, non-trivial machinery being implemented for the first time here |
| M4 — Reports, Settings, Release Readiness | 15–25 person-days | **Low–Medium** | Includes the widest range of genuinely unknown-until-attempted work: physical printer dialect issues (A-07), performance-budget tuning on real hardware, and the first real run of the full adversarial sync suite — this milestone's range is deliberately wide because its content is disproportionately "things that might not work on the first try" |
| M5 — First Real Shop | Not effort-estimated | N/A | This milestone's duration depends on pilot-shop scheduling and real-world feedback cycles, not engineering effort — see [pilot-plan.md](pilot-plan.md) |

**Total V1 engineering effort: roughly 67–100 person-days**, before any buffer (§3) or calendar
conversion (§4).

## 3. Buffer — explicit, per this phase's exit criterion

**A flat 25% is added on top of the total above, as its own visible line item — never distributed
silently into individual milestone estimates.** Per this phase's rule, hidden buffer is consumed
silently and teaches nobody anything; a visible buffer line, tracked separately, shows plainly if
and where it was actually needed once real work happens, which is itself useful information for
estimating V2.

```
V1 total effort:        67–100 person-days
Explicit buffer (25%):  17–25 person-days
V1 total, with buffer:  84–125 person-days
```

## 4. Converting to a date — resolved

Using [capacity-model.md §2](capacity-model.md#2-conversion)'s midpoint (15 hrs/week solo = 1.875
person-days/week) for a single readable schedule, with the full 10–20 hrs/week range carried as an
explicit sensitivity band rather than smoothed away:

| Milestone | Duration (midpoint) | Cumulative (midpoint) | Cumulative (full 10–20 hrs/week range) |
| --- | --- | --- | --- |
| M0 — Walking Skeleton | 8–11 weeks | Week 8–11 | Week 6–16 |
| M1 — Full Catalogue & Inventory | 6–10 weeks | Week 14–21 | Week 11–30 |
| M2 — Full POS Loop | 8–12 weeks | Week 22–33 | Week 17–48 |
| M3 — Customers & Returns | 5–8 weeks | Week 27–41 | Week 21–60 |
| M4 — Reports, Settings, Release Readiness | 8–13 weeks | Week 35–54 | Week 27–80 |
| Explicit buffer (25%) | 9–13 weeks | **Week 44–67** | **Week 34–100** |

**V1 (pilot-ready) lands at roughly Week 44–67 from implementation start at the midpoint pace — call
it 10 to 15 months** — with the honest caveat that the full 10–20 hrs/week band alone (before any
real-world surprise) spans roughly 8 months to 2 years. This is a wide range because 10–20 hrs/week
is itself a wide input, not because the estimation was sloppy — narrowing it is a matter of the
founder's own actual weekly hours turning out to sit closer to one end, observable only once real
work starts.

**"Implementation start" is Phase 18's first day, once Phase 17 (Sprint Planning) sequences M0's
first sprint — not today's date.** This document deliberately does not anchor Week 0 to today,
since Phases 17 and the remaining Phase 16 approval step still sit between here and actual coding.

M5 (First Real Shop) is not included in this clock at all, per
[roadmap.md §2](#2-v1-milestones--effort-sized-confidence-rated)'s row for it — its duration is
pilot-scheduling-driven, not engineering-effort-driven.

## 5. V2–V4 — ordering confirmed, not yet effort-estimated

| Release | Content | Confidence this is the right *order* |
| --- | --- | --- |
| V2 — "Buy and Grow" | Per [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) — Suppliers, Purchase Orders, Loyalty/Wallet/Store Credit/Coupons (grouped, per that document's own money-liability grouping rule), full customer profiles, Employee Management, web admin | High — this ordering was already decided and approved in Phase 01 (OD-04); not re-litigated here |
| V3 — "Reach" | QR Ordering, online payment, Shipping & Delivery, Notifications | High — same reason; additionally gated on the launch-market/payment-provider decision ([OD-01](../01-vision/open-decisions.md)) |
| V4 — "Scale and Verticals" | Multi-outlet, Warehouse, Batch/Expiry, Serial numbers, Restaurant/Salon modules | High — same reason |

V2–V4 are not effort-estimated in person-days yet — per this project's own "one module/one phase at
a time" discipline, detailed estimation for a release 12+ months of real-world learning away from
V1 would be speculative precision, not useful planning; each is re-estimated when its own Phase
16-equivalent planning pass actually happens, informed by V1's real velocity.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | V1 milestones effort-sized (person-days) with confidence ratings and stated basis; explicit 25% buffer as its own line item; V2–V4 ordering confirmed at high confidence without premature effort estimation; calendar-date conversion deliberately deferred to OD-06. |
| 0.2.0 | 2026-07-31 | OD-06 resolved (solo, 10–20 hrs/week) — converted to a ~44–67 week (10–15 month) midpoint schedule for V1, with the full sensitivity range (~8 months–2 years) stated honestly alongside it rather than smoothed away. |
| 0.2.1 | 2026-07-31 | **Correction:** the intermediate cumulative-max figures in the full-range column (M1–M4) didn't actually sum from the per-milestone effort ranges one column over (e.g. M1's max was off by ~1.4 weeks, compounding through M4). Recomputed row by row; the final total (Week 34–100) was already correct and is unchanged. |
