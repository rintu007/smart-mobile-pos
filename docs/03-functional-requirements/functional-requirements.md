# Functional Requirements

> **Status:** 🔵 In review
> **Phase:** 03 — Functional Requirements
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Product Manager / CTO
> **Approved by:** _pending_

84 requirements (`FR-001`–`FR-084`), grouped to mirror
[business-requirements.md](../02-business-requirements/business-requirements.md)'s groups A–L. Each
describes **behaviour**, not interface — screens are Phase 10's concern. Each is atomic: a
requirement joined by "and" has been split. Each states its offline behaviour explicitly, per this
phase's rule — there is no global "offline mode" footnote.

Detailed acceptance criteria live on the traced `BR`; this document does not repeat them. Where an
FR's testability isn't obvious from its own statement, read it alongside its `BR`.

---

## Group A — Foundational & Onboarding

The ten-minute promise ([BR-001](../02-business-requirements/business-requirements.md)) is
decomposed per-step below, per this phase's exit criterion, using the step budgets from
[project-vision.md §12](../01-vision/project-vision.md).

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-001** | Account creation and verification completes within a 2-minute budget. | BR-001 | Requires connectivity — the one onboarding step that must, since an account cannot be verified against a server that has never been reached. |
| **FR-002** | Selecting a business type loads its associated tax, category and unit defaults within the 1-minute step budget, with no network request. | BR-001, BR-002, BR-020 | Fully offline — business-type templates ship bundled with the app. |
| **FR-003** | Shop identity (name, currency, address) is captured within a 2-minute budget with no field required beyond name and currency. | BR-001, BR-006 | Fully offline — saved locally, synced later. |
| **FR-004** | The first three products are added, or a starter catalogue is imported, within a 3-minute budget. | BR-001, BR-020, BR-017 | Fully offline. |
| **FR-005** | A first sale (item selection → payment confirmation → receipt) completes within a 1-minute budget. | BR-001, BR-003, BR-010, BR-011, BR-033 | Fully offline. |
| **FR-006** | Total elapsed time from account creation to first completed sale is measured and recorded for product analytics. | BR-001 | Measurement is captured locally and queued for sync like any other event. |
| **FR-007** | Tax-registration status (standard GST / Composition / unregistered) is captured during setup with a pre-selected default. | BR-002 | Fully offline. |
| **FR-008** | The correct document type (Tax Invoice vs. Bill of Supply) is selected automatically based on captured tax-registration status. | BR-002, BR-031 | Fully offline — selection logic is local. |
| **FR-009** | A complete sale (cart → payment confirmation → stock update → receipt) executes correctly with zero network connectivity. | BR-003 | This requirement **is** the offline case. |
| **FR-010** | A completed sale is never marked failed, retried, or rolled back on the basis of its sync status. | BR-004 | Sync status is informational only; it never gates a sale's completed state. |
| **FR-011** | A queued sale resubmitted more than once, carrying the same client-generated idempotency key, is applied exactly once server-side. | BR-004, BR-051 | Occurs at sync time — the deduplication itself is a server-side guarantee. |
| **FR-012** | No code path — including internal administrative tooling — can edit or delete a completed sale record. | BR-004, BR-030 | Enforced at both the local and server schema layers. |
| **FR-013** | A user authenticates once and the issued session is validated locally for subsequent offline use. | BR-005 | Initial login requires connectivity; subsequent use does not. |
| **FR-014** | An authorised user can revoke another device's session remotely; the revoked device is blocked at its next sync attempt. | BR-005 | Revocation requires connectivity; enforcement happens when the revoked device next reaches the server. |
| **FR-015** | Shop name, currency, and locale are captured once during setup and stored centrally for reuse. | BR-006 | Fully offline. |
| **FR-016** | The configured currency format renders identically across the POS screen, printed receipts, and all reports. | BR-006, BR-047 | Fully offline — rendering is local. |
| **FR-017** | Every sale, stock movement, and store-scoped user record carries a store reference from creation, with no user input required in V1. | BR-007 | Fully offline. |
| **FR-018** | Every user action is checked against the acting user's role-derived permissions, re-validated server-side regardless of client state. | BR-008 | The client enforces a locally cached permission set for UX; the server independently re-validates at sync and rejects if the permission was revoked in the meantime. |
| **FR-019** | A role assignment change is recorded as an auditable event. | BR-008, BR-009 | Role changes require connectivity — this is a server-authoritative entity. |
| **FR-020** | An audit entry (who, what, when, before/after state) is written for every action that changes money, stock, or permissions. | BR-009 | Entries are generated locally and queued for sync like any other event. |
| **FR-021** | No API operation exists that can modify or delete an existing audit entry. | BR-009 | Server-side guarantee; not applicable offline. |

