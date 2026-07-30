# Accessibility Profiles

> **Status:** 🔵 In review
> **Phase:** 05 — User Personas
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead
> **Approved by:** _pending_

Four profiles that cut across the personas in [personas.md](personas.md) — not everyone who uses
this product is a confident reader, has typical vision, or shares a first language with whoever
wrote the interface copy. Direct input to Phase 10's `accessibility.md`, and to the numbered
accessibility requirements already set in
[non-functional-requirements.md](../03-functional-requirements/non-functional-requirements.md)
(`NFR-020`–`NFR-023`).

---

## Literacy range

| | |
| --- | --- |
| **Profile** | Ranges from comfortable reading to low-literacy, across Owner, Manager, and Cashier alike — literacy is not something to assume correlates with the role. |
| **Consequence** | Interfaces lead with icons, product images, and recognisable visual patterns before text. Critical actions (confirm payment, print receipt) are never text-only — a recognisable icon accompanies every critical label. Error messages are short, concrete, and avoid abstraction ("Printer not connected" beats "Print operation failed: device unreachable"). |
| **Ties to** | [voice-and-tone.md](../10-design-system/README.md) (Phase 10 deliverable, not yet written) will own the actual copy standard; this profile is the constraint it must satisfy. |

## Language

| | |
| --- | --- |
| **Profile** | The provisional market ([OD-01](../01-vision/open-decisions.md), unconfirmed — India) implies a realistic need for at least one regional language alongside English, not English-only. This is **not yet decided** — no specific language has been chosen, and doing so is blocked on OD-01 confirmation the same way the tax/regulatory content is. |
| **Consequence** | The interface's text layer should be externalised (not hard-coded strings) from the first implementation, even though V1 may ship English-only — retrofitting localisation into hard-coded strings later is exactly the kind of avoidable rework the rest of this documentation set has been designed to prevent. |
| **Open item** | Which language(s), if any, ship in V1 vs. later is a Phase 06/08 decision once OD-01 is confirmed — not decided here. |

## Age-related vision

| | |
| --- | --- |
| **Profile** | The Owner persona skews toward an age range where presbyopia (reduced near-focus ability) is common; small default text sizes and low-contrast "modern minimal" UI trends work against this persona specifically. |
| **Consequence** | Default text sizes are generous, not merely "meets minimum contrast" — and the app must respect the OS-level text-scaling setting rather than fighting it, per [NFR-021](../03-functional-requirements/non-functional-requirements.md)/[NFR-023](../03-functional-requirements/non-functional-requirements.md) and [QA-007](../04-srs/quality-attributes.md) (tested at 130% and 200% OS scale). |

## Colour vision deficiency

| | |
| --- | --- |
| **Profile** | Roughly 1 in 12 men (lower for women) have some form of colour vision deficiency — common enough that "some Cashier, somewhere, has this" should be the design assumption, not an edge case. |
| **Consequence** | No status, warning, or state (low stock, sync pending, discount applied, error) is conveyed by colour alone — an icon, shape, or text label always accompanies it. Already stated as [NFR-022](../03-functional-requirements/non-functional-requirements.md); this profile is the human reason that requirement exists. |

---

## What this means for Phase 10, stated plainly

None of these four profiles is a minority edge case to accommodate as an afterthought — between
low-literacy moments (everyone, under stress or in a rush), age-related vision (a large share of
the Owner persona), and colour vision deficiency (a real, non-trivial fraction of any staff pool),
**most shops will have at least one of these profiles present on any given day.** Phase 10's design
system should be built to these profiles as the default expectation, not as a "high contrast mode"
users have to discover and switch into.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial four accessibility profiles: literacy, language, age-related vision, colour vision deficiency. |
