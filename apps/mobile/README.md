# apps/mobile — not yet scaffolded

**This directory is intentionally empty of Dart/Flutter code.** The machine this repository was
first scaffolded on does not have the Flutter SDK installed, and hand-writing `pubspec.yaml`/Dart
files without the SDK available to verify them against current, real package versions would be
exactly the kind of unverified-tooling guess this project's documentation set has consistently
avoided (see `docs/adr/ADR-0007-client-generated-uuid-primary-keys.md` and
`docs/14-testing/device-matrix.md §2` for the same standing practice applied elsewhere).

## What needs to happen here, and by whom

This is a founder/engineer action, not something achievable from the documentation alone — the
same category of gap as `docs/16-milestones/capacity-model.md`'s OD-06 resolution and
`docs/14-testing/device-matrix.md §3`'s physical reference device.

1. Install the Flutter SDK (stable channel) on a machine that will build this app.
2. From `apps/mobile/`, run `flutter create --org com.smartposx --project-name mobile .`
   targeting Android only for V1 (per `docs/01-vision/project-vision.md`'s Android-first decision
   — iOS is explicitly out of scope at launch, per `docs/02-business-requirements/scope-and-release-slices.md`'s
   permanent scope boundary).
3. Replace the generated `lib/` structure with the feature-first layout already fully specified in
   `docs/08-folder-structure/mobile-structure.md` — that document is the actual design; whatever
   `flutter create` scaffolds by default is just a starting point to reshape.
4. Add the packages already named in `docs/01-vision/project-vision.md`'s tech stack (Riverpod,
   Go Router, Drift, Freezed, flutter_secure_storage, mobile_scanner, etc.), at whatever their
   current stable versions are at the time — not the versions this document would have guessed at
   months earlier.

## What's already fully specified and ready to build against

Everything in `docs/08-folder-structure/mobile-structure.md`, `docs/10-design-system/`, and
`docs/13-offline-sync/` — the folder structure, every screen's design tokens and states, and the
entire sync engine architecture — is complete. Scaffolding this app is mechanical once the SDK is
available; no design decision is waiting on it.
