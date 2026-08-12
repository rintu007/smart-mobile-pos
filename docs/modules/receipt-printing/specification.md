# Module Specification — Receipt & Printing

> **Status:** 🟢 Approved
> **Module:** Receipt & Printing
> **Slice:** V1 — this document scopes only backlog.md item 10's M0-minimal cut, not the full
> [receipt-design.md](../../10-design-system/receipt-design.md) shape (§1)
> **Version:** 0.1.0
> **Last updated:** 2026-08-13
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 15](../../17-sprints/sprint-15.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Lets a Cashier print a physical receipt for a completed sale over Bluetooth ESC/POS —
[backlog.md item 10](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)
("Bluetooth ESC/POS receipt print (58 mm), against
[receipt-design.md](../../10-design-system/receipt-design.md)'s worked example"), the last piece
[milestones.md — M0](../../16-milestones/milestones.md#m0--walking-skeleton)'s exit criterion
needs before item 11's end-to-end proof.

**Deliberately narrow scope, found while writing this spec:** [receipt-design.md §2](../../10-design-system/receipt-design.md#2-layout--common-structure-two-widths)'s
full layout needs shop address, GSTIN, cashier name, a discount/tax breakdown, and split-payment
line — of which M0's local cache has **none**. Company & Store Setup never caches a store's
address locally (only `id`/`name`, per `store_context_api.dart`'s own parsing); no local
display-name cache exists for the signed-in user; discount/tax/split-payment are all M1/M2 scope,
already named in `pos/specification.md §1`. This sprint's receipt is therefore: shop name only
(header), invoice number + date (no cashier line), line items, a total (no discount/tax
breakdown, since M0 has none to show), and a fixed `Paid (Cash)` line (M0 is cash-only). Each
omission mirrors a gap this project already named elsewhere — not a new one invented here.

**Also narrower than the full module:** 58 mm only (backlog item 10's own wording; 80 mm is
receipt-design.md §2's second column, out of scope), no PDF/share-sheet equivalent
(receipt-design.md §4, a separate, later concern), no printer-setup/pairing screen (pairing
happens in the phone's own Bluetooth settings, per every ESC/POS Bluetooth app's usual pattern —
this app only lists already-paired devices and lets the user pick one).

**The one thing this document cannot close, by its own design's admission:** receipt-design.md §5
already states plainly that a receipt layout is "proven correct on paper... but not yet proven
correct on a physical... thermal printer," and
[manual-test-scripts.md — MTS-01](../../14-testing/manual-test-scripts.md#mts-01--thermal-printer--both-widths-real-hardware)
requires "at least one 58 mm... Bluetooth ESC/POS printer" to actually run. This sprint builds and
unit-tests the full software stack against a real in-process ESC/POS encoder (§10) but **does not,
and cannot, verify it against a physical printer** — the same category of gap
[device-matrix.md §3](../../14-testing/device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly)
already named for the physical reference device: a founder action, not an engineering one, tracked
here rather than silently assumed passed.

## 2. Business rules

- A receipt's content is built once, from the same `SaleDetail` `/sales-history/:id` already loads
  (Sprint 10) — never a second, independent read of `sales`/`sale_line_items`, so a printed
  receipt can never disagree with what the app itself shows for that sale.
- Per [BR-034](../../02-business-requirements/business-requirements.md)/[BR-035](../../02-business-requirements/business-requirements.md):
  a printing failure never blocks or reverses the sale it prints — printing is reachable only from
  an already-completed sale's own detail view, so there is no code path where a failed print
  could roll anything back. `BluetoothPrinterRepository.printBytes()` always disconnects, even on
  a write failure or a thrown error, so a failed attempt never leaves the radio in a stale
  connected state for the next attempt.
- Amounts print **without** the ₹ symbol — most thermal printers' default ESC/POS code pages
  (CP437 etc.) can't render the Rupee glyph reliably, and receipt-design.md §3's own worked
  example already shows plain numbers for exactly this reason.

## 3. Database tables and relationships

None — this module reads `SaleDetail` (already assembled by `sales_history`'s own repository,
Sprint 10) and `StoreContext.storeName` (cached locally since Sprint 08). No new local table, no
server involvement at all — printing is entirely on-device.

## 4. API contract

None — no server endpoint exists or is needed. This is the first M0 module with zero backend
component.

## 5. Validation rules (client and server)

None beyond what already exists — the printer picker only ever offers an already-paired device
(no manual MAC-address entry, no new input to validate).

## 6. Error handling and user-facing messages

- No paired Bluetooth devices found, or Bluetooth is off/permission not granted: the picker shows
  an inline message rather than an empty, unexplained list (`printer_picker_empty`).
- A connection failure surfaces as a `SnackBar` naming the failure; a connection that succeeds but
  whose write fails surfaces "Printer did not accept the receipt." — distinct messages, since the
  two failure points mean different things to a Cashier (retry pairing vs. retry the print).

## 7. Offline behaviour

Fully offline by construction — printing is a local Bluetooth radio operation with no network
involvement whatsoever, the same "no server round-trip to fail or wait on" reasoning
sales-invoices/specification.md §7 already established for local-only reads.

## 8. Realtime behaviour

None — not applicable to a local hardware action.

## 9. UI specification

A `print` `IconButton` on `/sales-history/:id`'s `AppBar` (`sale_detail_print_button`) — the
natural place a Cashier already is right after completing a sale (via sales history) or looking up
a past one to reprint. Tapping it opens a modal printer picker (`printer_picker_item_<mac>`,
listing every paired Bluetooth device — not filtered to "printers," since neither this app nor the
underlying plugin can distinguish one) or an empty-state message if none are paired
(`printer_picker_empty`). Selecting one connects, prints, and disconnects, surfacing the result via
`SnackBar` (`receipt_print_result`). No new route — a modal dialog, same reasoning `/catalogue/add`'s
FAB and `/pos`'s home-screen button already established for entry points that don't need one.

## 10. Test plan

**Sprint 15 scope:**
- Unit tests (`receipt_formatter_test.dart`, pure Dart, no Flutter binding needed): shop
  name/invoice number/date formatting; every line item's plain (no ₹) amount formatting;
  falls back to `productId` when `productName` is `null` (mirrors
  `sales-invoices/specification.md §2`'s already-established fallback); total/payment labels;
  default vs. custom footer message.
- Unit tests (`esc_pos_receipt_encoder_test.dart`, real `esc_pos_utils_plus` encoding, via
  `TestWidgetsFlutterBinding.ensureInitialized()` since `CapabilityProfile.load()` reads a bundled
  asset): produces a non-empty byte stream; every text field is actually present in the encoded
  stream (a substring check against the decoded bytes — loose but real, not asserting brittle
  byte-exact command sequences); ends with the full-cut command.
- Unit tests (`bluetooth_printer_repository_test.dart`, injected fakes — no real Bluetooth adapter
  exists in CI or this dev machine): returns no printers when permission/Bluetooth is off; returns
  paired devices otherwise; never attempts a write when connect fails; always disconnects, even
  when the write fails or throws; returns `true` only when both connect and write succeed.
- 75/75 `flutter test` (up from 60), `flutter analyze` clean.

**Explicitly deferred, and explicitly not verifiable without hardware (§1):** MTS-01's physical
printer run, 80 mm, the PDF/share-sheet equivalent, a printer-setup/pairing screen, GSTIN/address/
cashier-name/discount/tax/split-payment content.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [receipt-design.md §2](../../10-design-system/receipt-design.md#2-layout--common-structure-two-widths)/[§3](../../10-design-system/receipt-design.md#3-worked-example--58-mm) (58 mm layout, worked example) | §1, §9, §10 | **Partially met** — narrowed to M0's actual local data (§1); structurally proven via encoder tests, not yet a physical printout |
| [receipt-design.md §5](../../10-design-system/receipt-design.md#5-what-this-document-does-not-close-out) (physical-printer verification) | — | **Not met, by design** — a founder action (§1), tracked in [manual-test-scripts.md — MTS-01](../../14-testing/manual-test-scripts.md#mts-01--thermal-printer--both-widths-real-hardware) |
| [BR-034](../../02-business-requirements/business-requirements.md)/[BR-035](../../02-business-requirements/business-requirements.md) (printing failure never blocks/reverses a sale) | §2, §10 | Met |
| [milestones.md — M0 exit criterion](../../16-milestones/milestones.md#m0--walking-skeleton) ("...print the receipt") | §9 | Software half met — the physical print itself is the founder's own remaining step |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | First version — written to drive Sprint 15's Bluetooth ESC/POS receipt printing (backlog.md item 10). Scope deliberately narrow: 58 mm only, M0's actual local data only, no printer-setup screen, no PDF equivalent. Named, not built: physical-printer verification (MTS-01), a founder action per device-matrix.md §3's own precedent. |
