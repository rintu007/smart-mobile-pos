# Module Registry

> **Status:** 🔵 In review
> **Version:** 0.1.0
> **Last updated:** 2026-07-28
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
| Authentication | V1 | ⚪ | ⚪ | — |
| Company & Store Setup | V1 | ⚪ | ⚪ | Authentication |
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
2. Only **one** module is 🔨 at any time.
3. A module reaches ✅ only when every Definition of Done box is ticked.
4. This table is updated in the same pull request as the work it describes.
