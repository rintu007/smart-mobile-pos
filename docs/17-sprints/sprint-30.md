# Sprint 30

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M2 — Full POS Loop (backlog item 6 — Hold/Resume, the milestone's last item)
> **Status:** Closed — M2 item 6 done. **M2 — Full POS Loop is now fully closed, all 6 items done.**

## Goal

Hold/Resume: `sales.status` transitions `draft`→`held`→`draft`→`completed` on the client
([state-machines.md#sale](../06-workflows/state-machines.md#sale)), mobile-only — per
[sales.md](../11-api/endpoints/sales.md)'s own note a held/draft cart is never synced to the server
as a partial row, so this item is till-screen hold list + resume-into-cart local-DB/UI work, not a
new endpoint.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Local `held`/`draft` transitions, till hold button, held-carts screen, resume-into-cart | POS (mobile) | 2 | — |

## Design decisions, found while writing the spec

Full detail in [pos/specification.md §1/§2](../modules/pos/specification.md#1-purpose-and-business-context).

1. **Built to a fuller requirement than the backlog item's own wording named.**
   [navigation-model.md §4](../09-navigation/navigation-model.md) already specified continuous
   auto-persistence of the active cart from its first item added onward — a real, already-documented
   requirement broader than "add a hold button." `CartController` now upserts a `draft` row on every
   `addProduct`/`decrementProduct`, not only on an explicit hold; `completeSale` was rewritten to
   transition the existing draft/held row in place (`insertOnConflictUpdate` on `sales` itself,
   delete-and-reinsert for line items/payments) rather than inserting a fresh row at payment time,
   the change this auto-persistence requirement actually forces.
2. **A real schema-local.md correction, not a workaround.** Its "Immutable event... never edited
   after creation" classification for `sales`/`sale_line_items`/`sale_payments` was never literally
   true once a draft/held row is genuinely mutated pre-completion by this sprint's own design. Split
   into a new "Immutable event once completed" row, mirroring `schema-server.md`'s own completion
   trigger rather than contradicting it — the documentation was wrong, not the implementation.
3. **Provisional invoice number assigned once, at Draft creation, not deferred to completion.**
   SQLite has no cheap way to relax an existing `NOT NULL` column (a full table rebuild), and
   [ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) already frames the provisional
   number as "shown immediately... and permanent" — assigning it at Draft creation is both simpler
   and more consistent with that framing than deferring it. Abandoned/cancelled drafts create
   acceptable gaps in the local provisional sequence, explicitly distinct from the canonical
   sequence's own stronger gapless guarantee.
4. **Resuming a different held cart while one is already active implicitly holds the active cart
   first.** Not explicitly specified by WF-005; chosen because it is the only option that satisfies
   FR-026's durability guarantee for both carts simultaneously, rather than silently discarding
   whichever cart wasn't picked.
5. **WF-006 (cancel) stays explicitly deferred**, distinct from WF-005 (hold/resume) — this sprint
   builds the latter only.

## Capacity check

2 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — not used as rework; spent instead on a self-found
      regression (see Retrospective) caught before it reached a test failure.
- [x] Documentation capacity reserved: `pos/specification.md` (§1–§4, §9–§11 touched),
      `schema-local.md`, module registry, backlog.md, implementation-log, README bumps.

## Risks

- **None new.** Mobile-only, no server change, no live-HTTP dependency — the same low-risk shape
  Sprint 15 (Bluetooth printing) established for mobile-only sprints. The one real risk this sprint
  carried (silently regressing the atomic-write-rollback guarantee while rewriting `completeSale`)
  was caught by the existing test suite itself, not by inspection — see Retrospective.

## Definition of Done

- [x] Local Drift schema migration v3→v4: `sales.createdAt` added, backfilled from `completedAt`
      for pre-existing rows.
- [x] `SaleRepository` gains `saveDraft`/`deleteDraft`/`holdSale`/`resumeSale`/`listHeldSales`;
      `completeSale` rewritten to transition the existing draft/held row in place.
- [x] `CartController` restructured to `CartState{draftId, lines}`, auto-persisting a draft on every
      mutation; `hold()` and `loadResumed()` added.
- [x] Till screen: `pos_hold_button` (disabled when the cart is empty) and `pos_held_carts_button`
      added to the app bar.
- [x] New `HeldCartsScreen` (`/pos/hold`): auto-resumes when exactly one cart is held, shows a picker
      list for two or more, empty state for zero.
- [x] Unit/widget tests: `drift_sale_repository_test.dart` (~10 new cases),
      `pos_providers_test.dart` (rewritten, hold/loadResumed group added),
      `till_screen_test.dart` (3 new cases), `held_carts_screen_test.dart` (new, 4 cases);
      3 unrelated screen tests' Fake repositories updated to compile against the widened interface.
- [x] `flutter analyze`/`flutter test` — 118/118 clean.
- [x] `pos/specification.md`, `schema-local.md` both updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** WF-006 (cancel), any server-side change (none was
needed — a held/draft cart is never synced as a partial row), discount/tax/split-payment in the
mobile write path (still server-only, a named pre-existing gap this sprint didn't touch).

## Demo script

**Mobile, run 2026-08-14** via `flutter test` (no live-HTTP dependency this sprint — mobile-only
change, per the module spec's own stated equivalent-rigor position for mobile-only work):

1. Add an item to the till → a `draft` row is written locally immediately, before any hold action —
   proving the navigation-model.md §4 auto-persistence requirement, not merely the literal backlog
   wording. ✅
2. Tap Hold → the row transitions to `status='held'`, the in-memory cart clears, the till screen
   shows an empty cart ready for a new sale. ✅
3. With exactly one held cart, open Held Carts → auto-resumes it and pops straight back to the till
   with the cart restored. ✅
4. With two held carts, open Held Carts → a picker list appears (the documented 2-tap exception in
   tap-count-audit.md); tapping an entry resumes that cart and pops back. ✅
5. Start a new cart while a different cart is already held, then resume yet another held cart → the
   active cart is implicitly held first, not discarded; both carts remain resumable afterward. ✅
6. Complete a resumed sale → the existing draft/held row transitions to `completed` in place; no
   duplicate row is created. ✅

**Unit tests, run 2026-08-14**: `flutter test` — 118/118 passing.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this sprint's one real
self-found bug was in the rewrite of `completeSale` itself — `outboundQueue`'s insert was briefly
changed to `insertOnConflictUpdate` while restructuring the surrounding transaction, which would have
silently defeated the existing atomic-write-rollback test (it relies on a genuine INSERT conflict to
prove transaction rollback). Caught by that existing test failing, not by inspection — a useful
reminder that a passing test suite earns its keep exactly at moments like this, restructuring code
around it rather than merely adding to it. A second, unrelated bug was caught the same way
(`flutter test`, not inspection): the first draft of `held_carts_screen_test.dart` threw
"There is nothing to pop" because it pushed `/pos/hold` before the router had attached to a running
widget tree — fixed by pumping `/pos` first, matching how a real user interaction actually drives the
navigation stack.

**M2 — Full POS Loop is now fully closed, all 6 items done**, per
[backlog.md §3](backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point).
**M3 — Customers & Returns is the next milestone**, not yet decomposed to item grain — per this
project's own stated practice (§ intro of backlog.md) of decomposing only once planning actually
reaches a milestone, the same discipline M0/M1/M2 each followed in turn.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 30 planned and built same-day: Hold/Resume built, `flutter analyze`/`flutter test` 118/118. Built to navigation-model.md §4's fuller continuous-auto-persistence requirement; corrected a real schema-local.md immutability-classification gap in the same pass. **M2 — Full POS Loop now fully closed, all 6 items done.** |
