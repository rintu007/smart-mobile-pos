# Workflow Catalogue

> **Status:** 🔵 In review
> **Phase:** 06 — Business Workflows
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Business Analyst / CTO
> **Approved by:** _pending_

Index of every workflow, in scope and deferred. **13 V1 workflows** are fully specified in this
phase's other documents. **10 deferred workflows** are listed only — they belong to V2/V4 modules
([Suppliers, Purchase Orders, Store Credit, Exchange, Warranty, Stock Transfer](../01-vision/scope-and-release-slices.md))
or V3 ([Delivery, QR Ordering](../01-vision/scope-and-release-slices.md)) and will be specified when
their own release slice reaches this phase — detailing them now would be exactly the scope creep
[scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) was written to prevent.

---

## V1 workflows

| ID | Workflow | Owning persona | Frequency | Module | Specified in |
| --- | --- | --- | --- | --- | --- |
| WF-001 | Shop onboarding (setup) | Owner | Once per shop | Company & Store Setup | [sales-workflows.md](sales-workflows.md) |
| WF-002 | Complete a single-item cash sale | Cashier | Very high (core loop) | POS | [sales-workflows.md](sales-workflows.md) |
| WF-003 | Complete a sale with a discount | Cashier, Manager (approval) | High | POS | [sales-workflows.md](sales-workflows.md) |
| WF-004 | Complete a sale with split payment | Cashier | Medium | POS | [sales-workflows.md](sales-workflows.md) |
| WF-005 | Hold and resume a sale | Cashier | Medium–high | POS | [sales-workflows.md](sales-workflows.md) |
| WF-006 | Cancel an in-progress sale | Cashier | Medium | POS | [sales-workflows.md](sales-workflows.md) |
| WF-007 | Open trading day | Cashier, Owner | Daily | Cash Drawer | [sales-workflows.md](sales-workflows.md) |
| WF-008 | Close trading day | Cashier, Owner | Daily | Cash Drawer | [sales-workflows.md](sales-workflows.md) |
| WF-009 | Record opening stock | Manager, Owner | Once per product | Inventory | [inventory-workflows.md](inventory-workflows.md) |
| WF-010 | Record a stock adjustment | Manager, Inventory Staff | Medium | Inventory | [inventory-workflows.md](inventory-workflows.md) |
| WF-011 | Perform a stock count and reconcile | Manager | Periodic (weekly/monthly) | Inventory | [inventory-workflows.md](inventory-workflows.md) |
| WF-012 | Process a return | Cashier | Medium | Returns | [returns-workflows.md](returns-workflows.md) |
| WF-013 | Approve a high-value return | Manager, Owner | Low | Returns | [returns-workflows.md](returns-workflows.md) |

Every V1 workflow above is re-traced offline in [offline-workflows.md](offline-workflows.md), and
the money-touching ones (WF-002–WF-004, WF-012, WF-013) have documented reversal paths per this
phase's exit criteria.

## Deferred workflows (V2–V4) — listed only

| ID | Workflow | Target release | Why deferred |
| --- | --- | --- | --- |
| WF-D01 | Exchange | V2 | Groups with Returns depth; needs the full returns model V1 deliberately kept basic. |
| WF-D02 | Store credit issue / redeem | V2 | Monetary-liability feature — [scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) groups these deliberately, not scattered across phases. |
| WF-D03 | Warranty claim | V2 | Same grouping as above. |
| WF-D04 | Partial / deferred payment ("credit tab") | V2 | **Scope gap discovered during this phase** — see the callout in [sales-workflows.md](sales-workflows.md#scope-gap-partial--deferred-payment-credit-tab). Recommended to group with Store Credit (WF-D02), not built as a standalone V1 feature. |
| WF-D05 | Supplier creation | V2 | Procurement module, out of V1 boundary. |
| WF-D06 | Purchase order creation / approval | V2 | Same. |
| WF-D07 | Goods receipt against a purchase order | V2 | Same — V1 receives stock only via Opening Stock and Stock Adjustment (WF-009/WF-010). |
| WF-D08 | Stock transfer between outlets | V4 | Requires multi-outlet UI, deferred alongside Warehouse. |
| WF-D09 | Delivery assignment / tracking | V3 | Requires Shipping & Delivery module. |
| WF-D10 | QR customer ordering / checkout | V3 | Requires the digital catalogue and online payment. |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial catalogue: 13 V1 workflows fully scoped for this phase, 10 deferred workflows listed for traceability. |
