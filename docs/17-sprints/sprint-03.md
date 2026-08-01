# Sprint 03

> **Dates:** Started 2026-08-01
> **Milestone:** M0 — Walking Skeleton
> **Status:** Done — Flutter SDK installed, `apps/mobile` scaffolded and reshaped to
> [mobile-structure.md](../08-folder-structure/mobile-structure.md), local Drift database built and
> verified via `flutter test` (schema opens, all five tables round-trip). See
> [implementation-log.md](../18-implementation/implementation-log.md) for the package-version
> findings this sprint hit.

## Goal

The mobile app has a real, feature-first Flutter project with a local SQLite database that opens
and holds the minimal `outbound_queue`/`products`/`sales`/`stock_movements` shape M0's remaining
backlog items build on.

## Scope

Backlog item 4 from [backlog.md §1](backlog.md#1-m0--walking-skeleton-fully-decomposed) — the item
every other remaining M0 item (5 through 11) depends on, since none of them can start without the
Flutter SDK and a local database to write to.

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Local Drift DB scaffold: `outbound_queue`, minimal `products`/`sales`/`stock_movements` tables | — (core infrastructure, not a business module — same category as Sprint 01) | 1.5 | 1 (done, Sprint 01) |

A real, out-of-band prerequisite consumed part of this sprint's capacity: the Flutter SDK itself
was not installed in this environment (named as a gap in `apps/mobile/README.md` since Sprint 01,
and explicitly why Sprint 02 stayed backend-only). Installing it, and the `flutter create`
scaffold + package setup it unblocks, is accounted for below rather than treated as free.

## Capacity check

1.5 person-days of backlog scope, plus the unplanned Flutter SDK install and package-version
troubleshooting (see Risks), against a ~3.75 person-day sprint budget. Tighter than Sprint 02's
headroom, but the same logic applies: no other backlog item is unblocked without this one landing
first (items 5–11 all depend on it, directly or transitively), so there was no alternative scope to
pull forward instead.

## Reserved capacity

- [x] Defect capacity reserved: 1.0 person-day — first contact with a from-scratch Flutter/Dart
      toolchain and a live package registry (`pub.dev`) neither of which had been exercised before
      in this project; per Sprint 01/02's own retrospectives, first contact with real tooling is
      exactly where estimates go wrong.
- [x] Documentation capacity reserved: 0.5 person-days — `apps/mobile/README.md` rewritten to match
      reality, this sprint document, and the implementation-log entry below.

## Risks

- **Ecosystem-version risk, realised:** `riverpod_lint`/`custom_lint` do not yet support Riverpod
  3.4.2 cleanly (a real, current dependency-solver conflict with `drift_dev`, discovered by actually
  running `flutter pub add`, not by reading changelogs). Resolved by dropping both lint packages and
  `riverpod_generator` for now — manual Riverpod provider syntax is used until the ecosystem catches
  up, named explicitly in `apps/mobile/README.md` rather than silently worked around.
- **A guessed dependency turned out to be obsolete:** `sqlite3_flutter_libs`, the package this
  project's own docs implicitly assumed would be needed for Drift-on-Flutter, is marked end-of-life
  (`0.6.0+eol`) — `sqlite3` v3.x now bundles native library resolution itself, and `drift_flutter` is
  the current recommended setup package. Found by checking pub.dev directly before committing to a
  dependency, per this project's standing practice of verifying tooling against its current real
  state rather than an assumption from when a doc was written.
- **[R-10](../01-vision/risks-constraints-assumptions.md) (dependency abandonment)** — carried
  forward again; this sprint is the first with any Flutter/Dart dependency at all, so it's the first
  point this risk actually applies on the mobile side, not just the backend's `npm` tree.

## Definition of Done

Infrastructure sprint, same narrow subset as Sprint 01 (no module specification, no API, no mobile
UI/offline/sync boxes — those apply once a real feature is built on top of this database, not to the
schema scaffold itself):

- [x] Local database schema matches `outbound_queue`'s full V1 shape
      ([schema-local.md](../07-database/schema-local.md)) and a deliberately minimal
      `products`/`sales`/`sale_line_items`/`sale_payments`/`stock_movements` slice, each table's own
      file-header comment stating exactly which server columns are deferred and to which milestone
      (M1/M2), not silently omitted.
- [x] Schema builds via `build_runner`/`drift_dev` with no errors, and `flutter analyze` reports no
      issues.
- [x] **A real proof the database opens, not just that it compiles** — `flutter test` exercises an
      in-memory database: schema creation, an `outbound_queue` round-trip, and a full
      sale-with-line-item-and-payment-and-stock-movement round-trip across all five tables. This is
      the mobile-side application of Sprint 02's addendum rule ("service-layer tested and typechecks"
      ≠ "the endpoint actually works") — here, "the Dart code compiles" ≠ "the database actually
      opens and holds data."
- [x] No secret, token, or key committed (nothing in this sprint touches secrets, but the check still
      applies).
- [x] Tests pass **in CI** on an actual merged PR — [PR #9](https://github.com/rintu007/smart-mobile-pos/pull/9),
      all 6 checks passed including `mobile-analyze-test`'s first real run (2m28s), merged to `main`.

**Explicitly not in this sprint's DoD subset:** any UI/offline/sync box (no feature screen exists —
`app/home_screen.dart` is a temporary composition-root proof, not a feature), Android build/run
verification (no Android SDK in this environment yet — named in `apps/mobile/README.md`, deferred to
whichever sprint first needs to build/run on a device, per backlog.md item 6 onward).

## Demo script

**Run 2026-08-01, all steps passed:**

1. `flutter --version` — confirms the SDK installed this sprint (3.44.8, stable channel). ✅
2. `flutter analyze` in `apps/mobile` — zero issues. ✅
3. `flutter test` in `apps/mobile` — 4/4 tests pass:
   `schema opens with no error`, `outbound_queue round-trips a queued operation`,
   `a sale with one line item and one cash payment round-trips`, and a widget test confirming the
   home screen renders "Local database ready — 0 product(s) cached." after actually querying the
   live (in-memory) database through the same Riverpod provider `main.dart` wires up. ✅
4. Inspect `lib/core/database/tables/*.dart` — each file's header comment states which
   schema-server.md columns are included vs. deferred, and why. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) — two real findings this sprint (the
`riverpod_lint`/Riverpod 3.x conflict, and `sqlite3_flutter_libs` being obsolete) are exactly the
kind of "first contact with real tooling" surprise Sprint 01/02's retrospectives already predicted
would keep happening as new toolchains get touched for the first time.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | Sprint 03 planned and built same-day: Flutter SDK installed, `apps/mobile` scaffolded and reshaped, local Drift database (backlog.md item 4) built and verified via `flutter test`. Two real package-version findings recorded (`riverpod_lint` vs. Riverpod 3.x, `sqlite3_flutter_libs` obsolescence). CI checkbox intentionally left unticked pending a real PR run. |
| 0.2.0 | 2026-08-01 | PR #9 opened, all 6 checks passed including `mobile-analyze-test`'s first real run, merged to `main`. Sprint 03 fully closed. |
