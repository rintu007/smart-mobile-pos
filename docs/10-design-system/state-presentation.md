# State Presentation

> **Status:** 🔵 In review
> **Phase:** 10 — Design System
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** UI-UX Lead
> **Approved by:** _pending_

How **loading**, **empty**, **error**, **offline**, and **permission-denied** appear — the same
way, everywhere, so a screen built in Phase 18 doesn't invent its own version of "no data" or "the
network is down." Every route in [route-map.md](../09-navigation/route-map.md) must resolve to one
of the states below (or its normal populated state); a route with an unhandled sixth state is a
defect.

---

## 1. Loading

| Rule | Detail |
| --- | --- |
| Never network-gated | Per [navigation-model.md §6](../09-navigation/navigation-model.md#6-offline-rendering--never-an-indefinite-spinner), loading reflects **local** data resolution only (reading from the Drift cache), never waiting on a network round-trip to show something. |
| Treatment | Skeleton placeholders matching the eventual content's shape (per [components.md](components.md)'s per-component loading rows) — a spinner is used only for actions with no meaningful content shape (e.g. submitting a payment), never for a screen's initial render. |
| Duration expectation | If local resolution takes over ~300 ms on the reference low-end device ([NFR-024](../03-functional-requirements/non-functional-requirements.md)), that is a performance defect to fix, not a state to design more elaborately around. |

## 2. Empty

Covered structurally in [patterns.md §4](patterns.md#4-empty-state) (genuinely-empty vs.
no-results). This document adds the one rule that applies regardless of flavour: **an empty state
always tells the Cashier/Manager whether this is expected or not.** A brand-new Catalogue and a
Catalogue that failed to sync are both "empty" in the technical sense but must never look the same
— the second is actually the offline-stale state below, not this one.

## 3. Error

| Rule | Detail |
| --- | --- |
| Never a raw error code or stack trace | Per [voice-and-tone.md](voice-and-tone.md) — the Cashier sees a plain-language message; the technical detail is logged (per [audit-model.md](../07-database/audit-model.md)'s logging, not this document's concern) for engineering, never surfaced in the UI. |
| Always paired with a next step | "Retry", "Go back", or (for a genuinely unrecoverable case) "Contact support" — never a message with no action at all, which leaves the Cashier stuck mid-sale with no idea what to do next. |
| Retry is idempotent by construction | Retrying a failed sync or submit is always safe to press more than once — this is guaranteed at the data layer by [identifiers.md](../07-database/identifiers.md)'s client-generated-ID idempotency, not something this UI layer has to protect against separately. |
| Visual treatment | `error` colour (per [foundations.md §2](foundations.md#2-colour--one-seed-two-themes)) **plus** a warning/error icon — colour is never the only signal, consistent with every other semantic-colour rule in this system. |

## 4. Offline

**The most important state in this document**, per [this phase's founding rule](README.md):
"Offline is a first-class visual state, designed deliberately — not a red banner added later."
[device-and-context.md](../05-personas/device-and-context.md) already established that offline is
the *normal* condition, not an exception — the visual language must match that reality.

| Sub-state | Treatment |
| --- | --- |
| **Offline, showing cached data** | A calm, neutral (not `error`-coloured) status chip — "Last updated 4 min ago" or similar — per [components.md §6](components.md#6-chips). Never a full-width alarming banner for a condition the product expects to be in routinely. |
| **Offline, no cached data available yet** | Distinct from the "no results" empty state — the message explicitly names the cause: "Not available offline yet — will appear once you're back online," not a generic "no data" that implies the data doesn't exist at all. |
| **Offline, action queued for sync** | A neutral "Pending sync" badge/chip on the affected item (e.g. a sale made offline, per [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md)'s provisional numbering) — this is **not** an error state; it is the system working exactly as designed. |
| **Back online, sync in progress** | The determinate progress pattern from [components.md §11](components.md#11-progress--sync-indicator) — "Syncing 12 of 40" — replacing the pending-sync badges as each item confirms. |
| **Sync conflict/rejection** ([sync_rejections](../07-database/schema-server.md) table) | This is the one offline-adjacent case that *is* an error state (§3) — something needs human attention (e.g. a sold-below-zero item after reconciliation) — surfaced distinctly from routine pending-sync, never conflated with it. |

## 5. Permission-denied

Structurally defined in [patterns.md §6](patterns.md#6-permission-denied). The rule this document
adds: permission-denied is a **designed state**, reached only because
[guards-and-redirects.md](../09-navigation/guards-and-redirects.md)'s permission guard already
prevents navigation to most restricted routes in the first place — this state exists for the
residual cases (a Manager's role changes mid-session on a shared device, per
[device-and-context.md](../05-personas/device-and-context.md)'s device-sharing finding) rather than
being the primary defence.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial five-state specification; offline given the most detailed treatment per this phase's founding rule. |
