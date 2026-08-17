# Sprint 39

> **Dates:** 2026-08-17 – 2026-08-17 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (backlog item 4 — printer pairing +
> receipt template)
> **Status:** Closed — M4 item 4 done. M4 now has items 5–9 remaining.

## Goal

Build `/settings/printer` (FR-077 — pair and test-print a Bluetooth printer from settings,
independent of any sale) and `/settings/receipt-template` (FR-078 — the one customisable receipt
field, never a mandatory one), reusing Sprint 15's existing Bluetooth ESC/POS transport.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `/settings/printer`, `/settings/receipt-template`, `PATCH /settings` accepts `receipt_template_config` | Settings, Receipt & Printing | 2.5 | 3 (Settings, mobile UI) |

## Design decisions, found while writing the spec

Full detail in
[settings/specification.md §1](../modules/settings/specification.md#1-purpose-and-business-context)
and [receipt-printing/specification.md §1](../modules/receipt-printing/specification.md#1-purpose-and-business-context).

1. **`receipt_template_config` gets exactly one field, not a broader shape.** receipt-design.md
   names only the footer message as customisable; every other zone is structurally mandatory.
   Rather than inventing a togglable-fields shape to make `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD`
   reachable (this item's own original, speculative framing), that error stays **deliberately
   unreachable** — the one real candidate for a conditionally-mandatory field, GSTIN, isn't
   captured anywhere in `shop_settings` yet, a separate, larger gap this item doesn't own.
2. **`printer_config` stays untouched — a paired printer is per-device data, not `shop_settings`
   data.** No `devices` table exists in this schema; a MAC address in a shop-wide row would mean
   every device overwrites every other device's own pairing on its next sync. Resolved entirely
   client-side: a new local-only Drift table, `PairedPrinterCache`, never sent to the server.
3. **The footer message needed to reach printing without breaking "Fully offline."** Resolved by
   extending `ShopSettingsCache` (Sprint 37) with a third field, synced through the existing
   `shop_settings` pull entity type — the same "extend the narrow cache" shape that table's own doc
   comment already anticipated.
4. **`SettingsRepository.updateSettings` becomes a true partial update on mobile.** Every scalar
   field but the two required ones is now optional, so `/settings/receipt-template` can send
   `footerMessage` alone.
5. **The per-sale print action gets a real, working improvement, not dead configuration.**
   `/sales-history/:id`'s print button now prefers the printer paired via `/settings/printer` and
   the configured footer message — both actually wired into the existing print path, not settings
   nobody reads yet.

## Capacity check

2.5 person-days against estimate — landed on it. Both found corrections above were resolved at
spec-writing time (documentation and scope corrections, not rework), and the mobile-only test
environment gotcha (below) cost time but no scope.

## Reserved capacity

- [x] Defect capacity reserved: one real test-environment issue found and fixed, not a code defect
      — `EscPosReceiptEncoder.encode`'s real asset load deadlocks inside `testWidgets()`'s
      fake-async zone; fixed by faking the encoder at the screen-test level (the encoder's own
      correctness is already covered by its dedicated unit tests), not by changing production code.
- [x] Documentation capacity reserved: `settings/specification.md`, `receipt-printing/specification.md`,
      `sync-engine/specification.md`, `route-map.md`, module registry, backlog.md, this sprint doc,
      implementation-log, README bumps.

## Risks

- **None new.** No schema migration — `printer_config`/`receipt_template_config` columns have
  existed since Sprint 25. `receipt_template_config`'s newly-accepted shape is additive and
  narrowly validated (`.strict()` on the nested object); `printer_config` is unchanged.
  `ShopSettingsCache`'s new column is nullable, backfills to `null` for existing local databases.

## Definition of Done

- [x] Server: `PATCH /settings` accepts `receipt_template_config: { footer_message }`
      (`.strict()`, 1–200 chars); `printer_config` still rejected entirely; `GET /sync/pull?entity_type=shop_settings`
      gains `receipt_footer_message`.
- [x] Mobile: `PairedPrinterCache` (new local table, schema v8→v9), `ShopSettingsCache.footerMessage`
      (same migration); `PairedPrinterRepository`; `/settings/printer` (choose printer, test print);
      `/settings/receipt-template` (footer-message editor, independent save cycle);
      `/sales-history/:id`'s print action now prefers the paired printer and configured footer.
- [x] `SettingsRepository.updateSettings` relaxed to a true partial update (every scalar field but
      `clientOperationId`/`baseUpdatedAt` now optional).
- [x] Unit tests: `settings/service.test.ts` (1 new case), `sync/service.test.ts` (1 new case, 2
      updated). Total 209 web tests.
- [x] Mobile tests: `paired_printer_repository_test.dart` (3 new cases), `printer_settings_screen_test.dart`
      (3 new cases), `receipt_template_screen_test.dart` (4 new cases), `sync_repository_test.dart`
      (2 new cases). Total 239 mobile tests.
- [x] `tsc --noEmit`/`eslint`/`vitest` (209 total web tests) all clean; `flutter analyze`/`flutter test`
      (239 total mobile tests) all clean; production build confirmed before pushing.
- [x] Live verification against the real database, throwaway tenants (deleted after) — 7/7 checks:
      `PATCH` accepts/round-trips `footer_message`; rejects it missing; rejects an unrecognized
      nested key; `printer_config` still rejected; sync pull carries the new field; cross-tenant
      isolation held.
- [x] `settings/specification.md`, `receipt-printing/specification.md`, `sync-engine/specification.md`,
      `route-map.md` all updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

## Demo script

**Server, run 2026-08-17** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. `PATCH /settings` with `{ receipt_template_config: { footer_message: "See you soon!" } }` → `200`,
   `GET /settings` reflects it. ✅
2. `PATCH` with `{ receipt_template_config: {} }` (missing `footer_message`) → `422`. ✅
3. `PATCH` with `{ receipt_template_config: { footer_message: "x", show_gstin: false } }` → `422
   VALIDATION_FAILED` — confirms `RECEIPT_TEMPLATE_MISSING_MANDATORY_FIELD` stays unreachable. ✅
4. `PATCH` with `{ printer_config: {} }` → still `422`, unchanged. ✅
5. `GET /sync/pull?entity_type=shop_settings` → includes `receipt_footer_message`. ✅
6. A second, untouched tenant's pull sees `receipt_footer_message: null` — cross-tenant isolation
   held. ✅

**Unit/widget tests, run 2026-08-17**: `vitest run` — 209/209 passing; `flutter test` — 239/239
passing.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: a genuinely new class of
gotcha this project hadn't hit before — `testWidgets()`'s fake-async zone deadlocking on a real
plugin's asset load (`EscPosReceiptEncoder`'s `rootBundle.loadString`), invisible until a widget
test actually exercised the print pipeline end-to-end for the first time (Sprint 15's own tests
only ever called the encoder from a plain `test()`). The fix — fake the encoder at the screen-test
boundary — is the same "inject what a real plugin needs, verify the plugin wrapper separately"
shape this codebase already uses everywhere else; the new information is *when* that shape becomes
necessary, not just for platform-channel calls but for fake-async-hostile real I/O in general.

M4 — Reports, Settings, and Release Readiness now has items 5–9 remaining, per
[backlog.md §5](backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-17 | Sprint 39 planned and built same-day: `/settings/printer` and `/settings/receipt-template` built and verified (7/7 server-side live checks; 239/239 mobile tests). M4 item 4 done, items 5–9 remain. |
