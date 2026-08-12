# Module Registry

> **Status:** 🔵 In review
> **Version:** 0.10.0
> **Last updated:** 2026-08-12
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
| Authentication | V1 | 🟢 [spec](authentication/specification.md) | 🔨 (sign-in, hook, `users` RLS, partial session resolution live; mobile `/auth/login` screen live and demoed against real Supabase Auth (Sprint 06); device registration/revocation not yet built) | — |
| Company & Store Setup | V1 | 🟢 [spec](company-store-setup/specification.md) | 🔨 (`POST /api/v1/onboarding` live, demoed against real infrastructure; `GET /api/v1/stores` live and verified with a cross-tenant RLS proof, mobile fetch-and-cache built (Sprint 08); `PATCH /stores/{id}` deferred) | Authentication |
| Roles & Permissions | V1 | ⚪ | ⚪ | Authentication |
| Audit Log | V1 | ⚪ | ⚪ | Authentication |
| Categories | V1 | ⚪ | ⚪ | Store Setup |
| Units | V1 | ⚪ | ⚪ | Store Setup |
| Products | V1 | 🟢 [spec](products/specification.md) | 🔨 (`POST /api/v1/products` live, name/price only; mobile local write path (`/catalogue/add`) live, verified against a real on-disk file (Sprint 07); `GET`/`PATCH`/`DELETE`, category/unit, and the sync engine that would push a locally-created product to the server all deferred) | Categories, Units *(named exception — see spec §1: M0's minimal slice doesn't wait on either, per the M0 exception below)* |
| Inventory — Stock Ledger | V1 | ⚪ | ⚪ | Products |
| Customers (basic) | V1 | ⚪ | ⚪ | Store Setup |
| POS | V1 | 🟢 [spec](pos/specification.md) | 🔨 (`POST /api/v1/sales` live, cash-only/no-discount/no-tax; mobile till screen (`/pos`) live — local write path built and tested, verified against a real Drift database, including a multi-row atomicity proof; no stock-ledger effect yet, sync engine not built so the mobile write path and the server endpoint aren't connected yet) | Products, Stock Ledger, Customers *(named exception — see spec §1: M0's minimal slice doesn't wait on Stock Ledger/Customers, per the M0 exception below)* |
| Sales & Invoices | V1 | 🟢 [spec](sales-invoices/specification.md) | 🔨 (mobile local sales list/detail (`/sales-history`) live Sprint 10, reading straight from this device's own local sales — no server `GET /sales*`, no canonical numbering, no permission enforcement; full V1 shape still M1 scope) | POS |
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

   **A second, narrower exception, added 2026-08-12:** Sales & Invoices moved to 🔨 (Sprint 10)
   while POS (an M0 row) was still 🔨 and M0 itself still open — Sales & Invoices was never part of
   M0's backlog, so the exception above doesn't cover it on its own wording. This was a deliberate,
   one-off, founder-directed insertion (the founder's own first hands-on test of the till screen
   surfaced the gap immediately — see [sprint-10.md](../17-sprints/sprint-10.md)), not a standing
   change to how this rule works. Named honestly rather than silently treated as already covered;
   Rule 2 reverts to governing literally (one module at a time, M0 aside) once both M0 and this
   insertion are done.
3. A module reaches ✅ only when every Definition of Done box is ticked.
4. This table is updated in the same pull request as the work it describes.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-28 | Initial registry: V1–V4 module lists, all rows ⚪, four operating rules fixed. |
| 0.2.0 | 2026-08-01 | Authentication and Company & Store Setup specifications authored and approved (the former retroactively, catching up to Sprint 01's already-live code). Rule 2 amended with the M0 walking-skeleton exception — a real ambiguity between this rule and Phase 18's own "M0 is the first module" framing, found and fixed rather than silently worked around. |
| 0.3.0 | 2026-08-01 | Company & Store Setup moved to 🔨: `POST /api/v1/onboarding` implemented and demoed against real infrastructure (Sprint 02). |
| 0.4.0 | 2026-08-01 | Products specification authored and approved; moved to 🔨: `POST /api/v1/products` implemented and demoed live (Sprint 04). Specification explicitly names the gap against its listed "Categories, Units" dependency and against FR-032/FR-035 — M0's minimal slice is name/price only, not the full V1 shape. |
| 0.5.0 | 2026-08-01 | POS specification authored and approved; moved to 🔨: `POST /api/v1/sales` implemented and demoed live (Sprint 05). Specification names the gap against its listed "Stock Ledger, Customers" dependency, against the stock-ledger effect WF-002 requires atomically, and against the still-unbuilt mobile till screen. |
| 0.6.0 | 2026-08-02 | Authentication row updated: mobile `/auth/login` screen built and demoed live against real Supabase Auth (Sprint 06) — the first real Flutter feature screen in the project, closing the gap found in backlog.md item 12. Device registration/revocation remain the only undone part of this module. |
| 0.7.0 | 2026-08-02 | Products row updated: mobile local write path (`/catalogue/add`) built and verified against a real on-disk file (Sprint 07) — the local write and `outbound_queue` enqueue are atomic and idempotent. Nothing yet drains the queue; the sync engine is still the named gap. |
| 0.8.0 | 2026-08-02 | Company & Store Setup row updated: `GET /api/v1/stores` built and verified live with a cross-tenant RLS proof, mobile fetch-and-cache built (Sprint 08) — closes the till screen's `store_id` prerequisite, a real gap found during Sprint 08 planning. |
| 0.9.0 | 2026-08-02 | POS row updated: mobile till screen (`/pos`) built (Sprint 09) — cart, cash-only sale completion, local write path proven atomic across a multi-row transaction. Server endpoint and mobile write path remain independently proven, not yet connected (sync engine, backlog.md item 9). |
| 0.10.0 | 2026-08-12 | Sales & Invoices specification authored and approved; moved to 🔨: mobile local sales list/detail (`/sales-history`) built (Sprint 10), a founder-directed insertion outside M0's own backlog — see Rule 2's new second exception, added this version. |
