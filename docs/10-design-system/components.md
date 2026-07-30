# Component Catalogue

> **Status:** 🔵 In review
> **Phase:** 10 — Design System
> **Version:** 0.1.1
> **Last updated:** 2026-07-31
> **Owner:** UI-UX Lead / Principal Flutter Engineer
> **Approved by:** _pending_

Every component used anywhere in the product, with every state it can be in. Per this phase's
exit criterion: **a component without a defined error state gets an inconsistent one invented at
implementation time** — so every row below is filled, not left blank for "not applicable" states
that turn out to apply anyway.

All tokens referenced (colour, spacing, radius, elevation, motion) are defined in
[foundations.md](foundations.md); none are re-specified here.

---

## 1. Buttons

| Variant | Default | Pressed | Disabled | Loading | Error |
| --- | --- | --- | --- | --- | --- |
| **Primary (filled, pill radius)** — Pay, Confirm, Save | Filled with primary accent, `on-primary` text | Tonal-darken 8%, `motion-fast` | 38% opacity, no ripple, label unchanged (never hidden — a Cashier must know *what* is disabled, per [voice-and-tone.md](voice-and-tone.md)) | Label replaced by a determinate or indeterminate spinner sized to the button height; button width does not change (prevents layout jump) | N/A — a button does not carry its own error state; the action's result is shown via [state-presentation.md](state-presentation.md), not a red button |
| **Secondary (outlined)** — Cancel, Add another | Outline in `on-surface`, transparent fill | Tonal fill at 8% | Outline at 38% opacity | Same spinner rule as primary | N/A |
| **Text (no container)** — Skip, Learn more | Text only, primary accent | Underline or tonal background flash | 38% opacity | Not used — text buttons never trigger long-running actions | N/A |
| **Destructive (filled, `error` colour)** — Delete product, Discard cart | Filled `error`, white text | Tonal-darken 8% | 38% opacity | Same spinner rule | N/A |

**Touch target:** every button variant, regardless of visual size, has a minimum **48×48 dp** hit
area — per [accessibility.md](accessibility.md) and this phase's exit criterion. A visually
compact chip-sized button still gets invisible padding to reach 48 dp.

## 2. Text input

| State | Treatment |
| --- | --- |
| Default (empty) | Outlined field, floating label, no content |
| Focused | Outline switches to primary accent, `motion-fast` |
| Filled | Outline neutral, label floated above |
| Disabled | 38% opacity, no cursor, no outline colour change on tap |
| Error | Outline and helper text switch to `error` colour, **and** an inline error icon appears at the field's trailing edge — colour is never the only signal, per [foundations.md §2](foundations.md#2-colour--one-seed-two-themes) |
| Loading (async validation, e.g. checking a barcode against the catalogue) | A small inline spinner replaces the trailing icon slot; the field remains editable — validation never blocks typing |

## 3. Numeric keypad — POS-specific, not a generic component

Used for cash tendered, quantity entry, and discount amount. Distinct from the OS system keyboard
by deliberate choice: a dedicated on-screen keypad is faster under
[device-and-context.md](../05-personas/device-and-context.md)'s queue-pressure condition (no
keyboard-type switching, no autocorrect interference with numbers) and works identically across
every device in the target band.

| State | Treatment |
| --- | --- |
| Default | Large-target (≥48 dp per key) 4×3 numeric grid plus a decimal separator and a backspace key |
| Key pressed | `motion-fast` tonal flash, plus a short haptic tick — satisfies [device-and-context.md](../05-personas/device-and-context.md)'s noisy-environment finding (never relies on an audio click alone) |
| Value invalid (e.g. tendered amount less than total) | The confirm button (§1) moves to its disabled state; an inline message states the specific problem (see [voice-and-tone.md](voice-and-tone.md)) — the keypad itself has no "error" skin, the surrounding context does |
| Disabled (e.g. quantity keypad opened for an out-of-stock item mid-entry) | Entire keypad at 38% opacity, non-interactive |

## 4. List item — product / cart line / sale-history row

| State | Treatment |
| --- | --- |
| Default | Leading image or icon, title, one supporting line, trailing value in tabular figures (money or quantity) |
| Pressed | Tonal flash at elevation level 1 |
| Disabled (e.g. an out-of-stock product shown in a catalogue search but not addable) | Content at reduced emphasis (not full 38% opacity — the item must still be *readable*, only its action affordance is muted), trailing badge states why (see §7) |
| Loading (row content not yet resolved, e.g. a product image still loading from cache) | Skeleton block in place of the image only — text renders immediately once known, never blocked on the image |
| Error (e.g. a cart line whose price could not be resolved offline) | Trailing value replaced by an inline warning icon plus "price pending", never a blank or zero value — a silent zero is a worse failure than a visible one |

