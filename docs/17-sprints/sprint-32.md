# Sprint 32

> **Dates:** 2026-08-16 – 2026-08-16 (single-day, same cadence as every prior sprint)
> **Milestone:** M3 — Customers, Returns & Refund, conflict-resolution field-merge (backlog item 2 — Customers, mobile)
> **Status:** Closed — M3 item 2 done. M3 now has items 3–5 remaining.

## Goal

Customers (mobile): local `customers` Drift table, `/customers` list with phone-match-as-you-type
search (FR-052), `/customers/:id` detail with purchase history (FR-051), inline capture/select
wired into the till's checkout flow (FR-050, offline-queued create) —
[customers/specification.md §1a](../modules/customers/specification.md#1a-sprint-32--customers-mobile-m3-item-2).
M3's second item, picking up exactly where [Sprint 31](sprint-31.md) named and deferred it.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Local `customers` table, mobile UI, `customer.create` sync-push, `POST /sales` `customer_id` | Customers (mobile) | 2.5 | 1 (Customers, server) |

## Design decisions, found while writing the spec

Full detail in
[customers/specification.md §1a](../modules/customers/specification.md#1a-sprint-32--customers-mobile-m3-item-2).

1. **A full-stack item, not mobile-only** — despite the backlog row's own "(mobile)" label. Sprint
   31 explicitly named and deferred two server-side pieces this item actually needs to be real:
   the `customer.create` sync-push operation type and `POST /sales` accepting `customer_id`.
   Building the mobile UI alone would have produced screens with nothing real to call.
2. **`customer.create` reuses `product.create`'s exact local-write-plus-outbound_queue shape**, not
   Categories/Units' online-only-direct-call shape — `customers.md` documents `POST /customers` as
   genuinely offline-queued, matching Products, not Categories.
3. **Reads stay direct-fetch-and-cache, not a new sync-pull cursor.** A full bidirectional
   `GET /sync/pull?entity_type=customers` mechanism is real, undiscussed scope disproportionate to
   what FR-052's local search actually needs — mirrors Categories/Units' own `refreshFromServer()`
   shape instead.
4. **Capture is a bottom sheet over the till screen, not a route push** — FR-050's own "without
   leaving the sale screen" wording, taken literally rather than loosely paraphrased.
   `/customers`/`/customers/:id` remain full routes for the separate browse/purchase-history job,
   reached via a distinct app-bar icon (`pos_customers_button`), the same two-entry-point shape
   Hold/Resume already established for held-carts (icon) vs. resume-into-cart (in-flow).
5. **The attached customer survives hold/resume** — the same FR-026 durability guarantee Sprint 30
   already established for line items, extended to `CartState`'s new `customerId`/`customerName`/
   `customerPhone` fields.

## Capacity check

2.5 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — not used as rework; the `DriftCustomerRepository`
      constructor was corrected from a raw `Dio` parameter to injected functions (matching
      `DriftCategoryRepository`'s own established testability precedent) before it shipped, caught
      while writing tests, not after.
- [x] Documentation capacity reserved: `customers/specification.md` §1a (and throughout),
      `pos/specification.md`, `sync-engine/specification.md`, module registry, backlog.md,
      implementation-log, README bumps.

## Risks

- **None new.** The server-side additions are small, additive extensions of already-proven
  mechanisms (a third sync-push type alongside two existing ones; an optional field on an
  already-working endpoint, validated the same way `category_id`/`unit_id` already are) — the same
  low-risk shape Trading Day's own `trading_day_id` addition (Sprint 26) established.

## Definition of Done

- [x] Local `customers` Drift table (schema v4→v5), `sales.customer_id` (nullable).
- [x] `DriftCustomerRepository` — `createCustomer` (local write + `outbound_queue` enqueue,
      atomic, idempotent), `searchByPhone` (local prefix match), `findById`, `refreshFromServer`,
      `getPurchaseHistory` (live, on demand).
- [x] Server: `customer.create` sync-push operation type (`sync/schema.ts`, `sync/service.ts`,
      `TYPE_ORDER`); `POST /sales` accepts an optional `customer_id`, validated against the
      caller's tenant (`NOT_FOUND` otherwise) via a new `customersService.customerExists`
      service-to-service call (not a repository-layer cross-module reach-through — a real,
      pre-existing inconsistency in `products/repository.ts`'s own `category_id`/`unit_id` checks
      was named, not copied).
- [x] Mobile UI: `CustomerPickerSheet` (bottom sheet, search + inline create-and-attach),
      `CustomersScreen` (`/customers`), `CustomerDetailScreen` (`/customers/:id`), till screen gains
      `pos_customer_chip` and `pos_customers_button`.
- [x] `CartController` gains `attachCustomer`/`removeCustomer`; `CartState`/`ResumedCart` carry the
      attached customer through hold/resume/complete.
- [x] Unit/widget tests: `drift_customer_repository_test.dart` (new, 10 cases),
      `drift_sale_repository_test.dart` (customerId group, 5 new cases), `pos_providers_test.dart`
      (attachCustomer/removeCustomer group, 4 new cases), `till_screen_test.dart` (4 new cases,
      including a full attach-flow test), `customers_screen_test.dart`/`customer_detail_screen_test.dart`
      (new, 6 cases total). Server: `pos/service.test.ts` (3 new cases), `sync/service.test.ts`
      (3 new cases).
- [x] `tsc --noEmit`/`eslint`/`vitest` (152 total web tests) all clean;
      `flutter analyze`/`flutter test` (145 total mobile tests) all clean; production build verified
      locally with CI-style placeholder env before pushing.
- [x] Live verification against the real database, throwaway tenant (deleted after) — 9/9 checks.
- [x] `customers/specification.md`, `pos/specification.md`, `sync-engine/specification.md` all
      updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** `customer.update` sync-push, mobile customer-edit
UI, the conflict-resolution field-merge policy itself — all named, M3 item 5's scope specifically.

## Demo script

**Server, run 2026-08-16** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenant deleted after:

1. `POST /sales` with a valid `customer_id` → `201`, the response's own `customer_id` echoes it. ✅
2. The completed sale appears in that customer's `GET /customers/{id}/purchase-history`. ✅
3. `POST /sales` with an invalid `customer_id` → `404 NOT_FOUND`. ✅
4. `POST /sync/push` with a `customer.create` operation → `accepted`, `entity_id` set. ✅
5. The sync-pushed customer is immediately queryable via `GET /customers?phone=`. ✅
6. A batch with `sale.create` submitted *before* `customer.create` in the request, the sale
   referencing that same customer — both still `accepted`, confirming `customer.create` is
   processed first regardless of submission order. ✅

**Mobile, run 2026-08-16** via `flutter test` (145/145): tapping the customer chip opens the
picker sheet; searching filters the local cache; tapping a result attaches it to the active cart
and updates the chip's label; the attachment persists through the local `saveDraft`/`completeSale`
write path.

**Unit tests, run 2026-08-16**: `vitest run` — 152/152 passing (7 new); `flutter test` — 145/145
passing (27 new).

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this sprint's own
self-caught inconsistency (a raw `Dio` parameter vs. `DriftCategoryRepository`'s already-established
injected-function testability pattern) is a useful reminder that a new repository should be checked
against its closest existing sibling's own *design*, not just its *behaviour*, before writing the
first test against it — the mismatch was only visible once test-writing started, not during the
initial implementation pass.

**M3 now has items 3–5 remaining: Returns & Refund (server), Returns & Refund (mobile),
conflict-resolution field-merge** — per
[backlog.md §4](backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | Sprint 32 planned and built same-day: Customers (mobile) built and live-verified (9/9 server, 145/145 `flutter test`). Built as a full-stack item — `customer.create` sync-push type and `POST /sales`'s `customer_id` field, both named-and-deferred in Sprint 31, built alongside the mobile UI itself. |
