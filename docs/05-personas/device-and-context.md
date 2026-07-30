# Device & Context

> **Status:** 🔵 In review
> **Phase:** 05 — User Personas
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Flutter Engineer / UI-UX Lead
> **Approved by:** _pending_

The physical and environmental conditions the app is actually used in — distinct from the
per-persona detail in [personas.md](personas.md), this document consolidates the environmental
factors that cut across personas, for direct input to Phase 09 (Navigation) and Phase 10 (Design
System). Grounded in [device-landscape.md](../reference/device-landscape.md); not re-derived here.

---

## Devices

| Factor | Finding | Design consequence |
| --- | --- | --- |
| Device class | Budget 5G Android, ₹13,000–25,000 band, is the realistic device — not a flagship, not necessarily a 2 GB-RAM bottom-tier device either | Reference low-end device (Phase 14) selected from this band, not assumed from the original founding-brief figure — see [NFR-024](../03-functional-requirements/non-functional-requirements.md). |
| Device ownership | Often shop-provided and **shared across shifts/staff**, not one device per person | The app must support fast user-switching at shift handover without a full logout/re-login cycle feeling heavyweight — a design question for Phase 09, flagged here as a real constraint, not yet solved. |
| Device age/condition | Screens may be cracked, aged, with degraded touch sensitivity at edges | Critical touch targets (payment confirmation, cart actions) should sit away from screen edges where physical damage concentrates. |

## Connectivity

| Factor | Finding | Design consequence |
| --- | --- | --- |
| Primary connection | Mobile data, not fixed broadband — [device-landscape.md](../reference/device-landscape.md) | Confirms offline-first as the normal condition, not the exception, per [project-vision.md §8](../01-vision/project-vision.md) Principle 1. |
| Connection quality | Flaky/throttled far more often than a clean binary online/offline | Test profile must include throttled 3G/weak-4G, not just airplane-mode — [NFR-026](../03-functional-requirements/non-functional-requirements.md). |

## Physical environment

| Factor | Applies most to | Design consequence |
| --- | --- | --- |
| **Lighting** — bright glare near a shop entrance/window, dim toward the back of a store or in a stockroom | Cashier, Inventory Staff | High-contrast UI required in both conditions, not tuned for indoor office lighting; verified against [NFR-020](../03-functional-requirements/non-functional-requirements.md) (WCAG AA) in both light and dark themes. |
| **Noise** — customers, street noise, general shop ambience | Cashier | The app must never rely on audio feedback alone for a critical confirmation (payment success, print complete) — visual and haptic feedback are required, audio is a bonus at most. |
| **One-handed operation** — the other hand is holding a product, a bag, cash, or a delivery box | Cashier, Inventory Staff, Delivery Staff (anticipated) | Primary actions (scan, confirm payment, hold cart) must be reachable one-handed on the device sizes in use; this is a direct input to the tap-count and layout work in Phase 09/10. |
| **Queue pressure / visible time pressure** — a waiting customer is watching the Cashier operate the app | Cashier | This is *the* reason the tap-count budget exists at all ([BR-011](../02-business-requirements/business-requirements.md)) — not an abstract performance target but a response to a real, uncomfortable social pressure. |
| **Shared, dirty, or gloved hands** — relevant in some V1 verticals (hardware, some grocery contexts) more than others | Cashier, Inventory Staff | Not assumed universal, but touch-target sizing already set generously (≥48 dp, [NFR-021](../03-functional-requirements/non-functional-requirements.md)) accommodates reduced touch precision without a vertical-specific redesign. |
| **Interruption** — a sale in progress may be interrupted by a phone call, another customer, or a colleague | Cashier | Ties directly to [BR-013](../02-business-requirements/business-requirements.md) (hold/resume) — this document supplies the *why*: interruption is normal, not exceptional. |

## What this means for Phase 09/10, stated plainly

Every condition above pushes in the same direction: **fewer taps, bigger targets, higher contrast,
no reliance on sustained attention or two free hands, and no assumption of a quiet, well-lit,
uninterrupted session.** A design that only works in a calm office demo is not tested against this
document's findings.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial consolidation of device and environmental-context findings for Phase 09/10 input. |
