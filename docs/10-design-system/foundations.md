# Foundations

> **Status:** 🔵 In review
> **Phase:** 10 — Design System
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead / Principal Flutter Engineer
> **Approved by:** _pending_

The token vocabulary every other Phase 10 document and every future screen is built from. Nothing
in [components.md](components.md) or [patterns.md](patterns.md) invents a colour, size, or duration
that isn't defined here.

---

## 1. Why Material 3, not a bespoke system

[project-vision.md's tech stack](../01-vision/project-vision.md) already commits the mobile client
to Flutter with Material 3. This phase does not re-open that choice; it makes the specific,
concrete decisions Material 3 leaves open (seed colour, type scale usage, spacing scale) and adds
the POS-specific rules Material 3 has no opinion on (receipt layout, offline state, money
alignment). Building on Material 3 rather than a bespoke system means contrast checking, touch
target sizing, and adaptive layout come from a maintained, free, open-source foundation
(`flutter/material`, part of the Flutter SDK — zero additional dependency) instead of being
reinvented and re-verified from scratch.

## 2. Colour — one seed, two themes

Per [this phase's founding rule](README.md) ("one accent colour... visually quiet"), the entire
palette derives from **one seed colour** via Material 3's tonal palette generation
(`ColorScheme.fromSeed`), not a hand-picked set of brand colours. This is a deliberate constraint:
a hand-picked palette invites a second accent colour to creep in screen by screen; a generated
tonal palette structurally cannot produce that drift.

| Token | Light value | Dark value | Role |
| --- | --- | --- | --- |
| `seed` | `#0F6B5C` (deep, desaturated teal) | *(same seed, dark tonal palette)* | The one accent colour. Chosen deliberately muted — a POS glanced at for eight hours a day is not the place for a saturated, attention-seeking brand colour. Full contrast proof in [theming.md](theming.md). |
| `surface` | `#FFFBFE`-family (M3 default neutral) | `#1A1C1B`-family (M3 default neutral) | Screen background. |
| `on-surface` | Near-black | Near-white | Body text and icons on `surface`. |
| `error` | `#B3261E` (M3 default error) | Lighter error tone | Reserved **exclusively** for destructive/failure states — never reused as a generic "important" colour, so its meaning stays unambiguous. |
| `success` (custom, non-M3-default extension) | `#2E7D32` | Lighter success tone | Confirmation states (payment succeeded, sync complete). Always paired with an icon per [accessibility.md](accessibility.md) — see §4. |

Full light/dark scheme, generated tonal steps, and the measured contrast ratios that prove AA
compliance (not merely assert it) are in [theming.md](theming.md).

## 3. Typography — one family, tabular figures for money

| Token | Value | Rationale |
| --- | --- | --- |
| Font family | Roboto (Flutter's bundled default) | Ships with the SDK — renders correctly offline on first launch with no font download, which matters given [device-and-context.md](../05-personas/device-and-context.md)'s finding that connectivity is routinely poor. A second, "nicer" font is a network dependency and a licensing question this project does not need. |
| Money and quantities | Roboto with `FontFeature.tabularFigures()` enabled | Per [this phase's founding rule](README.md) — digits must align in columns (price lists, receipts, cart totals). This is a rendering feature of the same font, not a second font family. |
| Type scale | M3 default scale (`displayLarge` … `labelSmall`), used as-is | Re-deriving a custom scale would duplicate work Material 3 has already validated for accessibility and rhythm; §4/[accessibility.md](accessibility.md) governs the one deviation (generous default body size). |
| Minimum body text size | 16 sp (M3's `bodyLarge`, not `bodyMedium` or smaller, as the default for any primary reading text) | Per [accessibility-profiles.md](../05-personas/accessibility-profiles.md)'s age-related-vision finding — the Owner persona skews toward presbyopia; defaulting to the scale's larger body size costs nothing and avoids a "technically AA but still too small to read comfortably" outcome. |

## 4. Spacing scale — 4 dp grid

| Token | Value | Typical use |
| --- | --- | --- |
| `space-xs` | 4 dp | Icon-to-label gap |
| `space-sm` | 8 dp | Within a compact control (chip padding) |
| `space-md` | 16 dp | Standard content padding, list item internal spacing |
| `space-lg` | 24 dp | Between distinct sections on a screen |
| `space-xl` | 32 dp | Screen-edge margin on tablet layouts — see [responsive.md](responsive.md) |
| `space-xxl` | 48 dp | Large empty-state / illustration breathing room |

All values are multiples of 4 dp so nothing in the system produces sub-pixel or visually
inconsistent gaps across the device range in [device-and-context.md](../05-personas/device-and-context.md).

## 5. Elevation — tonal, not shadow-heavy

Material 3's **tonal elevation** (a subtle surface-colour shift) is used in preference to heavy
drop shadows. Two reasons, both grounded in Phase 05 findings: (1) budget-device screens in the
₹13,000–25,000 band ([device-and-context.md](../05-personas/device-and-context.md)) often render
soft shadows poorly (banding, muddiness) at low brightness; (2) shadow-heavy UI reads as "busy,"
working against the calm, quiet, all-day-usable interface this phase's rules require.

| Level | Use |
| --- | --- |
| 0 | Base screen surface, the Till cart, list content |
| 1 | Cards, list items that need to visually separate from the base surface (e.g. a held-cart summary) |
| 2 | Bottom sheets, the active numeric keypad surface |
| 3 | Dialogs, confirmation prompts (see [components.md](components.md)) |

Levels above 3 are not used — a POS screen has no legitimate reason to stack more than one modal
layer; if a design needs to, that is a workflow problem to fix in the workflow itself, not a
z-index problem to solve visually.

## 6. Corner radius

| Token | Value | Use |
| --- | --- | --- |
| `radius-sm` | 8 dp | Text fields, chips, small buttons |
| `radius-md` | 12 dp | Cards, list items, dialogs |
| `radius-lg` | 20 dp | Bottom sheets (top corners only) |
| `radius-full` | 999 dp (pill) | The primary "Pay" / "Confirm" action button, and status badges — a consistently pill-shaped primary action is deliberately its own recognisable shape, distinct from every secondary button on screen. |

## 7. Motion

| Token | Duration | Easing | Use |
| --- | --- | --- | --- |
| `motion-fast` | 100 ms | M3 standard (emphasized-decelerate for entrances) | Micro-feedback: button press, chip toggle |
| `motion-standard` | 200 ms | M3 standard | Screen-level transitions, bottom sheet open/close |
| `motion-slow` | 300 ms | M3 standard (emphasized) | Full-screen transitions only (e.g. entering the active-sale screen per [navigation-model.md §3](../09-navigation/navigation-model.md)) |

**Reduced-motion rule:** when the OS-level "reduce motion" accessibility setting is on, every
duration above collapses to an instant (0 ms) cross-fade or cut — never removed as a visual state,
only stripped of its animation. This is a state-management concern owned here, not an
implementation afterthought.

## 8. Iconography

Material Symbols, **Outlined** style by default and **Filled** style reserved for the selected/
active state (e.g. the active bottom-navigation tab), sourced from Flutter's bundled `Icons` set —
again, zero additional dependency, zero offline-availability risk. A custom icon is only introduced
where no Material Symbols icon exists for a POS-specific concept (none identified so far); if one
is needed during Phase 18, it is added to this document before use, not invented ad hoc in a widget
file.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial token set: colour seed, type scale, 4 dp spacing, tonal elevation, radius, motion, iconography. |
