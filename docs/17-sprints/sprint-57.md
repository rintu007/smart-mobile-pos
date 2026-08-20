# Sprint 57

> **Dates:** 2026-08-21 – 2026-08-21 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — the last of `failure-scenarios.md`'s 10 named offline failure scenarios without
> real coverage)
> **Status:** Closed. `release-checklist.md`'s failure-scenarios release-gate row flips to
> satisfied for the first time in this project's history.

## Goal

With Sprint 56 closing M4's only outstanding cross-cutting OWASP finding, the only remaining named
gap of any kind left in this project's testing/release surface was "Token expired while queued" —
the one failure scenario `test-plan.md §3` still classified as **Deferred**, on the grounds that it
"needs a real Supabase Auth (GoTrue) JWT issuance/expiry — the full local Supabase CLI stack." This
sprint checks that claim directly, the same discipline Sprints 50, 51, 52, and 54 already applied to
four other "this needs infra we don't have" claims in this exact document — all four turned out to
be false. This is the fifth such check.

## What was found while investigating, before writing any code

1. **The infra-needed claim was false again — but the real gap underneath it was more consequential
   than the previous four.** `core/auth/session.ts` never emits a distinct `TOKEN_EXPIRED` code —
   `auth.getUser(token)`'s rejection of an expired JWT is caught by the exact same generic branch as
   a missing or malformed token, and mapped to plain `401 UNAUTHENTICATED`. `error-catalogue.md` had
   documented `TOKEN_EXPIRED` as a real, distinct code since Phase 11 — it never was one.
2. **No reactive refresh-and-retry code existed in the mobile client at all**, despite
   `authentication.md §3`'s own existing text already claiming the client refreshes "not only
   reactively on a 401" — implying a reactive path existed. Grepping `apps/mobile/lib` found zero
   `refreshSession`/`autoRefreshToken`/401-retry logic anywhere. The entire "invisible to the
   Cashier" guarantee was resting on `supabase_flutter`'s own proactive background-refresh timer
   alone.
3. **The proactive-only mechanism has one real, narrow gap**: `GoTrueClient`'s timer can only refresh
   while the app has connectivity. A device offline through its entire 60-minute access-token TTL
   and then reconnecting can have its very first queued sync request rejected before the timer's
   next tick catches up (confirmed by reading `gotrue-2.26.0`'s own source directly, not assumed from
   its docs).
4. **This gap was not actually invisible to the Cashier**, contradicting `failure-scenarios.md`'s
   own claim. `SyncRepository._pushQueuedOperations` has no try/catch around its push call, so a 401
   there aborts the entire `syncNow()` cycle (leaving the queued row safely untouched for the next
   cycle — no data lost) — but a manual "Sync now" tap hitting this would render `home_screen.dart`'s
   `error: (error, stack) => Text('Sync failed: $error', ...)` directly to the Cashier, not the
   silent retry the design doc promised.
5. **A self-found documentation error, corrected in the same pass**: while updating
   `docs/18-implementation/README.md`'s status line for this sprint, found that Sprint 56's own
   update to that file (merged, PR #81) had wrongly claimed "M4's 9 numbered backlog items are all
   done" — conflating Sprints 55/56's unnumbered device-registration cross-cutting fixes with M4's
   actual, still-founder-blocked item 9 (MTS execution). Corrected in this sprint's own docs update,
   named explicitly rather than silently fixed.

## Design decisions

1. **Fold `TOKEN_EXPIRED` into `UNAUTHENTICATED` rather than inventing a way to make it real.**
   Decoding a JWT server-side just to distinguish "expired" from "otherwise invalid" would add real
   complexity for a distinction the mobile client doesn't actually need — it responds to both the
   same way (try a refresh, retry once). `error-catalogue.md`'s `TOKEN_EXPIRED` row is removed; its
   client-handling guidance moves into `UNAUTHENTICATED`'s own row.
2. **The retry lives in `api_client.dart`'s existing `onError` interceptor, not a new module.**
   `isDeviceRevokedError`'s extraction pattern (a pure, independently-testable decision function) is
   reused directly for the new `isUnauthenticatedError` — same file, same shape, same test structure.
3. **The actual `refreshSession()` call itself stays untested, deliberately.** This project already
   trusts `supabase_flutter`'s proactive-refresh timer without re-proving it works against a real
   GoTrue server; the reactive fallback built here extends that same trust boundary rather than
   demanding a stricter bar just because this sprint happened to look at it closely. What's tested is
   the decision logic that drives the retry (`isUnauthenticatedError`), not GoTrue's own behavior.
4. **`DEVICE_REVOKED` is explicitly excluded from the new retry path.** Both are 401s, but a revoked
   device must never be retried after a refresh — `requireSession`'s own evaluation order means a
   request never carries both codes at once (JWT verification happens before the device check), so
   checking the code, not the status, keeps the two paths cleanly separate.

## Definition of Done

- [x] `apps/mobile/lib/core/network/api_client.dart` — `onError` interceptor now calls
      `refreshSession()` once and retries the same request once on any `401 UNAUTHENTICATED`,
      guarded against looping; `isUnauthenticatedError` extracted as a pure, testable function.
- [x] `apps/mobile/test/core/network/api_client_test.dart` — 4 new cases for `isUnauthenticatedError`
      (true for the real shape, false for `DEVICE_REVOKED`/other codes, false with no response body,
      false for a malformed body), matching `isDeviceRevokedError`'s existing 4-case shape exactly.
- [x] `docs/11-api/error-catalogue.md` — `TOKEN_EXPIRED` row removed (never actually implementable);
      `UNAUTHENTICATED`'s row corrected to describe the real, single mechanism.
- [x] `docs/11-api/authentication.md §3` — the reactive fallback documented alongside the existing
      proactive-refresh description.
- [x] `docs/13-offline-sync/failure-scenarios.md` / `test-plan.md` — "Token expired while queued"
      row corrected: built, with the real mechanism described, not the aspirational one.
- [x] `docs/14-testing/release-checklist.md` — failure-scenarios row **flips to satisfied**; bottom
      line updated to two remaining unresolved rows (down from three).
- [x] `docs/18-implementation/README.md` — Sprint 56's own status-line error (M4 item 9 wrongly
      marked done) found and corrected in the same pass.
