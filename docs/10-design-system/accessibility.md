# Accessibility

> **Status:** 🔵 In review
> **Phase:** 10 — Design System
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead
> **Approved by:** _pending_

The concrete, testable rules that satisfy [accessibility-profiles.md](../05-personas/accessibility-profiles.md)'s
finding that "most shops will have at least one of these profiles present on any given day" — not
a discoverable high-contrast mode, the default behaviour.

---

## 1. Contrast

Both themes are measured, not asserted, in [theming.md](theming.md). The rule this document adds:
**any new colour introduced after this phase must be measured against this same formula before
merge** — [theming.md §2](theming.md#2-the-contrast-formula-used-throughout-this-document) is the
reusable method, not a one-time calculation that only covers the colours known today.

## 2. Touch targets

**Every interactive element is at least 48×48 dp**, per this phase's exit criterion — stated per
component in [components.md](components.md), restated here as the absolute floor with no
exceptions, including:

- Icon-only buttons (Hold/Return/Day in the Till app bar) — the icon may render smaller, but the
  tappable area is padded to 48 dp.
- Adjacent targets have at least 8 dp of separation, per
  [device-and-context.md](../05-personas/device-and-context.md)'s finding on reduced touch
  precision from cracked screens, gloved hands, or one-handed operation.

## 3. Screen reader support

| Rule | Detail |
| --- | --- |
| Every icon-only control has a text semantic label | The Hold/Return/Day quick actions (icons only, visually, per [navigation-model.md §2](../09-navigation/navigation-model.md#2-quick-actions-surfaced-directly-on-the-till-screen--not-buried-in-a-menu)) announce as "Hold sale", "Start return", "Open or close trading day" to a screen reader — never left unlabelled because the icon "looks obvious." |
| Money is announced in full | A screen reader reads "one hundred seventy-three rupees and twenty-four paise," not a raw character-by-character digit string — tabular-figure formatting is a visual concern only ([foundations.md §3](foundations.md#3-typography--one-family-tabular-figures-for-money)) and must not leak into how the value is announced. |
| Live regions for state changes | Sync-status changes (§4 of [state-presentation.md](state-presentation.md)) and payment success/failure announce via an accessible live region — a sighted-only visual change (a chip updating) is not sufficient. |
| Reading order matches visual order | Especially in the Expanded-breakpoint master-detail layout ([responsive.md](responsive.md)) — the list is read before the detail pane, matching left-to-right visual scanning. |

## 4. Text scaling

Supported up to **200%** OS-level text scale without clipping or overlap, per
[accessibility-profiles.md](../05-personas/accessibility-profiles.md)'s age-related-vision finding
and [NFR-021](../03-functional-requirements/non-functional-requirements.md)/[NFR-023](../03-functional-requirements/non-functional-requirements.md).
Concretely: layouts use flexible sizing (§4 of [responsive.md](responsive.md)), never a fixed pixel
height that assumes 100% scale; where horizontal space genuinely runs out at 200% (e.g. a
segmented control label), the control reflows to a vertical stack rather than truncating text with
an ellipsis — truncated critical text (a payment method, a discount amount) is treated as a defect.

## 5. Colour independence

Restated as a single binding rule, gathering every instance already specified individually across
[foundations.md](foundations.md), [theming.md](theming.md), [components.md](components.md), and
[state-presentation.md](state-presentation.md): **no status, selection, or semantic meaning is ever
conveyed by colour as the only signal.** Every one of those documents' colour-carrying elements
(error, success, selected chip, selected segmented-control option, offline chip) already pairs
colour with an icon, shape, or text label — this document is where that cross-cutting rule is
declared once, so it can be checked as a single item during review rather than re-derived per
component.

## 6. What is not yet verified

Consistent with this documentation set's practice of stating gaps plainly rather than implying
false completeness (see [Phase 05's persona-validation gap](../05-personas/README.md)): the rules
above are design-time guarantees. **Actual screen-reader behaviour (TalkBack, the Android
default) and actual 200%-scale rendering have not been tested on a physical device** — that
verification belongs to Phase 14 (Testing Strategy) and Phase 18 (Implementation), not this
documentation phase, and this phase's exit criteria are written to require design completeness,
not device-verified completeness.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Contrast, touch targets, screen reader, text scaling, and colour-independence rules consolidated; device-verification gap flagged for Phase 14/18. |
