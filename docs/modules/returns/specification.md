# Module Specification — Returns & Refund

> **Status:** 🟢 Approved
> **Module:** Returns & Refund
> **Slice:** V1 — server half (Sprint 33, backlog.md M3 item 3): `returns`/`return_line_items`
> tables, `POST /returns`, `GET /returns/{id}`/`GET /returns`/`GET /returns/approvals`,
> `POST /returns/{id}/approve`/`reject`, the `return` stock movement,
> `return.create`/`return.approve`/`return.reject` sync-push operation types. Mobile UI (Sprint 34,
> backlog.md M3 item 4, §1b): local `returns`/`return_line_items` tables + outbound-queue enqueue,
> `/returns/new`/`/returns/:id`/`/returns/approvals`.
> **Version:** 0.2.0
> **Last updated:** 2026-08-16
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 33](../../17-sprints/sprint-33.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1. Extended (§1b and throughout) to drive
[Sprint 34](../../17-sprints/sprint-34.md).

---

## 1. Purpose and business context

[backlog.md M3 item 3](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point):
the server half of Returns & Refund — WF-012 (process a return) and WF-013 (approve a high-value
return), per [returns-workflows.md](../../06-workflows/returns-workflows.md) and
[returns.md](../../11-api/endpoints/returns.md), both fixed since Phase 06/11 and unchanged by this
sprint. This is M3's third item, depending only on item 1 (Customers, server) per the
`Customers → Returns` graph edge backlog.md §4 traced to WF-012 step 1's phone-lookup path — a
mobile-flow dependency, not a server-schema one (`returns` carries no FK to `customers`).

**Real gaps found while writing this spec, not by writing code first:**

1. **`returns` has no `created_by` column in schema-server.md's Context 6 table.**
   [returns.md](../../11-api/endpoints/returns.md)'s own permission column requires
   `GET /returns` to scope a Cashier to "own device only" — the same adaptation
   [sales-invoices/specification.md](../sales-invoices/specification.md) already made for `GET /sales`
   (no `devices` table exists, so "own device" becomes "own `created_by`"). That scoping is
   impossible without a column recording who filed the return. Resolved here as a dated correction,
   the same shape Sprint 31 corrected permission-matrix.md's missing rows: `returns` gains a standard
   `created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT` column, matching every other
   table's own boilerplate. `created_at` is likewise added as the same implicit standard column every
   table has (schema-server.md's column lists only name *notable* additions beyond the boilerplate —
   [customers/specification.md §3](../customers/specification.md#3-database-tables-and-relationships)
   already established this reading for `id` itself).
2. **`returns.client_operation_id` (a column separate from `returns.id`) has no working precedent
   anywhere else in this schema.** Every other client-generated-idempotency table (`sales`,
   `trading_days`, `customers`) reuses its own `id` as the sole idempotency key — `id`-based
   upsert-or-replay-check, no second column. `stock_movements`' own docstring states this pattern
   explicitly: "every movement carries a unique `client_operation_id` (its own primary key)," i.e.
   `id` *is* the idempotency key there too. A redundant second `client_operation_id UNIQUE` column
   that would always equal `id` (since `POST /returns`' own request body's `id` is already
   client-generated, per returns.md's request shape) adds a second uniqueness constraint with no
   behaviour it doesn't already get from `id`'s own primary-key uniqueness. Resolved as a dated
   deviation from schema-server.md's literal column list, the same category of named deviation
   Sprint 22 made for `movement_type: 'opening'` and Sprint 26 made for `trading_days.device_id`:
   **`returns` uses `id` alone as its idempotency key**, matching every other table's actual working
   mechanism; no separate `client_operation_id` column is added.
3. **`returns.status`'s documented five-value vocabulary (`initiated`, `pending_approval`,
   `approved`, `completed`, `rejected`) has only three reachable values in this sprint's code paths.**
   returns.md's own request/response shapes only ever show `completed` (auto-approved, set at
   creation) or `pending_approval` (set at creation, above threshold) — there is no code path that
   ever produces a bare `initiated` row (creation always resolves immediately to one of those two),
   and WF-013's own table ("On approval, WF-012 continues... completes") means an approval decision
   moves `pending_approval` directly to `completed` in the same request, with no separately-persisted
   `approved` steady state. `approved_by` is still written on that same transition. This mirrors
   Sprint 22's own named precedent exactly (`movement_type: 'opening'` documented but never a
   `POST /stock-movements` input) — `initiated`/`approved` remain part of the `CHECK` vocabulary for
   forward compatibility but are not produced by any handler this sprint.
4. **`POST /returns/{id}/reject`'s `reason` (returns.md's own documented required field) has no
   column to persist to** — schema-server.md's `returns` table has no `rejection_reason`/`rejected_at`
   column. Resolved as a dated, deliberate simplification: the reason is captured in the rejection's
   own `audit_log` entry (`after_state.reason`), not a dedicated column — matching
   [modules/README.md](../../modules/README.md)'s own "not logged... anything already fully captured
   by its own immutable record" framing in reverse (here, the audit trail *is* the record, since
   `returns` itself has no field for it). A dedicated column can be added later if a reporting need
   for it emerges; none is named in this sprint's own DoD.

