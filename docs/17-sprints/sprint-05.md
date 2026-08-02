# Sprint 05

> **Dates:** Started 2026-08-02
> **Milestone:** M0 — Walking Skeleton
> **Status:** Done — `POST /api/v1/sales` implemented and demoed live against real infrastructure,
> including server-side price/payment recompute and a cross-tenant RLS proof. No new bugs found this
> time — the `requireSession` fix from Sprint 04 held on its second real caller.

## Goal

A signed-in, onboarded user can complete a cash sale whose totals are computed and verified
server-side, never trusted from the client, and durably, idempotently, tenant-isolated stored.

## Scope

Backlog item 6 from [backlog.md §1](backlog.md#1-m0--walking-skeleton-fully-decomposed) — server
side only. Two real gaps were found and resolved before writing code, both against
already-approved Phase 03/11 documents: `sales.md`'s full `POST /sales` contract requires
`trading_day_id` (Trading Day is M2 scope, not built) and tax/discount/split-payment fields (also
M1/M2); [WF-002](../06-workflows/sales-workflows.md#wf-002--complete-a-single-item-cash-sale)
requires the stock-ledger movement atomically with the sale, but that's backlog.md's own later item
7, depending on this one. Both documented as dated corrections / named gaps, the same pattern
Sprint 02/04 already used.

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `POST /sales` (cash-only, no discount/tax) — server side | POS | 3.0 (till screen), of which this sprint takes the server-recompute slice | 5 (done, Sprint 04) |

**Explicitly not in this sprint's scope:** the mobile till screen UI and its local write path (no
Flutter feature screen exists yet — the third sprint in a row deferring mobile UI, named explicitly
in the Risks section below rather than let it compound silently); the stock-ledger effect of a
completed sale (backlog.md item 7, a separate later sprint).

## Capacity check

This sprint's actual scope (the server-recompute slice of backlog.md's 3.0-person-day till-screen
estimate) is well under the ~3.75 person-day sprint budget — most of the original estimate was for
mobile UI work this sprint deliberately doesn't attempt yet (see Risks). Headroom went to the two
spec-gap resolutions and this sprint's own documentation.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-days — smaller than Sprint 04's 1.0, since
      `requireSession`'s bug (the actual source of Sprint 04's surprise) is already fixed and this
      sprint is its second real caller; still reserved, not assumed zero-risk.
- [x] Documentation capacity reserved: 0.5 person-days — the POS module specification, the
      `sales.md`/`error-catalogue.md` corrections, and this sprint document.

## Risks

- **Mobile UI deferral, now three sprints running:** Sprint 03 built only the Drift schema, Sprint
  04 built only a server endpoint, and this sprint does the same again. Each deferral was
  individually correct (scope discipline, matching Sprint 02's own precedent), but the pattern
  itself is worth naming directly rather than let it compound past the point it's still a deliberate
  choice: the M0 exit criterion (backlog.md item 11) genuinely needs a working mobile app, and every
  sprint that defers the UI moves that need further down the backlog without shrinking it. Flagged
  here as a standing item for whoever plans Sprint 06 to weigh explicitly, not a decision made for
  them by this sprint's own momentum.
- **[R-10](../01-vision/risks-constraints-assumptions.md) (dependency abandonment)** — carried
  forward again, low likelihood, standing mention per prior sprints' risk registers.

## Definition of Done

Backend-only slice, same narrow subset as Sprint 02/04:

- [x] Module specification exists, all 11 sections, 🟢 Approved —
      [pos/specification.md](../modules/pos/specification.md)
- [x] Schema: `sales`/`sale_line_items`/`sale_payments` tables (M0-minimal columns), RLS enabled on
      `sales` (`supabase/sql/005_rls_sales.sql`), applied to the live Supabase database and verified
      via the demo script's cross-tenant step
- [x] `POST /api/v1/sales` matches
      [pos/specification.md §4/§5](../modules/pos/specification.md#4-api-contract) exactly — every
      input validated with Zod; every price/total figure server-recomputed from current `products`
      rows, never trusted from the request
- [x] Endpoint is idempotent — replaying the same `id` returns the same sale, without re-running
      price validation against a possibly-since-changed price (verified live, demo step 5)
- [x] Authentication enforced server-side — `requireSession`; `created_by` resolved via
      `identityService.resolveUserId`, same sanctioned cross-module path Sprint 04 established
- [x] Error responses use the standard envelope with `VALIDATION_FAILED`, `PRICE_MISMATCH`,
      `PAYMENT_AMOUNT_MISMATCH` (new this sprint), `NOT_FOUND`
- [x] Unit tests for the service layer (recompute from current price, `PRICE_MISMATCH`,
      `PAYMENT_AMOUNT_MISMATCH`, `NOT_FOUND`, idempotent replay skipping recompute) —
      `src/modules/pos/service.test.ts`, 5 tests
- [x] Cross-tenant negative test: tenant B's session cannot read tenant A's `sales` row — run live,
      passed (empty result)
- [ ] Tests pass **in CI** on an actual merged PR — not checked until that PR is actually open and
      green, per Sprint 01's own rule
- [x] No secret, token, or key written to logs
- [x] Module registry ([modules/README.md](../modules/README.md)) updated to reflect POS' build
      status, including the honest gaps against its listed dependency, WF-002's atomicity
      requirement, and the still-unbuilt mobile till screen

**Explicitly not in this sprint's DoD subset:** mobile/offline/UI boxes (no Flutter client exists),
`GET /sales*` (deferred, per the specification's §4), the stock-ledger effect (backlog.md item 7),
trading-day/tax/discount/split-payment fields (M1/M2 scope, per §1).

## Demo script

**Run 2026-08-02, all 9 steps passed** against the live database, via real HTTP requests to a local
dev server pointed at production Supabase:

1. Sign up and onboard tenant A. ✅
2. Sign up and onboard tenant B, for the cross-tenant check. ✅
3. `POST /api/v1/products` as tenant A — a product to sell. ✅
4. `POST /api/v1/sales` as tenant A — 2 units at the product's real price, exact cash payment —
   show a `201` with the server-computed `grand_total_minor_units`. ✅
5. Replay the exact same request — show it returns the same sale, not a duplicate. ✅
6. `POST /api/v1/sales` with a stale `client_unit_price_minor_units` — show `409 PRICE_MISMATCH`. ✅
7. `POST /api/v1/sales` with a payment not equal to the computed total — show
   `409 PAYMENT_AMOUNT_MISMATCH`. ✅
8. `POST /api/v1/sales` referencing an unknown product — show `404 NOT_FOUND`. ✅
9. As tenant B's session, attempt to read tenant A's `sales` row directly by id — show it is denied
   (empty result). ✅

**No new bug found this sprint** — worth recording precisely because Sprint 04 found one on its
first real call and this is `requireSession`'s second real caller; the fix held.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if the mobile-UI-deferral risk (above)
produces a concrete process change when Sprint 06 is planned — not pre-judged here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-02 | Sprint 05 planned and built same-day: found and resolved two real spec gaps (sales.md's full contract vs. backlog.md's M0-minimal scope; WF-002's stock-ledger atomicity vs. backlog.md's own item 6/7 split) before writing code, wrote the POS module specification, implemented and demoed `POST /api/v1/sales` live including server-side recompute and a cross-tenant RLS proof. No new bug found — `requireSession`'s Sprint 04 fix held on its second real caller. |
