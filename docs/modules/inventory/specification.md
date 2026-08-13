# Module Specification — Inventory (Stock Ledger)

> **Status:** 🟢 Approved
> **Module:** Inventory — Stock Ledger
> **Slice:** V1 — full `adjustment`/`reason_code` support and the public
> `POST`/`GET /stock-movements`, `GET /products/{id}/stock-balance` endpoints (§1); WF-009's own
> dedicated opening-stock screen and any mobile UI remain deferred (§1)
> **Version:** 0.2.0
> **Last updated:** 2026-08-14
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Updated to drive [Sprint 22](../../17-sprints/sprint-22.md) — specification before code, per
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
correct" — this was that requirement's implementation, closed in Sprint 11.

**This version (Sprint 22, [backlog.md item 6](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point)):**
builds the `adjustment` movement type ([WF-010](../../06-workflows/inventory-workflows.md#wf-010--record-a-stock-adjustment),
DR-007) plus the three endpoints [inventory.md](../../11-api/endpoints/inventory.md) already
documented but Sprint 11 explicitly deferred: `POST /stock-movements`, `GET /stock-movements`,
`GET /products/{id}/stock-balance`.

**Design decision, found while writing this spec: `movement_type: 'opening'` is not accepted by
`POST /stock-movements`, even though inventory.md's own table says the endpoint is "reachable by a
client only for `opening` and `adjustment`".** Every product already receives exactly one `opening`
movement automatically, in the same transaction as its own creation (Sprint 11,
[products/specification.md](../products/specification.md)) — there is no live workflow that needs
a *second*, client-initiated `opening` write, and DR-006 ("distinct from an adjustment, never used
to correct one... exactly one, at creation") would otherwise need new guarding this sprint has no
real caller to justify. WF-009's own dedicated screen (the one place a *second* look at opening
stock could come from) remains explicitly out of scope this sprint too. A mis-recorded or since-
changed opening quantity is corrected the way WF-009 itself already says: "via a stock adjustment
(WF-010), never edited in place" — i.e., via `movement_type: 'adjustment'`, `reason_code:
'count_correction'`, already fully supported by this sprint's own endpoint. So `POST
/stock-movements`'s accepted `movement_type` values this sprint are `adjustment` (the only creatable
type), `sale`, and `return` (both rejected with `DIRECT_SALE_MOVEMENT_FORBIDDEN`, per inventory.md);
`opening` is excluded from the request schema entirely — a `422 VALIDATION_FAILED`, not a
`DIRECT_SALE_MOVEMENT_FORBIDDEN`, since (unlike `sale`/`return`) it was never a real target of this
endpoint's contract, just an unexamined artefact of listing all four schema-level `movement_type`
values together. `GET /stock-movements`'s `movement_type` filter, by contrast, does accept `opening`
— it is a real value already present in the table from every product's creation, and the movement-
history view needs to show it.

Also still narrow, unchanged from Sprint 11: `POST /api/v1/products`'s optional `initial_quantity`
(defaulting to 0) remains the only path that ever produces an `opening` movement, and `POST
/api/v1/sales` remains the only path that ever produces a `sale` movement — both server-side,
in-transaction side effects, never directly postable. WF-009's own dedicated "enter initial
quantity" screen (`/catalogue/inventory/opening-stock`) and any mobile UI for adjustments or balance
viewing remain unbuilt this sprint too (§9) — this sprint is the two server endpoints plus the
public balance/history read path, not a mobile feature.

## 2. Business rules

- [DR-006](../../03-functional-requirements/business-rules.md): an opening movement establishes a
  product+store's first recorded balance; distinct from an adjustment, never used to correct one.
  Enforced here by construction — exactly one `opening` movement is written, at creation, per
  product, and `POST /stock-movements` never accepts `movement_type: 'opening'` at all (§1) so
  nothing can write a second one for the same product.
- [DR-007](../../03-functional-requirements/business-rules.md): an adjustment movement requires a
  `reason_code` drawn from a fixed, non-empty list; one without it is rejected before it is
  persisted. Enforced in the service layer (`ADJUSTMENT_REASON_REQUIRED`, §6) — matching
  `movement_type`'s own existing precedent of relying on application code, not a hand-edited
  Postgres `CHECK`, for this table (see §3). The fixed list, drawn from
  [WF-010](../../06-workflows/inventory-workflows.md#wf-010--record-a-stock-adjustment)/[GLOSSARY.md](../../GLOSSARY.md):
  `damage`, `expiry`, `loss_theft`, `count_correction`, `other`.
- `quantity_delta` for an adjustment must be non-zero — a zero-quantity "change" records nothing
  and isn't a real correction; enforced by Zod (§5). No sign restriction otherwise: an adjustment
  may raise or lower the balance (WF-010's own "enter quantity change", not "enter quantity loss").
- [DR-005](../../03-functional-requirements/business-rules.md): a sale is never blocked by
  insufficient recorded stock — the resulting balance may go negative, and does, without error or
  warning at this layer (a future stock-report concern, per
  [inventory.md](../../11-api/endpoints/inventory.md)'s own "why oversell is not an error here").
  The same non-blocking treatment applies to an adjustment that would take the balance negative —
  no code path in this sprint rejects a movement for what the *resulting* balance would be, only
  for what the movement *itself* is missing (a reason, on an adjustment).
- `quantity_delta` is signed: positive for `opening`/most adjustments correcting a shortfall,
  negative for `sale`/most adjustments correcting an overcount — the sign is caller-supplied and
  meaningful per movement, not fixed per type (except `opening`, which is always non-negative, and
  `sale`, which is always negative — both server-produced, never from this endpoint).
  `return` remains a schema-valid `movement_type` (the column has no `CHECK` constraint, matching
  `Sale.status`'s own precedent) but nothing anywhere in the system produces or accepts it yet —
  Returns is M3 scope (dependency-graph.md).
- A stock movement, once written, is immutable — by construction, the same reasoning
  [sales-invoices/specification.md §2](../sales-invoices/specification.md#2-business-rules) already
  used: no update/delete code path exists anywhere for `stock_movements`, this sprint included —
  `POST /stock-movements` only ever creates, and `GET /stock-movements` only ever reads.
- Both Sprint-11 writes remain transactional with their triggering row: `products.createProduct`
  fails entirely (no product, no movement) if the movement insert fails, and `pos.createSale`
  likewise fails entirely (no sale, no movements) if any movement insert fails — verified live
  (§10). `POST /stock-movements` (this sprint's own new write) has no triggering row of its own to
  be transactional with — it is the movement.

## 3. Database tables and relationships

`stock_movements`, a still-partial slice of [schema-server.md](../../07-database/schema-server.md)
Context 3. Implements as of this sprint: `id`, `tenant_id`, `store_id`, `product_id`,
`quantity_delta`, `movement_type`, `reason_code` (**added this sprint**), `reference_type`,
`reference_id`, `created_at`, `created_by`. **Still not built:**
`variant_id`/`batch_id`/`serial_number` (V2/V4 stubs, unchanged from Sprint 11). **Still deviates
from schema-server.md:** `device_id NOT NULL` remains omitted — the same M0-wide gap `sales`
already has (device registration isn't built — [module registry](../README.md), Authentication
row); still true this sprint, not newly found. `created_by` continues to substitute for attribution
here, matching every other table's own precedent (`products.created_by`, `sales.created_by`).

`reason_code` is `TEXT`, nullable at the column level — no Postgres `CHECK` constraint tying it to
`movement_type = 'adjustment'` (schema-server.md's own documented constraint), the same
application-code-not-CHECK precedent `movement_type` itself already established in this table
(§2, `ADJUSTMENT_REASON_REQUIRED`). No fixed-list `CHECK`/enum type either — the five reason values
(§2) are validated at the Zod layer (§5), matching `movement_type`'s own precedent again.

`quantity_delta` remains `INTEGER`, not schema-server.md's `NUMERIC(14,3)` — the same
fractional-quantity deferral `sale_line_items.quantity` already established
([pos/specification.md §3](../pos/specification.md#3-database-tables-and-relationships)) is still
true: Units' own `allows_fractional` flag (built M1 item 2) is not yet wired into any quantity field
anywhere in the system, stock movements included — named again here rather than assumed closed
just because Units itself now exists.

`products` gains no new column — `initial_quantity` (§4) is a request-only field, not stored on the
product row itself; it only ever produces a `stock_movements` row. Unchanged this sprint.

New index this sprint: `(tenant_id, store_id, created_at)` — the date-range list query (§4). The
`(tenant_id, store_id, product_id)` index (balance derivation) and RLS (tenant-scoped, same template
as `products`/`sales`,
[supabase/sql/006_rls_stock_movements.sql](../../../supabase/sql/006_rls_stock_movements.sql)) are
both unchanged from Sprint 11 — no new RLS policy is needed, `stock_movements` already has one.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/products`, `POST /api/v1/sales` | Unchanged since Sprint 11 — still the only paths producing `opening`/`sale` movements, server-side, in-transaction. |
| `POST /api/v1/stock-movements` | **Built this sprint.** Creates one `adjustment` movement (the only creatable type — §1). `id` (client-generated UUID, doubles as the idempotency key — upsert-on-id, same pattern as every other creation endpoint), `product_id`, `quantity_delta` (non-zero integer), `reason_code` (required). `store_id`/`created_by` resolved server-side, never accepted from the request — matching inventory.md's own stated principle. Response: `id`, `product_id`, `store_id`, `quantity_delta`, `movement_type`, `reason_code`, `reference_type` (`null`), `reference_id` (`null`), `created_at` — `created_by`/`device_id` are omitted from the response body, matching every other creation endpoint's own response shape in this codebase (`products`/`sales` responses omit them too; not a new deviation). |
| `GET /api/v1/stock-movements` | **Built this sprint.** Filters: `product_id`, `movement_type` (any of the four schema values, `opening` included — §1), `date_from`/`date_to` (ISO 8601, inclusive). Cursor-paginated on `(created_at, id)` — Tier 2, no `updated_at` column exists on this table (schema-server.md). |
| `GET /api/v1/products/{id}/stock-balance` | **Built this sprint.** Returns `{ product_id, store_id, balance }` — `balance` is the server-computed `SUM(quantity_delta)` for that product under the tenant's one store (ADR-0003), never a client-side sum of a locally cached movement list (inventory.md's own stated reasoning: a client's cache may be incomplete relative to other devices' synced movements). `404 NOT_FOUND` if `id` doesn't resolve to a product under the caller's tenant. |