**Cross-module data access, decided the correct way, not the older shortcut:** locating and reading
the original sale (`original_sale_id`, its line items) goes through a new
`posService.getCompletedSaleForReturn(tenantId, saleId)` service-to-service call
([layering-rules.md §2](../../08-folder-structure/layering-rules.md#2)), not a direct
`returns/repository.ts` query against `sales`/`sale_line_items` — following Sprint 32's own
`customerExists` precedent, not `products/repository.ts`'s older, separately-named
`findCategoryById`/`findUnitById` shortcut. Writing the `return` stock movement and the completion's
`audit_log` entry, by contrast, follows every existing sprint's own established idiom
(`pos/repository.ts`'s `createSale`, `trading-day/repository.ts`'s `openTradingDay`) of writing
directly into `tx.stockMovement`/`tx.auditLog` from within the owning module's own repository
transaction — these two tables are every module's own shared, direct-write ledger, not a
cross-module read needing a service boundary.

**Scope explicitly not in Sprint 33, named rather than silently dropped:** the mobile UI (`/returns/new`,
`/returns/:id`, `/returns/approvals`) and the local `returns`/`return_line_items` Drift tables +
outbound-queue enqueue are M3 item 4. The dedicated `sync_rejections` table and an Owner-facing
"review a rejected sync operation" screen — named in
[backlog.md §4](../../17-sprints/backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)
as [offline-workflows.md Finding 1](../../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux)'s
still-unbuilt full resolution — remain deferred; this sprint builds the underlying server-side
correctness that risk actually needs (§2 below), not the review UI around a rejection once it
happens.

## 1b. Sprint 34 — Returns & Refund (mobile), M3 item 4

[Sprint 33](../../17-sprints/sprint-33.md) built the full server contract with no mobile caller.
This sprint closes that gap: `/returns/new`, `/returns/:id`, `/returns/approvals`, local
`returns`/`return_line_items` tables, and `return.create`/`return.approve`/`return.reject` as real
`outbound_queue` operations.

**A real, blocking gap found while designing this sprint, not by writing code first: the server's
own `POST /returns` request shape needs `original_sale_line_item_id` per line, but no existing
server response ever exposes a sale line item's own `id`.** `pos/service.ts`'s `formatSale` — the
function every sale-reading endpoint (`GET /sales/{id}`, `GET /sales/lookup`, the `POST /sales`
response itself) shares — maps each line item to `{ product_id, quantity, unit_price_minor_units,
discount_minor_units, tax_rate_basis_points, tax_minor_units, line_total_minor_units }`, deliberately
omitting the row's own `id` (never needed by any caller before this one). Without it, no mobile
screen can construct a valid `POST /returns` request against a sale it just looked up. Resolved as a
small, backward-compatible server correction in this same sprint: `formatSale`'s `line_items`
mapping gains an `id` field (the existing `sale_line_items.id`, simply exposed) — every existing
consumer already tolerates additional response fields (nothing destructures line items positionally),
so this is additive, not a breaking change to an already-shipped, live contract.

**Locating the original sale — two paths, both hitting the network, per backlog.md item 4's own
wording** ("locate the original sale via `GET /sales/lookup` or via a customer's purchase history"):
`SaleRepository` (owned by `pos`, reused rather than duplicated — the same cross-feature-reuse
precedent `customers` already established for `CompletedSale`) gains two new, network-backed methods
— `lookupSale({provisionalInvoiceNumber, canonicalInvoiceNumber})` (`GET /sales/lookup`) and
`fetchRemoteSaleDetail(id)` (`GET /sales/{id}`, used after picking a sale from a customer's purchase
history, since `CompletedSale` alone has no line items). Both are network calls injected as plain
functions into `DriftSaleRepository`'s constructor — the same testability pattern
`DriftCustomerRepository`'s `fetchAll`/`fetchPurchaseHistory` already established, not a raw `Dio`
parameter. `SaleLineDetail` gains the same `id` field the server response now carries, threaded
through unchanged from `getSaleDetail`'s existing purely-local path (the local `sale_line_items`
table already had its own `id` — it was simply never read into this entity before). No separate
`/sales-history/lookup` route is added: route-map.md names it as "needed for returns," but
`/returns/new` already provides both lookup paths inline — a second entry point for the identical
capability would be redundant, undiscussed scope, not a documented requirement in its own right.

**No mobile pull exists for `returns`, matching the server spec's own stated scope
([returns/specification.md §7](#7-offline-behaviour) as it stood after Sprint 33) — this sprint
builds the mobile caller that section already anticipated, as a direct-fetch-and-cache shape, not a
sync-pull cursor.** `ReturnRepository.listMine()`/`listApprovals()` each do a best-effort live
`GET /returns`/`GET /returns/approvals` call, upsert the results into the local `returns` cache, then
read that cache — the same "cache-first, refresh best-effort" shape `customerSearchResultsProvider`
already established, just folded into the repository method itself rather than split across a
provider (this feature has no separate search-filter concern needing that split). `getDetail(id)`
checks the local cache first, falling back to a live `GET /returns/{id}` fetch-and-cache only if
absent. `createReturn`/`approveReturn`/`rejectReturn` all write locally and enqueue in the same
transaction, the exact `DriftCustomerRepository.createCustomer`/`DriftSaleRepository.completeSale`
shape — genuinely offline-capable creation and decisions, matching `returns.md`'s own documented
offline column for all three.

**No client-side role-awareness exists anywhere in this mobile app yet — a real, pre-existing gap,
not specific to Returns, and not solved here.** The mobile app has never once needed to know its own
signed-in user's role before this feature; every prior screen's permission boundary was enforced
purely server-side, with the client never gating its own UI by role (confirmed: no `role` concept
appears anywhere in `apps/mobile/lib` before this sprint). Building a role-fetch mechanism now, for
this feature alone, would be exactly the kind of speculative, disproportionate infrastructure this
project's own practice avoids. Resolved instead by leaning on the server's own enforcement, honestly:
the `/returns/approvals` entry point and screen are shown to every signed-in user regardless of role;
a Cashier who reaches it sees the server's `403 PERMISSION_DENIED` surfaced as a plain, honest error
state (`Text('Could not load approvals: $error')`, the same pattern every other list screen's error
state already uses) — not hidden speculatively behind a role check this codebase has no way to
perform correctly yet. The Till's own pending-approvals badge count (below) benefits from this same
honesty for free: a Cashier's background badge-count fetch simply fails and is swallowed (no badge
shown), the same `try { ... } catch (_) {}` best-effort-refresh shape `customerSearchResultsProvider`
already established — the *correct* behaviour (no badge for a Cashier) falls out of the existing
error-swallowing convention, not a new role check.

**The approvals queue badge, resolved as a dated correction to `returns.md`'s own forward
reference.** `returns.md` line 21 attributes the badge to "the Reports-tab badge, per
navigation-model.md" — but navigation-model.md's own body text never actually describes this
mechanism, and no Reports tab exists in the mobile app at all yet (Reports is M4, unbuilt). Resolved
here: the badge lives on a new `pos_returns_approvals_button` app-bar icon on the Till screen
(sibling to `pos_held_carts_button`/`pos_customers_button`), showing the live pending-approval count
(via the swallowed-error fetch above) as a small `Badge` overlay, tapping through to
`/returns/approvals` regardless of the count (including zero) — the honest, currently-buildable
equivalent of the badge `tap-count-audit.md`'s WF-013 queue-path numbers already assume exists,
without inventing a Reports tab a full milestone early.

**The interrupt vs. queue approval split (WF-013), resolved without new real-time infrastructure.**
`returns/specification.md §7`'s own Sprint 33 text names this explicitly as undecided, mobile-side
scope: "mobile's own UI... decides whether the Manager sees an interrupting prompt or a queued list
row." No push/realtime mechanism exists in this app (§8, unchanged) to notify a *different* device's
Manager the instant a return needs approval — building one is real, disproportionate scope for a
single navigation decision. Resolved as: immediately after `POST /returns` returns
`status: 'pending_approval'`, `NewReturnScreen` shows an inline "This return needs approval" prompt
with its own `returns_approve_now_button`, calling `approveReturn` right there — WF-013's interrupt
path in its only realistic mobile shape (a Manager/Owner operating the till themselves, the same
single-signed-in-identity-per-device reality this whole app already assumes everywhere else). If the
signed-in identity isn't Manager/Owner, tapping it surfaces the server's `403` as a plain error, the
same honest-server-enforcement stance the badge above already established — a minor, accepted V1
rough edge (a Cashier can tap a button that will always 403 for them) rather than new role-detection
machinery. The queue path (no one interrupts; a Manager finds it later via the badge) needs no
special handling at all — it's simply what happens when the inline prompt's own approve action is
never taken.

## 2. Business rules

- **DR-013** — a return line's quantity must not exceed its original sale line's quantity minus any
  quantity already returned against that same line, summed across every non-`rejected` return
  (`pending_approval` counts, so two concurrent below-the-original-quantity requests can't both
  later be approved past it).
- **DR-014** — a return line's refund equals the original line's per-unit price, inclusive of tax,
  times the returned quantity. **Rounding decision, not previously pinned down anywhere:**
  `sale_line_items.line_total_minor_units` is the *whole line's* tax-inclusive value; dividing it by
  quantity to get a per-unit figure is not guaranteed to be exact (a 3-unit line's tax/discount
  rounding is computed once, over the whole line, not per unit — [money-and-tax.md](../../07-database/money-and-tax.md)).
  Resolved as: when a return's requested quantity for a line equals that line's **entire remaining
  unreturned quantity**, the refund is the *exact remaining unrefunded amount*
  (`line_total_minor_units` minus whatever has already been refunded against it) — no division, no
  drift, and this covers the overwhelmingly common case (returning everything on a receipt, whether
  in one return or as the final one of several partials). For a **genuine partial** return (some
  quantity remains after this one), the refund is `round(line_total_minor_units × returned_quantity ÷
  original_quantity, shop's rounding_rule)` — the same `roundFraction` helper `pos/service.ts` already
  uses for tax/discount splits. Named limitation, consistent with every other proportional-rounding
  decision in this codebase: a sequence of several genuine partial returns against the same line is
  not guaranteed to sum to exactly `line_total_minor_units` if the *last* one isn't itself a
  full-remaining-quantity return; this is the same class of accepted small-value drift
  `roundFraction` already introduces elsewhere, not a new risk.
- **DR-015** — a return whose `refund_total_minor_units` (the sum of its own line refunds) exceeds
  `shop_settings.return_auto_approval_threshold_minor_units` is created at `status = 'pending_approval'`
  instead of `status = 'completed'` — **not an error**, a normal `201` response (returns.md's own
  documented shape), mirroring Discount's `DISCOUNT_REQUIRES_APPROVAL` only in spirit, not in
  mechanism (that one *rejects* the sale; this one *accepts* the return in a provisional state).
- **DR-016** — a return references exactly one `original_sale_id`; enforced structurally (the column
  is a single required UUID, never an array), not by an additional runtime check.
- **A return line item's `original_sale_line_item_id` must belong to the same `original_sale_id`.**
  Not separately named in DR-013–016 but load-bearing (without it, a client could reference another
  sale's line item and drain its own quantity budget against the wrong sale) — checked against the
  sale's own fetched line items, `NOT_FOUND` if any requested id isn't among them. Reuses the
  generic `NOT_FOUND` code, the same precedent `customer_id`'s existence check on `POST /sales`
  already established (no dedicated per-field code where a shared one already covers the shape).
- **The original sale must be `status = 'completed'`** — a draft/held sale is never returnable; the
  same "only completed sales are real, referenceable facts" stance
  [customers/specification.md §2](../customers/specification.md#2-business-rules) already applies to
  purchase history. A non-completed or nonexistent-under-this-tenant `original_sale_id` is
  `ORIGINAL_SALE_NOT_FOUND`, matching returns.md's own note that this code also covers "not yet
  synced from another device."
- **DR-017/DR-018** — every approve/reject re-validates the acting user's role fresh from
  `user_store_roles`, in the service layer, at the moment the operation is actually applied — not
  only at the calling Route Handler's own permission gate. This matters concretely for the
  **sync-push path**: `POST /sync/push`'s own Route Handler gate is deliberately generic
  (`cashier`/`manager`/`owner`, since one push batch can carry any operation type — see
  `sync/route.ts`), so a `return.approve`/`return.reject` operation reaching `runOperation` has *not*
  already been role-gated to Manager/Owner the way the direct
  `POST /returns/{id}/approve` endpoint's own `requirePermission(["manager","owner"])` gates it. The
  service functions `approveReturn`/`rejectReturn` therefore resolve the acting user's role via
  `rolesService.resolveActiveRole` themselves, unconditionally — redundant-but-harmless for the direct
  path (already gated), the actual correctness mechanism for the sync-push path (resolves the
  approving Manager's *current* role, catching a revocation that happened after the approval decision
  was made offline but before it synced — exactly
  [offline-workflows.md Finding 1](../../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux)'s
  named risk). The same shape `pos/service.ts`'s own discount-approval check already established for
  an analogous reason.
- **Approving or rejecting a return not currently `pending_approval` is `RETURN_ALREADY_DECIDED`**,
  except a replay of an approve on an already-`completed` return (or a reject on an already-`rejected`
  one), which is an idempotent no-op — the same `closeTradingDay`/`deactivateCustomer` shape every
  state-transition endpoint in this codebase already uses.
- **A completed return is immutable** — no code path ever updates a `completed` or `rejected` row
  again, matching `sales`' own "no `UPDATE`/`DELETE` once `status = 'completed'`" (BR-030).
- **No row-level locking against a race between two concurrent returns on the same line** — the same
  accepted small-scale simplification this codebase already lives with for stock oversell (DR-005);
  the one place a real invariant *is* lock-enforced (`trading_days`' one-open-day partial index)
  protects a different, harder invariant (a business-wide "exactly one" fact, not a bounded-quantity
  check). Not treated as a gap worth closing at this product's current scale.

## 3. Database tables and relationships

Two new tables, both Tier 2 ([schema-server.md Context 6](../../07-database/schema-server.md)),
adjusted per §1's two dated corrections (`created_by`/`created_at` added, `client_operation_id`
dropped):

**`returns`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `UUID PRIMARY KEY` | Client-generated, the sole idempotency key (§1, correction 2). |
| `tenant_id` | `UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT` | |
| `store_id` | `UUID NOT NULL REFERENCES stores(id) ON DELETE RESTRICT` | The original sale's own `store_id`, not necessarily the caller's session store — moot at V1's one-store-per-tenant scale, but the semantically correct value regardless. |
| `original_sale_id` | `UUID NOT NULL REFERENCES sales(id) ON DELETE RESTRICT` | DR-016. |
| `status` | `TEXT NOT NULL CHECK (status IN ('initiated','pending_approval','approved','completed','rejected'))` | Only `pending_approval`/`completed`/`rejected` are reachable this sprint (§1, correction 3). |
| `refund_total_minor_units` | `BIGINT NOT NULL` | Sum of this return's own line refunds. |
| `approved_by` | `UUID NULLABLE REFERENCES users(id) ON DELETE SET NULL` | Set only on the approve transition; stays null for an auto-approved (below-threshold) return — nobody "approved" it, the threshold simply wasn't crossed. |
| `completed_at` | `TIMESTAMPTZ NULLABLE` | Set when `status` becomes `completed` (at creation for auto-approve, at approval for the above-threshold case). |
| `created_at` | `TIMESTAMPTZ NOT NULL DEFAULT now()` | Added (§1, correction 1). |
| `created_by` | `UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT` | Added (§1, correction 1) — the actual mechanism behind `GET /returns`' Cashier "own device only" scope. |

Indexes: `(original_sale_id)` — has-this-sale-been-returned check. `(tenant_id, store_id, status)
WHERE status = 'pending_approval'` — the approval queue, WF-013. `(tenant_id, created_at, id)` — list
pagination.
RLS: tenant-scoped, standard template (`supabase/sql/015_rls_returns.sql`). No `UPDATE`/`DELETE` once
`completed`/`rejected` — enforced in the service layer this sprint, the same as every other
"immutable once decided" table's own current enforcement level (`sales` itself has no DB-level
trigger for this either yet).

**`return_line_items`**

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `UUID PRIMARY KEY` | Server-generated (`randomUUID()`) — no client-facing idempotency need of its own; identified only through its parent return. |
| `return_id` | `UUID NOT NULL REFERENCES returns(id) ON DELETE RESTRICT` | |
| `original_sale_line_item_id` | `UUID NOT NULL REFERENCES sale_line_items(id) ON DELETE RESTRICT` | |
| `quantity` | `INT NOT NULL` | `NUMERIC(14,3)` on schema-server.md's full design; `INT` here matches `sale_line_items.quantity`'s own already-established M0 simplification (fractional quantities remain out of scope everywhere in this codebase — no Unit's `allows_fractional` flag is wired into any quantity field yet, this one included). |
| `refund_amount_minor_units` | `BIGINT NOT NULL` | DR-014. |

Index: `(original_sale_line_item_id)` — the "quantity already returned" check backing DR-013.
RLS: none, by design — matching `sale_line_items`/`sale_payments`' own stated precedent
(`005_rls_sales.sql`'s own comment): access is always via `return_id`, never queried directly across
tenants.

**Mobile (Sprint 34) — local `Returns`/`ReturnLineItems` Drift tables**, schema v5→v6: `id`,
`originalSaleId`, `status`, `refundTotalMinorUnits`, `approvedBy` (nullable), `completedAt`
(nullable), `createdAt` mirror the server row exactly; `ReturnLineItems` mirrors `return_line_items`
(`id`, `returnId`, `originalSaleLineItemId`, `quantity`, `refundAmountMinorUnits`). No FK enforced
from `returns.originalSaleId` to the local `sales` table at the Drift layer — the referenced sale may
legitimately not exist locally at all (it was located via a live network fetch, per §1b), the same
softer, unenforced-FK precedent `sales.customerId` already established, not `sale_line_items.saleId`'s
enforced one. Domain entities are named `ReturnSummary`/`ReturnDetail` (not a bare `Return`) —
sidestepping the usual Drift-generated-row-class collision for the parent table entirely (the same
`CompletedSale`/`SaleDetail` split `pos` already uses for an analogous list-vs-detail shape); the
line-item domain entity, `ReturnLineItem`, does still collide with `ReturnLineItems`' own generated
row class the same way `Customer`/`Category`/`Unit`/`Product` already did, resolved identically — a
`hide ReturnLineItem` import wherever both are needed in one file.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/returns` | **Built this sprint.** Cashier, Manager, Owner. `id` (client-generated UUIDv4), `original_sale_id`, `line_items: [{ original_sale_line_item_id, quantity }]`. Refund amounts always server-computed (§2/DR-014), never trusted from the client — [api-principles.md §7](../../11-api/api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure). |
| `GET /api/v1/returns/{id}` | **Built this sprint.** Cashier, Manager, Owner. `line_items` embedded, matching `sales`' own aggregate convention. |
| `GET /api/v1/returns` | **Built this sprint.** Manager/Owner: store-wide. Cashier: own (`created_by`) only — §1, correction 1. Filter: `status`. Cursor-paginated on `(created_at, id)` descending (most-recent-first, matching `purchase-history`'s own UX reasoning). |
| `GET /api/v1/returns/approvals` | **Built this sprint.** Manager, Owner only. `status = 'pending_approval'` only, store-wide, same cursor shape as the list above. A static sibling of `returns/[id]/route.ts`, not nested under it — Trading Day/Customers' own proactive static-route-first precedent applied from the start. |
| `POST /api/v1/returns/{id}/approve` | **Built this sprint.** Manager, Owner only. No request body. Idempotent no-op if already `completed`; `RETURN_ALREADY_DECIDED` if `rejected`. |
| `POST /api/v1/returns/{id}/reject` | **Built this sprint.** Manager, Owner only. `{ reason: string }` required. Idempotent no-op if already `rejected`; `RETURN_ALREADY_DECIDED` if `completed`. |
| `POST /api/v1/sync/push` (`return.create`) | **Built this sprint.** Same payload shape as `POST /returns`'s own body (sync-api.md §1's "no second, parallel schema" rule), dispatches to the same `returnsService.createReturn`. |
| `POST /api/v1/sync/push` (`return.approve` / `return.reject`) | **Built this sprint.** Payload carries `{ id }` (approve) or `{ id, reason }` (reject) — the target return's `id` has nowhere else to travel in a push batch (no URL, unlike the direct endpoints), a structural difference from the direct endpoints' own bodies, not an inconsistency (§5). |

Route files: `returns/route.ts` (POST, GET), `returns/approvals/route.ts` (GET),
`returns/[id]/route.ts` (GET), `returns/[id]/approve/route.ts` (POST),
`returns/[id]/reject/route.ts` (POST) — the same static-siblings-of-`[id]` layout Trading Day/Sales
already established.

**Sprint 34 — small server correction, not a new endpoint:** `pos/service.ts`'s `formatSale` gains an
`id` field per line item in its `line_items` mapping (§1b) — additive, every existing consumer
(`GET /sales/{id}`, `GET /sales/lookup`, `POST /sales`'s own response) already tolerates extra
response fields.

**Mobile (Sprint 34) routes** — `/returns/new` (Cashier+, locates the original sale via
`GET /sales/lookup` or a customer's purchase history + `GET /sales/{id}`, then `POST /returns`),
`/returns/:id` (Cashier+, `GET /returns/{id}` cache-first), `/returns/approvals` (shown to every
role; the server's own `403 PERMISSION_DENIED` is what actually restricts it to Manager/Owner, per
§1b's role-awareness decision) — `route-map.md`'s three named routes, all built this sprint.

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `id` (create) | UUID v4 — Zod `.uuid()`. |
| `original_sale_id` | UUID v4. |
| `line_items` | `.array(...).min(1)`, each `{ original_sale_line_item_id: uuid, quantity: int().positive() }`. |
| `reason` (reject) | `.string().trim().min(1).max(500)`. |
| `status` (query filter) | `.enum(["pending_approval","completed","rejected"]).optional()` — `initiated`/`approved` excluded from the filterable set since no row is ever produced in those states (§1, correction 3). |

**The direct endpoints' request bodies and the sync-push payload schemas for `approve`/`reject`
deliberately differ**, found while writing this spec, not an oversight: `POST /returns/{id}/approve`
has no body at all (the target `id` is the URL's own path segment); `POST /returns/{id}/reject`'s
body is `{ reason }` only. A sync-push operation has no URL, so its `return.approve`/`return.reject`
payload schemas additionally carry `{ id }` — `syncApproveReturnPayloadSchema`/
`syncRejectReturnPayloadSchema` in `returns/schema.ts`, both re-used by `sync/service.ts`'s dispatch,
neither exposed on any direct route. `return.create`'s payload has no such split — `POST /returns`'s
own body already carries `id`, the same shape `product.create`/`customer.create`/`sale.create`
already have.

## 6. Error handling and user-facing messages

| Code | HTTP | Cause |
| --- | --- | --- |
| `RETURN_QUANTITY_EXCEEDS_SOLD` | 409 | Already reserved (error-catalogue.md). DR-013 violation. |
| `RETURN_ALREADY_DECIDED` | 409 | Already reserved. `approve`/`reject` on a return not in a state that transition can apply to. |
| `ORIGINAL_SALE_NOT_FOUND` | 404 | Already reserved. `original_sale_id` doesn't resolve to a `completed` sale under the caller's tenant. |
| `NOT_FOUND` | 404 | A requested `original_sale_line_item_id` isn't among the located sale's own line items; or `GET /returns/{id}`/`approve`/`reject` target a nonexistent `id`. |
| `PERMISSION_DENIED` | 403 | `approve`/`reject` attempted by a Cashier (direct path), or by a resolved-at-apply-time non-Manager/Owner role (sync-push path, DR-017/018). |
| `VALIDATION_FAILED` | 422 | Any Zod failure. |

## 7. Offline behaviour

**Genuinely offline-capable this sprint, at the server-contract level** (mobile's own queuing is M3
item 4's scope): `return.create`, `return.approve`, `return.reject` are all real `POST /sync/push`
operation types, dispatching to the exact same service functions their direct endpoints call —
sync-api.md §1's "no parallel schema" rule, held the same way every prior operation type already
holds it. `TYPE_ORDER` gains `return.create` after `sale.create` (a return references a sale that
may have arrived in the same batch) and `return.approve`/`return.reject` after `return.create` (an
approve/reject in the same batch as its own return's creation, while unlikely in practice — approvals
are normally a separate, later action — is still ordered correctly if it occurs). `GET /returns*`
reads are not sync-pulled this sprint — no mobile caller exists yet to need it (M3 item 4), the same
"named, not built until there's a real caller" stance `customers/specification.md §7` already took
for `customer.update`.

**The interrupt/queue approval split** (returns.md's own framing) is a navigation-timing distinction
on the *mobile* side, not a server-contract one — both paths call the identical
`POST /returns/{id}/approve`, online or via sync-push. Nothing in this server-side sprint
distinguishes them; mobile's own UI (M3 item 4) is what decides whether the Manager sees an
interrupting prompt or a queued list row.

**Sprint 34 — the mobile caller §7's Sprint 33 text anticipated, now built**, per §1b:
`createReturn`/`approveReturn`/`rejectReturn` all write the local `Returns`/`ReturnLineItems` cache
and enqueue `return.create`/`return.approve`/`return.reject` atomically in one Drift transaction —
genuinely offline-capable, matching this table's own documented offline column exactly. Reads
(`listMine`/`listApprovals`/`getDetail`) are direct-fetch-and-cache, not sync-pulled — the same
disciplined scope boundary `customers/specification.md §1a` already drew for its own reads, restated
here rather than silently generalised into a real sync-pull cursor mechanism nothing yet needs.
`SaleRepository.lookupSale` falls back to a local search of this device's own completed sales (by
provisional invoice number) when the network call itself fails — genuinely offline for the common
case (a customer returning something bought at this same till), matching
[returns-workflows.md](../../06-workflows/returns-workflows.md)'s own documented failure path
verbatim ("Fully offline against locally synced sales history; if the original sale hasn't yet
reached this device, the return cannot be located here" — a sale from *another* device, not yet
synced anywhere this device can see it, remains the one genuine offline gap, unchanged from that
pre-existing text). The customer-purchase-history path (`fetchRemoteSaleDetail`) has no local
fallback — purchase history was already online-only before this sprint (customers/specification.md
§1a), unchanged here.

## 8. Realtime behaviour

None specified for V1 — no requirement found for a live push when a return's status changes on
another device. Matches every other server-only module's own precedent (Roles & Permissions,
Settings, Trading Day, Customers): the next request (or next sync pull, once M3 item 4 builds one)
re-resolves state fresh, no cross-session push. A Manager working the approval queue via
`GET /returns/approvals` sees a return that was decided elsewhere only on their next fetch, the same
honest-staleness stance every other list endpoint here already accepts.

## 9. UI specification

**Built Sprint 34**, per §1b:

- **`NewReturnScreen`** (`/returns/new`) — two locate-the-sale entry points: an invoice-number field
  (`returns_lookup_field`, `returns_lookup_button`, calling `SaleRepository.lookupSale`) and a
  "Find by customer" button (`returns_find_by_customer_button`) opening the existing
  `CustomerPickerSheet` in a search-only mode, then that customer's purchase history
  (`returns_customer_history_list`) to pick a sale, resolved to full detail via
  `fetchRemoteSaleDetail`. Once a sale is located, its line items are listed
  (`returns_line_item_<id>`) each with a quantity stepper (`returns_line_item_decrement_<id>`/
  `returns_line_item_increment_<id>`, 0 up to the line's original quantity — DR-013's own
  cumulative-remaining check is server-side, only re-validated at submit) and a
  `returns_confirm_button` (disabled until at least one line has a positive quantity). On success:
  an auto-approved return navigates straight to `/returns/:id`; a `pending_approval` one shows the
  inline `returns_approve_now_button` prompt described in §1b before navigating.
- **`ReturnDetailScreen`** (`/returns/:id`) — status, refund total, line items
  (`return_detail_line_<id>`), and, only when `status == 'pending_approval'`, `returns_approve_button`/
  `returns_reject_button` (the latter opening a small reason prompt, `returns_reject_reason_field`) —
  the same actions `NewReturnScreen`'s own inline prompt and `ReturnApprovalsScreen`'s rows both
  reach, so a return can be decided from wherever it's currently being viewed, not only the queue.
- **`ReturnApprovalsScreen`** (`/returns/approvals`) — a plain list (`returns_approvals_list`,
  rows keyed `returns_approval_row_<id>`, empty state `returns_approvals_empty`), tapping a row
  navigates to `/returns/:id` for the actual decision (reusing `ReturnDetailScreen`'s own
  approve/reject actions rather than duplicating them inline in the list — the queue's job is
  surfacing what's pending, not re-implementing the decision UI a second time).
- **Till screen** gains `pos_return_button` (→ `/returns/new`, visible to every role — filing a
  return is a Cashier-baseline capability) and `pos_returns_approvals_button` (→
  `/returns/approvals`, with a live pending-count `Badge` per §1b's resolved badge-placement
  decision).

Tablet/phone: single-column throughout, matching every other V1 screen's own precedent.

## 10. Test plan

- Unit tests (`returns/service.test.ts`): `createReturn` — auto-approves below the threshold
  (`status: 'completed'`, stock movement + audit log written); creates `pending_approval` above the
  threshold (no stock movement yet); rejects a quantity exceeding what remains
  (`RETURN_QUANTITY_EXCEEDS_SOLD`), including the case where a prior return has already consumed part
  of the line's quantity; rejects a line item id not belonging to the located sale (`NOT_FOUND`);
  rejects a nonexistent/non-`completed` `original_sale_id` (`ORIGINAL_SALE_NOT_FOUND`); a full-quantity
  return refunds the exact remaining amount (no rounding drift); a genuine partial return uses the
  proportional-rounding formula; a replayed `id` is an idempotent no-op. `approveReturn` — completes a
  `pending_approval` return (stock movement + audit log written, `approved_by` set); idempotent replay
  on an already-`completed` return; `RETURN_ALREADY_DECIDED` on an already-`rejected` one;
  `PERMISSION_DENIED` when the resolved actor role isn't Manager/Owner (the DR-017/018 fresh check,
  exercised directly, not only via the Route Handler gate). `rejectReturn` — the mirror image, plus
  the `reason` landing in the audit log's `after_state`. `listReturns` — Cashier scoped to
  `created_by`; Manager/Owner see all; `status` filter; cursor round-trip. `listApprovals` — always
  `status = 'pending_approval'`, regardless of any caller-supplied filter.
- Unit tests (`sync/service.test.ts`): `return.create`/`return.approve`/`return.reject` each dispatch
  to the matching `returnsService` function; a bad payload is rejected the same way every other
  operation type's own bad-payload case already is; `return.create` in the same batch as its own
  `sale.create` (submitted in the "wrong" order) still succeeds, confirming `TYPE_ORDER`.
- **Live verification, real database, throwaway tenant (deleted after):**
  1. Complete a sale, then `POST /returns` for one of its line items at a quantity below the
     threshold → `201`, `status: 'completed'`, a `return` stock movement visible via
     `GET /products/{id}/stock-balance` (positive delta).
  2. `POST /returns` for a refund value above `return_auto_approval_threshold_minor_units` → `201`,
     `status: 'pending_approval'`, no stock movement yet.
  3. `POST /returns` requesting more quantity than remains (after step 1's partial return) →
     `409 RETURN_QUANTITY_EXCEEDS_SOLD`.
  4. `POST /returns/{id}/approve` (step 2's return) as a Cashier → `403 PERMISSION_DENIED`; as the
     Manager → `200`, `status: 'completed'`, the stock movement now present.
  5. A second `approve` on the same (now-`completed`) return → identical response, idempotent.
  6. `POST /returns/{id}/reject` on a fresh `pending_approval` return, with `reason` → `200`,
     `status: 'rejected'`; a follow-up `approve` on it → `409 RETURN_ALREADY_DECIDED`.
  7. `GET /returns` as the Cashier who filed step 1's return vs. a different Cashier → only the
     filer sees it; the Manager sees both.
  8. `GET /returns/approvals` → only `pending_approval` rows, regardless of a `status` query override.
  9. `POST /sync/push` with a `return.create` operation → `accepted`, `entity_id` set, immediately
     fetchable via `GET /returns/{id}`.
  10. Cross-tenant RLS: tenant B's `GET /returns` never resolves to tenant A's return.

**Sprint 34 additions:**

- Unit test (`pos/service.test.ts`): `formatSale`'s `line_items` mapping includes each line's own
  `id`.
- Widget/repository tests (`flutter test`, real in-memory Drift DB —
  `drift_return_repository_test.dart`): `createReturn` writes the local row(s) and enqueues a
  matching `return.create` operation, atomically (the same pre-seeded-conflict atomicity proof
  `drift_customer_repository_test.dart` established); idempotent replay on a repeated `id`;
  `approveReturn`/`rejectReturn` update the local row and enqueue `return.approve`/`return.reject`;
  `listMine`/`listApprovals` upsert the live-fetched page into the cache without duplicating, and
  fall back to the cache when the injected fetch throws; `getDetail` prefers the cache, falls back to
  a live fetch when absent. `drift_sale_repository_test.dart` (new group): `lookupSale` falls back to
  a local provisional-invoice-number match when the injected network function throws.
  `customers_screen_test.dart`-style fakes for `NewReturnScreen`/`ReturnDetailScreen`/
  `ReturnApprovalsScreen`: locating a sale and submitting a return; the inline approve-now prompt
  appearing only after a `pending_approval` response; approving/rejecting from the detail screen;
  the approvals list rendering and its empty state; the till's badge count reflecting a fake
  approvals-list length, and showing nothing when the fake throws (the Cashier case).
- **Live verification, real database:** `GET /sales/{id}` and `GET /sales/lookup` both now return
  each line item's own `id`; a `return.create` sync-push operation, submitted the way the mobile
  outbound queue would submit it, still creates the row exactly as before (no server-contract
  regression from the `formatSale` addition).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| FR-062 (locate original sale) | §4 (`original_sale_id` on `POST /returns`) — phone/customer-based lookup itself is [customers.md](../../11-api/endpoints/customers.md)/mobile's own job (M3 item 4) | Server precondition met |
| FR-063 (subset of line items, bounded by remaining quantity) | §2 (DR-013), §4 | Met |
| FR-064 (positive stock-ledger entry per returned unit) | §2, §3 | Met |
| FR-065 (refund equals tax-inclusive value returned) | §2 (DR-014) | Met |
| FR-066 (Manager approval above threshold) | §2 (DR-015), §4 | Met |
| DR-013–DR-018 | §2 | Met |
| [permission-matrix.md — Returns](../../05-personas/permission-matrix.md#returns) | §4 | Met — matrix already had both rows correct, no correction needed this sprint |
| `returns.md`'s offline-queued endpoints | §7 | `POST /returns`, `POST /returns/{id}/approve`, `POST /returns/{id}/reject` all met (server contract) |
| [offline-workflows.md Finding 1](../../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux) | §2 (DR-017/018 fresh re-check) | Underlying correctness met; dedicated `sync_rejections` table/review UI explicitly deferred, named in §1 |
| Mobile UI (`/returns/new`, `/returns/:id`, `/returns/approvals`) | §1b, §9 | Met (Sprint 34) |
| FR-062 (locate original sale, mobile) | §1b, §9 (`NewReturnScreen`'s two lookup paths) | Met (Sprint 34) |
| WF-013 interrupt/queue split | §1b (resolved without new realtime infrastructure) | Met (Sprint 34) — a named, accepted V1 shape, not the fullest possible design |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | First version — written to drive Sprint 33's implementation of Returns & Refund (server), backlog.md M3 item 3. Found and resolved four real gaps while writing, not by writing code first: `returns` needed a `created_by`/`created_at` column pair schema-server.md never listed; a redundant `client_operation_id` column with no working precedent elsewhere in this schema was dropped in favour of `id` alone; only 3 of 5 documented `status` values are reachable this sprint; `reject`'s `reason` has no column, captured in the audit log instead. DR-014's per-unit-price rounding ambiguity resolved: exact-remaining-amount for a full-remaining-quantity return, proportional rounding only for a genuine partial. |
| 0.2.0 | 2026-08-16 | §1b added — written to drive Sprint 34 (M3 item 4, Returns & Refund mobile). Found and fixed a real, blocking gap: no server response ever exposed a sale line item's own `id`, which `POST /returns` requires — `pos/service.ts`'s `formatSale` corrected to include it (additive, non-breaking). Two real design decisions resolved, both named as undecided in the Sprint 33 text: the approvals-queue badge (`returns.md`'s own forward reference to a "Reports-tab badge" that doesn't exist yet — placed on a new Till app-bar icon instead) and the WF-013 interrupt/queue split (resolved via an inline post-creation approve prompt, not new realtime infrastructure). Named, not solved: no client-side role-awareness exists anywhere in mobile yet — the approvals screen leans on the server's own `403` enforcement, surfaced honestly, rather than a speculative role check. |