## 5. Cards

| State | Treatment |
| --- | --- |
| Default | Elevation level 1, `radius-md`, `space-md` internal padding |
| Pressed (when the whole card is tappable, e.g. a held-cart summary card) | Elevation increases to level 2 briefly, `motion-fast` |
| Disabled | 38% opacity, elevation drops to 0 |
| Loading | Full skeleton (title bar + two content lines), never a spinner centred in an otherwise-empty card |
| Error | A dedicated error card layout — icon, one-line message, retry action — defined once in [patterns.md §9](patterns.md#9-error-card), not improvised per screen |

## 6. Chips

| Use | Default | Selected | Disabled |
| --- | --- | --- | --- |
| Filter (category, date range) | Outlined, `on-surface` text | Filled tonal, primary-accent text, a checkmark leading icon (never colour-only selection signal) | 38% opacity |
| Status (e.g. "Synced", "Pending sync", "Offline") | Filled tonal, matched to the semantic colour in [state-presentation.md](state-presentation.md) | N/A — status chips are not interactive | N/A |

## 7. Badges

Small numeric or dot indicators — e.g. the return-approval queue count on the Reports tab (per
[navigation-model.md](../09-navigation/navigation-model.md) / [route-map.md](../09-navigation/route-map.md)).

| State | Treatment |
| --- | --- |
| Count (1–99) | Filled circle, primary accent, white numeral |
| Count (>99) | Displays "99+", never truncates to an ambiguous shortened number |
| Zero | Badge is **absent**, not a badge showing "0" — an empty badge is a common inconsistency this catalogue rules out explicitly |

## 8. Bottom sheet

| State | Treatment |
| --- | --- |
| Opening/closing | Slides from bottom, `motion-standard`, `radius-lg` top corners, elevation level 2 |
| Content loading | Sheet opens immediately at its final height with skeleton content — never opens short and grows once data resolves, which reads as jank |
| Error | Same dedicated error layout as §5 Cards, inside the sheet |

## 9. Dialogs (confirmation)

| State | Treatment |
| --- | --- |
| Default | Elevation level 3, `radius-md`, scrim behind at 32% opacity |
| Destructive confirmation | Per [this phase's founding rule](README.md): **states what will be lost, in the shop's own terms** — e.g. "Remove 3 items and discard this sale?" not "Are you sure?" |
| Loading (confirming action in progress, e.g. voiding requires a server round-trip) | Primary action button enters its §1 loading state; the dialog does not auto-dismiss until the result is known |
| Error (action failed) | Dialog remains open, an inline error message replaces the loading spinner, primary action returns to its default (retryable) state |

## 10. Snackbar / toast

| State | Treatment |
| --- | --- |
| Success (transient) | Auto-dismisses after 4 s, single-line, optional single action ("Undo") |
| Error (transient but actionable) | Does **not** auto-dismiss on its own if it represents a failed critical action (e.g. failed print) — requires explicit dismissal or the retry action, so it can't be missed under queue pressure |
| Offline-context notice | Uses the calm offline treatment from [state-presentation.md](state-presentation.md), never the `error` colour — offline is an expected state, not a fault |

## 11. Progress / sync indicator

| State | Treatment |
| --- | --- |
| Indeterminate (short operation, <2 s expected) | Circular spinner |
| Determinate (bulk sync of a backlog after reconnection) | Linear progress bar with a count ("Syncing 12 of 40") — a spinner alone under-communicates for anything the Cashier might wait on for more than a couple of seconds |
| Stalled/failed | Switches to the error treatment in [state-presentation.md](state-presentation.md), never spins indefinitely — ties to [navigation-model.md §6](../09-navigation/navigation-model.md#6-offline-rendering--never-an-indefinite-spinner) |

## 12. Segmented control

Used for short, mutually exclusive choices (e.g. payment method: Cash / Card / UPI).

| State | Treatment |
| --- | --- |
| Default | Outlined segments, equal width |
| Selected segment | Filled tonal, primary-accent text, plus the selected segment's icon changes from Outlined to Filled per [foundations.md §8](foundations.md#8-iconography) — another non-colour-alone signal |
| Disabled segment (e.g. Card disabled on a cash-only device with no reader paired) | 38% opacity, non-interactive, no explanation inline — the reason belongs in a one-time settings message, not repeated on every sale |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial catalogue: buttons, text input, numeric keypad, list item, cards, chips, badges, bottom sheet, dialogs, snackbar, progress indicator, segmented control — every state defined. |
| 0.1.1 | 2026-07-31 | Linked the Error card cross-reference to patterns.md §9, now that it's actually written. |
