# Device Matrix

> **Status:** 🔵 In review
> **Phase:** 14 — Testing Strategy
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** QA Lead / Principal Flutter Engineer
> **Approved by:** _pending_

The reference low-end device, plus the supported device and OS range — per this phase's exit
criterion, the reference device must be **named and physically available**, not merely specified on
paper.

---

## 1. Supported range

| | Floor | Rationale |
| --- | --- | --- |
| Android version | 8.0+ | [NFR-024](../03-functional-requirements/non-functional-requirements.md), already a deliberate upward revision from the founding brief's original 2 GB/older-Android assumption, based on researched device data — not re-opened here |
| RAM | ≥3 GB | Same source — 2 GB devices remain in the field per [device-landscape.md](../reference/device-landscape.md) but are not the design floor; a 2 GB device is "best effort," not a supported configuration with its own test obligation |
| Screen size | Standard phone form factors within [responsive.md](../10-design-system/responsive.md)'s Compact breakpoint (<600 dp) as the primary target | Tablet (Medium/Expanded) is secondary, per [responsive.md §3](../10-design-system/responsive.md#3-till-screen-across-breakpoints)'s deliberate deferral of a tablet-specific Till layout |

## 2. Reference low-end device — selection criteria, named concretely

Per [device-landscape.md](../reference/device-landscape.md)'s own recommendation ("buy 1–2 actual
devices in the ₹13,000–₹18,000 band as the reference low-end device, rather than assuming a spec"),
the criteria a purchased unit must meet:

- Android 8.0–10 (the oldest OS versions realistically still active in this price band today, per
  [device-landscape.md](../reference/device-landscape.md) — testing against the *floor*, not a
  recent OS version running on old-spec hardware, which would understate real degradation)
- 3–4 GB RAM
- An entry/mid-tier chipset tier typical of this price band (e.g. Snapdragon 4-series or MediaTek
  Helio G-series class — a tier, not a specific SoC model, since exact chipset availability shifts
  month to month)
- Purchase price in the ₹13,000–18,000 band at time of purchase

**A specific current model number is deliberately not named in this document** — consistent with
this documentation set's standing practice of not committing to a specific fast-moving market
detail ahead of the point where it must actually be acted on (the same treatment given to unverified
software tooling, e.g. [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md)). Naming an
exact phone model today risks it being discontinued or repriced by the time Phase 18 actually
purchases it; the criteria above are what a purchasing decision is checked against at that time.

## 3. This is a founder action, not an engineering one — stated plainly

**Physically acquiring 1–2 units matching §2 is an action only the founder/team can take** — no
phase of this documentation exercise can purchase hardware. This is tracked the same way
[OD-06](../01-vision/open-decisions.md) (time capacity) is tracked: a real, named, non-blocking-until-it-blocks
open item. It blocks exactly one thing concretely: **any performance-budget assertion in
[performance-test-plan.md](performance-test-plan.md) that claims to be "measured on the reference
device"** cannot be genuinely satisfied — only simulated/emulated — until a unit meeting §2 is in
hand. Everything else in this phase's design work proceeds regardless.

## 4. Secondary devices — breadth, not depth

Once the reference device is acquired, 1–2 additional devices spanning the supported range's edges
(e.g. one Android 8 device at the RAM floor, one recent mid-range device near the top of the
₹13,000–25,000 band from [device-landscape.md](../reference/device-landscape.md)) round out the
matrix — enough to catch OS-version-specific and RAM-pressure-specific bugs without maintaining a
large device lab disproportionate to a small team's actual capacity.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Supported range fixed from NFR-024; reference-device selection criteria specified without naming an unverifiable specific model; physical acquisition flagged explicitly as a founder action, tracked like OD-06. |
