# Module Specification — Customers (basic)

> **Status:** 🟢 Approved
> **Module:** Customers (basic)
> **Slice:** V1, minimal — `customers` table, `sales.customer_id`, `POST`/`GET`/`PATCH`/`DELETE
> /customers`, `GET /customers/{id}/purchase-history`. Mobile UI, offline queuing, and the
> conflict-resolution field-merge policy are separate, later backlog items (§1).
> **Version:** 0.2.0
> **Last updated:** 2026-08-16
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 31](../../17-sprints/sprint-31.md) — specification before code, per
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

**Scope explicitly not in this sprint, named rather than silently dropped:** mobile UI (item 2);
`customer.create`/`customer.update` sync-push operation types and offline queuing (items 2 and 5);
the conflict-resolution field-merge policy itself (item 5) — this sprint's `PATCH /customers/{id}` is
a plain last-write-wins online update, no base-`updated_at` comparison, since no concurrent-offline-
edit caller exists yet to make a merge policy meaningful. Building it now would be exactly the kind
of speculative abstraction this project's own practice avoids — see
[backlog.md §4](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)'s
own reasoning for why item 5 is scoped separately.

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

**Not built this sprint**, named explicitly rather than silently absorbed: `customers.md` documents
every write endpoint here as offline-queued, but no `customer.create`/`customer.update` sync-push
operation type exists yet in `sync/schema.ts`'s operation union — same "table/endpoint exists, sync
integration is a separate, later item" shape Categories/Units/Trading Day's own online-only-creation
precedent already established. `customer.create` is [backlog.md M3 item 2](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)'s
scope (paired with the mobile UI that actually produces the offline-created rows); `customer.update`
is item 5's scope specifically, since it's also this project's first `.update` operation type of any
kind and needs the field-merge policy, not just a bare upsert. `GET` endpoints are read-cached like
every other read endpoint once a mobile caller exists (none does yet this sprint).

## 8. Realtime behaviour

None specified for V1 — no requirement found for a live push when a customer record changes on
another device. Matches every other module's own precedent (Roles & Permissions, Settings, Trading
Day): the next request re-resolves state fresh, no cross-session push.

## 9. UI specification

None this sprint — every endpoint built is called only by throwaway live-verification scripts so
far, the same position Trading Day's own spec (§9) recorded for its first sprint. `/customers` and
`/customers/:id` already have route-level entries in
[route-map.md](../../09-navigation/route-map.md) (Cashier+, offline yes) from the original V1 route
decomposition, but no screen exists yet — that's [backlog.md M3 item 2](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point).

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

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| FR-050 (inline capture during checkout) | §4 (`POST /customers`) | Server half met; mobile checkout wiring is item 2 |
| FR-051 (purchase history on profile) | §2, §4, §10 | Met |
| FR-052 (phone-match-as-you-type search) | §4 (`GET /customers?phone=`) | Server half met; mobile as-you-type UI is item 2 |
| FR-062 (return lookup by customer phone) | §3 (phone index), §4 | Server half met; consumed by [backlog.md M3 item 3/4](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point) (Returns) |
| [permission-matrix.md — Customers](../../05-personas/permission-matrix.md#customers) | §4 | View/add/purchase-history met; edit/deactivate rows were missing from that matrix entirely — added in this same PR as a dated correction, matching this sprint's own decisions (PATCH: Cashier+, DELETE: Manager/Owner) |
| `customers.md`'s offline-queued write endpoints | §7 | **Not met this sprint, named explicitly** — no sync push-operation type yet (items 2, 5) |
| Conflict-resolution field-merge (conflict-resolution.md) | — | **Not in this sprint's scope, named explicitly** — [backlog.md M3 item 5](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | First version — written to drive Sprint 31's implementation of Customers (backlog.md M3 item 1): `customers` table, `sales.customer_id` (nullable), `POST`/`GET`/`PATCH`/`DELETE /customers`, `GET /customers/{id}/purchase-history`. No design gap found — customers.md/schema-server.md/FR-050-052 were already fully fixed. Mobile UI, offline queuing, and the conflict-resolution merge policy are explicitly out of scope, named for M3 items 2 and 5. |
| 0.2.0 | 2026-08-16 | Built and live-verified (12/12). Found and fixed a real bug live: a Zod `.refine()` for "at least one of name/phone" always returned the generic `VALIDATION_FAILED` instead of the documented `CUSTOMER_IDENTIFIER_REQUIRED` — removed in favour of the service-layer check that already existed, §5. Permission matrix's missing edit/deactivate rows corrected in the same PR (§11). |