## Group B — Point of Sale

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-022** | A successful camera barcode scan adds the matching product to the active cart at quantity 1. | BR-010 | Fully offline — resolved against the local catalogue cache. |
| **FR-023** | Barcode resolution never issues a network request. | BR-010, BR-003 | Fully offline by construction. |
| **FR-024** | A single-item cash sale completes in 3 or fewer discrete user actions from an empty cart. | BR-011 | Fully offline. |
| **FR-025** | A partial product name or SKU search returns matching results from the local catalogue. | BR-012 | Fully offline. |
| **FR-026** | A held cart's line items, quantities, and discounts are preserved exactly across an app restart until resumed or explicitly cleared. | BR-013 | Fully offline — persisted to local storage. |
| **FR-027** | No stock movement is recorded for a held (non-completed) cart. | BR-013, BR-025 | Fully offline. |
| **FR-028** | A single sale can be settled across two or more payment methods, with the amount attributed to each recorded individually. | BR-014 | Fully offline — each method's amount is a local entry; no live card-network call exists in V1. |
| **FR-029** | A discount exceeding a shop-configured threshold requires Manager-role confirmation before the sale can complete. | BR-015 | Enforced against the locally cached role and threshold; re-validated server-side at sync. |
| **FR-030** | Every applied discount is attributed to the acting user in the audit trail. | BR-015, BR-009 | Fully offline — attribution is captured at the point of application. |
| **FR-031** | Cancelling a cart before payment confirmation leaves no stock movement and no financial record beyond an abandonment entry. | BR-016 | Fully offline. |

## Group C — Catalogue

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-032** | A product can be created with only name, price, unit, and category as required fields. | BR-017 | Fully offline. |
| **FR-033** | SKU, barcode, and HSN/SAC are optional product fields; a missing HSN/SAC is flagged, not blocked, for a standard-GST-regime shop. | BR-017, RR-003 | Fully offline. |
| **FR-034** | A product with no barcode remains addable to a cart via search. | BR-012, BR-017 | Fully offline. |
| **FR-035** | Every product belongs to exactly one category, selected at creation. | BR-018 | Fully offline. |
| **FR-036** | The POS product grid can be filtered by category. | BR-018 | Fully offline. |
| **FR-037** | A product's configured unit determines whether fractional quantities are accepted (e.g. kilogram) or rejected (e.g. piece). | BR-019 | Fully offline. |
| **FR-038** | A fractional quantity is rejected for a product configured with a whole-number unit. | BR-019 | Fully offline. |
| **FR-039** | An importable starter product catalogue is offered, matched to the business type selected during onboarding. | BR-020, BR-001 | Fully offline — bundled with the app, not fetched. |

