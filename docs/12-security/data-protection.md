# Data Protection

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.1.0
> **Last updated:** 2026-07-30
> **Owner:** Security Engineer / CTO
> **Approved by:** _pending_

Encryption at rest and in transit, on-device storage, and key handling — the concrete answer to
this phase's rule that **the offline database is assumed readable by an attacker who has the
device.**

---

## 1. In transit

TLS everywhere, with no configuration decision left implicit: Supabase enforces TLS on its Postgres,
Auth, Realtime, and Storage endpoints by default (not an opt-in this project must remember to
enable); Vercel enforces HTTPS on every deployed route by default. No plaintext HTTP path exists
anywhere between the mobile client and any backend service — this is a platform default being
relied on deliberately, not verified separately, because both platforms make plaintext transport
unavailable to configure even by mistake.

## 2. At rest — server side

Supabase's underlying PostgreSQL storage and Supabase Storage are encrypted at rest by the platform
by default — again, a platform default this project relies on rather than re-implements. This
project adds no additional server-side encryption layer beyond this, since doing so would duplicate
a guarantee the hosting platform already provides at no extra cost, consistent with the free/
open-source-first constraint.

## 3. On-device storage encryption

**Decision: the local Drift/SQLite database is encrypted at rest**, using SQLCipher (open-source,
BSD-style licence, free) as the underlying encrypted SQLite implementation Drift connects to,
rather than an unencrypted database relying solely on Android/iOS app sandboxing. This goes further
than app-sandboxing alone because this phase's own rule states the device itself is assumed
compromised (lost, stolen, or physically accessed) — sandboxing protects against another app on the
same device, not a person with the device in hand and, on an older or rooted Android device,
filesystem access to another app's data directory.

**Key handling:** the encryption key is a random value generated on first app launch (not derived
from any static app secret, which would make every installation's database decryptable by the same
key), stored exclusively in the platform's secure storage (`FlutterSecureStorage`, backed by Android
Keystore / iOS Keychain — already in [project-vision.md](../01-vision/project-vision.md)'s tech
stack). The key never appears in application code, configuration, or the database file itself.

*(The exact SQLCipher-for-Drift integration package is confirmed against current Flutter/Drift
ecosystem documentation at Phase 18, per this documentation set's standing practice of not
committing to unverified tool specifics — the architectural decision made now is encryption with a
platform-secure-storage-held key; the specific package is a Phase 18 verification, same treatment
as [ADR-0007](../adr/ADR-0007-client-generated-uuid-primary-keys.md)'s UUID tooling.)*

## 4. The trade-off this decision creates, stated plainly rather than hidden

Encrypting the local database with a key held only in secure storage means: **if that key is lost —
app data cleared, the app uninstalled, or, rarely, Keystore/Keychain corruption — the local database
becomes permanently unreadable, including any sales not yet synced to the server.** This is a real
tension with [risk R-09](../01-vision/risks-constraints-assumptions.md) (device loss with unsynced
sales) and [authentication.md §5](../11-api/authentication.md#5-revocation-flow)'s rule that
revocation must never delete the unsynced queue — encryption doesn't delete it, but it can make it
permanently inaccessible under the same failure modes.

**Why this is still the right call:** the scenarios that clear secure storage (explicit "clear app
data," uninstall, factory reset) are exactly the scenarios in which a device is being decommissioned
or has already been compromised — a shop owner does not routinely clear app data on a working till.
The realistic risk this closes (a stolen, still-installed device readable by whoever has it) is
common and severe; the risk it introduces (data loss on a deliberate wipe of an already-lost device)
overlaps almost entirely with data that was already unrecoverable in that scenario regardless of
encryption. The mitigation for the residual overlap is **operational, not cryptographic**: sync as
aggressively as connectivity allows ([sync-api.md §7](../11-api/sync-api.md#7-what-triggers-a-sync-cycle))
to keep the unsynced window small, which is already this project's standing design goal independent
of this decision.

## 5. What is never stored on-device at all

Per [RR-007](../02-business-requirements/regulatory-requirements.md), raw payment instrument data
(card numbers, UPI credentials) is never captured or stored by this product anywhere, on-device or
server-side — encryption at rest is a defence for business and customer-contact data, not a
substitute for simply not holding payment credentials in the first place.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-07-30 | On-device SQLCipher encryption decided, key handling via platform secure storage specified, encryption-vs-unsynced-data trade-off stated and justified rather than hidden. |
