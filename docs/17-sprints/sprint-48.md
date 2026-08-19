# Sprint 48

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — closes finding M9 from Sprint 43's OWASP checklist review)
> **Status:** Closed.

## Goal

Close the fifth of Sprint 43's OWASP checklist findings, and the last one that was genuinely
unblocked engineering rather than founder-blocked or intentionally out-of-phase: the local Drift
database was plain, unencrypted SQLite despite `data-protection.md §3` having decided on SQLCipher
encryption since Phase 12. Unlike the RLS finding (still open, founder input pending) and Android
signing (founder-blocked on real credentials), and unlike alerting/monitoring (A09, intentionally
scheduled for Phase 18 per `incident-response.md`, not pulled forward here), on-device encryption
carried no such blocker — it was real, bounded engineering that `data-protection.md §3` itself had
already deferred exact package specifics on until "Phase 18," i.e. actual implementation time,
which this sprint is.

## Design decisions, found while writing the spec

1. **The ecosystem moved since `data-protection.md §3` was written.** The `sqlcipher_flutter_libs`
   plugin package it anticipated is a no-op stub as of version 0.7.0 — confirmed by reading the
   package's own bundled README, not assumed from its continued presence as a transitive
   dependency in `pubspec.lock`. `package:sqlite3` 3.x (already in use via `drift`/`drift_flutter`)
   now resolves its native library through Dart's hooks/native-assets build system; selecting the
   SQLCipher precompiled binary is a `pubspec.yaml` declaration
   (`hooks.user_defines.sqlite3.source: sqlcipher`), not a plugin dependency at all. Verified
   directly against the installed `sqlite3` 3.5.0 package's own `doc/hook.md` and
   `test/ffi/encryption_test.dart`, not assumed from search-engine-era documentation.
2. **Raw key, not a passphrase.** `getOrCreateDatabaseEncryptionKey` generates 256 bits of real
   randomness once and stores it via secure storage; SQLCipher's `PRAGMA key = "x'<hex>'"` raw-key
   form is used rather than a passphrase, since passphrase mode runs the input through PBKDF2 to
   derive a key from low-entropy human input — real cost, no benefit, when the input is already a
   uniform random key.
3. **`FlutterSecureStorageAdapter` made public.** Sprint 47's `SecureKeyValueStore`
   seam/adapter (`core/auth/secure_local_storage.dart`) already existed for the session token;
   the database key is a second, independent caller of the same seam (different storage key,
   same platform mechanism), so the adapter was made public rather than duplicated.
4. **`appDatabaseProvider` now has no default body.** Opening the real database needs an
   asynchronously-resolved key, which a synchronous `Provider` can't do internally without either
   turning it into a `FutureProvider` (rippling an async wait into all ~11 existing synchronous
   consumers — disproportionate to this change) or silently opening an unencrypted database as a
   fallback. Resolved by having `main.dart` resolve the key at startup and override the provider —
   the same pattern `storeContextProvider`/`autoSyncOnStartProvider` already use in every test —
   and having the unoverridden default throw, matching `Env.assertConfigured()`'s existing
   fail-fast style rather than ever constructing an unencrypted database by accident.
5. **The already-installed-unencrypted-database question, which `data-protection.md §3`'s own
   "not yet built" status explicitly left open, is answered by a reset, not a migration.** This is
   the first sprint this app has ever set a SQLCipher key, so any database file already present at
   the target path predates encryption and is guaranteed plaintext — there is no ambiguity to
   detect at runtime beyond "does a file exist here." Rather than issue `PRAGMA key` against a
   plaintext file (undefined, corruption-risking behaviour) or build bespoke SQLCipher
   plaintext-export migration machinery (real, separate scope), `legacy_database_reset.dart`
   deletes a legacy plaintext file once so drift recreates a fresh encrypted one — the same
   "no migration path, pre-pilot, accepted one-time reset" call already made for the session token
   (Sprint 47) and `erased_at` (Sprint 46), extended here to the one case that actually risks real
   local test/demo data rather than a trivial re-sign-in.

## Capacity check

No estimate was carried in the backlog for this item, since it was not a planned backlog line — the
same same-day-fix-of-a-flagged-finding shape Sprints 44–47 all took.

## Reserved capacity

- [x] Defect capacity reserved: this closes a real, previously-flagged gap (Sprint 43 finding M9),
      not new discretionary scope.

## Risks

- **Real, and taken seriously — not the same low-risk shape as Sprints 45–47.** Unlike the
  session-token/erasure fixes, this touches genuine local data (unsynced sales, catalogue, an
  outbound queue). Mitigated by: (1) the legacy-plaintext-file reset only ever fires once, only on
  a file proven plaintext by a real read attempt, never on a file that already fails to open
  (§ design decision 5); (2) verified against a real `flutter build apk --debug
  --target-platform android-arm64` — `libsqlcipher.so` genuinely bundled, not silently falling
  back to plain SQLite; (3) a dedicated test proves the actual guarantee (unkeyed reads fail
  against a keyed-write file), not just that `PRAGMA key` runs without error.
