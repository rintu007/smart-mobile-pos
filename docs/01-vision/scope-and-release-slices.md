# Scope & Release Slices

> **Status:** 🟢 Approved
> **Phase:** 01 — Project Vision
> **Version:** 1.0.0
> **Last updated:** 2026-07-28
> **Owner:** CTO / Product
> **Approved by:** Founder, 2026-07-28 (OD-04)

---

## 1. The scope problem, stated plainly

The founding brief lists **62 business modules**, ~24 POS features, ~20 inventory features, and
sizeable customer, returns, shipping and reporting sets. Under our own Definition of Done — where a
module includes business rules, schema, API, validation, error handling, offline behaviour,
realtime behaviour, UI, tests and documentation — that is a multi-year programme for a small team.

**This is a scope recommendation, not a refusal.** Everything in the brief stays on the roadmap.
The question is only *ordering*, and ordering is the highest-leverage decision available in
Phase 01, because it determines whether we learn anything from real shops before we have spent all
our time.

The failure mode I am steering us away from is specific and common: eighteen months of building,
sixty modules at 80% each, nothing at 100%, no user has ever run a real day of trading on it, and
the first real customer immediately reveals that our returns model is wrong. **Every incumbent on
our comparison list launched narrow.** Square launched as card-reader-plus-till. Loyverse launched
as POS plus basic stock. Shopify POS launched as a companion to an existing store.

**My recommendation: ship V1 to real shops in four slices, then let their behaviour order
everything after.**

---

## 2. Release slices

### V1 — "Sell and Stock" · the minimum honest POS

The smallest product a real shop can run a full trading day on and be better off than a notebook.
If a module is not required to complete one honest day of trading, it is not in V1.

| Module | Why it is unavoidable in V1 |
| --- | --- |
| Authentication | Account, session, secure token storage. |
| Company / Store setup | Currency, tax basis, shop identity. Drives the ten-minute promise. |
| Products, Categories, Units | Nothing sells without a catalogue. Brands folded into Products for now. |
| Barcode / SKU | Scanning is the speed promise. |
| Inventory — opening stock, stock movements | The append-only ledger. Everything downstream depends on this being right from the very first record. |
| POS — scan, search, quantity, discount, tax, cash payment, hold and resume | The core loop. |
| Receipt — print (Bluetooth ESC/POS) and share | A sale without a receipt is not a sale. |
| Sales & Invoices | The immutable record. |
| Customers (basic) | Name, phone, purchase history. Required by returns. |
| Returns & Refund (basic) | Every real shop has returns on day one. Deferring this makes the product unusable, not merely limited. |
| Cash Drawer / day open & close | Owners reconcile cash daily. Without this they do not trust the app. |
| Reports — daily sales, top products, stock value, low stock | The four numbers an owner actually looks at. |
| Offline sync engine | Principle 1. It is architecture, not a feature, and cannot be added later. |
| Roles & Permissions (Owner, Manager, Cashier) | The minimum to let a second person touch the till. |
| Audit Log | Retrofitting an audit trail loses all history before it existed. Cheap now, impossible later. |
| Settings — tax, currency, printer, receipt | Only these four. |

**Explicitly out of V1, and the reason:**

| Deferred | Reason |
| --- | --- |
| Purchase Orders, Goods Receive, Suppliers | Stock can enter via "opening stock" and "stock adjustment" in V1. Full procurement is V2. |
| Loyalty, Wallet, Store Credit, Gift Cards, Coupons | These create *monetary liabilities*. Getting them wrong costs the shop real money. They deserve their own design cycle, not a rushed one. |
| Warehouse, Stock Transfer, Multi-outlet | Single outlet is 80%+ of the target segment. Multi-outlet changes the tenancy and sync model — it must be designed for in the schema from day one, but not built in V1. |
| QR Ordering / Customer Ordering / Online Payment | Depends on a payment provider decision that is market-specific and unresolved. |
| Shipping & Delivery | Not part of the counter-sale loop. |
| Employee Management, Attendance | Not required to trade. |
| Batch, Expiry, Serial, Variants | Vertical-specific. Required for pharmacy and fashion, which are deferred verticals. **The schema must accommodate them from the start**; the UI does not ship in V1. |
| Warranty, Exchange | V2, alongside full returns. |
| Backup / Restore | Cloud sync *is* the backup in V1. Explicit export ships in V2. |
| Voice Search, Email/WhatsApp receipt | Nice, not load-bearing. |

### V2 — "Buy and Grow"
Suppliers · Purchase Orders · Goods Receive · Stock Adjustment reasons · Expenses · Brands ·
Product Variants · Exchange · Warranty · Full customer profiles · Loyalty & Points · Store Credit ·
Coupons & Promotions · Employee Management · Full report suite · Web admin · Data export.

### V3 — "Reach"
QR Ordering & digital catalogue · Online payment · Customer order tracking · Shipping & Delivery ·
Delivery assignment & proof of delivery · Notifications · Wallet · Gift Cards · Membership.

### V4 — "Scale and Verticals"
Multi-outlet · Warehouse & Stock Transfer · Batch & Expiry (pharmacy) · Serial numbers ·
Restaurant module (tables, KOT, modifiers) · Salon module (appointments) · Advanced analytics ·
Accountant role & accounting-package export.

---

## 3. Ordering rationale

| Ordering rule | Consequence |
| --- | --- |
| Anything that touches the **stock ledger's shape** is designed in V1 even if built in V4 | Schema changes to a ledger with live customer data are the most expensive migrations we will ever face. |
| **Money-liability features** (loyalty, wallet, credit, gift cards) are grouped and deferred together | They share failure modes — double-spend, negative balance, expiry, reconciliation — and are cheaper and safer designed as one unit than scattered. |
| **Vertical-specific features** are deferred until the horizontal core is proven | Otherwise we build a pharmacy feature before knowing whether pharmacies will adopt us. |
| **Anything requiring a payment provider** waits on the launch-market decision | See [OD-01](open-decisions.md). |
| **Audit logging and multi-tenancy** ship in V1 regardless of scope pressure | Both are retro-fit-impossible. |

---

## 4. Permanent scope boundary

Not deferred — **out of scope for the product**. Recorded so it is not relitigated.

| Not building | Why |
| --- | --- |
| Full double-entry accounting | Separate product, separate expertise, established competitors. We export instead. |
| Payroll | Jurisdiction-specific labour law. Enormous liability for tiny value. |
| Manufacturing / bill of materials | ERP territory. |
| Holding or settling customer funds | Regulated activity. Changes what this company legally is. |
| General e-commerce storefront | The QR catalogue serves existing customers, not search traffic. |
| iOS at launch | Android-first is a stated product decision, not an oversight. Flutter keeps the door open at low cost; we walk through it when the market asks, not before. |
| Desktop application | Web admin covers what phones do badly. |

---

## 5. Module registry status

The authoritative per-module build status lives in [docs/modules/README.md](../modules/README.md).
That registry is the operational tracker; this document is the strategic rationale behind it.

---

## 6. Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-28 | Initial draft. Proposes four release slices and a V1 boundary of 16 modules against the 62 in the founding brief. |
| 1.0.0 | 2026-07-28 | Approved as proposed (OD-04). |
