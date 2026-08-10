# Sprint 09

> **Dates:** 2026-08-02 – 2026-08-02 (single-day, same pattern as Sprints 02–08)
> **Milestone:** M0 — Walking Skeleton
> **Status:** Closed

## Goal

Build the till screen (`/pos`): manual product-add-to-cart, cash payment only, completing a sale
through the local write path (Drift + `outbound_queue`) — [backlog.md item 6](backlog.md#1-m0--walking-skeleton-fully-decomposed),
now unblocked by item 5 (local products, Sprint 07) and item 13 (store context, Sprint 08).

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| 6 | POS (mobile till screen + local write path) | 3 | 5, 13 — both done |

## A real gap found while planning: provisional invoice numbering has no caller yet

[pos/specification.md §3](../modules/pos/specification.md#3-database-tables-and-relationships)
already notes that `provisional_invoice_number` was accepted as a plain client-supplied string in
Sprint 05 because "no mobile write path exists yet." That mobile write path is exactly what this
sprint builds — so the column stops being a placeholder and needs an actual value, and
`sales.provisional_invoice_number` is `NOT NULL` (server) and required non-empty (Zod schema)
either way: the till screen cannot complete a sale without producing one.

[ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md) and
[identifiers.md §3–§4](../07-database/identifiers.md) already fully specify the scheme
(`{device_short_id}-{financial_year}-{device_local_sequence}`, financial year rolling over April 1,
`local_provisional_sequence` keyed by `(device, financial_year)`, `client_device_id` generated
fresh per install rather than derived from hardware) — this was never an undocumented gap the way
Sprint 06/08's items 12/13 were. What backlog.md never made explicit is that item 6 cannot be built
without it. **Not treated as a new backlog item** (unlike items 12/13): this is intrinsic to item
6's own declared shape ("`POST /sales` with server-side recompute" requires a real request body,
and the request body requires this field), not a missing prerequisite module. Named here instead so
it isn't silently absorbed without a trace.

**Deliberately narrower than the full ADR-0008 device model:** `client_device_id` normally lives in
the not-yet-built `devices` table (Authentication's device-registration slice — still absent per the
[module registry](../modules/README.md)). This sprint generates and persists a local-only device
short id (never derived from a hardware identifier, matching identifiers.md §4's edge case) with no
server-side `devices` row backing it yet — sufficient for the numbering scheme's local half, not a
claim that device registration is done. Canonical-number assignment (ADR-0008's server half) has no
caller yet either, since the sync engine (item 9) isn't built — `canonical_invoice_number` stays
`null` on every sale this sprint produces, same as every sale Sprint 05 produced directly online.

## A second small gap: `core/money` was deferred twice, this is the second feature that needs it

[sprint-07.md's Risks](sprint-07.md#risks) already named this: `add_product_screen.dart` inlined its
own decimal-to-minor-units conversion because no second feature needed the same logic yet — flagged
explicitly as "until a second feature needs it too." The till screen needs to both parse (none,
actually — it only formats) and format money for display (cart lines, running total, receipt-style
confirmation). Built this sprint per [mobile-structure.md §3](../08-folder-structure/mobile-structure.md#3-what-belongs-in-core-and-what-doesnt)'s
own rule, and `add_product_screen.dart` is updated to use it instead of keeping the logic
duplicated.

## What stays out of scope, on purpose

- **Stock-ledger effect** — backlog.md item 7, explicitly the next item after this one, not folded
  in here.
- **Receipt printing** — item 10, depends on this item, not built yet.
- **The sync engine actually draining `outbound_queue`** — item 9. This sprint's sale-completion
  write enqueues a `sale.create` operation with a payload shaped identically to `POST /api/v1/sales`'s
  own request body ([sync-api.md §1](../11-api/sync-api.md#1-one-request-shape)), matching Sprint
  07's product-creation precedent exactly — nothing drains it yet.
- **Change-due / tendered-amount entry** — [pos/specification.md §2](../modules/pos/specification.md#2-business-rules)
  requires the single cash payment to equal the grand total *exactly*, so the till screen has no
  "amount tendered" field at all this sprint — the cart total *is* the amount charged, no change
  calculated. Split payment and change-due tracking are M1/M2 scope, already named in the spec.
- **Barcode scan / search** — backlog.md item 6 says "manual product add to cart (no scanning
  yet)"; the product list is a plain tappable list, `mobile_scanner` (already a dependency) stays
  unused this sprint.
- **A bottom-nav shell** — [navigation-model.md](../09-navigation/navigation-model.md)'s tab shell
  isn't built. `/pos` is reached from `HomeScreen` via a button, the same pattern
  `/catalogue/add`'s FAB already established in Sprint 07 — not a claim that till is "the" home
  route yet, even though [route-map.md](../09-navigation/route-map.md) calls it that for the
  eventual shell.

## Capacity check

3 person-days against [sprint-cadence.md](sprint-cadence.md)'s ~3.75 person-day budget — inside
budget, the largest single-item sprint of M0 so far, matching backlog.md's own estimate.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: this sprint's own doc updates (pos/specification.md,
      schema-local.md's two new local-only tables, route-map.md if `/pos`'s reachability note is
      needed, module registry, implementation-log, README bumps) are inside the estimate above.

## Risks

- **Same device-target gap as Sprints 06–08** (`flutter doctor` still missing the Windows C++
  workload and Android SDK) — proven via `flutter test` against a real Drift database
  (atomicity, idempotency, invoice-number sequencing) plus widget tests with overridden providers
  (cart/UI behaviour), no device needed for either half, matching Sprint 07/08's precedent. No new
  backend code this sprint, so no new live-HTTP demo is required either — `POST /api/v1/sales`
  itself was already proven live in Sprint 05 and is unchanged here.
- **Largest local-write transaction built so far** (sale + N line items + 1 payment + 1
  outbound_queue row + 1 invoice-sequence increment, all atomic) — the atomicity proof needs to
  cover a genuinely multi-row write, not the single-row case Sprint 07 proved.

## Definition of Done

- [x] `/pos` screen: product list (from the local `products` cache), tap-to-add-to-cart,
      per-line quantity shown, running grand total, "Complete sale" action.
- [x] Completing a sale writes `sales` + `sale_line_items` + `sale_payments` + one `outbound_queue`
      row atomically, idempotent on the sale's `id`, payload shaped identically to
      `POST /api/v1/sales`'s request body.
- [x] A real, non-empty `provisional_invoice_number` is generated locally per ADR-0008's scheme
      (device short id + financial year + per-device sequence), persisted, and never reused.
- [x] `core/money` built; `add_product_screen.dart` migrated to use it.
- [x] `flutter analyze` / `flutter test` clean (44 tests total), including a multi-row atomicity
      test against a real Drift database (`NativeDatabase.memory()`, same convention as every prior
      sprint's repository tests).
- [x] No secret, token, or key written to logs or committed to source.
- [x] `pos/specification.md`, `schema-local.md`, module registry, implementation-log, and READMEs
      updated in the same PR. No backlog.md change — the numbering-generator work is intrinsic to
      item 6's own declared shape (see this doc's own gap note above), not a missing prerequisite
      module, so it isn't tracked as a separate backlog line the way items 12/13 were.

**Explicitly not in this sprint's DoD subset:** stock-ledger effect (item 7), receipt printing
(item 10), the sync engine (item 9), split payment/change-due/discount/tax (M1/M2), barcode scan,
a bottom-nav shell.

## Demo script

**Mobile, local** (`flutter test`, no device needed):
1. `InvoiceNumberGenerator` — sequential numbers increment within one financial year; a device short
   id is generated once and stays stable across calls; a date before vs. after April 1 produces a
   different financial-year segment.
2. `DriftSaleRepository.completeSale` — writes one `sales` row, its line items, its payment, and one
   `outbound_queue` row, all atomically; a retry with the same `id` returns the original sale
   unchanged without re-writing anything; an injected failure mid-transaction leaves zero rows
   behind (same atomicity-proof pattern as Sprint 07's product-creation test, extended to a
   multi-row write).
3. Cart controller — adding the same product twice increments its line's quantity rather than
   duplicating a row; removing down to zero removes the line; the grand-total provider matches the
   sum of line totals.
4. Till screen widget tests (overridden providers, no real device/network) — tapping a product adds
   it to the cart and updates the visible total; completing a sale shows the resulting provisional
   invoice number and clears the cart.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-02 | Sprint 09 planned: the till screen (backlog item 6), now unblocked by items 5 and 13. Found that provisional invoice numbering (ADR-0008) has no caller until this sprint's local write path exists, and that `core/money` — deferred twice (Sprint 07's own risk register) — is needed by a second feature now. Neither treated as a new backlog item; both intrinsic to item 6's own declared shape, named here rather than silently absorbed. |
| 0.2.0 | 2026-08-02 | Sprint 09 closed: `/pos` built — cart, cash-only sale completion, an atomic multi-row local write (`sales`/`sale_line_items`/`sale_payments`/`outbound_queue`), `InvoiceNumberGenerator` (ADR-0008's local half), `core/money`. 10 new mobile tests, 44 total, all green; `flutter analyze` clean; backend untouched (`vitest`, 17/17, re-run as a sanity check). PR pending. |
