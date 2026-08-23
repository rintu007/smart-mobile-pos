# Sprint 63

> **Dates:** 2026-08-21 – 2026-08-21 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — closes the code half of Sprint 43's own M8 finding)
> **Status:** Closed. The second consecutive sprint in this run that builds something rather than
> correcting or verifying a claim.

## Goal

Following Sprint 62's diagnostic script (turning "go check RLS in production" from an open-ended
task into a five-minute action), this sprint applies the same idea to the other named-but-not-fully-
scoped founder action: Android release signing. `owasp-checklist.md`'s M8 finding has said, since
Sprint 43, that fixing this "needs a real, founder-owned production keystore and its credentials" —
true, but that framing left an implicit, unstated second task bundled in: actually wiring
`build.gradle.kts` to use one once it exists. That second task is real engineering work this session
*can* do, and hadn't been separated out from the part that genuinely can't.

## What was built

`apps/mobile/android/app/build.gradle.kts` — the standard Flutter release-signing pattern:

- Loads `key.properties` (via `rootProject.file(...)`, resolving relative to the `android/`
  directory) if it exists.
- A new `signingConfigs.create("release")` block, populated from that file's four values
  (`keyAlias`, `keyPassword`, `storeFile`, `storePassword`) — only created at all when the file
  exists, so nothing references undefined properties when it doesn't.
- `buildTypes.release.signingConfig` switches to the new `"release"` config when `key.properties`
  exists, and falls back to `"debug"` — byte-for-byte the same as before this sprint — when it
  doesn't.

`apps/mobile/android/key.properties.example` (NEW, the only version tracked in git — the real file
is already covered by Flutter's own default `.gitignore` scaffold, confirmed before writing any
code) — the exact `keytool -genkey` command to run, the four resulting values to fill in, and an
explicit warning that losing the keystore file permanently forfeits the ability to publish an
update to any device that ever installed a build signed with it.

## A bug caught before it shipped, not after

The first draft used a bare `file(...)` call for `storeFile`, copying the exact line from Flutter's
own official documentation example. That resolves relative to the `app/` module directory — but
`key.properties` itself (and the `keytool` instructions written in the same pass) both put the
keystore in the parent `android/` directory, alongside `key.properties`. Running the official
example verbatim would have looked for the keystore in the wrong directory the first time the
founder actually tried to use it. Caught by reading the two files against each other before
committing, not discovered later when a real build failed for a founder holding a real keystore —
fixed by using `rootProject.file(...)` for `storeFile` too, matching where `keystorePropertiesFile`
itself is resolved.

## Design decisions

1. **No behaviour change until `key.properties` exists.** The entire point is that this sprint's
   code change is safe to merge and verify today, before any real keystore exists — `hasRealKeystore`
   gates every new code path, and the fallback is identical to what shipped before this sprint.
2. **`key.properties.example`, not inline instructions only.** A real file the founder copies and
   edits is less error-prone than reconstructing a properties file from prose in a doc — the same
   reasoning behind Sprint 62 shipping an actual `.sql` file rather than only describing the query.
3. **Verify with a real build, not just `flutter analyze`.** This change touches Gradle/Kotlin, not
   Dart — `flutter analyze` wouldn't catch a Gradle syntax error or the path-resolution bug found
   above. A real `flutter build apk --debug` was run and confirmed to still produce a working APK
   with `key.properties` absent, matching this project's own standing "verify what you build"
   discipline.
4. **Correct three documents, not just note it in one.** `cd-workflows.md §2`, `owasp-checklist.md`'s
   M8 row and summary, and `release-checklist.md`'s Android row all separately described this gap —
   the same "reference it from every place a reader would look" discipline Sprint 62 established.

## Definition of Done

- [x] `apps/mobile/android/app/build.gradle.kts` — reads real signing credentials from a gitignored
      `key.properties` if present, falls back to debug unchanged otherwise.
- [x] `apps/mobile/android/key.properties.example` (NEW) — exact `keytool` command, four values,
      keystore-loss warning.
- [x] Verified: `flutter build apk --debug --target-platform android-arm64` succeeds with
      `key.properties` absent; `flutter analyze` clean (unaffected — no Dart file touched).
- [x] `docs/15-github-project/cd-workflows.md §2`, `docs/12-security/owasp-checklist.md` (M8 row +
      summary item 4), `docs/14-testing/release-checklist.md` (Android row) all corrected.
- [x] `backlog.md`, `implementation-log.md`, `docs/18-implementation/README.md`, `docs/README.md`
      updated in the same PR.

## Demo script

**Local, run 2026-08-21:**

1. `flutter build apk --debug --target-platform android-arm64` (with no `key.properties` present) —
   succeeds, `app-debug.apk` produced, confirming the fallback path genuinely still works rather
   than just compiling. ✅
2. `flutter analyze` — clean, 0 issues (this change touches no Dart file). ✅
3. Read `key.properties.example` against the gradle change's own `rootProject.file(...)` calls —
   confirmed both agree the keystore and properties file live in `android/`, the exact
   inconsistency found and fixed before this demo step. ✅

**Not performed, and cannot be performed by this session:** generating a real production keystore
or producing a real, non-debug-signed release build. `keytool -genkey` is interactive (prompts for
passwords and identity details) and the resulting file must be kept by the founder, outside this
repository — this remains, correctly, the one piece of this gap that stays founder-owned.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process change.
Worth naming: Sprints 62 and 63, taken together, are the same move applied twice — a finding that
had been described only as "founder-blocked" turned out, on closer look, to bundle a real
engineering task together with a genuinely founder-only one. Separating the two doesn't remove the
founder-only part, but it stops it from hiding the engineering part behind it. Worth checking for a
third time before assuming the remaining two items (sign-in rate limiting, MTS hardware) are as
irreducibly founder-only as they appear — sign-in rate limiting in particular is worth one more
look, since "architecturally unreachable from this codebase" was a Sprint 45 finding, not
re-examined since.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-21 | Sprint 63: wired `build.gradle.kts` to read real Android signing credentials from a gitignored `key.properties` if present, falling back to the debug keystore unchanged otherwise — closes the code half of Sprint 43's M8 finding. Added `key.properties.example` with the exact `keytool` command. Caught and fixed a real path-resolution bug (bare `file()` vs `rootProject.file()`) before committing. Verified with a clean `flutter build apk --debug`. Corrected `cd-workflows.md`, `owasp-checklist.md`, and `release-checklist.md` — all three remaining OWASP release-gate findings are now purely founder actions. |
