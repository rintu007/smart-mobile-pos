# Sprint 54

> **Dates:** 2026-08-20 – 2026-08-20 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item)
> **Status:** Closed.

## Goal

The last real, buildable gap in the offline failure-scenario list — "Storage full,"
`failure-scenarios.md §3` — is genuinely different in kind from Sprints 50–53's work: not a test
proving existing behaviour, but new product surface (a new third-party dependency, new UI, a
threshold decision). Confirmed with the founder before starting, since that's a different scope of
decision than a same-day verification pass. Sprint 53 already closed tier 1 (proactive pruning) as
a byproduct of investigating this same scenario; this sprint closes tier 3 — real free-disk-space
detection and the warning `failure-scenarios.md §3` already designed but never built.

## Design decisions

1. **Package choice verified directly against pub.dev, not assumed from name recognition.** The
   original candidate, `disk_space`, has a maintained fork, `disk_space_plus` (last published 14
   months ago) and a newer one, `disk_space_2` (published 26 days ago, more platforms, a cleaner
   static API). Chose `disk_space_2` — the same "check the actual current ecosystem state, don't
   assume" diligence Sprint 48 applied to SQLCipher.
2. **A narrow `DeviceStorageProbe` seam, not a direct dependency on the plugin.** Matches this
   codebase's established "fake, not a mock" testing convention (Sprint 39's
   `_FakeEscPosReceiptEncoder`, Sprint 47's `SecureKeyValueStore`) — tests substitute a genuine fake
   instead of mocking `disk_space_2`'s own platform channel.
3. **A 100 MB threshold, stated as a dated, correctable decision, not a measured budget.** This app
   writes only small text/JSON rows locally — confirmed no image or media caching exists anywhere
   in the schema (Sprint 53's own correction to this same section) — so 100 MB is deliberately
   conservative headroom, not a tuned number.
4. **Fails open on a probe error, reasoned explicitly rather than left as an accidental default.**
   A platform-call failure is treated as "not critical," not "critical." The alternative
   (fail-closed) risks a persistent, undismissable warning shown to every Cashier on any device
   where the probe merely glitches — judged worse than the rare case of one delayed real warning,
   especially since tier 1's bounded local cache and tier 2's "never prune the queue" guarantee
   already substantially reduce this app's actual exposure to real storage exhaustion.
5. **Checked once per app session on `HomeScreen`, matching `canViewReportsProvider`'s own
   `autoDispose` shape exactly** — no new polling/timer infrastructure invented for a first cut.
6. **Placed on `HomeScreen`, this project's current (explicitly temporary, per that screen's own
   docstring) composition-root screen — not a new dedicated widget or design-system component.**
   Consistent with that screen's existing level of polish; a real bottom-nav shell replacing it
   later would carry this banner along with everything else that screen currently owns.
7. **`sync-ui.md` was not extended with this banner, named honestly rather than silently implied.**
   That document specifically covers the sync-status indicator, not app-wide device-health
   banners — a real, minor, separate documentation gap, stated rather than glossed over.

## Capacity check

No estimate carried in the backlog — a same-day feature build, not a planned backlog line, following
directly from the founder's confirmation to build it.

## Reserved capacity

- [x] Defect capacity reserved: this closes a real, previously-designed-but-unbuilt gap
      (`failure-scenarios.md §3`'s own tier 3), not new discretionary scope beyond what was already
      decided on paper.

## Risks

Low. Purely additive: one new dependency, one new local module, one new banner on an
already-temporary screen. The threshold and fail-open choice are both named, dated, and easily
revisited if real device experience suggests otherwise — neither is presented as a measured,
final answer.

## Definition of Done

- [x] `apps/mobile/pubspec.yaml` — `disk_space_2` added, with the pub.dev comparison against
      `disk_space_plus` recorded in a comment.
- [x] `apps/mobile/lib/core/storage/device_storage_probe.dart` (NEW) — `DeviceStorageProbe`,
      `DiskSpace2Probe`, `criticallyLowStorageThresholdMb` (100), `isStorageCriticallyLow`
      (fail-open on a null reading).
- [x] `apps/mobile/lib/core/storage/storage_providers.dart` (NEW) — `deviceStorageProbeProvider`,
      `isStorageCriticallyLowProvider` (`autoDispose`, matching `canViewReportsProvider`).
- [x] `apps/mobile/lib/app/home_screen.dart` — persistent low-storage banner (no dismiss action),
      the exact copy `failure-scenarios.md §3` already specified.
- [x] `apps/mobile/test/core/storage/device_storage_probe_test.dart` (NEW, 4 cases): below
      threshold, comfortably above, exactly at the threshold, and a null (failed) reading.
- [x] `apps/mobile/test/widget_test.dart` — 2 new cases (banner shown/hidden); all 6 pre-existing
      `HomeScreen`-pumping tests updated to override the new provider, the same discipline already
      applied to `autoSyncOnStartProvider`/`storeContextProvider`.
- [x] Verified locally: `flutter analyze` clean; `flutter test` full suite green (266/266 — 260
      pre-existing + 6 new); a real `flutter build apk --debug --target-platform android-arm64`
      succeeds with the new dependency linked (no new KGP warning introduced beyond the two
      pre-existing plugins already flagged).
- [x] `docs/13-offline-sync/failure-scenarios.md §3`, `test-plan.md §3`,
      `docs/14-testing/release-checklist.md §2` all updated — storage-full is now the 6th of 10
      named failure scenarios with real coverage; only "Token expired while queued" remains.
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-20:**

1. `flutter test test/core/storage/device_storage_probe_test.dart` — 4/4. ✅
2. `flutter test test/widget_test.dart` — 12/12, including both new banner cases. ✅
3. `flutter analyze` — 0 issues. ✅
4. `flutter test` (full suite) — 266/266 (260 pre-existing + 6 new). ✅
5. `flutter build apk --debug --target-platform android-arm64` — succeeds; the new plugin links
   cleanly. ✅

No live-device verification of the actual `StatFs`-equivalent reading against a real device's real
free space — a reasonable manual check for whenever a real device is next in hand, named rather
than silently skipped, the same treatment Sprint 47 gave its own live-device gap.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: this is the first sprint in this run (50–54)
that built genuinely new product surface rather than testing or fixing existing intent, and it was
explicitly confirmed with the founder first rather than assumed autonomously — a different class of
decision (a new dependency, new UI, a threshold judgment call) than a same-day verification pass,
and treated that way rather than folded silently into the sprint before it.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-20 | Sprint 54: storage-full handling built (`disk_space_2`-backed free-disk-space detection, a 100 MB fail-open threshold, a persistent `HomeScreen` warning), closing failure-scenarios.md §3's tier 3 and the last real, buildable gap in the offline failure-scenario list. Founder-confirmed before starting. 266/266 mobile tests (260 pre-existing + 6 new), `flutter analyze` clean, real Android debug build confirmed. Only "Token expired while queued" remains genuinely unverified of the 10 named scenarios. |
