# Business Requirements

> **Status:** 🔵 In review — provisional on unconfirmed [OD-01](../01-vision/open-decisions.md); ready for review otherwise
> **Phase:** 02 — Business Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-29
> **Owner:** Business Analyst / Product Manager
> **Approved by:** _pending_

54 requirements (`BR-001`–`BR-054`) covering all sixteen V1 modules plus the cross-cutting offline
sync engine. Each traces to Phase 01 vision, Phase 02 market/regulatory/competitor research, or
both. Each has a testable acceptance criterion — "should be fast" and "user friendly" do not appear
below, per [documentation-standards.md](../00-governance/documentation-standards.md).

**Numbering note:** IDs are permanent and grouped by module for readability, not assigned in a flat
sequence — do not infer priority order from the number. [competitor-analysis.md](competitor-analysis.md)
already cross-references BR-001–BR-004 and BR-010–BR-013 by number; those references are honoured
here.

MoSCoW priority is assigned against the **V1 boundary** ([scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)),
not against the full 62-module wishlist — a "Could have" here is still inside V1 scope.

---

## Group A — Foundational & Cross-Cutting

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-001** | An owner must be able to install the app, create an account, configure their shop, and complete a first sale within 10 minutes, unassisted. | [project-vision.md §12](../01-vision/project-vision.md); the "notebook" segment in [competitor-analysis.md](competitor-analysis.md) has zero switching-cost tolerance. | Must | Median time-to-first-sale ≤ 10 minutes, measured per [success-metrics.md](../01-vision/success-metrics.md), on a first-time user with no prior training. |
| **BR-002** | Shop setup must capture the business's tax-registration status (GST standard regime / Composition scheme / unregistered) with a working default, not a forced technical question. | [RR-001](regulatory-requirements.md#rr-001--tax-registration-status-is-per-shop-not-assumed). | Must | A shop can complete setup without knowing what "Composition scheme" means; the correct default is pre-selected for the most common case and can be changed in one tap. |
| **BR-003** | A sale must be completable, from scan to receipt, with zero network connectivity. | [project-vision.md §8](../01-vision/project-vision.md) Principle 1; this is the product's core differentiator per [competitor-analysis.md](competitor-analysis.md). | Must | With the device in airplane mode, a complete cash sale (scan → payment → receipt) succeeds with no error, no retry prompt, and no degraded feature. |
| **BR-004** | No completed sale may ever be lost, duplicated, or silently altered, regardless of connectivity state, app termination, or device restart during the sale or during sync. | [project-vision.md §8](../01-vision/project-vision.md) Principle 2. | Must | Success metric target of **zero** "sales lost to system failure" and **zero** duplicate-sale rate, per [success-metrics.md](../01-vision/success-metrics.md); verified by the adversarial test suite in Phase 13. |
| **BR-005** | Users must authenticate to use the app, with sessions that survive being offline and can be revoked remotely if a device is lost. | [12-security/README.md](../12-security/README.md). | Must | A user can log in once and use the app offline for an extended period without being forced to re-authenticate; an admin can revoke a specific device's session from another device once connectivity is restored, and the revoked device is blocked from further sync. |
| **BR-006** | A shop must configure its identity, currency, and locale once, during setup, and have it apply consistently across POS, receipts, and reports. | [project-vision.md §12](../01-vision/project-vision.md). | Must | Currency symbol, minor-unit precision, and number formatting are consistent across every screen and printed receipt without per-screen configuration. |
| **BR-007** | The system must record which physical store a sale, stock movement, or user belongs to, even though V1 exposes only one store per shop. | [ADR-0003](../adr/ADR-0003-multi-outlet-modelled-from-day-one.md). | Must | Every stock movement and sale row has a non-null store reference from the first migration; no V1 user-facing screen exposes a store selector. |
| **BR-008** | Access to features and actions must be restricted by role (Owner, Manager, Cashier at minimum), enforced server-side. | [project-vision.md §8](../01-vision/project-vision.md) Principle 8; [05-personas](../05-personas/README.md) permission matrix. | Must | A Cashier-role account attempting a Manager-only action (e.g. issuing a return above a threshold) is rejected by the API even if the mobile UI were bypassed. |
| **BR-009** | Every action that changes money, stock, or permissions must be recorded in an audit trail that cannot be altered or deleted by any application code path. | [project-vision.md §8](../01-vision/project-vision.md); retrofitting an audit trail is impossible once history exists. | Must | Querying the audit log for any completed sale, stock adjustment, or role change returns who, what, when, and the before/after state; no API endpoint exists that can modify or delete an audit row. |