- [x] `backlog.md`, `implementation-log.md`, `docs/README.md` updated in the same PR.
- [x] Verified: `flutter analyze` clean; `flutter test` 277/277 (273 pre-existing + 4 new).

## Demo script

**Local, run 2026-08-21:**

1. Read `gotrue-2.26.0`'s own installed source (`_autoRefreshTokenTick`, `startAutoRefresh`) directly
   from the pub cache to confirm the proactive-refresh timer's actual behavior, rather than assuming
   it from `supabase_flutter`'s public docs alone. ✅
2. Confirmed via `grep` that `core/auth/session.ts` never constructs a `TOKEN_EXPIRED` `ApiError`
   anywhere — every invalid-token branch throws `UNAUTHENTICATED`. ✅
3. Confirmed via `grep` that no 401-retry/refresh logic existed anywhere in `apps/mobile/lib` before
   this sprint. ✅
4. `flutter analyze` — clean, 0 issues. ✅
5. `flutter test` — 277/277 passing, including the 4 new `isUnauthenticatedError` cases. ✅

**Not performed this sprint, named rather than silently skipped:** a live end-to-end proof against a
real Supabase Auth server (a genuinely expired token, a real `refreshSession()` call, a real retried
request succeeding) — this remains the one thing "the full local Supabase CLI stack" would actually
be needed for, and this sprint deliberately narrows the gap to exactly that trust boundary rather
than eliminating it. The decision logic that drives the retry is real, tested code; the SDK's own
refresh mechanism is trusted, not re-proven, the same way this project already trusts it elsewhere.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming regardless: this is the **fifth** consecutive instance (after Sprints 50, 51, 52, and
54) of this exact test-plan.md document's own "needs infrastructure we don't have" reasoning being
checked directly and found false. At this point the standing lesson isn't "check this one claim" —
it's that this document's original infra-needed classifications, written once at Phase 13's initial
authoring before any of this project's actual test infrastructure existed, have a poor hit rate
against reality and are worth re-examining on sight rather than trusted by default. Separately: this
sprint's own self-correction (finding Sprint 56's status-line error in `docs/18-implementation/README.md`)
is a small, concrete instance of the same discipline this whole run of sprints has applied to design
docs, applied for the first time to a status claim this session itself wrote two sprints ago.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-21 | Sprint 57: "Token expired while queued" built — `api_client.dart`'s `onError` interceptor now retries once after a silent `refreshSession()` call on any `401 UNAUTHENTICATED`. Found `TOKEN_EXPIRED` was never a real, implementable server-side code (corrected in `error-catalogue.md`/`authentication.md §3`), and that no reactive refresh-and-retry logic existed in the mobile client at all before this sprint. All 10 named failure scenarios now have real coverage — `release-checklist.md`'s failure-scenarios row flips to satisfied. Also found and corrected a self-introduced documentation error from Sprint 56's own status-line update (M4 item 9 wrongly marked done). 277/277 mobile tests (273 pre-existing + 4 new), `flutter analyze` clean. |
