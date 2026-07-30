# Realtime

> **Status:** 🔵 In review
> **Phase:** 11 — API Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Principal Next.js Engineer / CTO
> **Approved by:** _pending_

Which changes push via Supabase Realtime, to whom, and what happens when a message is missed — the
concrete design for the "Realtime read subscriptions" half of
[ADR-0001](../adr/ADR-0001-hybrid-api-and-direct-realtime-access.md)'s Option C, secured by
[tenancy-model.md](../07-database/tenancy-model.md)'s Row Level Security as the **only** gate, per
[system-context.md](../04-srs/system-context.md)'s TB-2 finding — restated here because every
design decision in this document has to hold given that constraint, not despite it.

---

## 1. What Realtime is for, precisely

**Latency, not correctness.** Every change Realtime pushes is also, eventually, delivered by
[sync-api.md](sync-api.md)'s pull endpoint — Realtime exists purely to shave the delay between
"something changed" and "this device notices," for the small set of changes where that delay
matters to a person waiting on the other end. If Realtime disappeared entirely tomorrow, every
workflow in this product would still complete correctly, just slower. This framing is what makes
§4 (missed messages) safe to answer simply.

## 2. Subscriptions — what pushes, to whom

| Change | Subscribed by | Why it needs to be near-real-time, not just eventually-pulled |
| --- | --- | --- |
| `returns.status` transitioning `pending_approval → approved/rejected` | The Cashier's device that created the return | Backs the **interrupt path** in [returns.md §"The approve endpoint's two paths"](endpoints/returns.md#the-approve-endpoints-two-paths-and-why-offline-capability-differs-between-them) — a Manager approving on another device should resolve the waiting Cashier's screen within seconds, not on the next pull cycle, since a customer is standing there. |
| A new row in `returns` at `status = pending_approval` for this store | Every Manager/Owner device currently online at this store | Powers the live badge count on the Reports tab ([navigation-model.md](../09-navigation/navigation-model.md)) without the Manager having to manually refresh. |
| `devices.revoked_at` for the current device | The device itself | Forces an immediate sign-out rather than waiting for the next API call to hit `DEVICE_REVOKED` — see [authentication.md §5](authentication.md#5-revocation-flow). |
| `user_store_roles` change for the current user | The affected user's device | A permission downgrade (e.g. a shared-device shift handover changing who's logged in — [device-and-context.md](../05-personas/device-and-context.md)) takes effect without waiting for a background pull. |
| `shop_settings` change | Every device at the tenant | Rare, but a tax-mode change must be visible everywhere quickly — a sale calculated against a stale tax mode for even a few extra minutes is a real, if small, financial-accuracy problem. |

**Everything else — catalogue changes, other devices' sales/stock movements, customer records — is
deliberately left to pull sync only.** Subscribing to every table "just in case" would mean paying
a live-connection cost for changes nobody is waiting on with a person standing in front of them; the
table above is short by design, not by omission.

## 3. Payload shape

A Realtime message carries only enough to invalidate/refresh the affected local cache entry — the
entity's `id` and `updated_at`/`status`, not a full denormalised payload duplicating the row. The
receiving device reacts by pulling that one entity via its normal `GET` endpoint (or, if a pull
sync is already due, simply lets the next scheduled pull pick it up) — Realtime **triggers**
freshness, it does not **carry** the authoritative data itself. This keeps the Realtime payload
schema trivial and avoids a second place where a row's shape needs to be kept in sync with
[schema-server.md](../07-database/schema-server.md).

## 4. What happens when a message is missed

Per §1, this is simple by construction: a missed Realtime message (connection drop, backgrounded
app, a message sent while the device was offline) is **not specially detected or retried at the
Realtime layer at all.** The device's normal [sync-api.md](sync-api.md) pull cycle — triggered on
reconnect and on app foreground, per [sync-api.md §7](sync-api.md#7-what-triggers-a-sync-cycle) —
independently catches up on any state Realtime would have pushed, because pull sync's cursor-based
feed is a superset of everything Realtime ever sends. The one degraded experience is **latency**,
not correctness: an approval a Manager made while the Cashier's device had briefly lost its
Realtime connection is picked up on reconnect's pull sync within the same few seconds that
reconnect already takes, rather than instantly.

## 5. Restating the standing TB-2 gap, not re-solving it here

[system-context.md](../04-srs/system-context.md) already flagged that Realtime has no API-layer
defence-in-depth — RLS is the only authorisation gate on a Realtime subscription. This document
does not change that; it only makes sure that **nothing this product needs to be correct** depends
on Realtime working, which is the actual mitigation available at this layer. Closing the TB-2 gap
itself (giving Realtime a second, independent authorisation check) remains an open item, tracked
where [system-context.md](../04-srs/system-context.md) already tracks it — not silently treated as
resolved by this document.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | Initial Realtime scope: 5 subscription types, thin invalidation-only payloads, missed-message behaviour resolved by framing Realtime as latency-only with pull sync as the correctness backstop. |
