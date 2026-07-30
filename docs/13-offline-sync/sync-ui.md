# Sync UI

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO / UI-UX Lead
> **Approved by:** _pending_

How sync state is shown to a non-technical user, and what they can actually do about it — assembled
entirely from components [10-design-system](../10-design-system/README.md) already defined, per
this phase's exit criteria that sync progress and the unsynced count must be visible **without the
user seeking them out**, and that conflicts are presented in **business language, never technical.**

---

## 1. The persistent, glanceable indicator — never something you have to go looking for

A small status chip, always present in the app bar (per
[components.md §6](../10-design-system/components.md#6-chips) and
[state-presentation.md §4](../10-design-system/state-presentation.md#4-offline)'s calm, non-alarming
offline treatment), cycling through exactly these states:

| State | Shown as |
| --- | --- |
| Fully synced | No chip at all — the absence of a badge is itself the "everything is fine" signal, per [components.md §7](../10-design-system/components.md#7-badges)'s "zero means absent, not a zero badge" rule applied to the same principle here |
| Operations queued, not yet synced | A neutral count chip — "3 pending" — never `error`-coloured, per [state-presentation.md §4](../10-design-system/state-presentation.md#4-offline) |
| Actively syncing | The determinate progress pattern, [components.md §11](../10-design-system/components.md#11-progress--sync-indicator) — "Syncing 2 of 5" |
| An operation stuck retrying (per [outbound-queue.md §5](outbound-queue.md#5-poison-message-handling)'s transient-failure threshold) | The chip's wording shifts to "Having trouble syncing — checking connection," still neutral, not alarming, since this is very often just "the shop's data connection is bad today," not a fault |
| A rejected operation or an unresolved field conflict awaits review | A distinct, actionable badge — this is the one state that **does** warrant drawing the eye, since it needs a human decision, unlike routine pending/syncing states |

## 2. What tapping the indicator does

Opens a bottom sheet ([patterns.md §5](../10-design-system/patterns.md#5-bottom-sheet-action)) listing,
in business language:

- Items currently pending or syncing — "3 sales waiting to sync," not a list of raw operation IDs.
- Items needing the Owner/Manager's attention — rejected operations
  ([outbound-queue.md §5](outbound-queue.md#5-poison-message-handling)), field conflicts
  ([conflict-resolution.md §3](conflict-resolution.md#3-field-edit-collisions--merge-what-doesnt-overlap-ask-about-what-does)),
  and Finding-1-style post-hoc rejections ([failure-scenarios.md §2](failure-scenarios.md#2-resolving-finding-1--provisional-approvals-rejected-after-the-fact)) —
  each with the exact business-language wording already specified in those documents, reused here
  verbatim rather than re-worded per screen.
- A manual "sync now" action — mostly redundant given the opportunistic triggers in
  [sync-architecture.md §4](sync-architecture.md#4-what-opportunistic-not-scheduled-means-concretely),
  but present because a Cashier who is uncertain benefits from a visible, actionable "try it now" —
  per [voice-and-tone.md](../10-design-system/voice-and-tone.md)'s rule against leaving a worried user
  with nothing to do.

## 3. Resolving Finding 3 — distinguishing "not found" from "not synced here yet"

[offline-workflows.md — Finding 3](../06-workflows/offline-workflows.md#finding-3--return-lookup-is-bounded-by-what-has-synced-to-this-device)
specifically asked for this distinction to be made visible, not left as one generic "not found."
**Resolved:** [sales/lookup](../11-api/endpoints/sales.md) and the returns flow's sale-search
distinguish two outcomes explicitly:

| Outcome | Shown as |
| --- | --- |
| No sale matches this invoice number, anywhere | *"No sale found with that number."* |
| A sale with this number may exist but hasn't reached this device yet (this device is currently offline, or its cache is known to be incomplete for this store's other devices) | *"Not found on this device yet — it may exist on another till. Try again once you're back online, or check the till it was made on."* — genuinely different guidance than a flat "not found," and honest about the specific cause |

This distinction is only knowable because the device tracks its own pull-sync completeness per
[inbound-sync.md](inbound-sync.md) — the UI layer asks "am I currently caught up on other devices'
sales for this store?" rather than guessing from the absence of a result alone.

## 4. What is deliberately never shown

Per this phase's exit criterion and [voice-and-tone.md](../10-design-system/voice-and-tone.md): no
`client_operation_id`, no `updated_at` timestamp, no HTTP status code, no raw error code from
[error-catalogue.md](../11-api/error-catalogue.md), and no database or sync-engine vocabulary
("idempotency," "cursor," "conflict resolution") anywhere a Cashier, Manager, or Owner can see it.
Every message this document's states produce is written in the same concrete, action-oriented style
already fixed in [voice-and-tone.md](../10-design-system/voice-and-tone.md) — this document supplies
the sync-specific content; that one supplies the standard it must be held to.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Persistent glanceable chip across 5 states; tap-through bottom sheet reusing existing business-language wording; Finding 3 resolved with an explicit not-found-vs-not-synced-yet distinction; banned-vocabulary list stated. |
