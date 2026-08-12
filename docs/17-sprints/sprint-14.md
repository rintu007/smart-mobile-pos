# Sprint 14

> **Dates:** 2026-08-13 – 2026-08-13 (single-day, same pattern as Sprints 02–13)
> **Milestone:** M0 — Walking Skeleton (backlog item 9, mobile half)
> **Status:** Closed

## Goal

Close the gap Sprint 13 named directly: wire the mobile app to actually call
`POST /sync/push`/`GET /sync/pull`, draining `outbound_queue` and refreshing the local `products`
cache — the mobile half of [backlog.md item 9](backlog.md#1-m0--walking-skeleton-fully-decomposed),
completing it in full. Matches the same backend/mobile split precedent products (Sprint 04/07) and
sales (Sprint 05/09) already went through.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Sync engine: mobile trigger — drains `outbound_queue` via `POST /sync/push`, refreshes local `products` via `GET /sync/pull` | Offline Sync Engine | remainder of item 9's 3.0-person-day estimate | Sprint 13 (backend push/pull) |

See [sync-engine/specification.md §1](../modules/sync-engine/specification.md#1-purpose-and-business-context)
for the exact cut: an automatic, once-per-session trigger plus a manual "Sync now" button — not the
full connectivity-listener/app-foreground/background-timer trigger set, and no persisted pull
cursor (both named, deliberate trade-offs).

## Capacity check

Mobile half only, completing item 9's total 3.0-person-day estimate together with Sprint 13's
backend half.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `sync-engine/specification.md` update (§1/§7/§9/§10/§11),
      backlog.md, module registry, implementation-log, README bumps.

## Risks

- **A new local table would have required a schema migration against the founder's own
  already-installed, persistent app** (real data since Sprint 10) — avoided entirely by not
  persisting a pull cursor between sync runs (named trade-off, `sync-engine/specification.md §2`),
  rather than risk a migration bug against data that can't be thrown away and re-seeded like every
  prior sprint's throwaway demo accounts could.
- **An auto-sync failure must never block the home screen** — the automatic on-start trigger
  swallows its own errors deliberately (the manual "Sync now" button still surfaces them), tested
  directly rather than assumed.

## Definition of Done

- [x] `apps/mobile/lib/core/sync/` — `SyncRepository.syncNow()` pushes every `queued`/
      `failed_retrying` `outbound_queue` row, updates each row's status per its own push result
      (`synced` / `failed_retrying` + incremented `attempt_count` for `DEPENDENCY_NOT_FOUND` /
      `rejected` + `rejection_reason` for anything else), then pages `GET /sync/pull` for
      `products` and upserts every row locally.
- [x] `autoSyncOnStartProvider` fires once per app session, right after `storeContextProvider`
      resolves; failures are swallowed (never blocks the home screen).
- [x] Home screen gains a `sync_now_button` and a `sync_status` line showing the last run's
      accepted/pending/rejected/pulled counts, or an inline error for a manual-trigger failure.
- [x] `flutter analyze` clean; `flutter test` clean, 60/60 (up from 52 — 7 new repository tests, 1
      new widget test).
- [x] No secret, token, or key written to logs or committed to source.
- [x] Module registry, backlog.md, `sync-engine/specification.md`, implementation-log, READMEs
      updated in the same PR.

**Explicitly not in this sprint's DoD subset:** sync-api.md §7's full trigger set, a persisted pull
cursor, every push operation/pull entity type beyond Sprint 13's own two/one, `sync_rejections`,
M0's own remaining items (10–11).

## Demo script

**Run 2026-08-13** — `flutter test` (no device needed), extending Sprint 09/10's own precedent that
repository correctness is proven against a real in-memory Drift database, not a live device, unless
the sprint's own DoD specifically needs one (it doesn't here — no new device-target risk, same Dio
client Sprint 08 already proved against the live backend):

1. An accepted push result marks its `outbound_queue` row `synced`. ✅
2. A `DEPENDENCY_NOT_FOUND` rejection marks its row `failed_retrying` and increments
   `attempt_count`, leaving it eligible for the next sync attempt. ✅
3. Any other rejection marks its row `rejected` with a `rejection_reason`. ✅
4. One push batch includes both `queued` and `failed_retrying` rows, never `synced` ones. ✅
5. A sync with nothing queued never calls push at all. ✅
6. Pull pages across multiple calls (a two-page fake), upserting each product locally. ✅
7. Pulling an already-cached product updates it in place rather than duplicating it. ✅
8. Widget: the home screen's initial sync status reads "Not synced yet this session"; tapping
   "Sync now" against a faked, empty-queue repository shows "Synced — nothing queued, 0 product(s)
   pulled." ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. One thing worth naming regardless: this is the first
mobile sprint where a "the obvious next step" (a persisted pull cursor, matching the backend's own
design) was deliberately *not* built because of a real constraint unique to this project's current
state — a persistent, non-throwaway installed app on the founder's own device. Every prior sprint's
mobile work could assume a fresh install; this one couldn't, and the design changed as a result.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | Sprint 14 planned and built same-day: mobile sync trigger (`core/sync/`) built, closing backlog.md item 9 in full. `flutter test` 60/60 (7 new repository tests, 1 new widget test), `flutter analyze` clean. Deliberately no persisted pull cursor, avoiding a schema migration against the founder's real installed app. |
