# Sprint 51

> **Dates:** 2026-08-20 – 2026-08-20 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item)
> **Status:** Closed.

## Goal

Sprint 50 closed 2 of the 9 unverified offline failure scenarios and left "Schema version mismatch
after an update" named but untouched, since it was originally classified alongside genuinely
infra-blocked rows without being individually attempted. Checked directly: it too is fully
reproducible with this project's existing `flutter test`/Drift infrastructure — no historical
schema-snapshot tooling required, since the actual migration logic can be exercised by reconstructing
an old-schema database as the exact inverse of what `onUpgrade`'s own blocks add. Writing that test
found something significantly more important than the test itself: **a real, previously-undetected
bug that would permanently lock a real device out of its own local database for a specific, entirely
plausible upgrade path.**

## The bug, found by the test, not assumed beforehand

`database.dart`'s `MigrationStrategy.onUpgrade` had never been exercised against a real upgrade
before this sprint's first migration test. `Drift`'s `Migrator.createTable(x)` builds table `x` from
its **current** Dart definition — not the shape it had at the historical point that `createTable`
call was originally written. Sprint 37 (schema v7→v8) wrote `await
m.createTable(shopSettingsCache)`; Sprint 39 (v8→v9) later added a column to that same table and
wrote `await m.addColumn(shopSettingsCache, ...footerMessage)` right after it, assuming the column
would genuinely be missing at that point. It is — for a device that was ever actually at exactly
v8. It is **not** for a device jumping straight from v7 or earlier to v9 in one update (this
project's own APK-rebuild cadence doesn't line up with every schema-changing sprint, so this is a
real, not theoretical, scenario) — that device's `createTable` call already produces
`shop_settings_cache` with `footer_message` present, and the very next line's `addColumn` throws an
unhandled `SqliteException: duplicate column name`. There is no fallback: the local database fails to
open, on every launch, until it is deleted — silently destroying any unsynced sales in the process.

This is arguably the single most severe bug this project's testing has found to date on the mobile
side: not a missing feature or an incomplete gap, but a live, previously-shippable path to permanent,
unrecoverable local data loss for a real user.

## Design decisions

1. **Fixed with a guard, not a full rewrite.** `from < 9`'s `addColumn` now checks
   `pragma_table_info('shop_settings_cache')` for the column's existence first, adding it only if
   genuinely missing. This is the minimal, targeted fix for the one table this actually affects
   today — not an argument that this class of bug can never recur (see point 3).
2. **The migration test reconstructs a genuine v3 database by inverting `onUpgrade`'s own blocks,
   not by assuming any historical schema tooling.** This project has never run `drift_dev schema
   generate`, so there is no captured historical snapshot to restore. Instead: open a fresh, real,
   current-shape (v9) database, undo exactly what `from < 4` through `from < 9` each add (in
   reverse), set SQLite's own `user_version` pragma to 3 (the mechanism drift's native backend
   already uses to detect the "from" version, confirmed against its own source rather than assumed),
   and reopen through the real `AppDatabase` — triggering the actual, unmodified `onUpgrade(m, 3,
   9)` code path.
