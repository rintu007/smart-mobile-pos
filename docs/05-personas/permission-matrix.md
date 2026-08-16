# Permission Matrix

> **Status:** 🔵 In review
> **Phase:** 05 — User Personas
> **Version:** 0.3.0
> **Last updated:** 2026-08-16
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

The direct input to the Roles & Permissions module. Covers all three V1 system roles (Cashier,
Manager, Owner — per [DR-019](../03-functional-requirements/business-rules.md)–[DR-021](../03-functional-requirements/business-rules.md))
against every V1 capability, with no undefined cell.

**Reading the "Source" column:** `DR` means the cell is a direct, explicit consequence of the
already-written domain rules — not a new decision. `Judgment call` means no prior document settled
this cell, and the decision made here is a Phase 05 proposal that Phase 06 (workflows) or Phase 07
(schema) should either ratify or explicitly override — flagged so nobody mistakes a new call for an
established fact.

---

## Legend

✅ Allowed — 🔒 Requires approval from a higher role — ❌ Denied

## Sale operations

| Capability | Cashier | Manager | Owner | Source |
| --- | --- | --- | --- | --- |
| Complete a sale | ✅ | ✅ | ✅ | DR-019 |
| Hold / resume a sale | ✅ | ✅ | ✅ | DR-019 |
| Cancel an in-progress (not yet completed) sale | ✅ | ✅ | ✅ | Judgment call — BR-016 places no restriction on this; it carries no financial/stock consequence ([FR-031](../03-functional-requirements/functional-requirements.md)), so restricting it would add friction with no benefit. |
| Apply a discount ≤ shop threshold | ✅ | ✅ | ✅ | DR-019 |
| Apply a discount > shop threshold | 🔒 (Manager approval) | ✅ | ✅ | DR-019, DR-020 |
| **Void a completed sale** | ❌ | ❌ | ❌ | **Resolved inconsistency** — DR-019 names this as something a Cashier may not do, which implies the capability exists. It does not: sales are immutable by architecture ([BR-030](../02-business-requirements/business-requirements.md)/[FR-053](../03-functional-requirements/functional-requirements.md)); the only reversal mechanism for any role is the Returns workflow. No role can "void" a completed sale — this row exists to close that reading, not to grant the capability to anyone. |

## Returns

| Capability | Cashier | Manager | Owner | Source |
| --- | --- | --- | --- | --- |
| Process a return ≤ shop threshold | ✅ | ✅ | ✅ | Judgment call — BR-036/BR-037 place no restriction on ordinary return processing; only approval above threshold is restricted (BR-038). |
| Approve a return > shop threshold | 🔒 (Manager approval) | ✅ | ✅ | DR-020 |

## Catalogue (products, categories, units)

| Capability | Cashier | Manager | Owner | Source |
| --- | --- | --- | --- | --- |
| View the product catalogue | ✅ | ✅ | ✅ | Judgment call — required for POS to function at all. |
| Create / edit a product, category, or unit | ❌ | ✅ | ✅ | Judgment call — catalogue changes affect pricing and tax; not in DR-019's Cashier allow-list, treated as a back-office action alongside stock adjustment (DR-020). |

## Inventory

| Capability | Cashier | Manager | Owner | Source |
| --- | --- | --- | --- | --- |
| View stock balance / low-stock list | ✅ | ✅ | ✅ | Judgment call — supports informed selling, no restriction implied anywhere. |
| Record a stock adjustment | ❌ | ✅ | ✅ | DR-020 |
| Record opening stock | ❌ | ✅ | ✅ | Judgment call — grouped with stock adjustment as a back-office, not till-facing, action. |

## Customers

