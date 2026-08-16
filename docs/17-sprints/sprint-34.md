# Sprint 34

> **Dates:** 2026-08-16 – 2026-08-16 (single-day, same cadence as every prior sprint)
> **Milestone:** M3 — Customers, Returns & Refund, conflict-resolution field-merge (backlog item 4 — Returns & Refund, mobile)
> **Status:** Closed — M3 item 4 done. M3 now has item 5 remaining.

## Goal

Returns & Refund (mobile): `/returns/new`, `/returns/:id`, `/returns/approvals`, local
`returns`/`return_line_items` tables + outbound-queue enqueue for create/approve/reject —
[returns/specification.md §1b](../modules/returns/specification.md#1b-sprint-34--returns--refund-mobile-m3-item-4).
M3's fourth item, picking up exactly where [Sprint 33](sprint-33.md) left the server contract with
no mobile caller.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Local `returns`/`return_line_items` tables, mobile UI, `return.create`/`return.approve`/`return.reject` sync-push enqueue | Returns & Refund (mobile) | 2.5 | 2 (Customers, mobile), 3 (Returns, server) |

## Design decisions, found while writing the spec

Full detail in [returns/specification.md §1b](../modules/returns/specification.md#1b-sprint-34--returns--refund-mobile-m3-item-4).

1. **A real, blocking gap found before writing any code**: no server response ever exposed a sale
   line item's own `id`, which `POST /returns` requires as `original_sale_line_item_id`. Fixed with
   a small, additive correction to `pos/service.ts`'s `formatSale` — every existing consumer already
   tolerates extra response fields.
2. **Locating the original sale hits the network — both paths**, per backlog.md item 4's own
   wording: `SaleRepository` gains `lookupSale` (`GET /sales/lookup`) and `fetchRemoteSaleDetail`
   (`GET /sales/{id}`), both injected functions, not a raw `Dio`. `lookupSale` falls back to a local
   search of this device's own completed sales when the network call fails — genuinely offline for
   the common case.
3. **No client-side role-awareness exists anywhere in mobile yet — named, not solved here.** The
   approvals entry point and screen are shown to every role; the server's own `403` is surfaced
   honestly rather than hidden behind a role check this codebase has no way to perform correctly.
4. **The approvals-queue badge, resolved as a dated correction** to `returns.md`'s own forward
   reference to a "Reports-tab badge" that doesn't exist yet (Reports is M4, unbuilt) — placed on a
   new Till app-bar icon instead.
5. **WF-013's interrupt/queue split, resolved without new realtime infrastructure** — an inline
   post-creation "Approve now?" prompt covers the interrupt path (a Manager/Owner operating the till
   themselves); the queue path needs no special handling, it's simply what happens when that prompt
   isn't acted on.

## Capacity check

2.5 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — not used as rework; the blocking `formatSale`
      line-item-id gap was found and fixed before any mobile code was written, not discovered by a
      failing test afterward.
- [x] Documentation capacity reserved: `returns/specification.md` §1b (and throughout), `pos/specification.md`,
      module registry, backlog.md, implementation-log, README bumps.

## Risks

- **None new.** The local-write-plus-enqueue mechanism reuses `DriftCustomerRepository`/
  `DriftSaleRepository`'s own already-proven shape exactly; the two new network reads are additive,
  injected functions following the same testability pattern every prior network-backed repository
  method already established.

## Definition of Done

- [x] Server: `pos/service.ts`'s `formatSale` gains `id` per line item (additive, non-breaking).
- [x] Local `Returns`/`ReturnLineItems` Drift tables (schema v5→v6).
- [x] `SaleRepository` gains `lookupSale`/`fetchRemoteSaleDetail`; `SaleLineDetail` gains `id`;
      new `pos/data/data_sources/sales_api.dart`.
- [x] `ReturnRepository`/`DriftReturnRepository` — `createReturn` (local write + enqueue, atomic,
      idempotent), `listMine`/`listApprovals` (live refresh + cache, offline fallback),
      `getDetail` (cache-first, live fallback), `approveReturn`/`rejectReturn` (local update +
      enqueue, atomic, idempotent).
- [x] Mobile UI: `NewReturnScreen` (`/returns/new`, invoice-number and customer-purchase-history
      lookup paths, line-item quantity selection, inline approve-now prompt), `ReturnDetailScreen`
      (`/returns/:id`, approve/reject when pending), `ReturnApprovalsScreen` (`/returns/approvals`,
      honest 403 surfacing). Till screen gains `pos_return_button` and
      `pos_returns_approvals_button` (with a live pending-count badge).
- [x] Router: `/returns/new`, `/returns/:id`, `/returns/approvals` registered.
- [x] Unit/widget tests: `drift_return_repository_test.dart` (new, 15 cases),
      `drift_sale_repository_test.dart` (`lookupSale`/`fetchRemoteSaleDetail` groups, 6 new cases),
      `return_approvals_screen_test.dart`/`return_detail_screen_test.dart`/`new_return_screen_test.dart`
      (new, 13 cases total). Server: `pos/service.test.ts` (1 new case). Four existing fake
      `SaleRepository` implementations updated for the two new interface methods.
- [x] `tsc --noEmit`/`eslint`/`vitest` (182 total web tests) all clean; `flutter analyze`/
      `flutter test` all clean; production build verified locally before pushing.
- [x] `returns/specification.md`, `pos/specification.md` both updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** the conflict-resolution field-merge policy itself
(M3 item 5), any generalisation of the badge-placement/role-awareness decisions beyond Returns.

## Demo script

**Mobile, run 2026-08-16** via `flutter test`: locating a sale by invoice number and by a customer's
purchase history both surface the sale's line items with quantity steppers; confirming a below-
threshold selection creates the return and navigates to its detail screen; confirming an
above-threshold selection shows the inline approve-now prompt instead; the approvals screen renders
its empty state, a populated queue, and a plain error for a simulated 403 — the same honest-error
shape every other list screen in this app already uses.

**Server regression check, run 2026-08-16**: `GET /sales/{id}`/`GET /sales/lookup` both now return
each line item's own `id`; every other server test (`vitest run`, 182/182) remains green.

**Unit tests, run 2026-08-16**: `flutter test` and `vitest run` both fully green (exact counts in
the Definition of Done above).

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: the blocking
`original_sale_line_item_id` gap was found by tracing the mobile screen's actual data need back to
the server's own response shape *before* writing any mobile code — the same "design before code"
discipline this project has followed from Sprint 01 onward, applied here to a cross-module contract
gap rather than a single module's own internal design.

**M3 now has item 5 remaining: conflict-resolution field-merge (`customers` only)** — per
[backlog.md §4](backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | Sprint 34 planned and built same-day: Returns & Refund (mobile) built and verified (`flutter test`/`vitest run` both fully green). Found and fixed a real, blocking server gap before writing mobile code — `formatSale` never exposed a sale line item's own `id`. Badge-placement and interrupt/queue-approval design decisions resolved and documented, both explicitly left open by Sprint 33's own text. |
