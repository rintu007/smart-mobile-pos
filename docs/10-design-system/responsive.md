# Responsive Layout

> **Status:** 🔵 In review
> **Phase:** 10 — Design System
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead / Principal Flutter Engineer
> **Approved by:** _pending_

Breakpoints and the layout adaptations at each, for the small number of device classes actually in
scope. Per [device-and-context.md](../05-personas/device-and-context.md), budget Android phones are
the realistic primary device — this document does not chase phone/tablet parity for its own sake,
it defines what changes and, as importantly, states plainly what **does not**.

---

## 1. Breakpoints

| Breakpoint | Width | Realistic device | Treatment |
| --- | --- | --- | --- |
| **Compact** | < 600 dp | The primary target — budget Android phones, ₹13,000–25,000 band | Single-column layouts throughout; bottom navigation bar (per [navigation-model.md](../09-navigation/navigation-model.md)) |
| **Medium** | 600–839 dp | Large phone (unfolded) or small tablet — a secondary, not primary, target | Catalogue and Reports gain a two-pane list/detail layout; Till remains single-pane (a cart does not benefit from a second pane) |
| **Expanded** | ≥ 840 dp | Tablet landscape — anticipated for some Manager back-office use, not assumed common | Master-detail persistent split view for Catalogue and Reports; bottom navigation becomes a **navigation rail** on the leading edge |

## 2. What changes across breakpoints — and what deliberately does not

This is the clarification this document exists to make explicit, because it is easy to conflate
the two: **the navigation *model* — which 4 destinations exist, which routes live under each, who
can see Reports — is fixed by [Phase 09](../09-navigation/README.md) and does not vary by
breakpoint.** What varies here is purely presentational:

| Fixed by Phase 09 (does not change) | Adapted by this document (does change) |
| --- | --- |
| The 4 destinations (Till, Catalogue, Reports, Settings) | Whether they render as a **bottom bar** (Compact/Medium) or a **navigation rail** (Expanded) |
| Which routes exist and their permissions | Whether a route's content renders single-pane or as one side of a master-detail split |
| The Till quick actions (Hold/Return/Day) | Their icon size and spacing, not their existence or position in the hierarchy |

A screen that behaves differently in *what it lets you do* depending on screen size would be a
navigation defect, not a responsive-design decision — this document only ever adapts layout, never
capability.

## 3. Till screen across breakpoints

The Till (active-sale) screen is deliberately **not** given a two-pane "catalogue beside cart"
tablet layout in V1, despite that being a common POS-tablet pattern elsewhere. Reason: per
[scope-and-release-slices.md](../01-vision/scope-and-release-slices.md) and
[device-and-context.md](../05-personas/device-and-context.md), the primary device is a phone, and
building a second, tablet-specific Till layout is real design and engineering cost for a device
class this product does not primarily target. If tablet-based tills become a validated V2+ need,
this is a dedicated redesign task then, not a default assumed now — consistent with this
documentation set's standing practice of not designing for hypothetical future requirements.

## 4. Text scaling interacts with breakpoints, not just font size

Per [accessibility.md §4](accessibility.md), the OS text-scaling setting (up to 200%) must not
clip content at any breakpoint. On Compact width specifically, this means list items and buttons
use flexible (not fixed) heights — a fixed-height row that fits `bodyLarge` at 100% scale will
clip at 200%, which is treated as a defect exactly as it would be for a badly-chosen colour
contrast.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Three breakpoints defined; explicit fixed-vs-adapted split against Phase 09's navigation model; tablet Till layout deliberately deferred. |
