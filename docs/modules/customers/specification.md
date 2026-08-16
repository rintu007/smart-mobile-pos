# Module Specification — Customers (basic)

> **Status:** 🟢 Approved
> **Module:** Customers (basic)
> **Slice:** V1, minimal — `customers` table, `sales.customer_id`, `POST`/`GET`/`PATCH`/`DELETE
> /customers`, `GET /customers/{id}/purchase-history` (Sprint 31); `customer.create` sync-push,
> `POST /sales` accepting `customer_id`, and the mobile UI (Sprint 32). Conflict-resolution
> field-merge remains a separate, later backlog item (§1).
> **Version:** 0.3.0
> **Last updated:** 2026-08-16
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 31](../../17-sprints/sprint-31.md); extended (§1a and throughout) to drive
[Sprint 32](../../17-sprints/sprint-32.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

[backlog.md M3 item 1](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point):
the server half of Customers — the smallest module in this API, deliberately
([customers.md](../../11-api/endpoints/customers.md)'s own framing: name, phone, purchase lookup,
not a full CRM). This is the first M3 item; M2's own closure ([Sprint 30](../../17-sprints/sprint-30.md))
left M3 fully decomposed but unstarted.

**Everything this spec needs was already fully fixed in Phases 03/07/11** —
[customers.md](../../11-api/endpoints/customers.md), the `customers` table in
[schema-server.md Context 4](../../07-database/schema-server.md), and FR-050/051/052 all predate
this sprint unchanged. No design gap was found writing this spec, the same "not every sprint needs
one" honesty [sprint-29.md](../../17-sprints/sprint-29.md) already modelled for Split Payment — worth
stating plainly rather than manufacturing a gap-hunt where none exists.

**One real decision made now, at planning time, not previously written down anywhere:** `sales`
already has a `customer_id` column documented in schema-server.md's Context 5 (`sales`) — this sprint
adds it as **nullable**, matching every other post-M0 `sales` column addition's own precedent
(`trading_day_id`, `canonical_invoice_number`), since a customer is optional on a sale
(FR-050/customers.md never require one) and there is no existing data to backfill regardless. `POST
/sales` itself is **not** extended to accept `customer_id` in this sprint — that belongs to
[backlog.md M3 item 2](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)
(the mobile checkout-flow wiring that actually produces a customer selection to send), the same
"column exists and is populated by every code path that can populate it, but nothing populates it
yet" shape [trading-day/specification.md §1](../trading-day/specification.md#1-purpose-and-business-context)
already established for `trading_day_id`. Building the column with no caller is still correct
groundwork, not speculative — item 2 depends on it existing.

**Scope explicitly not in Sprint 31, named rather than silently dropped:** mobile UI (item 2);
`customer.create`/`customer.update` sync-push operation types and offline queuing (items 2 and 5);
the conflict-resolution field-merge policy itself (item 5) — Sprint 31's `PATCH /customers/{id}` is
a plain last-write-wins online update, no base-`updated_at` comparison, since no concurrent-offline-
edit caller exists yet to make a merge policy meaningful. Building it now would be exactly the kind
of speculative abstraction this project's own practice avoids — see
[backlog.md §4](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)'s
own reasoning for why item 5 is scoped separately.

## 1a. Sprint 32 — Customers (mobile), M3 item 2

[Sprint 31](../../17-sprints/sprint-31.md) built and named exactly what item 2 needs: the
`customer_id` column with no caller, and no `customer.create` sync-push type. This sprint closes
both, plus the mobile UI itself.

**`customer.create` reuses the `product.create` shape exactly, not a new pattern.** Mobile's
`DriftCustomerRepository.createCustomer` writes the local `customers` row and enqueues a
`customer.create` `outbound_queue` entry in the same transaction — identical to
`DriftProductRepository.createProduct`'s own established shape (Sprint 07), not Categories/Units'
online-only-direct-call shape, since `customers.md` documents `POST /customers` as genuinely
offline-queued, unlike `POST /categories`/`POST /units`. `sync/service.ts` gains `customer.create`
in its `TYPE_ORDER` and dispatch, calling `customersService.createCustomer` unchanged — sync-api.md
§1's "push does not define a second, parallel request schema" rule, held exactly as every prior
operation type has held it.

**`POST /sales` gains an optional `customer_id`, validated server-side against the caller's own
tenant if supplied** — the same tenant-scoped existence check `products/service.ts` already
established for `category_id`/`unit_id`: an invalid/foreign-tenant value is rejected with the
already-generic `NOT_FOUND`, matching that exact precedent rather than inventing a new
per-field error code for what is already a well-established shape.

**Reads stay direct-fetch-and-cache, not a new sync-pull cursor.** FR-052's "matched against the
locally cached customer list" needs a local cache warm enough to search offline, but building a
full bidirectional `GET /sync/pull?entity_type=customers` cursor mechanism for a single new read
path is real, undiscussed scope disproportionate to what this item needs. Mirrors Categories/Units'
own `refreshFromServer()` shape instead (Sprint 20): a direct `GET /customers` call populates/
refreshes the local cache, `listAll()`/`searchByPhone()` then query that cache offline. Purchase
history (`GET /customers/{id}/purchase-history`) is fetched live, on demand, with no local cache at
all — the same shape `sales-history`'s own detail screen already established for read-through data
that doesn't need offline availability for a feature (FR-051's own offline classification) whose
primary use is "look this customer up while online, at the till."