- The encryption key is held only in platform secure storage — the same trade-off
  `data-protection.md §4` already stated plainly for the session token now applies to the local
  database too: clearing app data, uninstalling, or Keystore/Keychain corruption makes the local
  database (including any unsynced sales) permanently unreadable. Already named and justified in
  that section; not new to this sprint, and unchanged by it.

## Definition of Done

- [x] `apps/mobile/pubspec.yaml` — `hooks.user_defines.sqlite3.source: sqlcipher`, `sqlite3` added
      as a direct dependency (was transitive-only, which `flutter analyze` flagged).
- [x] `apps/mobile/lib/core/database/database_encryption_key.dart` —
      `getOrCreateDatabaseEncryptionKey`, a 256-bit random key generated once, persisted via the
      `SecureKeyValueStore` seam.
- [x] `apps/mobile/lib/core/database/legacy_database_reset.dart` —
      `resetLegacyUnencryptedDatabaseIfPresent` (production path, resolves the real path via
      `path_provider`) and `resetLegacyUnencryptedDatabaseAt` (testable seam, takes the file
      directly).
- [x] `apps/mobile/lib/core/database/database.dart` — new `AppDatabase.encrypted(encryptionKey)`
      constructor; `_openConnection` now accepts a nullable key and wires
      `DriftNativeOptions.setup` to run `PRAGMA key` when one is given. The existing
      `AppDatabase([executor])` constructor is unchanged — every test still passes an explicit
      in-memory executor.
- [x] `apps/mobile/lib/core/auth/secure_local_storage.dart` — `_FlutterSecureStorageAdapter` made
      public (`FlutterSecureStorageAdapter`) for reuse by the new key store.
- [x] `apps/mobile/lib/app/providers.dart` — `appDatabaseProvider` now throws if not overridden,
      rather than silently opening an unencrypted database.
- [x] `apps/mobile/lib/main.dart` — resets a legacy plaintext file, resolves the encryption key,
      overrides `appDatabaseProvider` with a real `AppDatabase.encrypted`.
- [x] `apps/mobile/test/core/database/database_encryption_key_test.dart` (4 cases),
      `legacy_database_reset_test.dart` (3 cases), plus one new case in the existing
      `database_test.dart` proving unkeyed reads fail against a keyed-write file — 8 new tests.
- [x] Verified locally: `flutter analyze` clean (0 issues, after adding `sqlite3` as a direct
      dependency and switching two deprecated `.dispose()` calls to `.close()`, both found by
      `flutter analyze` itself); `flutter test` 252/252 (244 pre-existing + 8 new); `flutter build
      apk --debug --target-platform android-arm64` succeeds, and `libsqlcipher.so` is confirmed
      present in the resulting APK.
- [x] `data-protection.md` (§3 rewritten from "not yet built" to built, with the actual verified
      implementation), `owasp-checklist.md` (M9 fixed, M10 now fully CONFIRMED, summary counts),
      `12-security/README.md` both updated in the same PR.
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-19:**

1. `flutter analyze` — 0 issues. ✅
2. `flutter test` — 252/252 passing (244 pre-existing + 8 new). ✅
3. `flutter build apk --debug --target-platform android-arm64` — succeeds;
   `unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep sqlite` shows
   `lib/arm64-v8a/libsqlcipher.so`, confirming the real build genuinely links the SQLCipher binary
   rather than silently falling back to plain SQLite. ✅

No live-device verification this sprint (no Android emulator/physical device available in this
environment, same limitation named in Sprint 47) — but unlike Sprint 47, a real Android build was
produced and its contents inspected directly, which is a stronger check than `flutter
analyze`/`flutter test` alone and was done specifically because this change touches the actual
native build output, not just Dart-level code.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: `data-protection.md §3`'s own original
wording — deferring the exact package choice to "Phase 18... per this documentation set's standing
practice of not committing to unverified tool specifics" — turned out to matter for real. The
ecosystem had moved since that section was written (the anticipated plugin package is now a no-op
stub); verifying against the actually-installed package source at implementation time, rather than
trusting the year-old design-time assumption, caught this before any code was written against the
wrong integration point.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 48: on-device database encryption built (SQLCipher via `package:sqlite3` 3.x's native-hooks mechanism, no separate plugin package), closing Sprint 43's finding M9. Legacy plaintext database reset (not migrated) on first launch after upgrade. Verified against a real Android debug build (`libsqlcipher.so` confirmed bundled) and a dedicated unkeyed-read-fails test. 252/252 mobile tests, `flutter analyze` clean. |
