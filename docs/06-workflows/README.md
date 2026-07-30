# Phase 06 — Business Workflows

> **Status:** 🔵 In review — all 7 deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Business Analyst / CTO

## Charter

| | |
| --- | --- |
| **Objective** | Map every end-to-end business process, including its failure paths, so the data model in Phase 07 is designed against real sequences rather than guessed entities. |
| **Inputs** | Phases 03 and 05 (both 🔵/🟡 In review — see their own open items). |

**Scope note (revised 2026-07-30):** this charter was originally written before
[scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) pinned the V1 boundary.
Suppliers/Purchase Orders/Goods Receipt (Procurement), Exchange/Store Credit/Warranty (Returns
depth), and Stock Transfer/Delivery all belong to V2–V4. This phase specifies the **13 V1
workflows** in full depth and lists the deferred ones for traceability only — detailing them now
would reopen exactly the scope creep Phase 01 fought to close.

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`workflow-catalogue.md`](workflow-catalogue.md) | 13 V1 workflows + 10 deferred (V2–V4), indexed by persona and frequency | 🔵 In review |
| [`sales-workflows.md`](sales-workflows.md) | WF-001–WF-008: onboarding, cash/discount/split sale, hold/resume, cancel, day open/close | 🔵 In review |
| [`inventory-workflows.md`](inventory-workflows.md) | WF-009–WF-011: opening stock, adjustment (incl. damage/expiry as reasons), stock count | 🔵 In review |
| [`returns-workflows.md`](returns-workflows.md) | WF-012–WF-013: return, high-value approval | 🔵 In review |
| [`procurement-workflows.md`](procurement-workflows.md) | Deliberate V2 placeholder — V1 needs no supplier/PO to receive stock | ⚪ Deferred by design |
| [`offline-workflows.md`](offline-workflows.md) | All 13 V1 workflows re-traced offline; 3 real divergences flagged forward to Phase 13 | 🔵 In review |
| [`state-machines.md`](state-machines.md) | Sale, Return, Trading Day, Sync Item — all exhaustive; Purchase Order/Delivery deferred | 🔵 In review |

## Exit criteria

- [x] Every workflow is a Mermaid diagram plus a numbered step table — all 13.
- [x] Every workflow documents its failure paths (no stock, no connection, no printer, no
      permission, payment declined, app killed mid-flow) — including "not applicable" stated
      explicitly where a failure mode doesn't apply, rather than left silent.
- [x] Every workflow has a tap count measured against its budget, or an explicit, justified
      exception (WF-001 onboarding is time-budgeted, not tap-budgeted).
- [x] Every state machine's transitions are exhaustive — Sale (4×4), Return (5×5), Trading Day
      (3×3), Sync Item (5×5) all fully resolved in [state-machines.md](state-machines.md).
- [x] Money-touching workflows (WF-002–WF-004, WF-012, WF-013) document their reversal path.

**Three findings surfaced during this phase, flagged forward to Phase 13, not resolved here:**
offline approvals are provisional until sync and need a defined business-process response when
rejected late; Trading Day's per-store-vs-per-device scoping is unresolved for multi-device shops;
return lookup is bounded by what has synced to the device in front of the customer. Also: a real
scope gap was found — "Partial Payment" in the founding brief maps to a credit-tab feature not
actually covered by any existing `BR`, recommended for V2 grouping with Store Credit rather than
built ad hoc now.

## Rules

- Diagrams are Mermaid, inline. Text diffs; binary images rot.
- The offline trace is not optional for any workflow. "It requires connectivity" is an acceptable
  answer, but it must be a written and justified one.
