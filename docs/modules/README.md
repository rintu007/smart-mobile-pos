# Module Registry

> **Status:** 🔵 In review
> **Version:** 0.2.0
> **Last updated:** 2026-08-01
> **Owner:** CTO

The operational tracker for every business module. The strategic rationale for the ordering lives
in [Scope & Release Slices](../01-vision/scope-and-release-slices.md).

Each module gets a folder `modules/<module-name>/` containing `specification.md` with all eleven
sections defined in [Documentation Standards](../00-governance/documentation-standards.md) §7.
**The specification is authored and approved before implementation begins**, not after.

**Status:** ⚪ Not specified · 🟡 Specification draft · 🔵 Specification in review · 🟢 Specification approved · 🔨 In implementation · ✅ Done (meets Definition of Done)

---

## V1 — Sell and Stock

| Module | Slice | Spec | Build | Depends on |
| --- | --- | --- | --- | --- |
| Authentication | V1 | 🟢 [spec](authentication/specification.md) | 🔨 (sign-in, hook, `users` RLS, partial session resolution live; device registration/revocation not yet built) | — |
| Company & Store Setup | V1 | 🟢 [spec](company-store-setup/specification.md) | ⚪ (Sprint 02, not yet started) | Authentication |
| Roles & Permissions | V1 | ⚪ | ⚪ | Authentication |
| Audit Log | V1 | ⚪ | ⚪ | Authentication |
| Categories | V1 | ⚪ | ⚪ | Store Setup |
| Units | V1 | ⚪ | ⚪ | Store Setup |
| Products | V1 | ⚪ | ⚪ | Categories, Units |
| Inventory — Stock Ledger | V1 | ⚪ | ⚪ | Products |
| Customers (basic) | V1 | ⚪ | ⚪ | Store Setup |
| POS | V1 | ⚪ | ⚪ | Products, Stock Ledger, Customers |
| Sales & Invoices | V1 | ⚪ | ⚪ | POS |
| Receipt & Printing | V1 | ⚪ | ⚪ | Sales |
| Returns & Refund (basic) | V1 | ⚪ | ⚪ | Sales, Stock Ledger |
| Cash Drawer / Day Close | V1 | ⚪ | ⚪ | Sales |
| Reports (core four) | V1 | ⚪ | ⚪ | Sales, Stock Ledger |
| Settings — tax, currency, printer, receipt | V1 | ⚪ | ⚪ | Store Setup |
| **Offline Sync Engine** | V1 | ⚪ | ⚪ | *Cross-cutting — designed in Phase 13, built alongside the first modules* |

## V2 — Buy and Grow

Suppliers · Purchase Orders · Goods Receive · Stock Adjustment · Expenses · Brands ·
Product Variants · Exchange · Warranty · Customers (full) · Loyalty & Points · Store Credit ·
Coupons · Promotions · Employee Management · Reports (full) · Web Admin · Backup & Export

## V3 — Reach

QR Ordering · Customer Ordering · Digital Catalogue · Online Payment · Order Tracking ·
Shipping · Delivery · Delivery Assignment · Proof of Delivery · Notifications · Wallet ·
Gift Cards · Membership

## V4 — Scale and Verticals

Multi-outlet · Warehouse · Stock Transfer · Batch Tracking · Expiry Tracking · Serial Numbers ·
Restaurant module · Salon module · Analytics · Accountant role & accounting export

---

## Rules

1. A module enters 🔨 only when its specification is 🟢.
2. Only **one** module is 🔨 at any time — **with one named exception**, added 2026-08-01 after
   Sprint 01/02 actually reached this point: [Phase 18's README](../18-implementation/README.md)
   itself calls the whole M0 walking skeleton "the first module... it touches every architectural
   layer" — a cross-cutting slice through Authentication, Company & Store Setup, Products, Stock
   Ledger, POS, and Sync **by design**, per [milestones.md — M0](../16-milestones/milestones.md#m0--walking-skeleton).
   That was true from Phase 16 onward but never reconciled against this rule's original wording
   until it actually mattered. Resolution, not a workaround: for the duration of M0, this rule's
   "one module" means *M0 itself*, not each individual row below — rows touched by M0's backlog
   ([17-sprints/backlog.md](../17-sprints/backlog.md)) progress to 🔨 together, each only as far as
   M0's own scope needs (Sprint 01 explicitly built only two of Authentication's evaluation-order
   steps, for example — see [its specification](authentication/specification.md)), and each is
   honestly *not* ✅ until its **full** Definition of Done is met, which for most rows below happens
   well after M0 closes. Once M0 is done, this exception ends and Rule 2 governs literally again —
   M1 onward builds one row at a time, no exception needed.
3. A module reaches ✅ only when every Definition of Done box is ticked.
4. This table is updated in the same pull request as the work it describes.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-28 | Initial registry: V1–V4 module lists, all rows ⚪, four operating rules fixed. |
| 0.2.0 | 2026-08-01 | Authentication and Company & Store Setup specifications authored and approved (the former retroactively, catching up to Sprint 01's already-live code). Rule 2 amended with the M0 walking-skeleton exception — a real ambiguity between this rule and Phase 18's own "M0 is the first module" framing, found and fixed rather than silently worked around. |
