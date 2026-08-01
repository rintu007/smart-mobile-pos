# apps/mobile

Flutter app for SmartPOS X — Android only for V1
([project-vision.md](../../docs/01-vision/project-vision.md)'s Android-first decision;
[scope-and-release-slices.md](../../docs/02-business-requirements/scope-and-release-slices.md)'s
permanent scope boundary).

## Status

Scaffolded in Sprint 03 (`flutter create --org com.smartposx --project-name mobile .`), reshaped
into the feature-first layout [mobile-structure.md](../../docs/08-folder-structure/mobile-structure.md)
specifies. `lib/core/database/` implements backlog.md item 4's scope: `outbound_queue` (full V1
shape) plus a minimal `products`/`sales`/`sale_line_items`/`sale_payments`/`stock_movements` slice
sized to M0's actual exit criterion — not the full V1 column set, which grows as M1/M2 land (see
each table file's own comment for exactly what's deferred and why).

No `features/` folder has real content yet — `app/home_screen.dart` is a temporary composition-root
screen proving the local database opens and is queryable, not the first feature. It's replaced once
Sprint 03+ builds the actual till/catalogue screens.

## Known environment gap: Android SDK

The Flutter SDK is installed locally (stable channel, not committed to this repo — see the machine
running this project's own `flutter --version`). The **Android SDK is not** — `flutter analyze` and
`flutter test` both run and pass without it (pure Dart analysis and the in-memory Drift database
don't need a device or emulator), but building or running the app on Android does. Installing
Android Studio / the standalone SDK is deferred until a sprint actually needs to build/run on a
device or emulator (backlog.md item 6 onward) — the same "don't install ahead of the backlog" logic
this document previously applied to the Flutter SDK itself.

## Adding features

Per [mobile-structure.md §2](../../docs/08-folder-structure/mobile-structure.md#2-per-feature-anatomy--identical-in-every-feature-folder),
every `features/<name>/` folder uses the same `domain/`/`data/`/`presentation/` three-layer anatomy.
`app/router.dart` and `app/providers.dart` are the only files touched when a new feature is
registered, per §4.

## Packages

Riverpod, Go Router, Drift (via `drift_flutter` — the current recommended setup, superseding manual
`sqlite3_flutter_libs` wiring), Freezed, `flutter_secure_storage`, `mobile_scanner`, Dio — all added
at whatever their actual current stable versions were as of Sprint 03
([project-vision.md](../../docs/01-vision/project-vision.md)'s tech stack), not guessed. Riverpod's
code-generation packages (`riverpod_generator`/`riverpod_lint`) are **not** installed — they don't
yet support Riverpod 3.x cleanly (a real, current ecosystem-version conflict with `drift_dev`, not a
gap in this setup); manual provider syntax is used until that resolves. Money columns use `integer()`
(plain 64-bit `int`), not Drift's `int64()` (`BigInt`) — this app has no web target, so the
JS-precision concern `int64()` exists for doesn't apply, and `int` is far more ergonomic throughout
till/catalogue code than `BigInt` would be.
