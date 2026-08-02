# ADR-0010 — Inject Supabase URL and anon key into the Flutter app via `--dart-define`, never hardcoded

> **Status:** 🟢 Accepted
> **Date:** 2026-08-02
> **Phase:** 18 — Implementation (Sprint 06)
> **Deciders:** CTO
> **Supersedes:** _none_

---

## Context

Sprint 06 builds the mobile app's first screen that talks to a real backend service (Supabase
Auth sign-in), which means the Flutter client needs to know which Supabase project to talk to —
a project URL and an anon (public) API key. No prior sprint decided how mobile app configuration
reaches compiled Dart code; `apps/web` uses `.env.local` (Next.js's built-in convention), but
Flutter has no equivalent file-based env loading without adding a package and a runtime read.

The Supabase anon key is designed to be embedded in public clients — it identifies the project,
not a secret credential; Row Level Security, not key secrecy, is what protects tenant data
([tenancy-model.md](../07-database/tenancy-model.md)). So this is not a "how do we keep a secret"
problem. It is a "how do we avoid hardcoding an environment-specific value into source, so dev and
production can point at different Supabase projects without editing committed code" problem.

## Decision drivers

- The same source must be buildable against different Supabase projects (dev vs. eventual
  production) without a code change — hardcoding one URL/key pair in a `.dart` file forecloses that.
- No package addition should be required just to answer this (Flutter already has a built-in
  mechanism); a manual `.env` parser adds a dependency and a runtime failure mode for zero benefit.
- Whatever convention is picked here is precedent for every future mobile config value, not just
  this one pair — worth deciding deliberately once rather than ad hoc per sprint.

## Options considered

### Option A — `String.fromEnvironment`, values passed via `--dart-define` at build/run time
Flutter's built-in compile-time constant mechanism. Values are passed on the command line
(`flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`) or via a
`--dart-define-from-file=<json>` pointing at a gitignored file, and read in Dart via
`String.fromEnvironment('SUPABASE_URL')`.

| Pros | Cons |
| --- | --- |
| Built into the Flutter SDK — no new dependency | Values must be supplied on every `flutter run`/`flutter build` invocation or via a `--dart-define-from-file` |
| Compile-time constant — no runtime file I/O, no missing-file failure mode | Slightly more typing than a `.env` file for local dev |
| Same mechanism CI will need anyway to build against a test project | |

### Option B — `flutter_dotenv` package reading a gitignored `.env` file at runtime
Mirrors `apps/web`'s `.env.local` pattern using a community package.

| Pros | Cons |
| --- | --- |
| Familiar `.env` file, matches the web app's convention | New dependency for a problem the SDK already solves |
| | Runtime file read — app can start with no config and fail later instead of failing to compile |
| | Asset bundling required (the `.env` file must be declared as a Flutter asset) to be readable on-device |

### Option C — Hardcode the dev project's URL/key directly in `core/config/env.dart`
Simplest possible option.

| Pros | Cons |
| --- | --- |
| Zero setup | Cannot point at a different Supabase project without editing and recommitting source |
| | Invites the same value drifting into version control that `.env.local` is deliberately gitignored to prevent on the web side |

## Decision

We will use **Option A** — `String.fromEnvironment`, values supplied via `--dart-define` (or
`--dart-define-from-file` pointing at a gitignored JSON file for local convenience), read once in
`lib/core/config/env.dart`.

Rationale: it is the only option that needs no new dependency and still lets dev and future
production builds point at different projects without a source change — directly answering the
decision driver that forced this ADR. Option C fails that driver outright; Option B pays a real
dependency and runtime-safety cost to reproduce a mechanism the SDK already provides for free.

## Consequences

**Positive**
- No new pubspec dependency for configuration.
- Missing config fails at compile time (`Env.supabaseUrl` empty-string default made to throw
  immediately in `main.dart`) rather than silently starting the app with a broken client.
- Establishes the pattern every future mobile config value (any other backend URL, feature flag)
  follows, so this decision does not need re-litigating per sprint.

**Negative — accepted costs**
- Every local `flutter run`/`flutter test` that touches the Supabase client needs the two
  `--dart-define` values supplied, either typed inline or via a local
  `--dart-define-from-file=mobile.env.json` (gitignored, analogous to `apps/web/.env.local`).
- CI must be taught the same flags once mobile CI actually builds/runs against a live project —
  not yet the case (`mobile-analyze-test` currently only runs `flutter analyze`/`flutter test`,
  neither of which needs live Supabase config).

**Neutral**
- The anon key is not secret in the sense the web service-role key is; this decision is about
  environment-swappability, not confidentiality.

## Compliance

`lib/core/config/env.dart` is the **only** file permitted to call `String.fromEnvironment` for
Supabase config; nothing else in `apps/mobile/lib` may reference a Supabase URL/key literal —
enforced by code review, matching the module loop's own "no placeholder/no shortcut" review step
until a lint rule is worth writing for it.

## Revisit when

Mobile CI needs to run against a real Supabase project (an integration-test tier beyond
`flutter analyze`/`flutter test`), at which point the CI secret-injection mechanism for these two
`--dart-define` values needs its own decision, or when a second environment (production) actually
exists to build against.
