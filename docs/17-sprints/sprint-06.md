# Sprint 06

> **Dates:** 2026-08-02 – 2026-08-02 (single-day, same pattern as Sprints 02–05)
> **Milestone:** M0 — Walking Skeleton
> **Status:** Closed

## Goal

Build the mobile app's first real screen — sign-in — closing the gap Sprint 06 planning found in
[backlog.md](backlog.md): item 11's end-to-end proof requires "sign in" as its first step, but no
backlog item ever decomposed the mobile sign-in screen itself.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| 12 | Authentication (mobile) | 1.5 | 2, 3 — both done (Sprint 01/02) |

Sign-in is a direct client call to Supabase Auth, not a REST endpoint this API owns
([authentication/specification.md §4](../modules/authentication/specification.md#4-api-contract)),
so this sprint touches only `apps/mobile` — no backend code changes. This is also the first sprint
to need mobile build-time configuration (the Supabase URL and anon key); resolved as
[ADR-0010](../adr/ADR-0010-mobile-config-via-dart-define.md) before writing the client code that
needed it, per this phase's "design before code" rule.

## Capacity check

1.5 person-days, against [sprint-cadence.md](sprint-cadence.md)'s ~3.75 person-day budget at the
midpoint pace — well inside budget, deliberately: this is the first Flutter *feature* screen this
project has built (Sprint 03 only scaffolded the local database), so the estimate stays
conservative rather than bundling in the product-creation local-write path (backlog item 5's still-
undone mobile half) or the till screen (item 6) in the same sprint. Named explicitly in Risks below
so it isn't silently deferred again without acknowledgement.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — same reservation every prior sprint has carried.
- [x] Documentation capacity reserved: this sprint's own doc updates (backlog.md item 12,
      ADR-0010, this file, module registry, implementation-log, README version bumps) are inside
      the estimate above, not appended after it.

## Risks

- **Three-sprints-running mobile-UI deferral** (named in
  [sprint-05.md](sprint-05.md#risks)) — this sprint is the first concrete action against it, but it
  closes only the sign-in slice. Backlog items 5's mobile local-write half and item 6 (till screen)
  remain undone after this sprint closes; Sprint 07 planning needs to weigh them directly rather
  than treating this sprint as having resolved the whole risk.
- **First `--dart-define`-based config in the project** — if a value is left unset, the app should
  fail loudly at startup, not silently hit a blank Supabase URL. Verified in the demo script below
  (step 1).
- **No mobile CI job yet exercises a real Supabase call** — `mobile-analyze-test` runs
  `flutter analyze`/`flutter test` only, so this sprint's live demo (not CI) is what actually proves
  sign-in works against production Supabase, same pattern as every backend sprint's live-demo
  requirement.

## Definition of Done

Mobile-only slice, first of its kind — the [Definition of Done](../00-governance/definition-of-done.md)
boxes this sprint's scope can actually satisfy:

- [x] Module specification already covers this screen —
      [authentication/specification.md §9](../modules/authentication/specification.md#9-ui-specification) —
      no new specification needed, only an implementation reaching what was already approved.
- [x] `/auth/login` route matches [route-map.md](../09-navigation/route-map.md)'s guard (`None` —
      unauthenticated-only, requires connectivity).
- [x] Session persisted on-device via `flutter_secure_storage` (already a dependency, unused until
      this sprint).
- [x] Config (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) injected via `--dart-define`, never hardcoded —
      [ADR-0010](../adr/ADR-0010-mobile-config-via-dart-define.md).
- [x] Widget tests for the login screen's loading/error/success states.
- [x] `flutter analyze` clean, `flutter test` green.
- [x] No secret, token, or key written to logs or committed to source.
- [x] Live demo against real Supabase Auth (not just widget tests against a mocked repository).
- [x] Module registry ([modules/README.md](../modules/README.md)) and backlog.md updated.

**Explicitly not in this sprint's DoD subset:** device registration/revocation (§4 of the
authentication spec — separately tracked, not blocking sign-in), `/auth/verify` (account creation
and email confirmation belong to Company & Store Setup's web onboarding flow, not mobile, per
[authentication/specification.md §1](../modules/authentication/specification.md#1-purpose-and-business-context)),
any product/sales/till screen (items 5's mobile half and 6, deferred per Risks above).

## Demo script

**As planned** (below), this assumed running the actual rendered `LoginScreen` end-to-end against
production Supabase on a real device. **What actually ran, and why it changed:** `flutter doctor`
found no usable device for that — the Windows desktop target is missing its C++ build workload and
Android has no SDK installed here; only Chrome (web) and the widget-test harness are available. And
`flutter test` itself turned out to block real HTTP calls and has no `shared_preferences` platform
channel, so it can't reach live Supabase either. Both are genuine environment gaps, not
this code's fault — recorded honestly rather than claiming the original script ran as written.

**Run 2026-08-02, in two parts:**

**Part A — widget-level UI proof** (`flutter test`, fakes, no network): the 8 tests in
`test/features/authentication/presentation/screens/login_screen_test.dart` and `test/widget_test.dart`
cover empty-field validation, the loading state during an in-flight sign-in, a thrown `AuthFailure`
rendering as inline error text, and the pre-existing home-screen database check — all against a
fake `AuthRepository`, proving the screen's own state machine.

**Part B — real-infrastructure proof** (Chrome, real Supabase, real credentials, no fakes): a
temporary Dart entrypoint (`live_demo/main_live_demo.dart`, run via `flutter run -d chrome`, deleted
after) called the actual `SupabaseAuthRepository` production class against a real, previously
onboarded user (created via the same `POST /api/v1/onboarding` pattern prior sprints' demo scripts
used, then deleted afterward along with its Supabase Auth account):

1. Assert no session exists before sign-in. ✅
2. Sign in with valid credentials — assert a session exists and the signed-in user's email matches. ✅
3. Sign out — assert the session is cleared. ✅
4. Sign in again with a wrong password — assert it throws, mapped to `AuthFailure`, not a raw
   Supabase exception. ✅

**What Part B does not cover, honestly:** it never rendered `LoginScreen` itself against a live
backend (no available device could run it), so the actual tap-a-button-see-a-redirect flow is
proven only by combining Part A (screen behaves correctly against a fake) and Part B (the same
repository class behaves correctly against the real backend) rather than by one single end-to-end
run. Closing that gap needs either the Windows C++ workload or an Android SDK — tracked as a
Sprint 06 finding below, not silently accepted as equivalent.

## Environment findings

Two real, unplanned blockers surfaced during this sprint, both resolved without changing scope:

- **The C: drive filled to 0 bytes free** partway through (`flutter pub add` failed outright) —
  not caused by this sprint's own work (the Temp folder itself held under 1 GB); root cause was
  accumulated package-manager caches (Docker, npm, pnpm, Composer) never pruned. Resolved by
  clearing npm/pnpm caches (~4.5 GB), confirmed with the founder before doing so since it's a
  machine-wide action outside this project's scope.
- **No local device can run the actual mobile UI** — Windows desktop needs the "Desktop development
  with C++" Visual Studio workload (not installed) and Android has no SDK configured. Discovered
  only when the demo script needed a real device, not during planning — `flutter doctor` should be
  the first command of any sprint touching mobile UI going forward, not something the demo script
  discovers the hard way. Logged as a retrospective entry below since it's a concrete process change.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md): the missing-device-target gap is a
concrete process change (run `flutter doctor` at the start of any UI-touching sprint), not just
sentiment.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-02 | Sprint 06 planned: closes the mobile-sign-in gap found in backlog.md (item 12), the first concrete action against the three-sprints-running mobile-UI-deferral risk named in sprint-05.md. |
| 0.2.0 | 2026-08-02 | Sprint 06 closed: `/auth/login` built, tested (8 widget tests), and verified live against real Supabase Auth via a temporary Chrome-run script (no local device could run the actual UI — logged as a retrospective finding, not worked around silently). PR pending. |
