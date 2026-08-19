# Sprint 47

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — closes finding M1 from Sprint 43's OWASP checklist review)
> **Status:** Closed.

## Goal

Close a fourth finding from Sprint 43's OWASP checklist review: `flutter_secure_storage` was a
`pubspec.yaml` dependency but had never actually been imported anywhere in `apps/mobile/lib` —
`Supabase.initialize()` passed no custom `localStorage`, so every session token this app has ever
persisted sat in `supabase_flutter`'s own default, plaintext-on-Android `SharedPreferences` storage.
Like rate limiting (Sprint 45) and customer erasure (Sprint 46), this carried no
production-configuration risk and was safe to build immediately — unlike the RLS finding, which
remains open pending founder input.

## Design decisions, found while writing the spec

1. **`data-protection.md §3`'s original citation for M1 conflated two different pieces of data.**
   That section is specifically about the SQLCipher database *key*, not the session token — the
   OWASP checklist's v0.1.0 draft cited the whole section for both claims as if they were the same
   decision. Split into a new §3a specifically for session-token storage, so the two concerns (and
   their two different implementation statuses — this sprint closes one, not the other) don't stay
   conflated under one citation going forward.
2. **No migration path from the old plaintext-stored sessions.** A deliberate, dated decision, not
   an oversight: no real installed base exists yet (`release-checklist.md`'s own "not pilot-ready
   today" status, Sprint 44), so an already-installed pre-Sprint-47 build's user simply signs in
   again once after updating — the same one-time cost this project has already accepted for prior
   pre-pilot schema/storage changes.
3. **Testable without mocking `flutter_secure_storage`'s own platform channel.** `SecureLocalStorage`
   depends on a narrow `SecureKeyValueStore` interface (just `read`/`write`/`delete`) rather than the
   concrete `FlutterSecureStorage` class directly — production wires the real package behind a small
   adapter, tests substitute a genuine in-memory fake, this codebase's established "fake, not a mock"
   convention (e.g. Sprint 39's `_FakeEscPosReceiptEncoder`) rather than mocking a platform channel,
   which this test suite has never needed to do before and would have been the first precedent for.
4. **A real, live-found fix along the way**: `flutter analyze` flagged `AndroidOptions
   (encryptedSharedPreferences: true)` as deprecated — `flutter_secure_storage` 10.x auto-migrates to
   its own custom ciphers by default and now ignores that parameter entirely. Removed rather than
   left in as dead, warning-triggering configuration.
5. **On-device database encryption (M9) is explicitly separate, deferred scope, not touched this
   sprint** — a materially larger piece of work (SQLCipher's Drift integration, plus a decision on
   what happens to an already-installed unencrypted database on upgrade), correctly out of this
   item's proportionate scope.

## Capacity check

No estimate was carried in the backlog for this item, since it was not a planned backlog line — the
same same-day-fix-of-a-flagged-finding shape Sprints 44–46 all took.

## Reserved capacity

- [x] Defect capacity reserved: this closes a real, previously-flagged gap (Sprint 43 finding M1),
      not new discretionary scope. The deprecated `AndroidOptions` parameter (design decision #4)
      was found and fixed via `flutter analyze` before merge, not left as a warning.

## Risks

- **None for production data** — purely additive: one new file (`core/auth/secure_local_storage.dart`),
  one new constructor argument on an existing `Supabase.initialize` call. No existing screen or flow
  changes behaviour for a user who is already signed in during this update (their session simply
  isn't found in the new storage location, so they're prompted to sign in again once — see design
  decision #2 for why this is an accepted, dated trade-off).

## Definition of Done

- [x] `apps/mobile/lib/core/auth/secure_local_storage.dart` — `SecureLocalStorage` (implements
      `supabase_flutter`'s `LocalStorage`) behind a testable `SecureKeyValueStore` seam.
- [x] `apps/mobile/lib/main.dart` — `Supabase.initialize` now passes `authOptions:
      FlutterAuthClientOptions(localStorage: SecureLocalStorage())`.
- [x] `apps/mobile/test/core/auth/secure_local_storage_test.dart` — 5 cases against a genuine
      in-memory fake: no token before any session, round-trip persist/read, removal, overwrite (not
      append) on a second session, and no cross-key interference.
- [x] Verified locally: `flutter analyze` clean (0 issues, after removing the deprecated parameter
      design decision #4 found), `flutter test` 244/244 (239 pre-existing + 5 new).
- [x] `data-protection.md` (new §3a), `owasp-checklist.md` (M1, M10 rows and summary counts) both
      updated in the same PR.
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-19:**

1. `flutter analyze` — 0 issues (after removing the deprecated `AndroidOptions` parameter found by
   this same command on the first pass). ✅
2. `flutter test` — 244/244 passing (239 pre-existing + 5 new `SecureLocalStorage` cases). ✅

No live-device verification this sprint — no Android emulator/physical device was available in this
environment; per this project's own established precedent (e.g. Sprint 30's mobile-only work,
verified via `flutter analyze`/`flutter test` alone, no live-HTTP or live-device step required for a
change with no server-side component), static analysis plus a genuine unit-test suite is the
established bar for this class of change. A live-device confirmation that a real sign-in genuinely
persists to `EncryptedSharedPreferences`/Keychain rather than the old location remains a reasonable
manual check for whenever a real device is next in hand — named, not silently skipped.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: this is the fourth of Sprint 43's flagged
findings closed this way, and the first mobile-side one — the same "found a real gap, safe to close
immediately, no production risk" shape held even outside the web backend this run of sprints has
otherwise focused on.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 47: mobile secure token storage built (`SecureLocalStorage`, `flutter_secure_storage`-backed), closing Sprint 43's finding M1. Found and fixed a deprecated `flutter_secure_storage` config option via `flutter analyze`. `data-protection.md` split into §3 (database key, still unbuilt, M9) and a new §3a (session token, now built). 244/244 mobile tests, `flutter analyze` clean. |
