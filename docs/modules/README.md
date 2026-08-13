# Module Registry

> **Status:** 🔵 In review
> **Version:** 0.17.0
> **Last updated:** 2026-08-14
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
| Audit Log | V1 | 🟢 [spec](audit-log/specification.md) | 🔨 (one `sale.completed` entry written server-side, atomic with the sale itself — Sprint 12; every other audit-model.md §1 trigger, including Sprint 11's own stock movements, has no audit coverage yet — named gap) | Authentication |
| Categories | V1 | 🟢 [spec](categories/specification.md) | 🔨 (`POST`/`GET /api/v1/categories` live — Sprint 17, create+list only, live-verified with idempotent creation, cursor pagination, and a cross-tenant RLS proof; `PATCH`/`DELETE`, `products.category_id`, mobile UI, and permission enforcement all deferred — first M1 module, Rule 2 governs literally, no exception) | Store Setup |
| Units | V1 | ⚪ | ⚪ | Store Setup |
| Products | V1 | 🟢 [spec](products/specification.md) | 🔨 (`POST /api/v1/products` live, name/price only; mobile local write path (`/catalogue/add`) live, verified against a real on-disk file (Sprint 07); a locally-created product now actually syncs to the server (Sprint 14's mobile trigger draining `outbound_queue`); `GET`/`PATCH`/`DELETE`, category/unit deferred) | Categories, Units *(named exception — see spec §1: M0's minimal slice doesn't wait on either, per the M0 exception below)* |
| Inventory — Stock Ledger | V1 | 🟢 [spec](inventory/specification.md) | 🔨 (`opening` movement on product creation, `sale` movement on sale completion, each server-side and atomic with its triggering row — Sprint 11; no adjustment workflow, no public stock-movement/balance endpoints, no mobile UI) | Products |
| Customers (basic) | V1 | ⚪ | ⚪ | Store Setup |
| POS | V1 | 🟢 [spec](pos/specification.md) | 🔨 (`POST /api/v1/sales` live, cash-only/no-discount/no-tax, now with a same-transaction `sale` stock movement per line item (Sprint 11) and a same-transaction `sale.completed` audit-log entry (Sprint 12); mobile till screen (`/pos`) live — local write path built and tested, verified against a real Drift database, including a multi-row atomicity proof; the mobile write path and the server endpoint are now actually connected (Sprint 14's mobile sync trigger)) | Products, Stock Ledger, Customers *(named exception — see spec §1: M0's minimal slice doesn't wait on Stock Ledger/Customers, per the M0 exception below)* |
| Sales & Invoices | V1 | 🟢 [spec](sales-invoices/specification.md) | 🔨 (mobile local sales list/detail (`/sales-history`) live Sprint 10, reading straight from this device's own local sales — no server `GET /sales*`, no canonical numbering, no permission enforcement; full V1 shape still M1 scope) | POS |
| Receipt & Printing | V1 | 🟢 [spec](receipt-printing/specification.md) | 🔨 (`ReceiptFormatter`/`EscPosReceiptEncoder`/`BluetoothPrinterRepository` built and unit-tested — Sprint 15, a print action on `/sales-history/:id`; 58 mm only, shop-name-only header; physical-printer verification (MTS-01) named as a founder action, not yet run — no hardware available) | Sales |
| Returns & Refund (basic) | V1 | ⚪ | ⚪ | Sales, Stock Ledger |
| Cash Drawer / Day Close | V1 | ⚪ | ⚪ | Sales |
| Reports (core four) | V1 | ⚪ | ⚪ | Sales, Stock Ledger |
| Settings — tax, currency, printer, receipt | V1 | ⚪ | ⚪ | Store Setup |
| **Offline Sync Engine** | V1 | 🟢 [spec](sync-engine/specification.md) | 🔨 (`POST /api/v1/sync/push` for `product.create`/`sale.create`, `GET /api/v1/sync/pull` for `products` — Sprint 13 backend, live-verified including a dependency-ordering proof and a cursor-pagination bug found and fixed live; mobile trigger built Sprint 14 — `outbound_queue` now actually drains, automatically once per session plus a manual "Sync now" button; no persisted pull cursor and no full connectivity/foreground/timer trigger set — both named trade-offs, not M0's own scope) | *Cross-cutting — designed in Phase 13, built alongside the first modules* |

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

   **A third exception, added 2026-08-14, ending the M0 exception itself:** backlog.md item 11's
   own last step — printing a physical receipt — remains open, blocked on Bluetooth ESC/POS printer
   hardware the founder doesn't yet own ([sprint-16.md](../17-sprints/sprint-16.md)), so M0 is not
   *literally* done by this rule's own original wording. Every other step of item 11 (sign in, add
   a product, sell it fully offline, reconnect, sync) has been run for real on the founder's own
   device and confirmed working, with no bug found. Founder-directed decision, asked and answered
   plainly rather than assumed: M1 begins now regardless, and the physical-print step stays tracked
   separately (in `sprint-16.md`) until printer hardware exists to close it — it does not block M1.
   This is a one-off judgment call about *this specific* remaining item (external hardware, not
   engineering work), not a reinterpretation of what "M0 done" means for any future milestone.
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
| 0.11.0 | 2026-08-13 | Inventory — Stock Ledger specification authored and approved; moved to 🔨: `opening`/`sale` stock movements built (Sprint 11), each atomic with its triggering row — backlog.md item 7, back inside M0's own backlog (no new Rule 2 exception needed). POS row updated to reflect the stock-ledger effect it previously named as missing. |
| 0.12.0 | 2026-08-13 | Audit Log specification authored and approved; moved to 🔨: one `sale.completed` entry built (Sprint 12), atomic with the sale — backlog.md item 8. Named gap: every other audit-model.md §1 trigger, including Sprint 11's own stock movements, still has zero audit coverage. POS row updated to reflect the new audit-log effect. |
| 0.13.0 | 2026-08-13 | Offline Sync Engine specification authored and approved; moved to 🔨: `POST /sync/push` (`product.create`/`sale.create`) and `GET /sync/pull` (`products`) built (Sprint 13) — backlog.md item 9's backend half. Found and fixed a real cursor-pagination off-by-one bug live. Products/POS rows updated: the backend half of sync now exists, but no mobile trigger calls it yet, so on-device writes still aren't actually connected to the server. |
| 0.14.0 | 2026-08-13 | Offline Sync Engine row updated: mobile trigger built (Sprint 14) — `outbound_queue` now actually drains via `POST /sync/push`, local `products` refreshed via `GET /sync/pull`, backlog.md item 9 done in full. Products/POS rows updated: on-device writes are now actually connected to the server, closing the gap Sprint 13 named. |
| 0.15.0 | 2026-08-13 | Receipt & Printing specification authored and approved; moved to 🔨: Bluetooth ESC/POS receipt printing built (Sprint 15) — backlog.md item 10's software half. Physical-printer verification (MTS-01) named as a founder action, not run, matching device-matrix.md §3's own precedent for hardware this project can't test without the founder's own equipment. |
| 0.16.0 | 2026-08-14 | Rule 2's third exception added: M0's own end-to-end proof (item 11) has one step still open (physical receipt printing, blocked on hardware the founder doesn't own), but the founder directed M1 to begin now regardless — asked and answered plainly, not assumed. M1 planning begins this version. |
| 0.17.0 | 2026-08-14 | Categories specification authored and approved; moved to 🔨: `POST`/`GET /categories` built (Sprint 17), live-verified — the first M1 module, Rule 2 governing literally again with no exception needed. |