**Capture is a bottom sheet over the till screen, not a route push — FR-050's own wording, taken
literally.** "captured inline during checkout without leaving the sale screen" is a real UI
constraint, not just a data-shape one: the till screen gains a Customer chip (next to Hold, in the
same row) opening a modal `CustomerPickerSheet` — phone-as-you-type search against the local cache,
tap a match to attach it to the active cart, or (no match) an inline two-field form that creates
and attaches in the same action. `/customers` and `/customers/:id` remain full routes for the
separate browse/purchase-history use case (reached via a new `pos_customers_button` app-bar icon,
the same entry-point shape Hold/Resume's own `pos_held_carts_button` established in Sprint 30) —
two distinct entry points for two distinct jobs, not one screen serving both awkwardly.

**The active cart's attached customer survives hold/resume**, the same durability guarantee
[FR-026](../../03-functional-requirements/functional-requirements.md) already requires for line
items (Sprint 30) — `CartState` gains `customerId`/`customerName`/`customerPhone`, persisted on the
local `sales` draft row alongside the cart's other fields, restored on resume.

## 2. Business rules

- **A customer record needs at least one of `name`/`phone`** — `CUSTOMER_IDENTIFIER_REQUIRED`
  otherwise, so a record is never created with no way to ever look it up again
  ([customers.md](../../11-api/endpoints/customers.md)).
- **`phone` is unique per tenant among active (non-deactivated) customers** —
  `(tenant_id, phone) WHERE deactivated_at IS NULL`, per schema-server.md. `PATCH` can collide with
  this same constraint (moving a customer's phone onto one already assigned elsewhere), not only
  `POST`.
- **Soft delete only.** `DELETE /customers/{id}` sets `deactivated_at`, never removes the row —
  `sales.customer_id` is `ON DELETE SET NULL`-safe regardless, but the historical sale record must
  never be blocked or altered by a later customer-record change
  ([customers.md](../../11-api/endpoints/customers.md), BR-030's immutability principle extended to
  the referencing side).
- **Deactivating an already-deactivated customer is an idempotent no-op** — returns the existing
  deactivated state unchanged, the same idempotent-state-transition stance
  [roles/service.ts's `deactivateUser`](../../../apps/web/src/modules/roles/service.ts) already
  established for the structurally identical `users.deactivated_at` case.
- **`GET /customers` excludes deactivated customers by default** (an inactive customer shouldn't
  resurface in checkout search or return-lookup) — no query parameter to include them this sprint;
  named as a small, deliberate simplification, not a documented requirement either way.
- **Purchase history only ever lists `sales` with `status = 'completed'`** — a draft/held sale is
  never attributable to a customer's history, matching FR-051's "prior *completed* sales" wording
  exactly.

## 3. Database tables and relationships

New table: `customers`, matching schema-server.md's documented shape exactly: `id`, `tenant_id`,
`name` (nullable), `phone` (nullable), `deactivated_at` (nullable), plus the standard
`created_at`/`updated_at`/`created_by`. `updated_at` is included even though schema-server.md's own
column list doesn't name it explicitly — every other Client-editable, PATCH-capable Tier 1 table
(`shop_settings`) already carries one, and [backlog.md M3 item 5](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)'s
conflict-resolution merge policy needs it to exist as a real column later — adding it now avoids a
second migration purely to bolt it on.

Index: `(tenant_id, phone) WHERE deactivated_at IS NULL` (unique) — the return-by-phone lookup
(FR-062) and inline checkout search (FR-052), and the actual mechanism behind §2's uniqueness rule.

`sales` gains `customer_id` — nullable `UUID REFERENCES customers(id) ON DELETE SET NULL`, matching
schema-server.md's own documented `ON DELETE SET NULL` exactly (the one FK in this sprint that
*isn't* `RESTRICT`, since a sale must survive its customer's later removal, per §1/§2).

RLS: tenant-scoped, same template as every other table
([supabase/sql/014_rls_customers.sql](../../../supabase/sql/014_rls_customers.sql)).

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/customers` | **Built this sprint.** Cashier, Manager, Owner. `id` (client-generated UUIDv4, creation-style idempotency — matches `products`/`categories`'s own upsert-on-id pattern), `name`/`phone` (at least one required). |
| `GET /api/v1/customers` | **Built this sprint.** Any authenticated role. Filter: `phone` (exact match). Cursor-paginated on `(updated_at, id)`, matching `products`'s own convention. Excludes deactivated customers (§2). |
| `PATCH /api/v1/customers/{id}` | **Built this sprint.** Cashier, Manager, Owner. Partial update (`name`/`phone`), plain last-write-wins (§1). |
| `DELETE /api/v1/customers/{id}` | **Built this sprint.** Manager, Owner only. Soft delete (§2), idempotent. |
| `GET /api/v1/customers/{id}/purchase-history` | **Built this sprint.** Any authenticated role. Cursor-paginated `sales` for this customer, `status = 'completed'` only (§2), ordered `(completed_at, id)` desc. |
| `POST /api/v1/sales` | **Extended Sprint 32.** `customer_id` accepted as an optional field, per §1a. When supplied, must resolve to a real `customers` row under the caller's tenant (`NOT_FOUND` otherwise) — deactivated customers are still valid targets (§2's soft-delete stance: a deactivated customer can still complete a sale in progress, only future *lookup* excludes them). |
| `POST /api/v1/sync/push` (`customer.create`) | **Built Sprint 32** — §1a. Dispatches to the same `customersService.createCustomer` `POST /customers` already calls, per sync-api.md §1. |

Route files: `customers/route.ts` (POST, GET — a static top-level file, no dynamic sibling risk),
`customers/[id]/route.ts` (PATCH, DELETE), `customers/[id]/purchase-history/route.ts` — applying
Sprint 23/24's own static-vs-dynamic routing lesson proactively from the start, same as Trading Day.

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `id` (create) | UUID v4 — Zod `.uuid()`. |
| `name` | `.string().trim().min(1).max(200).optional()`. |
| `phone` | `.string().trim().min(1).max(20).optional()`. At least one of `name`/`phone` enforced via `.refine()`, not per-field — `CUSTOMER_IDENTIFIER_REQUIRED` on violation. |
| `phone` (query filter) | `.string().trim().min(1).max(20).optional()`. |
| PATCH body | Same `name`/`phone` shapes, both optional independently — a `PATCH` with neither field present is a no-op, not an error (matches `PATCH /settings`'s own partial-update stance). |

**A real bug found live (Sprint 31's own verification script), not by inspection:** the "at least
one of name/phone" rule was first written as a Zod `.refine()` on `createCustomerRequestSchema`,
following [pos/schema.ts](../../../apps/web/src/modules/pos/schema.ts)'s own precedent for the
mutually-exclusive discount fields. Live-testing surfaced the difference that precedent didn't
share: a `.refine()` failure is indistinguishable from any other shape violation at the Route
Handler's `safeParse` boundary, so the endpoint always returned the generic `VALIDATION_FAILED` —
never the specific `CUSTOMER_IDENTIFIER_REQUIRED` [customers.md](../../11-api/endpoints/customers.md)
names for exactly this condition. Discount's own `.refine()` has no named code to preserve, so the
precedent held there; this rule does, so it doesn't transfer. Fixed by removing the `.refine()`
entirely and relying solely on `service.ts`'s `assertHasIdentifier()`, matching this codebase's own
"business rules live in the service layer, not the Route Handler" convention
([backend-structure.md §2](../../08-folder-structure/backend-structure.md)) for any rule that needs
a specific, documented error code.

## 6. Error handling and user-facing messages

| Code | HTTP | Cause |
| --- | --- | --- |
| `CUSTOMER_IDENTIFIER_REQUIRED` | 422 | Already reserved (error-catalogue.md). Both `name` and `phone` omitted on create, or a PATCH would leave both null. |
| `PHONE_ALREADY_ASSIGNED` | 409 | Already reserved. The `(tenant_id, phone) WHERE deactivated_at IS NULL` unique index's `P2002`, translated — on create or on a PATCH that moves `phone` onto an already-assigned value. |
| `NOT_FOUND` | 404 | `PATCH`/`DELETE`/purchase-history target an `id` that doesn't exist under the caller's tenant. |
| `PERMISSION_DENIED` | 403 | `DELETE` called by a Cashier. |
| `VALIDATION_FAILED` | 422 | Any Zod failure. |

## 7. Offline behaviour

**`POST /customers` is now genuinely offline-capable (Sprint 32)**, per §1a: local write +
`outbound_queue` enqueue, atomic in one Drift transaction, drained by the existing sync trigger
(Sprint 14) with no changes needed there. `customer.update` remains **not built** — item 5's scope
specifically, since it's also this project's first `.update` operation type of any kind and needs
the field-merge policy, not just a bare upsert; mobile has no customer-edit screen this sprint
either, so there is still no real caller for it. `GET /customers`/`GET /customers/{id}/purchase-history`
are not sync-pulled (§1a's direct-fetch-and-cache decision) — the local `customers` cache is
refreshed via a direct online call, offline search works against whatever was last fetched, the
same staleness shape Categories/Units already established.

## 8. Realtime behaviour

None specified for V1 — no requirement found for a live push when a customer record changes on
another device. Matches every other module's own precedent (Roles & Permissions, Settings, Trading
Day): the next request re-resolves state fresh, no cross-session push.

## 9. UI specification

**Built Sprint 32**, per §1a:

- **`CustomerPickerSheet`** — a modal bottom sheet launched from a new `pos_customer_chip` on the
  till screen (next to `pos_hold_button`), showing "Add customer" when the cart has none attached,
  or the attached customer's name/phone when it does. Phone-as-you-type search (`pos_customer_search`
  field) against the local cache; tapping a result attaches it (`pos_customer_result_<id>`); an
  inline two-field form (`pos_customer_new_name`/`pos_customer_new_phone`, a
  `pos_customer_create_button`) creates-and-attaches when no result matches. Closing the sheet
  without a selection leaves the cart's existing attachment (or lack of one) unchanged.
- **`CustomersScreen`** (`/customers`) — reached via a new `pos_customers_button` app-bar icon on
  the till screen, the same entry-point shape `pos_held_carts_button` established. Search field,
  scrollable result list (`customers_list`, rows keyed `customers_row_<id>`), empty state
  (`customers_empty`). Not a select flow — tapping a row navigates to detail.
- **`CustomerDetailScreen`** (`/customers/:id`) — name/phone header, purchase history list
  (`customer_history_list`, fetched live per §1a, empty state `customer_history_empty`).

Tablet/phone: single-column list + sheet, no distinct tablet layout needed — matches every other
V1 screen's own precedent (no module has needed one yet).

**FR-050's "without leaving the sale screen," checked against
[tap-count-audit.md](../../09-navigation/tap-count-audit.md)'s standard, not previously verified
numerically:** attaching an *existing* customer from the sheet is tap chip → tap search result (2
taps), the same order of magnitude as WF-003's own audited discount flow (5 steps including a typed
amount, per that row's own count). Creating a *new* customer inline (tap chip → type phone → tap
create) is comparable in shape — a typed field plus a confirming tap, not a new tap-count category
this document's existing rows don't already cover.

## 10. Test plan

- Unit tests (`customers/service.test.ts`): `createCustomer` — creates with only `name`, only
  `phone`, or both; rejects both-omitted with `CUSTOMER_IDENTIFIER_REQUIRED`; translates the phone
  unique-constraint violation to `PHONE_ALREADY_ASSIGNED`; a replayed `id` is an idempotent no-op
  (same shape `createProduct`'s own upsert-on-id test already covers). `updateCustomer` — partial
  update of `name` only, `phone` only, or both; a PATCH that would leave both fields null is rejected
  the same way creation is; translates a phone collision the same way creation does; a PATCH on a
  nonexistent `id` is `NOT_FOUND`. `deactivateCustomer` — sets `deactivated_at`; idempotent replay on
  an already-deactivated customer; `NOT_FOUND` on a nonexistent `id`. `listCustomers` — filters by
  exact `phone`; excludes deactivated customers; cursor pagination round-trips correctly (peek-and-
  trim, same pattern as `listProducts`). `getPurchaseHistory` — only `status = 'completed'` sales
  returned, ordered `(completed_at, id)` desc; `NOT_FOUND` on a nonexistent customer `id`.
- **Live verification, real database, throwaway tenant (deleted after):**
  1. `POST /customers` with only `phone` → `201`.
  2. `POST /customers` with neither `name` nor `phone` → `422 CUSTOMER_IDENTIFIER_REQUIRED`.
  3. A second `POST /customers` with the same `phone` (different `id`) → `409 PHONE_ALREADY_ASSIGNED`.
  4. `GET /customers?phone=<the number>` → the created customer, exact match.
  5. `PATCH /customers/{id}` with a new `name` → `200`, `phone` unchanged.
  6. `PATCH /customers/{id}` moving `phone` onto a second, already-assigned customer's phone → `409
     PHONE_ALREADY_ASSIGNED`.
  7. A completed sale created with this customer's `id` directly against the database (no `POST
     /sales` change this sprint — §1), then `GET /customers/{id}/purchase-history` → the sale
     appears; a draft/held sale for the same customer does not.
  8. `DELETE /customers/{id}` as a Cashier → `403 PERMISSION_DENIED`; as the Owner → `200`,
     `deactivated_at` set; a second `DELETE` → identical response, idempotent.
  9. `GET /customers` after step 8 → the deactivated customer is excluded.
  10. Cross-tenant RLS: tenant B's `GET /customers` never resolves to tenant A's customer.

**Sprint 32 additions:**

- Unit tests: `pos/service.test.ts` — `createSale` accepts a valid `customer_id` and links it;
  rejects one that doesn't exist under the caller's tenant with `NOT_FOUND`; a sale with no
  `customer_id` is unchanged from before. `sync/service.test.ts` — `customer.create` dispatches to
  `customersService.createCustomer`; a validation failure is rejected the same way `product.create`'s
  own bad-payload case already is.
  `drift_customer_repository_test.dart` (real in-memory Drift DB): `createCustomer` writes the
  local row and an `outbound_queue` entry atomically (the same multi-row atomicity proof
  `drift_product_repository_test.dart` already established); `searchByPhone` matches a partial
  prefix; `refreshFromServer` upserts without duplicating.
- **Live verification, real database:** `POST /sales` with a valid `customer_id` links it, visible
  in the customer's own `purchase-history`; an invalid `customer_id` → `404 NOT_FOUND`; a sync-push
  batch containing a `customer.create` operation creates the row exactly as the direct endpoint
  would, confirmed via a follow-up `GET /customers?phone=`.
- **Mobile:** `flutter analyze`/`flutter test` — `CustomerPickerSheet` attaches an existing customer
  to the active cart, or creates-and-attaches a new one; `CustomersScreen` search filters the local
  list; `CustomerDetailScreen` renders purchase history; hold-then-resume preserves the attached
  customer.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| FR-050 (inline capture during checkout) | §4 (`POST /customers`), §1a/§9 (mobile picker sheet) | Met (Sprint 32) |
| FR-051 (purchase history on profile) | §2, §4, §9, §10 | Met |
| FR-052 (phone-match-as-you-type search) | §4 (`GET /customers?phone=`), §1a/§9 (mobile local-cache search) | Met (Sprint 32) |
| FR-062 (return lookup by customer phone) | §3 (phone index), §4 | Server half met; consumed by [backlog.md M3 item 3/4](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point) (Returns) |
| FR-026 (durability guarantee, extended to the attached customer) | §1a | Met (Sprint 32) — survives hold/resume |
| [permission-matrix.md — Customers](../../05-personas/permission-matrix.md#customers) | §4 | View/add/purchase-history met; edit/deactivate rows were missing from that matrix entirely — added Sprint 31 as a dated correction |
| `customers.md`'s offline-queued write endpoints | §7 | `POST /customers` met (Sprint 32, `customer.create`); `PATCH` remains not met, named for M3 item 5 |
| Conflict-resolution field-merge (conflict-resolution.md) | — | **Not in this sprint's scope, named explicitly** — [backlog.md M3 item 5](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | First version — written to drive Sprint 31's implementation of Customers (backlog.md M3 item 1): `customers` table, `sales.customer_id` (nullable), `POST`/`GET`/`PATCH`/`DELETE /customers`, `GET /customers/{id}/purchase-history`. No design gap found — customers.md/schema-server.md/FR-050-052 were already fully fixed. Mobile UI, offline queuing, and the conflict-resolution merge policy are explicitly out of scope, named for M3 items 2 and 5. |
| 0.2.0 | 2026-08-16 | Built and live-verified (12/12). Found and fixed a real bug live: a Zod `.refine()` for "at least one of name/phone" always returned the generic `VALIDATION_FAILED` instead of the documented `CUSTOMER_IDENTIFIER_REQUIRED` — removed in favour of the service-layer check that already existed, §5. Permission matrix's missing edit/deactivate rows corrected in the same PR (§11). |
| 0.3.0 | 2026-08-16 | §1a added — written to drive Sprint 32 (M3 item 2, Customers mobile): `customer.create` sync-push (reusing `product.create`'s exact shape), `POST /sales` accepting an optional `customer_id`, and the mobile UI itself — `CustomerPickerSheet` (a bottom sheet, per FR-050's own "without leaving the sale screen" wording taken literally) plus full `/customers`/`/customers/:id` routes for browsing. Reads stay direct-fetch-and-cache (Categories/Units' own shape), not a new sync-pull cursor — named as a deliberate, disciplined scope boundary. |
