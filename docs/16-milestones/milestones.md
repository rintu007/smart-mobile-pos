# Milestones

> **Status:** 🔵 In review
> **Phase:** 16 — Milestones
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
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
| **Scope** | The four reports (daily sales, top products, stock value, low stock), Settings (tax, currency, printer, receipt), and closing out every remaining Phase 10–14 gap that blocked full release readiness (physical printer/device testing, the 10× load test, the full offline adversarial suite green in CI). |
| **Entry criteria** | M3 demonstrated. |
| **Exit criteria** | The **pilot-ready** half of [release-checklist.md](../14-testing/release-checklist.md) is fully satisfied — every box, not most of them. |
| **Demonstrable outcome** | A full simulated trading day, on real hardware, with a real printer ([MTS-03](../14-testing/manual-test-scripts.md#mts-03--a-full-simulated-trading-day-on-real-hardware-with-a-real-printer)), executed and evidenced. |

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
