# Sprint 38

> **Dates:** 2026-08-16 – 2026-08-16 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (backlog item 3 — Settings, mobile UI)
> **Status:** Closed — M4 item 3 done. M4 now has items 4–9 remaining.

## Goal

Build `/settings`, the first mobile screen to actually read or write tax mode/rate, pricing mode,
rounding rule, currency, low-stock threshold, and the two auto-approval thresholds — all
server-complete since [Sprint 25](sprint-25.md) but never given a UI.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `/settings` screen (Owner-edit, Manager/Cashier read-only per the already role-shaped `GET /settings` response), home-screen entry point | Settings | 1.5 | — |

## Design decisions, found while writing the spec

Full detail in [settings/specification.md §1](../modules/settings/specification.md#1-purpose-and-business-context).

1. **Pattern B, not Pattern A.** Reports (Sprint 37) hides its entry point entirely for a role
   without access, since no network call exists at report-view time to surface a `403`. Settings has
   the opposite shape: `GET /settings` is itself the network call this screen must make, already
   role-shapes its response (both auto-approval thresholds omitted for a Cashier), and `PATCH
   /settings` already `403`s a non-Owner. Hiding the entry point would duplicate a check the server
   already performs. Resolved as Pattern B — reachable by every role, same reasoning
   `return_approvals_screen.dart` already established for exactly this shape of screen.
2. **No local Drift cache.** Unlike `ShopSettingsCache` (Sprint 37, Reports-only), this screen's
   fields are read rarely (not every sync cycle) and writes require connectivity by this module's own
   rule (`SETTINGS_CHANGE_REQUIRES_CONNECTIVITY`) — a cache would need its own invalidation logic for
   no proportionate benefit. A plain, live `ApiSettingsRepository` (Dio only, no Drift) is the natural
   fit, same shape `units_api.dart` already established.
3. **A found spec-currency gap, unrelated to this sprint's own scope.** Sprint 37 added
   `shop_settings.low_stock_threshold_quantity` to the schema/service code but never bumped
   `settings/specification.md`'s own Change Log — the document and the code had silently drifted
   apart for two days. Folded into this sprint's spec update rather than left for later.
4. **`route-map.md` correction.** `/settings` was marked "Offline: Yes," overstating a cache this
   screen deliberately doesn't have; `/settings/tax`/`/settings/currency` are consolidated into the
   one screen rather than built as separate routes, since `PATCH /settings`'s whole-row optimistic
   concurrency has no natural per-field-group boundary to split along.

## Capacity check

1.5 person-days against estimate — landed exactly on it; no server work was needed (already
complete), and the two found gaps above were both documentation corrections, not new code.

## Reserved capacity

- [x] Defect capacity reserved: none used as rework — both found gaps were resolved at
      spec-writing time, before code.
- [x] Documentation capacity reserved: `settings/specification.md` (updated, §1/§3/§9/§10/§11),
      `route-map.md` (corrected), module registry, backlog.md, this sprint doc,
      implementation-log, README bumps.

## Risks

- **None new.** No server change this sprint — `GET`/`PATCH /settings` are unchanged from Sprint 25/37.
  The client-side DR-009 mirror (tax rate must be 0 outside Standard mode) cannot diverge from the
  server's own enforcement of the same rule, since a request that passes the client check can still
  fail the server's — the client check only saves a round trip, it never grants anything the server
  wouldn't also allow.

## Definition of Done

- [x] Mobile: `ShopSettings` entity, `SettingsRepository` interface, `ApiSettingsRepository` (plain
      Dio, no Drift), `SaveSettingsController`, `/settings` screen, home-screen entry point
      (`go_to_settings_button`, always visible).
- [x] Typed `SettingsPermissionDeniedException`/`SettingsConflictException`, mapped from `403`/`409`
      HTTP status codes, surfaced as distinct user-facing messages.
- [x] Client-side mirror of DR-009 (tax rate must be 0 outside Standard mode) blocks submission
      before any network call.
- [x] Whole-row optimistic concurrency honoured client-side: `base_updated_at` round-tripped from
      the last `GET`; a `409` discards the in-progress edit and re-fetches, never attempts a merge.
- [x] Both auto-approval threshold fields render only when present in the response (Manager/Owner),
      matching the server's own field-level read scope automatically.
- [x] Mobile tests: `settings_screen_test.dart` (8 new cases — loading/error states, Owner/Manager
      vs Cashier field visibility, successful save, `403`, `409`, client-side DR-009 block),
      `widget_test.dart` (1 new case — Settings entry point always present). Total 227 mobile tests
      (were 218).
- [x] `flutter analyze`/`flutter test` (227 total) both clean.
- [x] `settings/specification.md` updated in this PR (§1, §3, §9 filled in from a placeholder, §10,
      §11, Change Log); `route-map.md` corrected in the same PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.
- [x] No server change — `GET`/`PATCH /settings` were already live-verified 26/26 in Sprint 25; no
      new live verification needed this sprint.

## Demo script

**Mobile, run 2026-08-16** — `flutter test`:

1. `settings_screen_test.dart`: loading indicator while `GET /settings` resolves; generic error
   state on failure. ✅
2. An Owner/Manager-shaped response renders both auto-approval threshold fields; a Cashier-shaped
   response (thresholds omitted from the JSON) renders neither. ✅
3. Saving succeeds and the repository receives the exact submitted values; no error text shown. ✅
4. A `403` from the repository shows "Only the Owner can change settings." ✅
5. A `409` shows "Someone else changed these settings. Refresh and try again." ✅
6. Selecting a non-`standard` tax mode with a nonzero rate blocks submission locally — the fake
   repository's `updateSettings` is never called. ✅
7. `widget_test.dart`: the home screen's Settings button is present unconditionally, no provider
   override required. ✅

**Full suite:** `flutter test` — 227/227 passing. `flutter analyze` — clean.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the fourth
consecutive sprint (34, 36, 37, 38) where touching an area surfaced a small, previously invisible gap
in the documentation itself — this time not a missing capability but a spec that had quietly stopped
matching its own code two days earlier. The fix is the same each time: read the current state before
trusting what the document says, and correct it in the same pass rather than carrying the drift
forward.

M4 — Reports, Settings, and Release Readiness now has items 4–9 remaining, per
[backlog.md §5](backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | Sprint 38 planned and built same-day: `/settings` mobile screen built and verified (227/227 `flutter test`, `flutter analyze` clean). No server change needed. M4 item 3 done, items 4–9 remain. |