## Group B — Point of Sale

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-010** | A cashier must be able to add a product to the cart by camera-scanning its barcode. | [competitor-analysis.md](competitor-analysis.md) — Vyapar gap, counter-speed selling. | Must | Scanning a known barcode adds the correct product and quantity-1 to the cart in a single action, p95 scan-to-cart-update ≤ 800 ms on the reference low-end device ([success-metrics.md](../01-vision/success-metrics.md)). |
| **BR-011** | A single-item cash sale must be completable in **3 taps or fewer** from an empty cart — this is the **GA** bar; [success-metrics.md §3](../01-vision/success-metrics.md#speed-at-the-counter) allows ≤ 4 as an explicit interim **Pilot**-phase target, not a second, conflicting requirement. | [success-metrics.md §3](../01-vision/success-metrics.md); direct competitive differentiator against Vyapar's accounting-first UX. | Must | Measured tap count for scan → confirm payment → receipt-shown is ≤ 3 on the approved navigation flow ([09-navigation](../09-navigation/README.md) tap-count audit) by GA; ≤ 4 is acceptable at Pilot. |
| **BR-012** | A cashier must be able to find a product by text search when a barcode is missing, damaged, or unscannable. | Barcode scanning fails often enough in real retail (damaged labels, no barcode on loose goods) that search cannot be optional. | Must | Typing a partial product name or SKU returns the matching product within p95 400 ms against a 5,000-item catalogue, offline. |
| **BR-013** | A cashier must be able to hold an in-progress cart and resume it later without losing any line items, and without it affecting stock until the sale actually completes. | Real counters get interrupted; a lost cart is a lost sale opportunity and a frustrated cashier. | Must | A held sale with 3+ line items, quantities, and any applied discount is resumable exactly as left, including after an app restart; no stock movement is recorded for a held (non-completed) sale. |
| **BR-014** | A sale must support being settled across more than one payment method (e.g. part cash, part card) in a single transaction. | Listed explicitly in the founding brief's POS feature set; common in cash-dominant markets with partial digital adoption. | Should | A sale can be recorded as, e.g., 60% cash / 40% card, and the invoice and cash-drawer reconciliation both reflect the correct cash-only portion. |
| **BR-015** | Discounts applied at the point of sale must be attributable to the user who applied them and, where configured, require elevated permission. | Prevents unauthorised margin erosion; ties to BR-008 and BR-009. | Must | A discount beyond a shop-configured threshold cannot be applied by a Cashier-role account without Manager approval, and every applied discount is attributed in the audit trail. |
| **BR-016** | A cashier must be able to cancel an in-progress (not yet completed) sale without any stock or financial trace being recorded. | Distinguishes "changed my mind before paying" from a return, which is a materially different, auditable event. | Must | Cancelling a cart before payment confirmation leaves no stock movement and no audit entry beyond "cart abandoned," distinct from the Returns workflow. |

## Group C — Catalogue (Products, Categories, Units)

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-017** | A product must be creatable with a name, price, unit, category, and optional SKU, barcode, and HSN/SAC code. | [RR-003](regulatory-requirements.md#rr-003--tax-invoice-mandatory-fields) requires HSN/SAC on tax invoices. | Must | A product saved without a barcode is still sellable via search (BR-012); a product saved without an HSN/SAC code is flagged (not blocked) if the shop is in the standard GST regime. |
| **BR-018** | Products must be organisable into a single-level category structure for browsing and reporting. | Founding brief; supports Reports (BR-044) and POS browsing. | Must | Every product belongs to exactly one category; the POS product grid can be filtered by category. |
| **BR-019** | A product must be sellable in a defined unit of measure, including non-integer quantities (e.g. 0.5 kg). | Grocery and hardware verticals routinely sell by weight/volume, not just piece count. | Must | A product configured with unit "kg" accepts a quantity like 0.75 in the POS cart and prices it correctly; a piece-count product rejects a fractional quantity. |
| **BR-020** | New shops must be offered a starter product catalogue appropriate to their declared business type during onboarding. | Directly supports the 10-minute promise (BR-001); [project-vision.md §12](../01-vision/project-vision.md) budgets 3 minutes for "add first products." | Should | Selecting "Grocery" as business type during setup offers an importable starter catalogue of common grocery categories and sample products, reducing manual entry for a first sale. |

## Group D — Inventory (Stock Ledger)

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-021** | A shop must be able to record opening stock for each product when first entering the system. | Nothing downstream (low-stock alerts, stock value reports) is meaningful without a known starting quantity. | Must | Setting an opening quantity for a product creates a single, dated stock-ledger entry; the product's derived balance reflects it immediately. |
| **BR-022** | Completing a sale must decrement the relevant product's stock balance immediately and correctly, including when offline. | [project-vision.md §9](../01-vision/project-vision.md) — stock is an append-only ledger of deltas. | Must | A completed sale of quantity 2 produces a stock-ledger entry of −2 for that product/store, visible in the derived balance without requiring a sync round-trip. |
| **BR-023** | Stock quantity may be corrected via an adjustment that requires a reason (damage, loss, count correction, etc.). | Founding brief; also the mechanism by which a mis-recorded opening stock or sale is corrected without editing history. | Must | A stock adjustment cannot be saved without selecting a reason from a defined list; the adjustment appears as its own ledger entry, not an edit to a prior one. |
| **BR-024** | An owner must be able to see, at a glance, which products are low on stock. | Founding brief; directly serves the "owner sees the truth" pillar of [project-vision.md §5](../01-vision/project-vision.md). | Must | A configurable per-product or shop-wide low-stock threshold surfaces a visible low-stock list/report (feeds BR-045) without requiring the owner to check each product individually. |
| **BR-025** | Every stock movement must be immutable once recorded and individually attributable to its cause (sale, adjustment, opening stock, return). | [project-vision.md §9](../01-vision/project-vision.md); required for the stock balance to ever be trustworthy or auditable. | Must | No API endpoint can update or delete an existing stock-ledger row; the current balance is always the sum of all movements, never a separately stored, independently editable number. |
| **BR-026** | A sale that would take stock below zero must still be permitted to complete, and recorded as an overselling event for the owner's attention, rather than blocked or silently reconciled. | [13-offline-sync/README.md](../13-offline-sync/README.md) — overselling is a business decision, not a merge conflict; blocking a sale over a stock discrepancy violates BR-003/BR-004. | Must | Selling the last recorded unit of a product, then selling one more (e.g. from a second offline device before sync), completes both sales; the resulting negative balance is visibly flagged to the owner, not hidden or auto-corrected. |

## Group E — Customers (Basic)

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-027** | A shop must be able to record a customer's name and phone number, optionally, at the point of sale. | Required by Returns (BR-036, "return by phone number" in the founding brief) and supports basic relationship tracking. | Must | A sale can be completed with no customer attached (walk-in), or attached to a new or existing customer captured in-flow without leaving the sale screen. |
| **BR-028** | A customer's past purchases must be viewable from their profile. | Founding brief; also required to support returns without an original receipt. | Should | Opening a customer's profile lists their prior completed sales with dates and totals. |
| **BR-029** | A cashier must be able to attach an existing customer to a sale by searching name or phone number, without leaving the POS screen. | Keeps BR-011's tap-count budget intact — customer lookup cannot be a separate slow flow. | Should | Typing a partial phone number during checkout surfaces matching existing customers inline. |

## Group F — Sales & Invoices

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-030** | A completed sale must be immutable; any correction must be a new, linked record, never an edit to the original. | [project-vision.md §8](../01-vision/project-vision.md) Principle 2; ties directly to BR-004 and BR-009. | Must | No API endpoint permits modifying a sale after completion; a correction (e.g. a return) is a separate record referencing the original sale's ID. |
| **BR-031** | Every sale to a GST-registered (standard regime) shop must produce an invoice containing all fields required by GST Rule 46. | [RR-003](regulatory-requirements.md#rr-003--tax-invoice-mandatory-fields). | Must | A generated invoice includes GSTIN, sequential invoice number, date, HSN/SAC per line, and per-line tax breakup; this is verified against the actual field list before Phase 10 exits, per the GST-practitioner review flagged in [regulatory-requirements.md](regulatory-requirements.md). |
| **BR-032** | Invoice numbers assigned while offline must be preserved and mapped after sync, never renumbered. | [RR-002](regulatory-requirements.md#rr-002--invoice-numbering-is-sequential-and-gapless-per-financial-year-per-registration); renumbering after the fact breaks the audit trail the law exists to protect. | Must | A sale completed offline retains its original provisional number as a permanent reference after sync, even if a server-assigned canonical number is also attached. |

## Group G — Receipt & Printing

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-033** | A completed sale must be printable to a Bluetooth ESC/POS thermal printer at the point of sale. | Founding brief; "a sale without a receipt is not a sale" ([scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)). | Must | A paired, supported printer produces a legible receipt within 5 seconds of print being triggered, including on a low-end device. |
| **BR-034** | A receipt must be shareable digitally (e.g. as an image or PDF) as an alternative to printing. | [R-05](../01-vision/risks-constraints-assumptions.md) printer fragmentation risk — a failed printer must never be the only path to a receipt. | Must | The share option is available on every completed sale regardless of whether a printer is paired or working. |
| **BR-035** | A printer failure must never block or delay the completion of a sale. | Direct consequence of BR-003/BR-004 — the sale is already complete before printing is attempted. | Must | Simulating a printer disconnected or out-of-paper mid-print does not roll back, delay, or re-prompt the already-completed sale; the digital share fallback (BR-034) remains available. |

## Group H — Returns & Refund (Basic)

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-036** | A return must be initiatable against an original sale, located by receipt, invoice number, or customer phone number. | Founding brief; every real shop has returns on day one ([scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)). | Must | A return can be started by scanning/entering a receipt reference, or by looking up the originating sale via customer phone number when the receipt is unavailable. |
| **BR-037** | A return may cover part or all of an original sale's line items, and must produce correct, reversing stock and financial records. | Founding brief (partial/full return); correctness ties to BR-025 (ledger) and BR-030 (immutability). | Must | Returning 1 of 2 originally sold units restores exactly 1 unit to the stock ledger (a new, positive movement, not an edit) and refunds exactly the value of that unit, including its tax portion. |
| **BR-038** | A return above a shop-configured value threshold must require Manager-role approval before completing. | Fraud/loss-prevention; consistent pattern with BR-015. | Should | A return exceeding the configured threshold is blocked for a Cashier-role account until approved by a Manager-role account, recorded in the audit trail. |

## Group I — Cash Drawer / Day Close

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-039** | A trading day must begin with a recorded starting cash float. | Founding brief; required for BR-040's reconciliation to mean anything. | Must | Opening a day requires entering (or confirming a default) starting cash amount before the POS accepts cash sales. |
| **BR-040** | Closing a trading day must compare the physically counted cash against the system-expected cash, and record both. | [success-metrics.md](../01-vision/success-metrics.md) — "cash reconciliation variance" is a tracked trust metric. | Must | Day close requires entering the counted cash amount; the system displays expected cash (float + cash sales − cash refunds) and records both figures and the variance permanently. |
| **BR-041** | A non-zero cash variance at day close must be visibly flagged, never silently accepted or hidden. | [project-vision.md §8](../01-vision/project-vision.md) Principle 4 — correct beats convenient. | Must | Any non-zero variance is shown prominently before the day-close is finalised, and remains visible in the historical day-close record afterward. |

## Group J — Reports (Core Four)

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-042** | An owner must be able to view total sales for a given day, and trend across recent days, from their phone. | [project-vision.md §5](../01-vision/project-vision.md); one of the "four numbers an owner actually looks at" ([scope-and-release-slices.md](../01-vision/scope-and-release-slices.md)). | Must | Opening the daily sales report shows today's total and at minimum the trailing 7 days, without requiring an export or a desktop. |
| **BR-043** | An owner must be able to view the total value of current stock on hand. | Founding brief; ties to BR-025's ledger being the source of truth. | Must | The stock value report computes total value as the sum of (current derived balance × cost or price basis, per shop configuration) across all products, refreshed without a manual recalculation step. |
| **BR-044** | An owner must be able to see which products sell the most and which barely sell at all, over a selectable period. | Founding brief ("top products," "slow products"). | Should | The report ranks products by quantity or value sold over a selected date range, distinguishing top and bottom performers. |
| **BR-045** | An owner must be able to see a consolidated list of all products currently below their low-stock threshold. | Directly implements BR-024 as a standalone report. | Must | The low-stock report lists every product below threshold, sorted by how far below threshold it is, without the owner needing to check products individually. |

## Group K — Settings (Tax, Currency, Printer, Receipt)

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-046** | Tax rate(s), inclusive/exclusive pricing mode, and rounding rule must be configurable per shop, with defaults appropriate to its declared registration status (BR-002). | [RR-004](regulatory-requirements.md#rr-004--tax-is-computed-and-rounded-per-line-item); [risk R-06](../01-vision/risks-constraints-assumptions.md). | Must | Changing the shop's tax mode correctly recalculates how new sales compute tax; a worked example with a known input and expected output is verifiable in settings. |
| **BR-047** | Currency symbol and number formatting must be configurable and applied consistently (covered by BR-006; listed here as the settings-surface requirement). | [project-vision.md §12](../01-vision/project-vision.md). | Must | The configured currency and number format is reflected identically on the POS screen, receipt, and every report. |
| **BR-048** | A shop must be able to pair a Bluetooth printer and run a test print from settings. | [R-05](../01-vision/risks-constraints-assumptions.md) printer fragmentation; a shop should discover a printer problem in settings, not mid-sale. | Must | A test print action is available in settings and produces a printed test page (or a clear, specific failure message) without needing to start a sale. |
| **BR-049** | The receipt template's legally required fields (per BR-031) must not be removable by shop-level configuration, while non-mandatory fields (e.g. a thank-you message, logo) may be customised. | Prevents a shop from configuring itself into non-compliance. | Must | Settings UI does not offer a way to disable a mandatory GST field; it does offer customisation of non-mandatory content. |

## Group L — Offline Synchronisation (Cross-Cutting Detail)

Foundational guarantees already stated as BR-003 and BR-004. These four add the operational detail
that [13-offline-sync](../13-offline-sync/README.md) must design against.

| ID | Requirement | Rationale | Priority | Acceptance Criteria |
| --- | --- | --- | --- | --- |
| **BR-050** | The app must attempt to synchronise opportunistically whenever any connectivity becomes available, not on a fixed timer. | [13-offline-sync/README.md](../13-offline-sync/README.md) — a connectivity window may be seconds long. | Must | Restoring connectivity for as little as 10 seconds is sufficient to sync at least one queued operation, verified in the adversarial test suite. |
| **BR-051** | Replaying the same queued operation more than once (e.g. due to a retry after an ambiguous network failure) must never duplicate its effect. | [13-offline-sync/README.md](../13-offline-sync/README.md) idempotency; directly required by BR-004. | Must | Submitting an identical queued sale twice with the same client-generated idempotency key results in exactly one recorded sale server-side. |
| **BR-052** | Two devices making concurrent offline stock changes to the same product must, after both sync, produce a correct combined result — not a conflict requiring manual resolution. | [project-vision.md §9](../01-vision/project-vision.md) — stock deltas compose; this is what makes BR-026 safe. | Must | Two devices each offline-selling 1 unit of a product with starting stock 1 both sync successfully; the resulting balance is −1 (both movements recorded), not a discarded or manually-resolved conflict. |
| **BR-053** | A user must always be able to see, at a glance, whether there are unsynced operations pending. | [13-offline-sync/README.md](../13-offline-sync/README.md) sync-ui requirement; supports trust in an offline-first product. | Must | An unsynced-operations indicator is visible from the main app shell without navigating to a dedicated sync screen. |
| **BR-054** | The app must continue to function correctly for sales and stock recording after multiple consecutive days with no connectivity. | [project-vision.md §8](../01-vision/project-vision.md) Principle 1 — offline is the normal operating mode, not a brief interruption. | Must | Simulating 5 consecutive offline days of normal trading volume produces no data loss, no crash, and no degraded POS functionality; the queue drains correctly once connectivity returns. |

---

## Traceability — every V1 module covered

| V1 Module | Requirements |
| --- | --- |
| Authentication | BR-005 |
| Company & Store Setup | BR-001, BR-002, BR-006, BR-007 |
| Roles & Permissions | BR-008, BR-015, BR-038 |
| Audit Log | BR-009 |
| Categories | BR-018 |
| Units | BR-019 |
| Products | BR-017, BR-020 |
| Inventory — Stock Ledger | BR-021–BR-026 |
| Customers (basic) | BR-027–BR-029 |
| POS | BR-003, BR-010–BR-016 |
| Sales & Invoices | BR-004, BR-030–BR-032 |
| Receipt & Printing | BR-033–BR-035 |
| Returns & Refund (basic) | BR-036–BR-038 |
| Cash Drawer / Day Close | BR-039–BR-041 |
| Reports (core four) | BR-042–BR-045 |
| Settings | BR-046–BR-049 |
| Offline Sync Engine | BR-003, BR-004, BR-050–BR-054 |

Every V1 module has at least one requirement. No requirement above is unassigned to a module.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-29 | Initial 54 requirements across all 16 V1 modules plus offline sync, traced to Phase 01 vision and Phase 02 research. |
