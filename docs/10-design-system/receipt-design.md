# Receipt Design

> **Status:** 🔵 In review
> **Phase:** 10 — Design System
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead / Principal Flutter Engineer
> **Approved by:** _pending_

The one artefact in this whole design system that is not rendered by Flutter's widget tree at
all — a thermal receipt is generated as ESC/POS commands (text plus an optional raster logo) sent
to a Bluetooth thermal printer, and, separately, as a PDF for digital sharing. Both must express
the same content; neither is a screenshot of the other.

---

## 1. Why not just "print the screen"

Thermal printers render from ESC/POS commands (or a raster image) at a fixed character width
determined by paper size and the printer's built-in font — not from arbitrary Flutter widgets.
Designing the receipt as its own fixed-width, monospace layout from the start avoids the common
failure mode of a nice-looking app screen that produces a garbled or wrongly-wrapped physical
receipt.

## 2. Layout — common structure, two widths

| Zone | 58 mm (≈32 characters/line) | 80 mm (≈48 characters/line) |
| --- | --- | --- |
| Header | Shop name (centred, bold if the printer supports it), address, GSTIN (if registered — per [RR-001](../02-business-requirements/regulatory-requirements.md)) | Same content, more breathing room — address may fit on one line instead of wrapping to two |
| Invoice meta | Invoice number ([ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) — the **canonical** number once synced, the provisional number with a clear marker if printed before sync), date/time, cashier name | Same |
| Line items | `Name` (truncated with `…` if it overflows one line — never wrapped mid-word, which reads worse on thermal paper than a clean truncation), then `qty x unit-price` and `line-total` right-aligned on the next line | Name and quantity/price can usually share one line at 48 characters — a per-product-name-length decision made at render time, not hard-coded |
| Totals | Subtotal, discount (if any), tax breakdown by rate (per [money-and-tax.md](../07-database/money-and-tax.md)), **Total** in a visually heavier weight | Same |
| Payment | Method(s) and amount(s) — for a split payment ([WF-004](../06-workflows/sales-workflows.md#wf-004--split-payment-sale)), each method on its own line | Same |
| Footer | A configurable one-line thank-you message (per [shop_settings](../07-database/schema-server.md)), never hard-coded | Same |

All monetary values use tabular alignment achieved through fixed-width padding (spaces), since the
thermal font has no "tabular figures" feature to enable — this is the one place tabular alignment
is a manual layout responsibility rather than a font feature, and it is stated here so it isn't
silently dropped during implementation.

## 3. Worked example — 58 mm

```
        SHARMA GENERAL STORE
      12 MG Road, Pune 411001
         GSTIN: 27ABCDE1234F1Z5
--------------------------------
Invoice #A00042      30-Jul-2026
Cashier: Priya                 
--------------------------------
Amul Milk 500ml
  1 x 28.00                28.00
Parle-G Biscuit 200g
  2 x 20.00                40.00
--------------------------------
Subtotal                   68.00
Discount (5%)               3.40
CGST 2.5%                   1.62
SGST 2.5%                   1.62
--------------------------------
TOTAL                      67.84
--------------------------------
Paid (Cash)                70.00
Change                       2.16
--------------------------------
     Thank you, visit again!
```

This is the same worked scenario style as [money-and-tax.md](../07-database/money-and-tax.md)'s
numeric examples — a receipt layout claim is verified against real numbers, not described only in
the abstract.

## 4. PDF equivalent

The PDF (generated for the OS share sheet — email, WhatsApp, etc. — per the `SharePlus` package
already in [project-vision.md](../01-vision/project-vision.md)'s tech stack) mirrors the same
content and column structure at a fixed narrow width (matching the 80 mm proportions, since a PDF
has no physical paper-width constraint but should still read as "a receipt," not a full A4 invoice
layout) using Roboto with tabular figures ([foundations.md §3](foundations.md#3-typography--one-family-tabular-figures-for-money))
rather than a monospace font — the PDF is not paper, so it can use the same type system as the
rest of the app.

## 5. What this document does not close out

Per this phase's exit criterion, receipt layouts must be **tested on physical printers, not only
in preview** — that verification cannot happen inside a documentation phase; it requires
implementation and physical hardware. Consistent with how [Phase 05](../05-personas/README.md)
flagged its persona-validation gap and [accessibility.md §6](accessibility.md#6-what-is-not-yet-verified)
flagged screen-reader verification: **this layout is a design-time specification, proven correct on
paper (§3) but not yet proven correct on a physical 58 mm or 80 mm thermal printer.** That
verification is Phase 14 (Testing Strategy)/Phase 18 (Implementation)'s job, tracked there, not
silently assumed done here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | 58 mm/80 mm layout defined with a worked numeric example; PDF equivalent specified; physical-printer verification flagged as an open Phase 14/18 item. |
