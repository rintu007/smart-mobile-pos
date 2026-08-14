# Sprint 24

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M1 — Full Catalogue & Inventory, Multi-Role (backlog item 8 — the last M1 item)
> **Status:** Closed — **M1 is now fully closed, all 8 items done.**

## Goal

Sales & Invoices, full V1 shape: canonical invoice numbers assigned atomically ([ADR-0008](../adr/ADR-0008-offline-invoice-numbering.md)),
the `GET /sales*` server endpoints already documented in [sales.md](../11-api/endpoints/sales.md),
and permission enforcement on all of it — GST invoice fields excepted, exactly as backlog.md's own
item 8 entry anticipated.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| GST invoice fields, canonical invoice numbers assigned at sync, `GET /sales*` server endpoints, permission enforcement | Sales & Invoices | 3.0 | 7 |

## Design decisions, found while writing the spec

Full detail in [sales-invoices/specification.md §1](../modules/sales-invoices/specification.md#1-purpose-and-business-context).

1. **GST invoice fields stay deferred.** `sales`/`sale_line_items` have no tax/discount columns at
   all — M0's minimal slice never added them, and tax computation itself is M2 scope. Backlog.md's
   own item 8 entry already anticipated this ("item 8's GST fields genuinely need tax computation
   to be fully meaningful"); this sprint doesn't build half of a tax feature just to claim the row.
2. **`canonical_invoice_number` is never actually null in this implementation.** `POST /sales` and
   `POST /sync/push`'s `sale.create` operation call the exact same `pos/service.ts#createSale`, and
   this server never persists a `sales` row until it has already "arrived" — the
   provisional-only, pending-sync state is a mobile-only concept, never a partial server row. So
   canonical-number assignment always happens in the same transaction as the row's own creation, a
   stronger guarantee than sales.md's original "null until sync" framing suggested.
3. **`GET /sales`'s Cashier restriction is adapted, not implemented literally.** sales.md documents
   "Cashier: own device's trading day only" — unimplementable, since neither `devices` nor
   `trading_days` exists in code. Built instead: a Cashier sees only sales they themselves created;
   Manager/Owner see every sale, store-wide.
4. **A pre-existing gap closed in the same migration**: `provisional_invoice_number` was never
   actually enforced unique at the database level, despite identifiers.md already documenting it as
   a business-meaningful identifier. Cheap to add alongside the new canonical-number constraint, so
   fixed here rather than left for a later sprint to rediscover.

## Capacity check

3.0 person-days against the ~3.75 person-day sprint budget — M1's last item, closing the milestone.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `sales-invoices/specification.md` (all 11 sections),
      `sales.md`, `identifiers.md`, ADR-0008 (implementation note only, decision unchanged), module
      registry, backlog.md, implementation-log, README bumps.

## Risks

- **A real, pre-existing data-integrity gap** (`provisional_invoice_number` never enforced unique)
  is closed by a migration adding a `UNIQUE` constraint against 5 real existing sales rows — checked
  for duplicates before applying (none found), not applied blind.
- **Financial-year rollover uses UTC, not IST**, for the April 1 boundary calculation — consistent
  with every other timestamp in this system being stored/reasoned about in UTC, but named as a
  simplification, not a claim of precise IST rollover (same provisional status as everything else
  tied to OD-01's still-unconfirmed launch market).
- **Applying Sprint 23's own routing lesson proactively**: `GET /sales/lookup` and `GET /sales/{id}`
  were built as separate static/dynamic sibling route files from the start, avoiding a repeat of
  the exact `/users/invite`-vs-`users/[id]` collision Sprint 23 found live.

## Definition of Done

- [x] `invoice_sequences` table (new migration + RLS) — atomic per-`(tenant_id, financial_year)`
      counter.
- [x] `sales` gains `canonical_invoice_number`/`financial_year`, both new unique constraints, and a
      `(tenant_id, store_id, completed_at)` index.
- [x] `POST /sales` assigns a canonical invoice number atomically, in the same transaction as the
      sale — idempotent-replay-safe (ADR-0008's own compliance test).
- [x] `GET /api/v1/sales/{id}` — full detail with `line_items`/`payments` embedded, any role.
- [x] `GET /api/v1/sales` — summary fields, cursor-paginated on `(completed_at, id)`,
      `date_from`/`date_to` filters, Cashier scoped to own sales.
- [x] `GET /api/v1/sales/lookup` — exact match on exactly one of
      `provisional_invoice_number`/`canonical_invoice_number`.
- [x] Unit tests: `pos/service.test.ts` extended for the new response fields;
      `sales-invoices/service.test.ts` (11 new tests) for role-scoping, pagination, lookup
      validation, `NOT_FOUND` handling.
- [x] `tsc --noEmit`/`eslint`/`vitest` (85 tests total across the web app) all clean; production
      build verified locally with CI-style placeholder env before pushing.
- [x] Live verification against the real database, throwaway tenants deleted after — 7/7 checks.
- [x] `sales-invoices/specification.md`, `sales.md`, `identifiers.md`, ADR-0008 (implementation
      note) all updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** GST invoice fields (FR-055/FR-056, M2), a
correction/void flow (FR-054), `trading_day_id`/`customer_id` filters on `GET /sales` (neither
module exists), any mobile UI consuming the three new endpoints, receipt printing/sharing changes.

## Demo script

**Server, run 2026-08-14** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. Two sales created back-to-back → `canonical_invoice_number` 1, then 2, same `financial_year`. ✅
2. Replaying the identical `POST /sales` request (same `id`) → still canonical number 1, counter
   not advanced a second time. ✅
3. A second tenant's first sale → `canonical_invoice_number = 1` again — genuinely per-tenant. ✅
4. `GET /sales/{id}` → returns the sale with `line_items`/`payments` embedded. ✅
5. `GET /sales/lookup` by either `provisional_invoice_number` or `canonical_invoice_number`
   resolves to the same sale; both params in the same request → `422 VALIDATION_FAILED`. ✅
6. `GET /sales` as a Cashier who created 0 of the tenant's 2 sales → 0 results; as the tenant's
   Owner → both. ✅
7. Cross-tenant RLS: tenant B's session → `404` on tenant A's sale by id; its own `GET /sales`
   shows only its own 1 sale. ✅

**Unit tests, run 2026-08-14**: `vitest run` — 85/85 passing.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the fifth sprint
running where writing the module spec first surfaced a real gap between an already-written
document's claims and what the system actually produces (`canonical_invoice_number`'s "null until
sync" framing, `GET /sales`'s unimplementable "own device" restriction) — the same pattern named in
Sprints 20 through 23's own retrospectives, now spanning every M1 sprint without exception. Also
the first sprint to apply a previous sprint's own hard-won lesson *proactively* (the
static-route-sibling fix for `/sales/lookup`/`/sales/{id}`) rather than rediscovering it live —
worth treating as a sign the "write it down so it isn't relearned" discipline is actually paying
off, not just a documentation exercise.

**M1 — Full Catalogue & Inventory, Multi-Role is fully closed as of this sprint.** All 8 backlog
items done: Categories, Units, extended Products, mobile catalogue UI, barcode/SKU search, full
stock-movement types, Roles & Permissions, and Sales & Invoices. M2 — Full POS Loop (discount, tax
computation, split payment, hold/resume, Cash Drawer/trading day) is the next milestone, per
[milestones.md](../16-milestones/milestones.md#m2--full-pos-loop) — not yet decomposed to item
grain, per this project's own stated practice of decomposing each milestone only once it's reached.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 24 planned and built same-day: canonical invoice numbers (`invoice_sequences`, atomic per-tenant-per-financial-year counter) and `GET /sales/{id}`/`GET /sales`/`GET /sales/lookup` built and live-verified (7/7). GST invoice fields remain explicitly deferred (M2). A pre-existing `provisional_invoice_number` uniqueness gap closed in the same migration. **M1 fully closed.** |
