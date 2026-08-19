# Sprint 56

> **Dates:** 2026-08-20 – 2026-08-20 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — the mobile half of the same gap [Sprint 55](sprint-55.md) deliberately deferred)
> **Status:** Closed. Sprint 43's OWASP finding for `authorisation-model.md §2`'s device-revocation
> step is now closed end to end, server and mobile both.

## Goal

Sprint 55 built device registration/revocation server-side and, after an explicit founder go/no-go
decision, deliberately left the mobile side — the register-device call, a locally-generated
`client_device_id`, the `X-Device-Id` header, and revoked-session handling — as the next piece
rather than bundling it in under time pressure. This sprint builds exactly that, wires it into the
existing bootstrap/sign-in paths, and verifies it with `flutter analyze`/`flutter test`.

## Design decisions

1. **`client_device_id` lives on the existing `device_identity` table, not a new one.** That table
   already exists purely to give `InvoiceNumberGenerator` a stable per-device `shortId` (Sprint 09) —
   adding one nullable column and widening its repository's responsibility was simpler than a second
   single-row local table with its own lifecycle.
2. **Extracted `ensureDeviceIdentity` out of `InvoiceNumberGenerator` into its own
   `device_identity_repository.dart`.** `InvoiceNumberGenerator` was the table's only reader/writer
   before this sprint; now two independent callers (invoice numbering, device registration) need it,
   so the shared logic moved to a seam neither owns.
3. **No `pragma_table_info` duplicate-column guard needed for this migration.** Sprint 51 found that
   `Migrator.createTable` always builds a table from its *current* Dart shape, breaking a naive
   `addColumn` for any table re-created by a later `createTable` step. `device_identity` has never
   been re-created since its original v1 `onCreate` — a single unguarded `addColumn` is safe here,
   the same reasoning Sprint 51's own retrospective anticipated being reusable.
4. **`apiClientProvider` loses its default implementation, made fail-fast like `appDatabaseProvider`
   already is.** The real client needs the resolved device id baked into every request's header —
   something a synchronous default `Provider` can't resolve on its own — so `main.dart` overrides it
   after bootstrap resolves the identity, and tests override it directly wherever real construction
   is exercised (found, during verification, to include `saleRepositoryProvider`, not only the
   `storeContextProvider` chain originally assumed — see Errors below).
5. **Device registration is best-effort everywhere it's called, not just at bootstrap.** `main.dart`
   already swallowed a bootstrap-time registration failure (an app relaunch with an existing
   session); this sprint applies the identical swallowed-try/catch shape to `SignInController`'s
   fresh-sign-in registration too, once verification showed why that consistency actually matters
   (see Errors below) rather than only for symmetry's own sake.
6. **`isDeviceRevokedError` extracted as a standalone pure function**, matching this codebase's
   established "fake, not a mock" convention — testable against a real constructed `DioException`/
   `Response`, no network and no mocking package involved.

## Errors found and fixed during verification

`flutter analyze`/`flutter test` are this project's standing verification step for mobile work, not
a formality — both surfaced real problems here, not just the expected build-generation gap:

1. **Generated code gap (expected, mechanical):** `database.g.dart` hadn't been regenerated after
   the schema change; `flutter pub run build_runner build` resolved all 8 resulting analyzer errors.
2. **A real test-fixture gap, the same class Sprint 51 first found:** `migration_test.dart`'s two
   tests reconstruct a "genuine historical database" by taking a fresh, current-shape database and
   manually undoing every `onUpgrade` block added since — but the reconstruction only undid blocks
   through v9, since v10 (this sprint's own migration) didn't exist when those tests were written.
   Result: the reconstructed "v3"/"v8" database already had `client_device_id`, so replaying the
   real `onUpgrade` path threw a duplicate-column error identical in shape to Sprint 51's original
   finding. Fixed by adding the missing `ALTER TABLE device_identity DROP COLUMN client_device_id`
   to both tests' rollback list — a test-maintenance gap, not a code bug, but a genuine one: any
   future migration step needs the same treatment, or these tests silently stop testing what they
   claim to.
3. **A real correctness bug, not a test artifact:** `SignInController.signIn()` initially called
   `ensureDeviceIdentity`/`registerDevice` unconditionally inside the same `AsyncValue.guard` as the
   sign-in call itself, with no error handling of its own. `login_screen_test.dart`'s existing "valid
   submit shows the loading state" case caught this immediately — a fresh sign-in with valid
   credentials was rendering "Sign-in failed. Try again." because a transient (in the test's case,
   fail-fast-by-design) failure in the *follow-on* registration call was indistinguishable, to the
   guard, from the sign-in itself failing. Fixed by wrapping the device-identity/registration step in
   its own swallowed try/catch — the same best-effort shape `main.dart`'s bootstrap call already used,
   and for the same reason: a transient failure here must not make a valid sign-in look broken, since
   the very next authenticated API call would surface `DEVICE_REVOKED` anyway if registration
   genuinely never succeeds.
4. **A design assumption that didn't hold:** `store_context_providers.dart`'s docstring, written
   right after making `apiClientProvider` fail-fast, claimed existing tests were safe because they
   "override `storeContextProvider`/`syncRepositoryProvider` directly, never actually reaching
   `apiClientProvider`." `pos_providers_test.dart` disproved this — `saleRepositoryProvider` (in
   `pos_providers.dart`, unrelated to the `storeContextProvider` chain) reads `apiClientProvider`
   directly, and that test exercises real `CartController` construction rather than overriding
   `saleRepositoryProvider` the way the screen-level tests do. Fixed by adding
   `apiClientProvider.overrideWithValue(Dio())` to that test's container setup — the test never
   triggers a real request through it, so a plain unconfigured `Dio()` satisfies construction.