No permission check beyond a valid tenant-scoped session on any of the three new endpoints —
Roles & Permissions (backlog.md item 7, deliberately last) doesn't exist yet, the same named scope
boundary every M1 module before it has used (`categories`, `units`, `products`). inventory.md's own
documented "Manager, Owner" permission column is not yet enforced anywhere in the code — a
continuing gap, closed only once item 7 retrofits every endpoint at once, not module-by-module.

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `initial_quantity` (on `POST /products`) | Unchanged since Sprint 11 — non-negative integer, optional, defaults to `0`. |
| `id` (on `POST /stock-movements`) | UUID v4 — Zod `.uuid()`. |
| `product_id` (on `POST /stock-movements`) | UUID v4, and must reference a product that exists under the caller's own tenant — `NOT_FOUND` otherwise (§6), the same tenant-scoped existence check `products`/`pos` already use for their own foreign references. |
| `quantity_delta` (on `POST /stock-movements`) | Non-zero integer — Zod `.int().refine((v) => v !== 0)`. |
| `movement_type` (on `POST /stock-movements`) | Zod `.enum(["adjustment", "sale", "return"])` — deliberately excludes `opening` (§1); `sale`/`return` pass schema validation but are rejected at the service layer (`DIRECT_SALE_MOVEMENT_FORBIDDEN`, §6), not at the schema layer, so the client gets the specific named business error inventory.md documents rather than a generic `VALIDATION_FAILED`. |
| `reason_code` (on `POST /stock-movements`) | Optional at the schema layer — Zod `.enum(["damage","expiry","loss_theft","count_correction","other"]).optional()`; required *when `movement_type = 'adjustment'`*, enforced in the service layer (`ADJUSTMENT_REASON_REQUIRED`, §6), not by Zod's own conditional validation, matching DR-007's own "rejected before it is persisted" framing without needing a Zod discriminated union for a single dependent field. |
| `product_id`/`movement_type`/`date_from`/`date_to`/`cursor`/`limit` (on `GET /stock-movements`) | All optional; `movement_type` — Zod `.enum(["opening","sale","return","adjustment"])` (all four, §1); dates — Zod `.string().datetime()`; `limit` — same `.int().positive().max(200).default(50)` convention as every other list endpoint. |

