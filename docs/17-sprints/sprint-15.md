# Sprint 15

> **Dates:** 2026-08-13 – 2026-08-13 (single-day, same pattern as Sprints 02–14)
> **Milestone:** M0 — Walking Skeleton (backlog item 10)
> **Status:** Closed

## Goal

Let a Cashier print a physical receipt for a completed sale over Bluetooth ESC/POS —
[backlog.md item 10](backlog.md#1-m0--walking-skeleton-fully-decomposed), the second-to-last M0
item before item 11's end-to-end proof.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Bluetooth ESC/POS receipt print (58 mm), against receipt-design.md's worked example | Receipt & Printing | 2.0 | 6 (POS core loop, done Sprint 09) |

Mobile only — this is the first M0 module with zero backend component (no server involvement in
printing at all). See
[receipt-printing/specification.md §1](../modules/receipt-printing/specification.md#1-purpose-and-business-context)
for the exact cut: shop name only in the header (no address/GSTIN/cashier name — none are cached
locally), no discount/tax/split-payment (M0 has none), 58 mm only, no printer-setup screen (pairing
happens in the phone's own Bluetooth settings).

## Capacity check

2.0 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — the first native-plugin (Bluetooth) integration in
      this project, genuinely new integration surface.
- [x] Documentation capacity reserved: `receipt-printing/specification.md` (new), backlog.md,
      module registry, implementation-log, README bumps.

## Risks

- **Cannot be verified against a physical printer this sprint** — named directly, not glossed
  over: [manual-test-scripts.md — MTS-01](../../14-testing/manual-test-scripts.md#mts-01--thermal-printer--both-widths-real-hardware)
  requires real Bluetooth ESC/POS hardware, which is a founder action per
  [device-matrix.md §3](../../14-testing/device-matrix.md#3-this-is-a-founder-action-not-an-engineering-one--stated-plainly)'s
  own already-established precedent (the physical reference device). The full software stack —
  receipt content, ESC/POS byte encoding, the Bluetooth transport's connect/write/disconnect
  sequencing — is built and unit-tested against real in-process encoding logic; only the actual
  ink-on-paper step is unverified.
- **First native-plugin dependency** (`print_bluetooth_thermal`) — added Android manifest
  permissions (`BLUETOOTH`, `BLUETOOTH_ADMIN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`) matching the
  plugin's own documented requirement exactly, verified against its example manifest rather than
  guessed.

## Definition of Done

- [x] `receipt-printing/specification.md` (new), all 11 sections, 🟢 Approved.
- [x] `ReceiptFormatter` builds a `ReceiptDocument` from a `SaleDetail` + shop name, matching
      receipt-design.md's structure narrowed to M0's actual local data.
- [x] `EscPosReceiptEncoder` turns a `ReceiptDocument` into real ESC/POS bytes via
      `esc_pos_utils_plus`, 58 mm.
- [x] `BluetoothPrinterRepository` wraps `print_bluetooth_thermal`'s connect/write/disconnect,
      always disconnecting even on failure.
- [x] A `print` action on `/sales-history/:id` opens a printer picker and surfaces the result.
- [x] `flutter analyze` clean; `flutter test` clean, 75/75 (up from 60 — 15 new tests across the
      formatter, encoder, and Bluetooth repository).
- [x] Android manifest permissions added, matching `print_bluetooth_thermal`'s own documented
      requirement.
- [x] No secret, token, or key written to logs or committed to source.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset — named, not silently assumed:** MTS-01's physical
printer verification (a founder action, tracked separately, not blocking this sprint's closure),
80 mm, the PDF/share-sheet equivalent, a printer-setup/pairing screen, M0's own remaining item (11).

## Demo script

**Run 2026-08-13** — `flutter test` (no physical printer needed for this half; see Risks for what
that does and doesn't prove):

1. `ReceiptFormatter` produces the correct shop name, invoice number, date, per-line amounts
   (plain, no ₹), total, and payment labels from a worked `SaleDetail` fixture. ✅
2. A line whose product is missing from the local cache falls back to showing its raw
   `product_id`. ✅
3. `EscPosReceiptEncoder` produces a non-empty byte stream; every text field is present in the
   encoded stream; the stream ends with the full-cut command. ✅
4. `BluetoothPrinterRepository`: no printers listed when permission/Bluetooth is off; paired
   devices returned otherwise; a failed connect never attempts a write; a failed or throwing write
   still disconnects; `printBytes` returns `true` only when both connect and write succeed. ✅

**Not run, named explicitly:** MTS-01's real-hardware script — no Bluetooth ESC/POS printer is
available in this environment. Tracked as the founder's own next step once a printer is on hand,
same category as every other physical-hardware gap this project has already named rather than
silently claimed closed.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. One thing worth naming regardless: this is the first
M0 module built entirely without a backend component, and the first whose Definition of Done
includes an explicitly-named, DoD-excluded verification step (the physical print) rather than
either faking it or blocking the sprint on hardware that doesn't exist yet — a deliberate
precedent for any future hardware-dependent module (a barcode scanner's real-device edge cases,
a cash drawer trigger) that hits the same shape of gap.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | Sprint 15 planned and built same-day: `receipt-printing/specification.md` written first, `ReceiptFormatter`/`EscPosReceiptEncoder`/`BluetoothPrinterRepository` built and unit-tested (75/75, up from 60), a printer-picker + print action wired into `/sales-history/:id`. Physical-printer verification (MTS-01) named as a founder action, not run — no hardware available in this environment. |