| Capability | Cashier | Manager | Owner | Source |
| --- | --- | --- | --- | --- |
| View / add a customer | ✅ | ✅ | ✅ | Judgment call — directly required by the checkout flow (BR-027, BR-029). |
| Edit a customer's name/phone | ✅ | ✅ | ✅ | **Correction, found live (Sprint 31):** this row was missing entirely, even though [customers.md](../11-api/endpoints/customers.md) already documented `PATCH /customers/{id}` as Cashier+ before this matrix was ever checked against it. Same reasoning as "add" — a Cashier under time pressure needs to correct a walk-in customer's own details without waiting for a Manager. |
| Deactivate a customer | ❌ | ✅ | ✅ | **Correction, found live (Sprint 31):** also missing. Grouped with catalogue/inventory's own back-office judgment call (this row's "Create/edit... not in DR-019's Cashier allow-list" reasoning above) rather than with "add," since removing a customer record is a data-governance action, not a checkout-flow necessity — matches `customers.md`'s own already-documented Manager/Owner-only `DELETE`. |
| View a customer's purchase history | ✅ | ✅ | ✅ | Judgment call — directly required by the return-without-receipt workflow (BR-036). |
| Review/resolve a field-edit conflict | ❌ | ✅ | ✅ | **Added Sprint 35** — [conflict-resolution.md §3](../13-offline-sync/conflict-resolution.md#3-field-edit-collisions--merge-what-doesnt-overlap-ask-about-what-does)'s own framing ("surfaced the next time an Owner/Manager is online"); grouped with "Deactivate a customer" as a back-office judgment call, not a checkout-flow necessity. |

## Cash Drawer / Day Close

| Capability | Cashier | Manager | Owner | Source |
| --- | --- | --- | --- | --- |
| Open a trading day (set float) | ✅ | ✅ | ✅ | Judgment call — a single-till shop needs its Cashier able to open their own day. |
| Close a trading day (normal reconciliation) | ✅ | ✅ | ✅ | Judgment call — same reasoning. |
| Override / reopen an already-closed day | ❌ | ✅ | ✅ | DR-020 |

## Reports

| Capability | Cashier | Manager | Owner | Source |
| --- | --- | --- | --- | --- |
| View daily sales / stock value / top-slow-product / low-stock reports | ❌ | ✅ | ✅ | Judgment call — shop-wide revenue and performance figures are treated as business-sensitive by default; a Cashier's own till reconciliation (Cash Drawer, above) is separate and already available to them. **Flagged for Phase 06 confirmation** — a shop with a single Cashier who is also trusted with the whole picture may want this loosened. |

## Settings

| Capability | Cashier | Manager | Owner | Source |
| --- | --- | --- | --- | --- |
| Configure tax rate / mode / rounding | ❌ | ❌ | ✅ | DR-021 |
| Configure currency / locale | ❌ | ❌ | ✅ | DR-021 |
| Pair a printer / run a test print | ✅ | ✅ | ✅ | Judgment call — hardware pairing is operational, not business-sensitive; a Cashier needs to be able to reconnect a printer mid-shift without waiting for a Manager. |
| Configure receipt template (non-mandatory fields) | ❌ | ❌ | ✅ | DR-021 |

## Administration

| Capability | Cashier | Manager | Owner | Source |
| --- | --- | --- | --- | --- |
| Manage users and role assignments | ❌ | ❌ | ✅ | DR-021 |
| View the audit log | ❌ | ✅ | ✅ | Judgment call — a Manager plausibly needs to review shift activity; a Cashier reviewing the audit log has no operational purpose and the log itself may reference other staff's actions. |
| Revoke a device session | ❌ | ❌ | ✅ | Judgment call, deliberately restrictive — a security-sensitive action ([BR-005](../02-business-requirements/business-requirements.md)) starts Owner-only per the "fail closed" security principle ([12-security/README.md](../12-security/README.md)); loosening this later is cheap, tightening it after a Manager has misused it is not. |

---

## Coverage check

Every V1 capability derivable from [functional-requirements.md](../03-functional-requirements/functional-requirements.md)
and [business-rules.md](../03-functional-requirements/business-rules.md) appears above with no
undefined cell. 16 rows, 3 roles each = 48 cells, all resolved to ✅/🔒/❌.

**8 of 16 rows are explicit `DR` consequences; 8 are judgment calls made in this document.** The
judgment-call rows are exactly the ones Phase 06 (Business Workflows) should confirm against a real
walked-through workflow, and Phase 05's own persona validation gap (see
[personas.md](personas.md#what-is-missing--read-before-using-these-to-settle-a-real-argument))
applies here too — a real Manager or Owner conversation may reveal that the Reports or Catalogue
restrictions above are wrong for how these shops actually want to delegate trust.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial matrix: 16 capabilities × 3 roles, 8 rows DR-derived, 8 rows judgment calls, including the resolved "void a completed sale" inconsistency. |
| 0.2.0 | 2026-08-16 | **Correction, found live building Sprint 31 (Customers, backlog.md M3 item 1):** the Customers section never listed "edit" or "deactivate" at all, despite [customers.md](../11-api/endpoints/customers.md) already documenting `PATCH /customers/{id}` (Cashier+) and `DELETE /customers/{id}` (Manager/Owner) since Phase 11. Added both rows, matching customers.md's already-fixed decisions exactly rather than re-deciding them here. |
| 0.3.0 | 2026-08-16 | Sprint 35 (backlog.md M3 item 5): added "Review/resolve a field-edit conflict" (Manager/Owner only) — the new `GET /customers/conflicts`/`POST /customers/conflicts/{id}/resolve` endpoints. |