No new validation on `POST /sales` — every stock movement it produces is derived entirely from
already-validated line items (§4/§5 of [pos/specification.md](../pos/specification.md)), never from
new input.

## 6. Error handling and user-facing messages

| Code | HTTP | Cause |
| --- | --- | --- |
| `ADJUSTMENT_REASON_REQUIRED` | 422 | `movement_type = 'adjustment'` submitted without `reason_code` (DR-007) — already reserved in [error-catalogue.md](../../11-api/error-catalogue.md), implemented this sprint. |
| `DIRECT_SALE_MOVEMENT_FORBIDDEN` | 403 | `movement_type` of `sale` or `return` submitted to `POST /stock-movements` directly — already reserved, implemented this sprint. **Not** raised for `movement_type = 'opening'`, which is excluded at the schema layer instead (§1, §5) and surfaces as ordinary `VALIDATION_FAILED`. |
| `NOT_FOUND` | 404 | `product_id` (on `POST /stock-movements`) or `id` (on `GET .../stock-balance`) doesn't resolve to a product under the caller's tenant — the existing cross-tenant-safe `NOT_FOUND` convention, not a new code. |
| `VALIDATION_FAILED` | 422 | Any Zod failure on either endpoint's request shape, per §5 — including a zero `quantity_delta` and a `movement_type: 'opening'` attempt. |

