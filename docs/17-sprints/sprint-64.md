# Sprint 64

> **Dates:** 2026-08-21 – 2026-08-21 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — real client-side defense-in-depth found hiding inside a third "purely
> founder-blocked" finding)
> **Status:** Closed. The third and, on current evidence, last instance of this pattern in this
> project's remaining release-gate findings.

## Goal

Sprints 62 and 63 each re-examined a finding that had been labeled "purely a founder action, no
engineering work possible" and found that framing bundled a real, buildable engineering task
together with a genuinely founder-only one. This sprint applies the same scrutiny to the third and
last item carrying that label: Sprint 45's sign-in rate-limiting finding.

## What was found

`rate-limiting.md`'s Auth row has said, since Sprint 45, that server-side rate limiting for sign-in
"cannot be implemented in this codebase" — true, and re-confirmed directly this sprint, not just
trusted: sign-in is a direct client call to Supabase Auth (GoTrue), and genuinely never reaches an
`apps/web` Route Handler this codebase's own `requirePermission`-based rate limiter could intercept.
That narrow claim holds fully.

But `apps/mobile/lib/features/authentication/presentation/screens/login_screen.dart` and
`SignInController` had **zero** mitigation of any kind on the client: the submit button disabled
only while a single request was in flight, then re-enabled immediately on failure with no attempt
counter, no backoff, no cooldown — a user, or a script, could retry sign-in as fast as the network
round-trip allowed, unboundedly. Nothing about that gap depends on Supabase configuration; it's
ordinary client-side defense-in-depth this codebase simply never built.

A second possibility was investigated and deliberately not pursued this sprint: `apps/web`'s
existing service-role `supabaseAdmin` client (already wired, already used for
`admin.inviteUserByEmail`) also exposes `admin.updateUserById(userId, { ban_duration })` — a
technically-reachable path to a server-side lockout, mediated through the Admin API rather than
attached to the sign-in request itself. Real, but requires new plumbing (a source of failed-attempt
observations, e.g. an Auth webhook) not attempted this sprint, and — more importantly — risks
exactly the DoS-against-a-legitimate-Cashier vector `identity-and-sessions.md §6` already reasoned
through and deliberately rejected for server-side account lockout. Named as real, separately-scoped
future work, not built speculatively.

## What was built

`SignInController` (`apps/mobile/lib/features/authentication/presentation/providers/auth_providers.dart`)
now tracks consecutive failed sign-in attempts in memory:

- The first 3 failures are always free — no delay, so a Cashier who mistypes a password twice is
  never affected.
- The 4th failure onward triggers an exponential cooldown before the same running app instance can
  retry: 5s, 10s, 20s, 40s, capped at 60s.
- Any successful sign-in resets the counter to zero.
- While in cooldown, `signIn()` short-circuits before ever calling the repository, surfacing
  `AuthFailure('Too many attempts. Try again in Ns.')` through the exact same error-rendering path
  `login_screen.dart` already had — no UI change needed.

## Design decisions

1. **In-memory only, deliberately.** The counter lives on the `SignInController` instance, resetting
   on app restart. This is an explicit, named limitation, not an oversight: the goal is raising the
   cost of a rapid retry loop from a single running app instance, not providing an airtight
   guarantee — that guarantee, if it's ever built, is the server-side control this sprint leaves
   open. Persisting the counter (e.g., to the local Drift database) would add real complexity for a
   security property client-side code can't actually deliver regardless.
2. **Reuse `AuthFailure`, not a new state shape.** The existing `AsyncValue<void>` state on
   `SignInController`, and the existing `AuthFailure`-aware error rendering in `login_screen.dart`,
   already do everything needed — constructing an `AuthFailure` with a cooldown-specific message
   flows through both unchanged. A richer state type (e.g., exposing "seconds remaining" for a live
   countdown) was considered and rejected as unnecessary polish for what this sprint frames as a
   security mitigation, not a UX feature.
3. **Only the credential-check call is wrapped for failure-counting**, not the whole
   `AsyncValue.guard` block — a separate inner `try`/`catch` around `signInWithPassword` specifically,
   so the already-separate, already-swallowed device-registration failure path (Sprint 56) can't
   accidentally increment the same counter a valid sign-in shouldn't be penalised for.