## Group D — Inventory (Stock Ledger)

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-040** | Setting an initial quantity for a product records a single, dated opening-stock ledger entry. | BR-021 | Fully offline. |
| **FR-041** | A product's current stock balance is derived as the sum of its ledger entries, never stored as an independently editable value. | BR-021, BR-025 | Fully offline — derived from the local ledger cache. |
| **FR-042** | Completing a sale records a negative stock-ledger entry equal to the sold quantity, immediately and without server dependency. | BR-022, BR-003 | Fully offline. |
| **FR-043** | A stock adjustment cannot be saved without a reason selected from a defined list. | BR-023 | Fully offline. |
| **FR-044** | A stock adjustment is recorded as a new ledger entry, never as a modification of an existing one. | BR-023, BR-025 | Fully offline. |
| **FR-045** | A list of products at or below a configurable low-stock threshold (shop-wide or per-product) is available on demand. | BR-024 | Fully offline — computed from the local ledger cache. |
| **FR-046** | No API or local-database operation can update or delete an existing stock-ledger row. | BR-025 | Enforced at both schema layers. |
| **FR-047** | A sale is permitted to complete even where it reduces a product's derived balance below zero. | BR-026, BR-003 | Fully offline. |
| **FR-048** | A product with a negative derived balance is flagged for owner visibility, distinct from the standard low-stock list. | BR-026, BR-024 | Computed locally; visibility across multiple devices may lag until sync. |

## Group E — Customers (Basic)

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-049** | A sale can be completed with no customer attached. | BR-027 | Fully offline. |
| **FR-050** | A new customer's name and phone number can be captured inline during checkout without leaving the sale screen. | BR-027, BR-029 | Fully offline. |
| **FR-051** | A customer's prior completed sales, with date and total, are listed on their profile. | BR-028 | Fully offline from locally synced history; may be incomplete until the device is fully hydrated. |
| **FR-052** | Matching existing customers are surfaced as a cashier types a partial phone number during checkout. | BR-029 | Fully offline — matched against the locally cached customer list. |

## Group F — Sales & Invoices

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-053** | No API or local operation can modify a sale record once it is marked complete. | BR-030, BR-004 | Constraint enforced at both schema layers. |
| **FR-054** | Any correction to a completed sale is represented as a new record referencing the original sale's identifier. | BR-030 | Fully offline. |
| **FR-055** | Every invoice issued by a standard-GST-regime shop includes GSTIN, sequential invoice number, invoice date, and per-line HSN/SAC and tax breakup. | BR-031, RR-003 | Fully offline — fields are computed and rendered locally at sale completion. |
| **FR-056** | A Composition-scheme or unregistered shop's completed sale produces a Bill of Supply, not a Tax Invoice. | BR-002, BR-031 | Fully offline. |
| **FR-057** | A sale completed offline is assigned a provisional invoice number, generated locally without server coordination. | BR-032 | This requirement **is** the offline case. |
| **FR-058** | A sale's original provisional invoice number is preserved permanently after sync; any server-assigned canonical number is attached as an additional reference, never a replacement. | BR-032, RR-002 | Occurs at sync time. |

## Group G — Receipt & Printing

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-059** | A formatted receipt is sent to a paired Bluetooth ESC/POS printer within 5 seconds of the print action. | BR-033 | Fully offline. |
| **FR-060** | A shareable digital receipt (image or PDF) is generated for any completed sale, regardless of printer pairing state. | BR-034 | Generation is fully offline; the chosen share channel's own connectivity requirement is outside our control. |
| **FR-061** | A printer failure, disconnection, or paper-out condition does not delay, roll back, or re-prompt an already-completed sale. | BR-035, BR-004 | Fully offline. |

## Group H — Returns & Refund (Basic)

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-062** | A return can be initiated by locating the original sale via receipt reference, invoice number, or customer phone number. | BR-036 | Fully offline against locally synced sales history; limited if the original sale has not yet reached this device. |
| **FR-063** | A return accepts any subset of the original sale's line items, up to the originally sold quantity per line minus any quantity already returned. | BR-037 | Fully offline. |
| **FR-064** | A return records a positive stock-ledger entry for each returned unit, distinct from the original sale's negative entry. | BR-037, BR-025 | Fully offline. |
| **FR-065** | A return's refunded amount equals the exact value, including tax portion, of the returned line items. | BR-037 | Fully offline. |
| **FR-066** | A return exceeding a shop-configured value threshold is blocked until a Manager-role user approves it. | BR-038, BR-008 | Enforced against the locally cached threshold and role; re-validated at sync. |

