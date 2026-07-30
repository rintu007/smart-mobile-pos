# Manual Test Scripts

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** QA Lead
> **Approved by:** _pending_

The scripted human checks [test-strategy.md §5](test-strategy.md#5-what-is-deliberately-not-automated)
named — printers, scanning, a real trading day. Per this phase's rule, **"manual" means scripted and
evidenced**: every script below specifies numbered steps, a pass/fail criterion per step, and the
evidence to capture. "I tried it and it seemed fine" is not an acceptable record of having run one
of these.

---

## MTS-01 · Thermal printer — both widths, real hardware

**Devices:** at least one 58 mm and one 80 mm Bluetooth ESC/POS printer, per
[device-landscape.md](../reference/device-landscape.md)'s market research (dialect variation between
cheap manufacturers is real and only physical testing resolves it, per that document's own note).

| Step | Action | Pass criterion | Evidence |
| --- | --- | --- | --- |
| 1 | Pair the printer via the app's printer-setup flow | Pairing completes without a crash or hang | Screen recording |
| 2 | Print the worked-example receipt from [receipt-design.md §3](../10-design-system/receipt-design.md#3-worked-example--58-mm) | Every line present, correctly aligned, tabular money columns actually aligned on the physical paper (not just in preview) | Photo of the physical receipt |
| 3 | Print a receipt with a long product name requiring truncation | Truncates cleanly with `…`, never wraps mid-word, never breaks the column alignment of the lines after it | Photo |
| 4 | Disconnect the printer mid-print | The app surfaces a clear, actionable error (per [voice-and-tone.md](../10-design-system/voice-and-tone.md)), the sale itself remains completed and unaffected — printing failure never blocks or reverses a sale, per [BR-034](../02-business-requirements/business-requirements.md)/[BR-035](../02-business-requirements/business-requirements.md) | Screen recording |
| 5 | Repeat steps 1–4 on the second printer width/model | Same results — this is specifically testing for ESC/POS dialect variation between units, not re-testing the same unit twice | Photo + recording per printer |

## MTS-02 · Barcode scanning — real conditions, not a lab bench

| Step | Action | Pass criterion | Evidence |
| --- | --- | --- | --- |
| 1 | Scan a barcode in bright, glare-heavy lighting (near a window) | Resolves within the [performance-test-plan.md §1](performance-test-plan.md#1-client-side-budgets--asserted-on-the-reference-device) budget or fails cleanly to manual search — never an indefinite hang | Screen recording |
| 2 | Scan a barcode in dim lighting | Same | Screen recording |
| 3 | Scan a barcode one-handed, device held at a natural checkout angle | Same, specifically checking the scan target area is reachable one-handed per [device-and-context.md](../05-personas/device-and-context.md)'s finding | Screen recording |
| 4 | Attempt to scan a damaged/partially obscured barcode | Fails to text search cleanly, per [BR-012](../02-business-requirements/business-requirements.md)/[FR-025](../03-functional-requirements/functional-requirements.md) — never a crash | Screen recording |

## MTS-03 · A full simulated trading day, on real hardware, with a real printer

**This is the centrepiece of the release checklist's own exit criterion.** Run on the physical
reference device ([device-matrix.md](device-matrix.md)) with a physical printer (MTS-01's units),
simulating one realistic shop day end-to-end:

| Step | Action | Pass criterion |
| --- | --- | --- |
| 1 | Open the trading day with a starting float | Day opens, float recorded |
| 2 | Complete 10+ cash sales, at least one with a discount, at least one split payment | Every sale completes, prints/shares correctly, stock decrements correctly |
| 3 | Process one return against an earlier sale in this same session | Return completes, refund correct, stock increments correctly |
| 4 | Toggle the device to airplane mode partway through, continue selling 5+ more sales fully offline | Every offline sale completes with no degradation, per this phase's "never stop selling" objective |
| 5 | Restore connectivity | The sync indicator ([sync-ui.md](../13-offline-sync/sync-ui.md)) shows the pending count, then drains it within [performance-test-plan.md §2](performance-test-plan.md#2-sync-budgets)'s budget |
| 6 | Close the trading day, enter a counted-cash figure with a deliberate small variance | Variance computed and displayed correctly, matching manual arithmetic done independently by the tester |
| 7 | Review the full day's sales history and receipts on-device | Every sale from steps 2–4 is present, correct, and in the right order |

**Evidence required:** a single continuous screen recording of the entire session (steps 1–7), plus
photos of every printed receipt, plus the tester's independently-computed expected cash-variance
figure alongside the app's — a mismatch between the two is treated as a release-blocking finding,
not a rounding footnote.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Three scripted suites: printer (both widths), barcode scanning under real conditions, and the full real-hardware trading-day simulation with explicit evidence requirements per step. |
