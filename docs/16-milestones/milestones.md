# Milestones

> **Status:** 🔵 In review
> **Phase:** 16 — Milestones
> **Version:** 0.1.2
> **Last updated:** 2026-08-21
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

Each milestone: scope, entry criteria, exit criteria, demonstrable outcome. Every milestone is
**outcome-based**, per this phase's rule — no milestone below is named or sized as "N weeks of
work"; each is named for what a shop owner would actually see. Dates are deliberately absent from
this document — see [roadmap.md](roadmap.md) and [capacity-model.md](capacity-model.md) for why.

---

## M0 — Walking Skeleton

**This is this phase's own mandatory first milestone, taken verbatim from its rule:** authenticate,
add a product, make a sale offline, sync it, print a receipt. Deliberately the narrowest possible
slice that still touches every architectural layer — Auth, Company/Store setup, a minimal
`products` write path, the POS scan/add loop, the offline outbound queue, sync push/pull, the
stock ledger (one `opening` and one `sale` movement), the audit log (per DR-025, from the very
first sale, not retrofitted), and Bluetooth receipt printing.

| | |
| --- | --- |
| **Entry criteria** | Phase 15's repository, CI pipeline, and branch protection exist and are green on an empty scaffold. |
| **Exit criteria** | A single Owner account can sign in, add one product, complete one cash sale **with the device in airplane mode**, reconnect, watch it sync, and print a physical receipt — with an audit-log entry and a stock-ledger entry both present and correct. |
| **Demonstrable outcome** | A live phone, in front of the founder, completing exactly that sequence — not a description of it. |

## M1 — Full Catalogue & Inventory, Multi-Role

| | |
| --- | --- |
| **Scope** | Categories, Units, full barcode/SKU search ([FR-022](../03-functional-requirements/functional-requirements.md)–[FR-025](../03-functional-requirements/functional-requirements.md)), the full stock-movement set (adjustment with required reason, stock count), and Roles & Permissions enforced across every endpoint added so far (Cashier/Manager/Owner, not just Owner). |
| **Entry criteria** | M0 demonstrated. |
| **Exit criteria** | A Manager can set up a real product catalogue (barcodes, categories, units) offline; a Cashier-role account can complete a sale but cannot perform a Manager-only action, enforced server-side and proven by the [permission-matrix.md](../05-personas/permission-matrix.md) test suite. |
| **Demonstrable outcome** | A shop owner scans a real product from their own shelf, on a real barcode, and sees it resolve correctly. |

## M2 — Full POS Loop

| | |
| --- | --- |
| **Scope** | Discount (with auto-approval threshold, [DR-011](../03-functional-requirements/business-rules.md)/[DR-012](../03-functional-requirements/business-rules.md)), tax computation ([DR-008](../03-functional-requirements/business-rules.md)), split payment, hold/resume, Cash Drawer / trading day open and close. |
| **Entry criteria** | M1 demonstrated. |
| **Exit criteria** | The full [tap-count-audit.md](../09-navigation/tap-count-audit.md) budget is met on every Till workflow, measured on the reference low-end device ([device-matrix.md](../14-testing/device-matrix.md)), not estimated. |
| **Demonstrable outcome** | A Cashier completes a discounted, split-payment sale under real queue-pressure-like conditions, opens and closes a trading day, and the counted-cash variance is correct to the paisa. |

