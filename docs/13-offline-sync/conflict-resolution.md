# Conflict Resolution

> **Status:** 🔵 In review
> **Phase:** 13 — Offline Synchronisation
> **Version:** 0.1.0
> **Last updated:** 2026-07-31
> **Owner:** CTO / Principal Flutter Engineer
> **Approved by:** _pending_

Per-entity-class policy with worked examples, for every entity
[entity-classification.md](entity-classification.md) marked **client-editable**:
`categories`, `units`, `products`, `customers`, `shop_settings`. (`trading_days` needs no policy at
all — conflict-free by construction, per [entity-classification.md §3](entity-classification.md#3-finding-2-resolved--restated-here-as-this-phases-own-record-not-just-phase-07s).)

---

## 1. Two distinct conflict shapes — not one problem

| Shape | What happens | Example |
| --- | --- | --- |
| **Creation collision** | Two devices independently create what turns out to describe the same real-world thing, before either has synced | Two Cashiers, on two devices, each capture a new walk-in customer with the same phone number |
| **Field-edit collision** | Two devices edit the *same existing* row while both offline (or both racing online), before either sees the other's change | A Manager on Device A updates a customer's phone number; an Owner on Device B, unaware, updates the same customer's name at the same time — or, worse, both update the phone number, to different values |

## 2. Creation collisions — reject the duplicate, point at the original

Per [error-catalogue.md](../11-api/error-catalogue.md)'s `PHONE_ALREADY_ASSIGNED` and
`BARCODE_ALREADY_ASSIGNED`, the second creation to sync is rejected outright — **never silently
merged into the first**, because a customer or product creation carries no prior "base version" to
merge against; there is nothing to reconcile, only two independent originals. The rejection is
surfaced to whoever created the second one in business language: *"A customer with this phone
number already exists — search for them instead of creating a new one."* This is an action the
Cashier can actually take (look the existing customer up), not a dead end.

## 3. Field-edit collisions — merge what doesn't overlap, ask about what does

Every client-editable row carries the `updated_at` value it had **as of the last time this device
pulled it** (its "base version"). A queued edit's push includes that base value alongside the
change. At sync:

- **If the row's current server `updated_at` still matches the device's base version**, no
  concurrent edit occurred — the change is applied outright.
- **If it doesn't match**, a concurrent edit already landed. The server compares the *fields*
  touched by each edit:
  - **Non-overlapping fields** (Device A changed `phone`, Device B changed `name`) — **both are
    applied automatically.** This is the common case, and it requires no human involvement at all,
    because the two edits don't actually disagree about anything.
  - **The same field, to different values** (both devices changed `phone`, to different numbers) —
    **neither value is applied automatically.** This is recorded as a field-level conflict awaiting
    human resolution and surfaced the next time an Owner/Manager is online, per
    [sync-ui.md](sync-ui.md), in exactly the form this phase's exit criterion requires: **business
    language, never technical.**

### Worked example — the exit criterion's own case

> **"Two staff edited this customer's phone number."**
> Ramesh Kumar's phone number: Device A (Priya, Cashier) changed it to `9876543210`; Device B
> (Anil, Manager), unaware, changed it to `9876500000` — both while genuinely offline, both
> believing they had the only edit.
>
> **What the Owner sees, once online:** *"Ramesh Kumar's phone number was changed by two people at
> the same time. Priya set it to 9876543210. Anil set it to 9876500000. Which is correct?"* — with
> both values shown and a single tap to pick one. **Never shown:** row IDs, `updated_at` timestamps,
> "version conflict," or any database vocabulary at all.

The customer's `name` field, if only one of the two devices touched it, is applied without ever
appearing in this prompt — the conflict UI shows exactly the one field genuinely in dispute, not
every field either device touched.

## 4. The one deliberate exception — `shop_settings` does not field-merge

Unlike `customers`/`products`, `shop_settings`' fields are **interdependent** — `tax_mode` and
`pricing_mode` together determine whether a price is correct; auto-merging a `tax_mode` change from
one edit with a `pricing_mode` change from a concurrent edit could produce a combination neither
Owner actually intended, which is a materially worse outcome than simply asking. **Policy: whole-row
optimistic concurrency, reject-and-retry, never merge.** A concurrent `PATCH /settings` against a
stale base version is rejected outright (`SETTINGS_CONFLICT`, added to
[error-catalogue.md](../11-api/error-catalogue.md)) with a message telling the Owner someone else
just changed settings and to review the current values before retrying — safe by refusing to guess,
consistent with [settings.md](../11-api/endpoints/settings.md)'s already-stated stance that this one
entity trades offline convenience for correctness.

## 5. Why last-write-wins alone was rejected

A naive whole-row last-write-wins (whichever edit reaches the server second simply overwrites the
first entirely) was considered and rejected for `customers`/`products`/`categories`/`units`: it would
silently discard Priya's phone-number correction the moment Anil's unrelated name edit happened to
sync a few seconds later — a real data loss with no visible sign it occurred. Field-level merging
with human resolution **only for genuine same-field disagreement** avoids exactly this, at the cost
of the bookkeeping in §3, which is judged worth it given how routinely two staff members plausibly
touch the same customer or product record independently in a real shop.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-31 | Two conflict shapes (creation, field-edit) resolved distinctly; base-version field-level merge policy with the exit criterion's own worked example; shop_settings' whole-row reject-and-retry exception justified by field interdependence. |
