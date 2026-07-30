# Theming

> **Status:** 🔵 In review
> **Phase:** 10 — Design System
> **Version:** 0.1.1
> **Last updated:** 2026-07-31
> **Owner:** UI-UX Lead
> **Approved by:** _pending_

The full light/dark Material 3 colour scheme generated from the seed in
[foundations.md §2](foundations.md#2-colour--one-seed-two-themes), and the **measured** proof —
not an assertion — that it clears WCAG AA in both themes. Per this phase's exit criterion,
contrast must be "verified by measurement"; this document is that measurement.

---

## 1. Why both themes are mandatory, not dark-mode-as-afterthought

[device-and-context.md](../05-personas/device-and-context.md) documents two physical-environment
extremes a Cashier actually works in: bright glare near a shop entrance, and dim light toward the
back of a store or in a stockroom. A single theme tuned for one condition fails visibly in the
other. Light and dark themes are therefore both first-class, both shipped at V1, both proven below
— not a light theme with a dark theme "coming later."

## 2. The contrast formula used throughout this document

Per WCAG 2.x, relative luminance for an sRGB channel value `c` (0–1) is:

```
c_lin = c / 12.92                       if c ≤ 0.03928
c_lin = ((c + 0.055) / 1.055) ^ 2.4     otherwise

L = 0.2126·R_lin + 0.7152·G_lin + 0.0722·B_lin
```

Contrast ratio between two colours: `(L_lighter + 0.05) / (L_darker + 0.05)`. AA requires **≥ 4.5:1**
for normal text and **≥ 3:1** for large text (≥18 pt) and UI components/graphics.

## 3. Light theme — measured

| Pair | Foreground | Background | Computed ratio | AA target | Result |
| --- | --- | --- | --- | --- | --- |
| Primary accent on surface | `#0F6B5C` (L = 0.1140) | `#FFFFFF` (L = 1.0000) | **6.40 : 1** | 4.5:1 (text) | ✅ Pass, with margin |
| On-primary text on filled primary button | `#FFFFFF` (L = 1.0000) | `#0F6B5C` (L = 0.1140) | **6.40 : 1** | 4.5:1 (text) | ✅ Pass — same pair, ratio is symmetric |
| Body text on surface | `#1B1C1C` (M3 default `on-surface`, L ≈ 0.012) | `#FFFBFE` (L ≈ 0.987) | **~15.6 : 1** | 4.5:1 (text) | ✅ Pass, large margin — M3 default, unchanged |

**Worked calculation for the load-bearing pair (primary on white):**

`#0F6B5C` → R=15, G=107, B=92 → r=0.0588, g=0.4196, b=0.3608

```
R_lin = ((0.0588+0.055)/1.055)^2.4 = 0.00478
G_lin = ((0.4196+0.055)/1.055)^2.4 = 0.14720
B_lin = ((0.3608+0.055)/1.055)^2.4 = 0.10720

L = 0.2126(0.00478) + 0.7152(0.14720) + 0.0722(0.10720)
  = 0.001016 + 0.105278 + 0.007740
  = 0.11403
```

`#FFFFFF` → L = 1.0 exactly.

```
Contrast = (1.0 + 0.05) / (0.11403 + 0.05) = 1.05 / 0.16403 = 6.40
```

**6.40:1 clears the 4.5:1 text threshold with real margin** — the seed colour was chosen partly
*because* it holds this margin at a desaturation level calm enough to satisfy
[foundations.md](foundations.md)'s "quiet all day" constraint. A more saturated teal would pass
contrast just as easily but would fail the calmness rule; a lighter/more pastel teal would satisfy
calmness but fail contrast. `#0F6B5C` was selected as a point that clears both.

## 4. Dark theme — measured

| Pair | Foreground | Background | Computed ratio | AA target | Result |
| --- | --- | --- | --- | --- | --- |
| Primary accent (dark-tonal, `#6FCFB9`) on dark surface | `#6FCFB9` (L = 0.5152) | `#1A1C1B` (L = 0.0113) | **9.22 : 1** | 4.5:1 (text) | ✅ Pass, large margin — deliberately generous; dark-theme accents desaturate under low ambient light less forgivingly than light-theme accents |
| Body text on dark surface | `#E3E3E1` (M3 default `on-surface` dark, L ≈ 0.7675) | `#1A1C1B` (L = 0.0113) | **~13.3 : 1** | 4.5:1 (text) | ✅ Pass, large margin — M3 default, unchanged |

**Worked calculation for the load-bearing pair (dark-tonal accent on dark surface):**

`#6FCFB9` → r=0.4353, g=0.8118, b=0.7255 → L = 0.2126(0.1591) + 0.7152(0.6240) + 0.0722(0.4853) = 0.5152
`#1A1C1B` → r=0.1020, g=0.1098, b=0.1059 → L = 0.2126(0.01034) + 0.7152(0.01163) + 0.0722(0.01097) = 0.01131

```
Contrast = (0.5152 + 0.05) / (0.01131 + 0.05) = 0.5652 / 0.06131 = 9.22
```

**Both the light-theme and dark-theme primary-accent pairs are measured, not assumed, and both
clear AA with margin.** This closes this phase's contrast exit criterion for the one colour pair
most likely to drift during implementation (the brand accent) — every other pair uses M3's own
already-validated default neutrals, which are not re-derived here.

## 5. Semantic colours — never the sole signal

`error` and `success` (and, later, a neutral "sync pending" tone) are used **only** in combination
with an icon or text label, never alone — per [accessibility.md §4](accessibility.md) and
[accessibility-profiles.md](../05-personas/accessibility-profiles.md)'s colour-vision-deficiency
finding. This document defines the colour values; [state-presentation.md](state-presentation.md)
defines the icon/label pairing rule for each state.

## 6. What this document does not do

It does not re-verify every M3 default neutral pairing (body text, disabled-state grey, divider
colour) — those come pre-validated from Material 3's own accessibility work, and re-deriving them
here would be duplicated effort with no product-specific value. It measures precisely the one
thing that *is* product-specific: the custom seed colour this project chose, in both themes.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Light and dark schemes defined; primary-accent contrast measured and proven ≥AA in both themes. |
| 0.1.1 | 2026-07-31 | **Correction:** the dark-theme body-text contrast ratio was arithmetically wrong (stated ~14.9:1; the document's own luminance figures actually compute to ~13.3:1). Corrected — the AA-pass conclusion is unaffected, only the stated figure. |
