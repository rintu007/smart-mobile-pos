# Phase 10 — Design System

> **Status:** 🔵 In review — all 9 deliverables drafted
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead

## Charter

| | |
| --- | --- |
| **Objective** | Establish the visual and interaction system so that every screen is assembled from a known vocabulary rather than designed from scratch. |
| **Inputs** | Phases 05 (🟡, hard-blocked on real validation, used here for its research findings) and 09 (🔵 In review). |

## Deliverables

| Document | Content | Status |
| --- | --- | --- |
| [`foundations.md`](foundations.md) | Colour seed, typography, 4 dp spacing scale, tonal elevation, radius, motion, iconography | 🔵 In review |
| [`theming.md`](theming.md) | Material 3 colour scheme, light and dark, contrast **measured** (worked calculations, not asserted) | 🔵 In review |
| [`components.md`](components.md) | 12 components, every state defined: default, pressed, disabled, loading, error | 🔵 In review |
| [`patterns.md`](patterns.md) | 8 recurring compositions, plus a 3-screen composition proof inventing nothing new | 🔵 In review |
| [`state-presentation.md`](state-presentation.md) | Loading, empty, error, offline (5 sub-states), and permission-denied, defined consistently | 🔵 In review |
| [`responsive.md`](responsive.md) | 3 breakpoints; explicit fixed-vs-adapted split against Phase 09's navigation model | 🔵 In review |
| [`accessibility.md`](accessibility.md) | Contrast, 48 dp touch targets, screen reader, 200% text scaling, colour-independence | 🔵 In review |
| [`receipt-design.md`](receipt-design.md) | 58 mm/80 mm thermal layout with a worked numeric example, plus PDF equivalent | 🔵 In review |
| [`voice-and-tone.md`](voice-and-tone.md) | Error/empty-state writing rules with bad/good examples | 🔵 In review |

## Exit criteria

- [x] Every component documents **all** of its states — [components.md](components.md) covers 12
      components with no blank state cells; a component with no legitimate error state (e.g. text
      buttons never carrying long-running actions) states that explicitly rather than leaving it out.
- [x] Colour contrast meets WCAG AA in both light and dark themes, verified by measurement —
      [theming.md §3–4](theming.md#3-light-theme--measured) shows the full luminance/contrast
      calculation for the load-bearing accent pair in both themes (6.40:1 light, 9.22:1 dark).
- [x] No information is conveyed by colour alone — stated once as a binding rule in
      [accessibility.md §5](accessibility.md#5-colour-independence), gathering every instance already
      specified individually across the other documents.
- [x] All touch targets are at least 48 dp — [accessibility.md §2](accessibility.md#2-touch-targets)
      and the per-component rows in [components.md](components.md).
- [x] The system is proven by composing three complete screens from it without inventing anything
      new — [patterns.md §10](patterns.md#10-proof--three-complete-screens-composed-from-this-system-nothing-invented)
      (Till active sale, Catalogue search/detail, Returns processing).
- [~] Receipt layouts are tested on physical printers, not only in preview — **not fully closable
      in a documentation phase.** [receipt-design.md §3](receipt-design.md#3-worked-example--58-mm)
      proves the layout correct on paper with a worked example; §5 explicitly flags physical-printer
      verification as a Phase 14/18 item, following the same practice established in
      [Phase 05](../05-personas/README.md) for its own unmeetable-by-documentation exit criterion.

Five of six exit criteria are fully met. The sixth (physical printer testing) is honestly carried
forward as pending hardware verification, not silently assumed — [accessibility.md §6](accessibility.md#6-what-is-not-yet-verified)
carries the same honest-gap treatment for screen-reader and text-scaling device verification.

## Rules

- **Offline is a first-class visual state**, designed deliberately — not a red banner added later.
  The product is used offline routinely; that state must look intentional and calm, never alarming.
- Money is always displayed in a tabular-figure font so digits align in lists. Misaligned prices
  are misread prices.
- Destructive actions require confirmation stating what will be lost, in the shop's own terms.
- One accent colour. A POS used for eight hours a day must be visually quiet.