No new failure mode on `POST /products`/`POST /sales` — unchanged since Sprint 11, a stock movement
produced by either is never independently rejectable; it either commits with its triggering row or
the whole transaction rolls back.

## 7. Offline behaviour

`POST /api/v1/products`/`POST /api/v1/sales` are unchanged (§7 as written in Sprint 11 — both
currently require connectivity; no mobile offline queue path pushes either yet). The three
endpoints built this sprint are **online-only, server-side capabilities with no mobile consumer
yet** — no mobile screen calls `POST`/`GET /stock-movements` or `GET .../stock-balance` this sprint
(§9); when a mobile adjustment/balance screen is eventually built, it will need the same
online-only-write, local-cache-read split `categories`/`units` already established
([modules/categories/specification.md §7](../categories/specification.md#7-offline-behaviour)), not
a new pattern — named here so that future sprint isn't surprised by it.

## 8. Realtime behaviour

None specified for V1 in this sprint's scope — no requirement found for live balance push to other
devices. `GET /products/{id}/stock-balance` (now built) is the read path; it is polled on demand,
not pushed.

## 9. UI specification

None this sprint — no mobile screen is built or changed, matching this sprint's own scope (§1): the
public endpoints are built and tested, but not yet consumed by any mobile screen, the same
"documented capability, not yet a built feature" position `GET /products` itself was left in after
Sprint 21. `/catalogue/inventory/opening-stock` (route-map.md, WF-009's dedicated screen) remains
unbuilt, deferred past this sprint too.

## 10. Test plan

**Sprint 11 scope (unchanged, still passing):** see the Sprint 11 items below.

**Sprint 22 scope:**
- Unit tests (`stock-movements/service.test.ts`): `movement_type: 'opening'` rejected as
  `VALIDATION_FAILED` at the schema layer; `movement_type: 'sale'`/`'return'` rejected as
  `DIRECT_SALE_MOVEMENT_FORBIDDEN`; `movement_type: 'adjustment'` without `reason_code` rejected as
  `ADJUSTMENT_REASON_REQUIRED`; unknown `product_id` rejected as `NOT_FOUND`; a valid adjustment
  resolves `store_id`/`created_by` server-side and passes them to the repository; `listStockMovements`
  passes filters through and applies the peek-and-trim cursor pattern; `getStockBalance` resolves
  the tenant's store and returns the repository's summed balance; unknown product for the balance
  endpoint rejected as `NOT_FOUND`.
- **Live verification, real database, throwaway tenants (deleted after) — 9/9 checks passed:**
  1. `POST /stock-movements` with `movement_type: 'adjustment'`, `reason_code: 'damage'`,
     `quantity_delta: -2` → `201`, correct `store_id`, `reason_code` persisted.
  2. The same request replayed (identical `id`) → still exactly one row (idempotent).
  3. `movement_type: 'adjustment'` with no `reason_code` → `422 ADJUSTMENT_REASON_REQUIRED`.
  4. `movement_type: 'sale'` → `403 DIRECT_SALE_MOVEMENT_FORBIDDEN`.
  5. `movement_type: 'opening'` → `422 VALIDATION_FAILED` (excluded at the schema layer, §1).
  6. `GET /products/{id}/stock-balance` after opening (10) + the adjustment above (-2) → `balance: 8`.
  7. `GET /stock-movements?movement_type=adjustment` → returns exactly the adjustment row, not the
     product's own `opening` row.
  8. `GET /stock-movements?product_id=<other product>` → zero rows.
  9. Cross-tenant RLS: tenant B's session reads zero of tenant A's `stock_movements` rows via
     PostgREST directly, and `POST /stock-movements` for tenant A's `product_id` from tenant B's
     session returns `404 NOT_FOUND`.

**Explicitly deferred:** WF-009's own dedicated opening-stock screen, any mobile UI for
adjustments/balance viewing, `device_id` attribution, Roles & Permissions enforcement (item 7).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-040](../../03-functional-requirements/functional-requirements.md) (setting an initial quantity records a single, dated opening-stock entry) | §2, §10 | **Partially met** — unchanged since Sprint 11; still no dedicated UI/endpoint for a Manager to *set* a nonzero quantity after the fact (WF-009) |
| [FR-043](../../03-functional-requirements/functional-requirements.md) (a stock adjustment cannot be saved without a reason) | §2, §5, §6, §10 | Met — proven live (`ADJUSTMENT_REASON_REQUIRED`) |
| [FR-044](../../03-functional-requirements/functional-requirements.md) (an adjustment is a new ledger entry, never a modification of an existing one) | §2 | Met — no update/delete code path exists |
| [DR-005](../../03-functional-requirements/business-rules.md) (sale/adjustment never blocked by insufficient stock) | §2, §10 | Met — proven live against a real oversell (Sprint 11) and extended to adjustments (§2) |
| [DR-006](../../03-functional-requirements/business-rules.md) (opening establishes first balance, distinct from adjustment) | §1, §2, §3 | Met — reinforced this sprint by excluding `opening` from `POST /stock-movements` entirely |
| [DR-007](../../03-functional-requirements/business-rules.md) (adjustment requires a reason from a fixed list) | §2, §5, §6, §10 | Met |
| [milestones.md — M0 exit criterion](../../16-milestones/milestones.md#m0--walking-skeleton) (stock ledger: one opening, one sale movement, present and correct) | §10 | Met (Sprint 11, unchanged) |
| [inventory.md](../../11-api/endpoints/inventory.md) (`POST`/`GET /stock-movements`, `GET .../stock-balance`) | §4, §10 | Met, with the `opening`-exclusion deviation named in §1 |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | First version — written to drive Sprint 11's minimal opening/sale stock-movement writes (backlog.md item 7). Scope deliberately narrow: no adjustment workflow, no public stock-movement endpoints, no mobile UI; `device_id` omitted (M0-wide gap, matching `sales`), `created_by` substituted for attribution. |
| 0.2.0 | 2026-08-14 | Sprint 22 (backlog.md item 6): built `adjustment`/`reason_code`, `POST`/`GET /api/v1/stock-movements`, `GET /api/v1/products/{id}/stock-balance`. Design decision found while writing this spec: `POST /stock-movements` excludes `movement_type: 'opening'` entirely (not just rejects it with a business error) since every product already gets one automatically at creation and no live workflow needs a second, client-initiated write — corrections use `adjustment`/`count_correction` instead, per WF-009's own stated reversal path. `device_id`/mobile UI/Roles enforcement remain named, continuing gaps, not newly found. |