## Definition of Done

- [x] `apps/mobile/lib/core/database/tables/device_identity.dart` — new nullable `clientDeviceId`
      column; `database.dart` schema v9→v10, unguarded `addColumn` (safe per design decision 3).
- [x] `apps/mobile/lib/core/database/device_identity_repository.dart` (NEW) — `ensureDeviceIdentity`,
      extracted out of `InvoiceNumberGenerator`; generates fresh, returns stable, and backfills a
      pre-existing shortId-only row, all in one function.
- [x] `apps/mobile/lib/core/invoicing/invoice_number_generator.dart` — now calls the shared
      `ensureDeviceIdentity` instead of owning the table itself.
- [x] `apps/mobile/lib/core/network/api_client.dart` — `buildApiClient` accepts `clientDeviceId`
      (sent as `X-Device-Id` via a request interceptor) and `onDeviceRevoked` (a response
      interceptor); new standalone `isDeviceRevokedError`.
- [x] `apps/mobile/lib/core/network/device_registration_api.dart` (NEW) — `registerDevice`.
- [x] `apps/mobile/lib/core/store_context/store_context_providers.dart` — `apiClientProvider` made
      fail-fast, matching `appDatabaseProvider`.
- [x] `apps/mobile/lib/main.dart` — resolves the device identity at bootstrap; best-effort
      re-registers on launch if a session already exists; overrides `apiClientProvider` with the
      real client, `onDeviceRevoked` wired to sign out.
- [x] `apps/mobile/lib/features/authentication/presentation/providers/auth_providers.dart` —
      `SignInController.signIn()` registers the device right after a fresh sign-in succeeds,
      best-effort (swallowed), per the fix in Errors item 3.
- [x] `apps/mobile/test/core/database/device_identity_repository_test.dart` (NEW, 3 cases).
- [x] `apps/mobile/test/core/network/api_client_test.dart` (NEW, 4 cases for `isDeviceRevokedError`).
- [x] `apps/mobile/test/core/database/migration_test.dart` — both reconstructed-historical-schema
      tests updated to also undo `client_device_id`, per Errors item 2.
- [x] `apps/mobile/test/features/pos/presentation/providers/pos_providers_test.dart` — adds
      `apiClientProvider.overrideWithValue(Dio())`, per Errors item 4.
- [x] Verified: `flutter analyze` clean; `flutter test` 273/273 (266 pre-existing + 7 new).
- [x] `docs/11-api/authentication.md` §4, `docs/11-api/endpoints/identity.md` (Devices section),
      `backlog.md`, `implementation-log.md`, `docs/README.md` all updated in the same PR.

## Demo script

**Local, run 2026-08-20:**

1. `flutter pub run build_runner build --delete-conflicting-outputs` — regenerates
   `database.g.dart` for the new column. ✅ (321 outputs written)
2. `flutter analyze` — clean, 0 issues. ✅
3. `flutter test` — 273/273 passing, including the 2 previously-failing `migration_test.dart` cases
   (fixed per Errors item 2), the previously-failing `login_screen_test.dart` case (fixed per Errors
   item 3), and all 11 previously-failing `pos_providers_test.dart` cases (fixed per Errors item 4). ✅

**Not performed this sprint, named rather than silently skipped:** a real device-registration flow
exercised against the live production Supabase project from an actual mobile build — the same gap
`sprint-55.md`'s own demo script named as "the more meaningful live check" once this sprint landed.
Still not performed here: this session has no way to run a real Android/iOS build against the real
backend interactively. `flutter analyze`/`flutter test` plus the server-side live verification
Sprint 55 already completed are judged sufficient for this sprint's own scope; a real device
end-to-end smoke test remains manual, founder-side verification, same as every prior mobile sprint's
Android-build-only (not live-network) verification ceiling.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming regardless: this sprint's own verification step (not code review, not planning) found
all three of this sprint's real bugs — the stale migration-test fixture, the swallowed-error gap in
sign-in, and the incomplete "tests never reach this provider" assumption behind making
`apiClientProvider` fail-fast. This is the same lesson Sprints 50–53 already named for design docs
("a claimed mechanism is not the same claim as a test proving it"), reapplied here to a design
*assumption* made in the middle of this very sprint rather than an older doc — it did not survive
contact with the existing test suite any better than an old doc would have.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-20 | Sprint 56: mobile-side device registration/revocation wiring built — `client_device_id` generated once per install and persisted on the existing `device_identity` table (schema v9→v10), registered via `POST /auth/register-device` on sign-in and on launch (best-effort), sent as `X-Device-Id` on every request, `DEVICE_REVOKED` forces an immediate local sign-out. Closes Sprint 43's OWASP finding for `authorisation-model.md §2`'s device-revocation step in full (server + mobile). Found and fixed two real bugs during verification: a migration test's reconstructed historical schema needed updating for the new column (same class of gap as Sprint 51), and a transient register-device failure was letting a successful sign-in surface as a failed one — both now fixed. 273/273 mobile tests (266 pre-existing + 7 new), `flutter analyze` clean. |