4. **Test the controller directly via `ProviderContainer`, not a widget tree.** None of this logic
   touches rendering — a dedicated `auth_providers_test.dart`, reusing the "fake, not a mock"
   convention `login_screen_test.dart`'s own `_FakeAuthRepository` already established, exercises the
   throttling behaviour directly and immediately, with no real time delays needed to prove the
   cooldown activates (only that it activates, not that it expires on schedule).

## Definition of Done

- [x] `apps/mobile/lib/features/authentication/presentation/providers/auth_providers.dart` —
      `SignInController` tracks consecutive failures, applies an exponential cooldown, resets on
      success.
- [x] `apps/mobile/test/features/authentication/presentation/providers/auth_providers_test.dart`
      (NEW, 3 cases): free attempts genuinely reach the repository; the cooldown genuinely blocks
      the repository from being called again; a success genuinely resets the counter.
- [x] Verified: `flutter analyze` clean; `flutter test` 280/280 (277 pre-existing + 3 new).
- [x] `docs/11-api/rate-limiting.md`'s Auth row, `docs/12-security/identity-and-sessions.md §6`,
      `docs/12-security/owasp-checklist.md`'s A07 row and summary item 2, and
      `docs/14-testing/release-checklist.md`'s OWASP row all corrected — none claim the server-side
      gap is closed, only that it's no longer the sole mitigation.
- [x] `backlog.md`, `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md`
      updated in the same PR, including an explicit self-correction of Sprint 63's own
      `implementation-log.md` entry, which had (wrongly, disproven within the same session) called
      Android signing "the last one that was genuinely engineering work."

## Demo script

**Local, run 2026-08-21:**

1. Re-confirmed the server-side claim directly rather than trusted from Sprint 45's own account:
   grepped `apps/web/src` for any route or middleware sign-in could reach — none exists; sign-in is
   entirely a Supabase-client-side call. ✅
2. Grepped `apps/mobile/lib/features/authentication/` for any existing attempt-counting, backoff, or
   lockout logic before writing any code — confirmed zero hits. ✅
3. `flutter analyze` — clean, 0 issues. ✅
4. `flutter test` — 280/280 passing, including the 3 new throttling test cases. ✅

**Not performed, and deliberately not attempted this sprint:** the admin-API-mediated server-side
lockout path named above. Real, but carries a genuine DoS risk if built without the same care
`identity-and-sessions.md §6` already applied to rejecting a simpler version of the same idea —
worth a dedicated future sprint with its own explicit risk analysis, not something to build in the
margin of re-examining a different finding.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming plainly: Sprints 62, 63, and 64 are the same move applied three times to the three
items this project's own documentation had labeled "purely founder-blocked, no engineering work
possible." All three turned out to be wrong in the same specific way — not wrong about the
founder-only part, which held in every case, but incomplete about it, having silently assumed no
other angle existed without checking. Sprint 63's own `implementation-log.md` entry claimed Android
signing was "the last" such case — disproven by this very sprint, within the same session, the kind
of claim this project's own standing practice exists specifically to catch and correct rather than
let stand unchallenged. Worth stating for the record now that all three are closed: there is no
remaining reason to expect a fourth. MTS execution genuinely has no code-shaped angle — it names
physical hardware nobody owns, not a mischaracterized software gap — and has been checked for
exactly that reason multiple times this run of sprints without finding one.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-21 | Sprint 64: found real client-side defense-in-depth hiding inside Sprint 45's "architecturally unreachable" sign-in rate-limiting finding — the server-side claim holds, but nothing throttled repeated failed attempts on the client either. Built `SignInController`'s exponential-cooldown attempt throttling (5s–60s, resets on success), honestly scoped as narrower than the still-open server-side gap. Investigated and deliberately deferred an admin-API-mediated server-side lockout path, named as real future work carrying its own DoS risk. `flutter test` 280/280 (277 pre-existing + 3 new). Corrected `rate-limiting.md`, `identity-and-sessions.md`, `owasp-checklist.md`, and `release-checklist.md`. |