## Group I — Cash Drawer / Day Close

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-067** | A starting cash float must be entered or confirmed before the POS accepts cash sales for a new trading day. | BR-039 | Fully offline. |
| **FR-068** | Expected cash at day close is computed as float plus cash sales minus cash refunds, with no manual calculation step. | BR-040 | Fully offline. |
| **FR-069** | Day close requires the counted cash amount to be entered, and records both counted and expected figures permanently. | BR-040 | Fully offline. |
| **FR-070** | A non-zero variance between counted and expected cash is displayed prominently before day-close is finalised, and retained in the historical record. | BR-041 | Fully offline. |

## Group J — Reports (Core Four)

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-071** | The daily sales report shows today's total and at least the trailing 7 days without requiring export. | BR-042 | Fully offline, computed from locally synced data; may be incomplete for a multi-device shop until fully synced. |
| **FR-072** | Total stock value is computed as the sum of (derived balance × cost or price basis) across all products, refreshed with no manual recalculation step. | BR-043, BR-025 | Fully offline. |
| **FR-073** | Products are ranked by quantity or value sold over a user-selected date range. | BR-044 | Fully offline. |
| **FR-074** | Every product below its configured low-stock threshold is listed, sorted by distance below threshold. | BR-045, BR-024 | Fully offline. |

## Group K — Settings (Tax, Currency, Printer, Receipt)

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-075** | Tax rate(s), inclusive/exclusive mode, and rounding rule are configurable, pre-populated with a default matching the shop's declared tax-registration status. | BR-046, BR-002 | Fully offline. |
| **FR-076** | A tax configuration change is reflected correctly in the next new sale immediately, verifiable via a worked example shown in settings. | BR-046, RR-004 | Fully offline. |
| **FR-077** | A Bluetooth printer can be paired and test-printed from settings, independent of any sale. | BR-048 | Fully offline. |
| **FR-078** | A legally mandatory receipt field cannot be disabled via shop-level settings; non-mandatory content remains customisable. | BR-049, RR-003 | Fully offline. |

## Group L — Offline Synchronisation (Cross-Cutting Detail)

| ID | Statement | Traces to | Offline behaviour |
| --- | --- | --- | --- |
| **FR-079** | Synchronisation is attempted immediately upon detecting any network connectivity, not on a scheduled interval. | BR-050 | This requirement governs the transition *out of* offline state. |
| **FR-080** | At least one queued operation is transmitted successfully within a connectivity window as short as 10 seconds. | BR-050 | Applies at the moment connectivity resumes. |
| **FR-081** | A queued operation resubmitted with the same client-generated idempotency key is applied exactly once server-side. | BR-051, BR-004 | Server-side guarantee, exercised at sync. |
| **FR-082** | Two devices' concurrent offline stock-quantity changes to the same product compose as an arithmetic sum after both sync, with no manual conflict resolution. | BR-052, BR-026 | Exercised at sync; the changes themselves were made offline. |
| **FR-083** | A persistent indicator of pending unsynced operations is visible from the main app shell at all times. | BR-053 | Fully offline. |
| **FR-084** | Sales and stock movements are recorded correctly after 5 or more consecutive days without connectivity, with no data loss on reconnection. | BR-054, BR-004 | This requirement **is** the offline case. |

---

## Coverage check

All 54 business requirements (`BR-001`–`BR-054`) are traced by at least one `FR` above. See
[traceability-matrix.md](traceability-matrix.md) for the consolidated `BR → FR → US` view.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial 84 functional requirements across 12 groups, decomposing all 54 business requirements. |
