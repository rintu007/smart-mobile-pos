# Clock and Ordering

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO / Principal Flutter Engineer
> **Approved by:** _pending_

Why device clocks are untrustworthy, and what every ordering-sensitive decision in this system uses
instead — a single rule this document exists to state once, since it is easy to accidentally violate
in a dozen small places otherwise.

---

## 1. Why device clocks cannot be trusted

Per [device-and-context.md](../05-personas/device-and-context.md) and this phase's founding rule: a
shop-floor Android device may have its clock wrong for entirely mundane reasons — a dead battery
resetting it, a manual timezone change, a user who set the date wrong, or simply a device that has
never had its clock synced against a time server because it's rarely (or never) online. None of
these are adversarial; all of them are routine. Any ordering decision (which sale happened "first,"
which stock movement should apply "before" another) that trusts `outbound_queue.created_at`
literally would be wrong on a predictable, recurring basis — not a rare edge case to shrug off.

## 2. What is ordered by device time — display only

`outbound_queue.created_at`, `sales`' locally-known creation moment, and every other local
timestamp remain useful for exactly one purpose: **showing a human a plausible, locally-consistent
sequence** ("your last 5 sales, most recent first," on a single device, where relative order within
that one device's own clock is still meaningful even if the absolute value is wrong). This is
already stated in [schema-local.md](../07-database/schema-local.md) for `outbound_queue`; this
document makes it the general rule, not a one-table note.

## 3. What is ordered by server time — everything that matters financially or causally

| Decision | Ordered by |
| --- | --- |
| Canonical invoice numbering | **Server arrival (sync) order**, per [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) — not the device-reported sale time |
| `stock_movements` balance derivation | **Not ordered at all** — per [stock-ledger.md](../07-database/stock-ledger.md), the sum is order-independent by construction, which is a stronger guarantee than "ordered correctly" would be, and sidesteps the clock question entirely for this specific case |
| Daily sales reports, financial-year rollover | Server `created_at`/sync time, per [identifiers.md §3](../07-database/identifiers.md#3-invoice-numbering--financial-year-rollover) — a sale created just before midnight on a device but synced after is reported in the period it synced into, not the period its (untrusted) device clock claimed |
| Field-edit conflict "who wins" for non-overlapping fields | Irrelevant — both apply, per [conflict-resolution.md §3](conflict-resolution.md#3-field-edit-collisions--merge-what-doesnt-overlap-ask-about-what-does); ordering is never consulted because there is no actual disagreement to order |
| Field-edit conflict base-version check | **Server `updated_at`**, per [conflict-resolution.md §3](conflict-resolution.md#3-field-edit-collisions--merge-what-doesnt-overlap-ask-about-what-does) — a device's *belief* about when it last saw a row is irrelevant; only whether the server's own value has moved since matters |
| Idempotency-key first-seen | Server `first_seen_at`, per [schema-server.md](../07-database/schema-server.md)'s `idempotency_keys` table |

**The pattern, stated once:** anywhere two devices' data must be reconciled, the server's own clock
or the server's own arrival sequence is authoritative — a device's self-reported time is advisory,
local-display-only, and never load-bearing for money, stock, or ordering-sensitive correctness.

## 4. What this means for a device with a badly wrong clock — the failure scenario itself

A device whose clock is wrong by hours or days ([failure-scenarios.md](failure-scenarios.md)'s
named scenario) still produces **entirely correct** financial outcomes under this design: its sales
still get the right canonical invoice number (assigned at sync, by real arrival order), its stock
movements still sum correctly (order-independent), and its local display simply shows a
locally-implausible timestamp on a receipt or list — a cosmetic symptom, not a correctness one. This
is the concrete payoff of designing around server-time authority from the start rather than
attempting to detect and correct bad device clocks (NTP-style clock discipline), which would be
meaningfully harder to get right and unnecessary given every load-bearing decision already avoids
depending on the device clock at all.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Single stated rule (device time = display-only, server time/arrival-order = authoritative) applied across every ordering-sensitive decision in the system; wrong-device-clock scenario shown to degrade only cosmetically, not financially. |