**Correction, found Sprint 60 (checking every milestone's own exit criterion against what was
actually verified when each was declared closed, the same discipline Sprints 58/59 applied to
M4's release gate):** [backlog.md §3](../17-sprints/backlog.md#3-m2--fully-decomposed-2026-08-14)
declared M2 "fully closed, all 6 items done" (Sprint 30) — true of the backlog items, but this
row's own Exit criteria above were never actually satisfied: the reference low-end device this
row names has never been owned (unchanged from Sprint 43's finding through today,
[device-matrix.md §3](../14-testing/device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly)),
so `tap-count-audit.md`'s budget has only ever been checked as a design-time trace, never
"measured, not estimated" as this row's own text explicitly requires. M0 and M4's own
hardware-dependent exit criteria were each closed (or, for M4, deliberately left open) with an
honest caveat naming this exact gap; M2's closure carried no equivalent caveat until now.

## M3 — Customers & Returns

| | |
| --- | --- |
| **Scope** | Customers (basic — name, phone, purchase history), Returns & Refund (basic, with auto-approval threshold and the interrupt/queue approval split from [returns.md](../11-api/endpoints/returns.md)), the conflict-resolution policy for `customers` live end to end. |
| **Entry criteria** | M2 demonstrated. |
| **Exit criteria** | A return against a real prior sale completes correctly, refunding the right amount and reversing the right stock; a field-edit conflict on a customer record (two devices, same field, different values) surfaces in the exact business-language form specified in [conflict-resolution.md](../13-offline-sync/conflict-resolution.md), not a placeholder. |
| **Demonstrable outcome** | A shop owner processes a real return end to end, including one deliberately provoked multi-device conflict, and reads the resulting prompt without needing it explained. |

## M4 — Reports, Settings, and Release Readiness

| | |
| --- | --- |
| **Scope** | The four reports (daily sales, top products, stock value, low stock), Settings (tax, currency, printer, receipt), and closing out every remaining Phase 10–14 gap that blocked full release readiness (physical printer/device testing, the full offline adversarial suite green in CI). |
| **Entry criteria** | M3 demonstrated. |
| **Exit criteria** | The **pilot-ready** half of [release-checklist.md §2](../14-testing/release-checklist.md#2-pilot-ready-checklist) is fully satisfied — every box, not most of them. |
| **Demonstrable outcome** | A full simulated trading day, on real hardware, with a real printer ([MTS-03](../14-testing/manual-test-scripts.md#mts-03--a-full-simulated-trading-day-on-real-hardware-with-a-real-printer)), executed and evidenced. |

**Correction, found 2026-08-16 decomposing this milestone in [backlog.md §5](../17-sprints/backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point):**
this row's own Scope line originally named "the 10× load test" as M4 content, but the Exit criteria
row already restricts M4 to [release-checklist.md](../14-testing/release-checklist.md)'s
**pilot-ready** tier (§2) — the 10× connection-pool load test is a **commercial-launch-ready** gate
(§3), a separate, later tier this milestone's own exit criterion deliberately excludes. Removed from
Scope rather than left as a standing inconsistency between this table's two rows; the load test
remains real, tracked scope for whenever commercial launch is actually approached (M5 or a future
milestone), not silently dropped.

## M5 — First Real Shop

| | |
| --- | --- |
| **Scope** | No new product scope — this milestone is the actual pilot recruitment and onboarding described in [pilot-plan.md](pilot-plan.md). |
| **Entry criteria** | M4 demonstrated. |
| **Exit criteria** | One real, consenting shop has completed at least one full real trading day on the product, unassisted past the initial onboarding session. |
| **Demonstrable outcome** | The [success-metrics.md](../01-vision/success-metrics.md) "never-stop-selling" row — sales lost to system failure — measured against a real shop's real day, not a simulation. |

## Why V1 is six milestones, not one

Per this phase's own rule, the first milestone is a narrow vertical slice specifically so a wrong
architectural assumption is discovered at the lowest possible cost — M0 exists to make that concrete
rather than aspirational. M1–M4 then layer in exactly the 16 V1 modules from
[scope-and-release-slices.md](../01-vision/scope-and-release-slices.md), grouped by the dependency
order [dependency-graph.md](dependency-graph.md) establishes, not by an arbitrary equal split. M5 is
deliberately scoped as **zero new product work** — a milestone whose entire content is "put it in
front of a real shop" is the concrete expression of this project's own founding emphasis on learning
from real usage before building further.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Six outcome-based V1 milestones (M0–M5) defined with entry/exit criteria and a demonstrable-to-a-shop-owner outcome each; no calendar dates, per this document's deliberate scope. |
| 0.1.1 | 2026-08-16 | M4's Scope row corrected: removed "the 10× load test," which belongs to release-checklist.md's commercial-launch tier (§3), not the pilot-ready tier (§2) M4's own Exit criteria row already restricts to — found decomposing M4 to item grain in backlog.md §5. |
| 0.1.2 | 2026-08-21 | Sprint 60: found M2's own closure (backlog.md, Sprint 30 — "fully closed, all 6 items done") carried no caveat against this row's own Exit criteria, which require the tap-count-audit.md budget "measured on the reference low-end device... not estimated" — a device that has never been owned, unchanged since Sprint 43. M0 and M4's own hardware-dependent exit criteria were each closed with an honest caveat naming this exact gap; M2's was not, until now. Corrected with a dated note under M2's row. |
