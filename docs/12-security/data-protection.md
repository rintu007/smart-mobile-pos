# Data Protection

> **Status:** 🔵 In review
> **Phase:** 12 — Security Design
> **Version:** 0.3.0
> **Last updated:** 2026-08-19
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

**Status: built, Sprint 48.** The Phase 18 package verification promised above is done: as of
`package:sqlite3` 3.x, there is no separate Flutter plugin to add at all —
`sqlcipher_flutter_libs`, the package this document originally expected to depend on, is a no-op
stub since 0.7.0 (confirmed by reading its own bundled README, not assumed from its continued
presence in `pubspec.lock` as a transitive dependency). `package:sqlite3` now resolves its native
library through Dart's own hooks/native-assets build system, and selecting the SQLCipher
precompiled binary is a `pubspec.yaml` declaration, not a dependency:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlcipher
```

At runtime, `core/database/database.dart`'s `AppDatabase.encrypted(encryptionKey)` opens the
database via `drift_flutter`'s `DriftNativeOptions.setup` callback, executing
`PRAGMA key = "x'<64 hex chars>'"` — SQLCipher's *raw-key* form, not a passphrase, since
`getOrCreateDatabaseEncryptionKey` (`core/database/database_encryption_key.dart`) already generates
256 bits of real randomness; running that through PBKDF2 (which passphrase-mode key derivation
does) adds cost without adding security when the input is already a uniform random key. The key
itself is generated once on first launch and stored via the same `SecureKeyValueStore` seam §3a
uses (`FlutterSecureStorageAdapter`, now public for this second caller), under its own storage key
distinct from the session token's.

**What happens to an already-installed unencrypted database on upgrade** (the decision this
section's original draft named as still open): this is the first sprint this app has ever set a
SQLCipher key, so any database file already present at the target path predates encryption and is
guaranteed plaintext. Rather than issue `PRAGMA key` against a plaintext file (undefined,
corruption-risking behaviour) or build bespoke SQLCipher plaintext-export migration machinery (real,
separate scope, disproportionate to this pre-pilot, no-real-installed-base product per
`release-checklist.md`), `core/database/legacy_database_reset.dart` detects a legacy plaintext file
on startup and deletes it once, so `drift` recreates a fresh encrypted one at the same path — the
same "no migration path, pre-pilot, accepted one-time reset" call §3a already made for the session
token, extended here to the one case where it actually risks real local test/demo data rather than
a trivial re-sign-in.

**Verified, not just assumed to work:** built and confirmed against a real `flutter build apk
--debug --target-platform android-arm64` — `libsqlcipher.so` is genuinely present in the resulting
APK (`unzip -l`), not silently falling back to plain SQLite. A dedicated test
(`test/core/database/database_test.dart`) opens a database through the same keyed-connection
mechanism `AppDatabase.encrypted` uses, writes a row, then reopens the same file with a bare
`sqlite3.open()` (no key) and confirms the read fails — proof the actual guarantee holds, not just
that `PRAGMA key` runs without error.

## 3a. Session-token storage (Sprint 47) — a related but distinct concern from §3's database key

This document's original v0.1.0 draft cited this whole section for the OWASP checklist's M1 claim
("tokens in platform secure storage only") even though the paragraphs above are specifically about
*the SQLCipher database key*, not the session token itself — two different pieces of data that
happen to want the same storage mechanism, conflated into one citation. Stated separately here,
found and corrected while actually building it (Sprint 43's OWASP review flagged M1 as a real gap;
Sprint 47 closed it):

**Decision: the Supabase session (access token, refresh token) is persisted via
`flutter_secure_storage`** (Android Keystore-backed `EncryptedSharedPreferences`, iOS Keychain) —
`supabase_flutter`'s own `Supabase.initialize` accepts a custom `LocalStorage` implementation for
exactly this purpose; without one, it silently falls back to its own
`SharedPreferencesLocalStorage`, plaintext on Android. `flutter_secure_storage` was already a
`pubspec.yaml` dependency (named in this document's own tech-stack references since v0.1.0) but had
never actually been imported anywhere in this app until Sprint 47 — a real, previously-unverified
gap between "the package is a dependency" and "the package is actually used," the same class of gap
Sprint 43's OWASP review found repeatedly elsewhere in this project.

No migration path exists from the old plaintext-stored sessions to the new secure-storage-backed
ones — a deliberate, dated decision, not an oversight: no real installed base exists yet to migrate
(`release-checklist.md`'s own "not pilot-ready today" status, recorded Sprint 44), so a signed-in
user on an already-installed pre-Sprint-47 build simply signs in again once after updating, the same
one-time cost this project has already accepted for prior pre-pilot schema changes.

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
| 0.2.0 | 2026-08-19 | §3 marked not-yet-built (M9, found unimplemented Sprint 43). New §3a: session-token storage split out as its own decision, distinct from §3's database key — built Sprint 47 (`flutter_secure_storage`, no migration from the old plaintext value, a dated decision given no real installed base exists yet). |
| 0.3.0 | 2026-08-19 | §3 built, Sprint 48: SQLCipher via `package:sqlite3` 3.x's native-hooks mechanism (no separate Flutter plugin — `sqlcipher_flutter_libs` is a no-op stub post-3.x), raw-key `PRAGMA key`, key generated once and stored via the same `SecureKeyValueStore` seam §3a uses. Legacy plaintext database reset (not migrated) on first launch after upgrade — the open question this section's original draft named. Verified against a real Android debug build and a dedicated unkeyed-read-fails test. |
