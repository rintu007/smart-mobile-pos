# Module Specification — Inventory (Stock Ledger)

> **Status:** 🟢 Approved
> **Module:** Inventory — Stock Ledger
> **Slice:** V1 — this document scopes only backlog.md item 7's M0-minimal cut, not the full V1
> shape (§1)
> **Version:** 0.1.0
> **Last updated:** 2026-08-13
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 11](../../17-sprints/sprint-11.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Gives every product a stock-ledger baseline the moment it's created, and lets a completed sale
debit that ledger automatically — [backlog.md item 7](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)
("Stock ledger: `opening` movement on product creation, `sale` movement on sale completion...in
the same transaction as the sale"), the M0 item both [pos/specification.md §1](../pos/specification.md#1-purpose-and-business-context)
and [products/specification.md](../products/specification.md) already named as a dependency they
don't yet meet. [milestones.md — M0](../../16-milestones/milestones.md#m0--walking-skeleton)'s own
exit criterion requires "the stock ledger (one `opening` and one `sale` movement)... present and
correct" — this is that requirement's implementation.

**Deliberately narrow scope, found while writing this spec:** the full V1 shape of this module —
[WF-009](../../06-workflows/inventory-workflows.md#wf-009--record-opening-stock)'s own dedicated
"enter initial quantity" screen (`/catalogue/inventory/opening-stock`), stock adjustments
([WF-010](../../06-workflows/inventory-workflows.md#wf-010--record-a-stock-adjustment)), the public
`POST`/`GET /stock-movements` and `GET /products/{id}/stock-balance` endpoints
([inventory.md](../../11-api/endpoints/inventory.md)), and any mobile UI at all — none of these are
built this sprint. Instead, `POST /api/v1/products` gains an **optional** `initial_quantity` field
(defaulting to 0) that produces a single `opening` movement in the same transaction as the product
row, and `POST /api/v1/sales` produces one `sale` movement per line item in the same transaction as
the sale. This satisfies DR-006 and M0's exit criterion without building WF-009's dedicated
screen/endpoint — a real, named narrowing of the full V1 workflow, not a claim that WF-009 is done.
Mobile continues sending `{ id, name, price_minor_units }` unchanged (no `initial_quantity`), so
every mobile-created product gets a zero-quantity opening movement until a later sprint adds the
field to `/catalogue/add` — also named here, not silently produced.

## 2. Business rules

- [DR-006](../../03-functional-requirements/business-rules.md): an opening movement establishes a
  product+store's first recorded balance; distinct from an adjustment, never used to correct one.
  Enforced here by construction — exactly one `opening` movement is written, at creation, per
  product, and nothing in this sprint's scope can write a second one for the same product.
- [DR-005](../../03-functional-requirements/business-rules.md): a sale is never blocked by
  insufficient recorded stock — the resulting balance may go negative, and does, without error or
  warning at this layer (a future stock-report concern, per
  [inventory.md](../../11-api/endpoints/inventory.md)'s own "why oversell is not an error here").
- `quantity_delta` is signed: positive for `opening`, negative for `sale` — the only two movement
  types this sprint ever writes. `adjustment`/`return` remain schema-valid values (the column has
  no `CHECK` constraint, matching `Sale.status`'s own precedent) but nothing in this sprint's code
  path produces them.
- A stock movement, once written, is immutable — by construction, the same reasoning
  [sales-invoices/specification.md §2](../sales-invoices/specification.md#2-business-rules) already
  used: no update/delete code path exists anywhere for `stock_movements`.
- Both writes are transactional with their triggering row: `products.createProduct` fails entirely
  (no product, no movement) if the movement insert fails, and `pos.createSale` likewise fails
  entirely (no sale, no movements) if any movement insert fails — verified live (§10).

## 3. Database tables and relationships

New table: `stock_movements`, an M0-minimal slice of
[schema-server.md](../../07-database/schema-server.md) Context 3. Implements: `id`, `tenant_id`,
`store_id`, `product_id`, `quantity_delta`, `movement_type`, `reference_type`, `reference_id`,
`created_at`, `created_by`. **Not yet built:** `variant_id`/`batch_id`/`serial_number` (V2/V4
stubs), `reason_code` (only needed once `adjustment` movements exist). **Deviates from
schema-server.md:** `device_id NOT NULL` is omitted entirely — the same M0-wide gap `sales`
already has (device registration isn't built — [module registry](../README.md), Authentication
row). `created_by` substitutes for attribution here, matching every other M0-minimal table's own
precedent (`products.created_by`, `sales.created_by`).

`quantity_delta` is `INTEGER`, not schema-server.md's `NUMERIC(14,3)` — the same fractional-quantity
deferral `sale_line_items.quantity` already established
([pos/specification.md §3](../pos/specification.md#3-database-tables-and-relationships)): Units,
which would say whether a product allows fractional quantities, is M1 scope.

`products` gains no new column — `initial_quantity` (§4) is a request-only field, not stored on the
product row itself; it only ever produces a `stock_movements` row.

RLS: tenant-scoped, same template as `products`/`sales`
([supabase/sql/006_rls_stock_movements.sql](../../../supabase/sql/006_rls_stock_movements.sql)).

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/products` | **Extended this sprint.** Request gains an optional `initial_quantity` (non-negative integer, defaults to 0 if omitted) — not part of [catalogue.md](../../11-api/endpoints/catalogue.md)'s documented request shape, a named, minimal addition. `store_id` is never accepted from the request — resolved server-side as the tenant's one store (ADR-0003), matching [inventory.md](../../11-api/endpoints/inventory.md)'s own stated principle for stock-movement writes generally. |
| `POST /api/v1/sales` | **Extended this sprint**, no request-shape change — the existing line items now each also produce a `stock_movements` row server-side, invisibly to the caller. Response shape unchanged. |
| `POST /stock-movements`, `GET /stock-movements`, `GET /products/{id}/stock-balance` | **Already documented** in [inventory.md](../../11-api/endpoints/inventory.md), **not implemented, and not needed this sprint** — see §1. Remain future (adjustment-workflow / stock-report) scope. |

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `initial_quantity` (on `POST /products`) | Non-negative integer, optional — Zod `.int().nonnegative().optional()`, defaults to `0` in the service layer if omitted |

No new validation on `POST /sales` — every stock movement it produces is derived entirely from
already-validated line items (§4/§5 of [pos/specification.md](../pos/specification.md)), never from
new input.

## 6. Error handling and user-facing messages

None new. `initial_quantity` failing Zod validation surfaces as the existing `VALIDATION_FAILED`
(422), same envelope as every other field on this endpoint. No new failure mode on `POST /sales` —
a stock movement is never independently rejectable; it either commits with the sale or the whole
transaction (sale included) rolls back.

## 7. Offline behaviour

Both writes ride the connectivity model their triggering endpoint already has (`POST /products`,
`POST /sales` — both currently require connectivity; no mobile offline queue path pushes either yet
per those modules' own §7). No independent offline behaviour exists for this module this sprint —
there is no mobile UI producing a stock movement directly (§1).

## 8. Realtime behaviour

None specified for V1 in this sprint's scope — no requirement found for live balance push to other
devices; a future `GET /products/{id}/stock-balance` (§4, deferred) would be the read path once it
exists.

## 9. UI specification

None this sprint — no mobile screen is built or changed. `/catalogue/inventory/opening-stock`
(route-map.md, WF-009's dedicated screen) remains unbuilt, deferred past this sprint (§1).

## 10. Test plan

**Sprint 11 scope:**
- Unit tests (`products/service.test.ts`): the tenant's primary store is resolved server-side and
  passed to the repository alongside the rest of the creation input.
- Unit test (`stores/service.test.ts`): `getPrimaryStoreId` returns the first store's id.
- **Live verification, real database, throwaway tenants (deleted after) — 16/16 checks passed:**
  1. `POST /products` with `initial_quantity: 10` → exactly one `opening` movement,
     `quantity_delta = 10`, correct `store_id`.
  2. Replaying the identical create request → still exactly one `opening` movement (idempotent).
  3. `POST /sales` for 3 units → a `sale` movement, `quantity_delta = -3`,
     `reference_type = 'sale'`, `reference_id` = the sale's id; derived balance (`opening` + `sale`)
     = 7.
  4. A second sale for 20 units against a balance of 7 → **succeeds** (`201`, not rejected),
     derived balance = -13 — DR-005 proven against a real oversell, not just asserted.
  5. Cross-tenant RLS: tenant B's session reads zero of tenant A's `stock_movements` rows via
     PostgREST directly.

**Explicitly deferred:** everything in §1's narrowing paragraph — WF-009's own screen, stock
adjustments (WF-010), the public stock-movements/balance endpoints, mobile UI for opening quantity,
`device_id` attribution.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-040](../../03-functional-requirements/functional-requirements.md) (setting an initial quantity records a single, dated opening-stock entry) | §2, §10 | **Partially met** — the entry is always recorded (even when `initial_quantity` is omitted, as 0); there is no dedicated UI/endpoint yet for a Manager to *set* a nonzero quantity after the fact (WF-009) |
| [DR-005](../../03-functional-requirements/business-rules.md) (sale never blocked by insufficient stock) | §2, §10 | Met — proven live against a real oversell |
| [DR-006](../../03-functional-requirements/business-rules.md) (opening establishes first balance, distinct from adjustment) | §2, §3 | Met |
| [milestones.md — M0 exit criterion](../../16-milestones/milestones.md#m0--walking-skeleton) (stock ledger: one opening, one sale movement, present and correct) | §10 | Met |
| [inventory.md](../../11-api/endpoints/inventory.md) (`POST`/`GET /stock-movements`, `GET .../stock-balance`) | — | **Not met this sprint** — named future scope (§1, §4) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | First version — written to drive Sprint 11's minimal opening/sale stock-movement writes (backlog.md item 7). Scope deliberately narrow: no adjustment workflow, no public stock-movement endpoints, no mobile UI; `device_id` omitted (M0-wide gap, matching `sales`), `created_by` substituted for attribution. |