3. **A second test protects the fix itself from a future regression.** A genuine v8 database (built
   by inverting only `from < 9`'s own additions) must still get `footer_message` added — proving the
   guard skips the redundant case without also skipping the case where the column is genuinely
   needed.
4. **The standing lesson is written down as a rule for every future migration, not just this
   instance** (`schema-local.md`'s new "Schema-migration safety" section): if a table is created in
   one step and altered in any later step, the later step's alteration must be guarded the same way,
   since a device can always jump both steps in one update. Drift's own `VersionedSchema`/`drift_dev
   schema generate` tooling is the more durable long-term fix (letting `createTable` reproduce a
   table's true historical shape at each step) — named explicitly as real, larger, deferred scope,
   not silently assumed unnecessary forever.

## Capacity check

No estimate carried in the backlog — a same-day fix, discovered while extending Sprint 50's own
still-open work, not a planned backlog line.

## Reserved capacity

- [x] Defect capacity reserved, and then some: this closes a real, previously-named test gap
      (test-plan.md §3's "Schema version mismatch" row) **and** fixes a genuine, previously-unknown
      production bug found in the process — the second is squarely defect work, not discretionary
      scope, regardless of the fact that nothing external had flagged it yet.

## Risks

**This sprint reduces risk rather than introduces it.** Before this fix, any device upgrading across
the v7/v8→v9 boundary in one jump would have its local database become permanently inaccessible on
every launch — a risk that existed, live, in the already-merged Sprint 39 code, entirely undetected
until this sprint's test found it. The fix itself is minimal and precisely targeted (one guarded
`addColumn`, no schema shape changed for any device), verified both for the previously-broken path
(v7/pre-v8 → v9) and the already-working path (genuine v8 → v9, which must still add the column).

## Definition of Done

- [x] `apps/mobile/lib/core/database/database.dart` — `from < 9`'s `addColumn` guarded by a real
      `pragma_table_info` existence check.
- [x] `apps/mobile/test/core/database/migration_test.dart` (NEW) — 2 cases: a genuine v3→v9 upgrade
      (proving both the `created_at` backfill and the duplicate-column bug are fixed) and a genuine
      v8→v9 upgrade (proving the guard doesn't skip a real, needed column add).
- [x] Verified locally: `flutter analyze` clean; `flutter test` full suite green (256/256 — 254
      pre-existing + 2 new).
- [x] `docs/07-database/schema-local.md` — new "Schema-migration safety" section: the full account
      of the bug, the fix, and a standing rule for every future migration.
- [x] `docs/13-offline-sync/failure-scenarios.md §1`, `test-plan.md §3`,
      `docs/14-testing/release-checklist.md §2` all updated to reflect the closed gap and the bug
      found while closing it.
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-20:**

1. `flutter test test/core/database/migration_test.dart` — both cases pass: a v3→v9 upgrade
   correctly backfills `sales.created_at` *and* completes without the duplicate-column crash; a
   v8→v9 upgrade still adds `footer_message` when it's genuinely missing. ✅
2. Reverting the guard and re-running the v3→v9 case reproduces the original crash exactly as
   described (`SqliteException(1): duplicate column name: footer_message`) — confirmed live before
   applying the fix, not assumed from reading the code. ✅
3. `flutter analyze` — 0 issues. ✅
4. `flutter test` (full suite) — 256/256 (254 pre-existing + 2 new). ✅

No live-device verification needed — the durability/versioning mechanism this test depends on
(SQLite's own `user_version` pragma, Drift's own `NativeDatabase` migration bootstrapping) is a
well-established platform guarantee, the same class of dependency this project already relies on
elsewhere (data-protection.md §3's SQLCipher integration, Sprint 48) without re-proving it from
scratch.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) — this one likely warrants an entry, not
just a note here: this project had zero migration test coverage for 8 sprints' worth of real schema
changes (Sprint 20 through Sprint 39) before this sprint, and the very first test written against
that code found a genuine, severe, silently-shipped bug on the first real attempt. The general
lesson — "a design doc's own claim that something works (`state-machines.md`'s `Syncing` status,
Sprint 50; `failure-scenarios.md`'s 'the schema migrates,' this sprint) is not the same claim as a
test proving it does" — has now recurred twice in two consecutive sprints. Worth naming as a pattern
worth deliberately checking for elsewhere, not just twice-coincidental.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-20 | Sprint 51: "Schema version mismatch after an update" failure scenario built (`migration_test.dart`, this project's first migration test), closing a 3rd of the 9 gaps test-plan.md §3 named. Found and fixed a real, previously-undetected production bug in the same pass: a table created in one `onUpgrade` step and altered in a later one broke with an unhandled duplicate-column error for any device jumping both steps in one update — permanently losing access to its own local database. Fixed with a guarded `addColumn`; standing rule for future migrations documented in schema-local.md. 256/256 mobile tests (254 pre-existing + 2 new), `flutter analyze` clean. |
