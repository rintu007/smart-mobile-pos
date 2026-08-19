# Sprint 53

> **Dates:** 2026-08-20 – 2026-08-20 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item)
> **Status:** Closed.

## Goal

Investigating storage-full handling (`failure-scenarios.md §3`, the last real gap in the offline
failure-scenario list, confirmed by the founder as worth building now rather than deferring) led
straight to its foundational piece first: tier 1's "proactive pruning, before the device is ever
actually full." Checked directly against the code before writing anything new: `inbound-sync.md §4`
had already decided a concrete retention window for `stock_movements` (current + prior financial
year) — but neither half of that decision was actually implemented. The server's pull was
unfiltered since Sprint 36, and nothing ever removed an already-pulled row from the local cache.
Every device's local `stock_movements` table has been growing without bound, unconditionally, since
that feature first shipped.

## What was found, checked directly rather than assumed

1. **The server-side pull has been unfiltered the whole time.** `sync/service.ts`'s
   `pullStockMovements` called `stockMovementsRepository.listStockMovements(tenantId, {}, ...)` —
   an empty filter object — despite `listStockMovements` already supporting a `dateFrom` bound
   (built for `GET /stock-movements`'s own date-range query, never wired into the sync pull). An
   existing unit test even locked this in explicitly: "passes a tenant-scoped, **unfiltered** query
   through to the repository."
2. **Nothing ever pruned the local cache either.** `SyncRepository._pullAllStockMovements` upserts
   every pulled row and persists a resume cursor, but no code anywhere deletes a local
   `stock_movements` row, ever, for any reason. The client-side "and retained locally" half of
   `inbound-sync.md §4`'s decision — implying a bound, not just an unbounded upsert — was never
   built either.
3. **The design doc's "cached product images" half of tier 1 describes a feature that doesn't
   exist.** No image field exists anywhere in the local or server `products` schema. This was
   corrected as a documentation fix, not built as new scope — there's nothing to prune.

## Design decisions

1. **Two independent fixes for two independent gaps, not one shared mechanism.** The server bound
   (`stockMovementsRetentionCutoff`, exported from `sync/service.ts`) controls what a device ever
   *receives*; the mobile prune (`SyncRepository._pruneStaleStockMovements`) controls what a device
   *keeps* after receiving it. Both are needed — bounding the pull alone would still leave
   already-cached old rows growing the local table forever for a device that synced before this
   fix shipped.
2. **Deliberately different clocks on each side.** The server bound uses the server's own clock —
   consistent with `clock-and-ordering.md §3`'s "server time is authoritative for anything that
   matters" rule. The mobile prune uses the device's own (possibly wrong) clock — a deliberate
   exception, reasoned explicitly: this is a purely local cache-size decision with no financial or
   cross-device consequence, the same class of "device time is fine for local-only purposes"
   `clock-and-ordering.md §2` already carves out, extended here to a new case rather than assumed
   to apply automatically.
3. **Pruning is unconditional, not threshold-gated — a deliberate simplification of the original
   design.** `failure-scenarios.md §3`'s original wording implied pruning only kicks in "once free
   storage drops below a warning threshold," which would have made this fix depend on tier 3's
   not-yet-built disk-space detection for no real benefit: there's no reason to keep more than the
   current + prior financial year locally even when storage is plentiful, since older data stays
   retrievable from the server on demand. Corrected the doc to match the simpler, always-correct
   policy actually built.
4. **One accepted, named consequence.** A device that hasn't synced across a financial-year
   rollover boundary will silently skip forward past whatever stock-movement history it fell behind
   on for other devices, never receiving it on its next sync. This is judged acceptable —
   `schema-local.md`'s own scoping already states this local cache was never designed to guarantee
   full tenant-wide history — and named explicitly in `inbound-sync.md §4` rather than left as a
   silent side effect for someone to discover later.
5. **Tier 3 (disk-space detection, the warning UI) is real, separately-scoped future work, not
   folded in here.** It's a genuinely different kind of task — a new third-party dependency, new
   UI, and product decisions about thresholds and copy — deliberately kept out of this sprint, which
   only fixes an already-designed, already-decided gap between documentation and code.

## Capacity check

No estimate carried in the backlog — a same-day gap closure, found while starting the
founder-confirmed storage-full investigation, not a planned backlog line itself.

## Reserved capacity

- [x] Defect capacity reserved: this closes a real, previously-decided-but-unbuilt gap
      (`inbound-sync.md §4`'s own retention window), not new discretionary scope.

## Risks

**Real, and reasoned through rather than assumed safe.** This changes what data existing devices
receive and retain — unlike Sprints 45–52's fixes, which were either additive or corrected
test/documentation gaps with no behavioural change. Mitigated by: (1) the bound only affects
`stock_movements`, a read-only local cache with no write path back to the server and no bearing on
money, stock correctness, or invoice numbering (all of which are already proven order-independent
or server-arrival-ordered, `clock-and-ordering.md §3`); (2) `outbound_queue` is explicitly
untouched, confirmed by inspection, not merely assumed; (3) older data remains fully available from
the server for any report that genuinely needs it, per this cache's own already-stated non-goal of
full offline history.

## Definition of Done

- [x] `apps/web/src/modules/sync/service.ts` — `stockMovementsRetentionCutoff` (exported, server
      clock), `pullStockMovements` now bounds its query to it (`now` as an optional trailing
      param for test injection).
- [x] `apps/web/src/modules/sync/service.test.ts` — the stale "unfiltered query" test replaced with
      one asserting the real bound; 3 new cases for `stockMovementsRetentionCutoff` itself across
      FY boundaries.
- [x] `apps/mobile/lib/core/sync/sync_repository.dart` — `_pruneStaleStockMovements`, called after
      every stock-movements pull, device clock, unconditional.
- [x] `apps/mobile/test/core/sync/sync_repository_test.dart` — 2 new cases: a stale row pruned, a
      recent row retained.
- [x] Verified locally: `tsc`/`eslint`/`vitest` clean (218 web unit tests, 215 pre-existing + 3
      new); `flutter analyze` clean; `flutter test` full suite green (260/260 — 258 pre-existing +
      2 new).
- [x] `docs/13-offline-sync/inbound-sync.md §4` (built, both clocks explained, the accepted
      consequence named), `failure-scenarios.md §3` (tier 1 built, two stale claims corrected)
      updated in the same PR.
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-20:**

1. `npx vitest run src/modules/sync/service.test.ts` — 36/36, including the corrected bounded-query
   assertion and 3 new `stockMovementsRetentionCutoff` cases. ✅
2. `npx tsc --noEmit` — clean. ✅
3. `npx vitest run` (full web suite) — 218/218 (215 pre-existing + 3 new). ✅
4. `flutter test test/core/sync/sync_repository_test.dart` — 26/26, including the 2 new pruning
   cases. ✅
5. `flutter analyze` — 0 issues. ✅
6. `flutter test` (full mobile suite) — 260/260 (258 pre-existing + 2 new). ✅

No live-device or integration-test verification — no existing integration-test coverage exists for
any sync-pull entity type (checked directly; unit tests against mocked repositories are this area's
established bar), and this fix doesn't touch RLS, tenancy, or any cross-tenant concern the
integration suite exists to catch.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: this is the fourth consecutive sprint (50
through 53) where checking a design doc's claim directly against the actual code, rather than
trusting either "it's probably fine" or "it's classified as needing infrastructure we don't have,"
turned up a real, previously-invisible gap — three of which were pure doc-vs-code drift with no
behavioural consequence once found, and one of which (Sprint 51) was a genuine, severe production
bug. This one sits in between: not a crash, but real, unbounded local storage growth that would
have eventually become the very storage-full scenario this investigation was trying to handle in
the first place.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-20 | Sprint 53: stock_movements retention window built on both sides — server pull bounded to current + prior financial year (`stockMovementsRetentionCutoff`), local cache pruned to match after every sync (`_pruneStaleStockMovements`, device clock, unconditional). Closes inbound-sync.md §4's own previously-undecided-in-practice gap, found while investigating storage-full handling. Two stale claims in failure-scenarios.md §3 corrected (threshold-gated pruning was never real; "cached product images" was never a built feature). 218/218 web unit tests (215 pre-existing + 3 new), 260/260 mobile tests (258 pre-existing + 2 new), `tsc`/`eslint`/`flutter analyze` all clean. |
