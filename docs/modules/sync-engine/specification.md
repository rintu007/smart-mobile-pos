# Module Specification — Offline Sync Engine

> **Status:** 🟢 Approved
> **Module:** Offline Sync Engine
> **Slice:** V1 — this document scopes only backlog.md item 9's M0-minimal cut, not the full
> [sync-api.md](../../11-api/sync-api.md) shape (§1)
> **Version:** 0.9.0
> **Last updated:** 2026-08-17
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 13](../../17-sprints/sprint-13.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Connects the two write paths every prior sprint has proven independently: the mobile local write
path (Sprint 07's `product.create`, Sprint 09's `sale.create`, both already enqueued to
`outbound_queue`) and the server endpoints that accept them (`POST /api/v1/products` Sprint 04,
`POST /api/v1/sales` Sprint 05). [backlog.md item 9](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)
("Sync engine: `POST /sync/push` for `product.create`/`sale.create`, `GET /sync/pull` for
`products` — the minimal slice of [sync-api.md](../../11-api/sync-api.md), not the full
5-entity-type pull") is exactly this connecting piece, and the last thing
[milestones.md — M0](../../16-milestones/milestones.md#m0--walking-skeleton)'s exit criterion
needs before item 11's end-to-end proof ("...watch it sync...") can be attempted for real rather
than described.

**Deliberately narrow scope, matching the backend/mobile split precedent already established**
(products: Sprint 04 backend / Sprint 07 mobile; sales: Sprint 05 backend / Sprint 09 mobile):
Sprint 13 built the **backend push/pull endpoints only**. **Sprint 14 closes that gap** —
`apps/mobile/lib/core/sync/` now calls both, draining `outbound_queue` via push and refreshing the
local `products` cache via pull. The trigger itself is still deliberately narrow: automatic, once
per app session, right after `storeContextProvider` resolves, plus a manual "Sync now" button —
not the full connectivity-listener/app-foreground/background-timer trigger set
[sync-api.md §7](../../11-api/sync-api.md#7-what-triggers-a-sync-cycle) describes, which stays a
named, deferred Phase 18 tuning decision (per that section's own wording).

**Narrower still than [sync-api.md](../../11-api/sync-api.md) itself**, even for the backend half:
- Push handles seven operation types (`product.create`, `sale.create`, `customer.create` — Sprint 32,
  [customers/specification.md §1a](../customers/specification.md#1a-sprint-32--customers-mobile-m3-item-2)
  — `return.create`/`return.approve`/`return.reject` — Sprint 33,
  [returns/specification.md §7](../returns/specification.md#7-offline-behaviour) — and, added
  Sprint 35, [customers/specification.md §1c](../customers/specification.md#1c-sprint-35--conflict-resolution-field-merge-m3-item-5-m3s-last-item),
  `customer.update` — **this engine's first `.update` operation type of any kind**) — sync-api.md
  §2's full six-group ordering (`catalogue.*`, `customer.*`, `stock_movement.*`, `trading_day.*`,
  `sale.*`, `return.*`) now covers every one of its own named groups except
  `catalogue.*`/`trading_day.*`/`stock_movement.*` push, none of which has a client-facing write
  path yet. `customer.create`/`customer.update` are ordered alongside `product.create`, all before
  `sale.create` — a sale created in the same batch as a customer it references needs that customer
  to exist first, the same dependency reason `product.create` already precedes `sale.create`.
  `return.create` is ordered after `sale.create` (a return references a sale that may have arrived
  in the same batch), and `return.approve`/`return.reject` after `return.create`. `stock_movement.*`
  push (`opening`/`adjustment`) in particular stays out of scope — Sprint 11 built `opening`/`sale`
  movements as **server-side side effects only**, per
  [inventory/specification.md §1](../inventory/specification.md#1-purpose-and-business-context);
  there is no public `POST /stock-movements` for a client to push to yet.
- Pull handles four of sync-api.md §6's eight documented entity types: `products` (Sprint 13),
  `stock_movements` and `sales` (Sprint 36, backlog.md M4 item 1 — see the dedicated note below),
  and `shop_settings` (Sprint 37, backlog.md M4 item 2 — deliberately minimal, originally one field,
  see [reports/specification.md §3](../reports/specification.md#3-database-tables-and-relationships);
  a second field, `receipt_footer_message`, added Sprint 39, backlog.md M4 item 4 — see
  [receipt-printing/specification.md §1](../receipt-printing/specification.md#1-purpose-and-business-context)).
  `categories`, `units`, `customers`, `user_store_roles`, `sync_rejections` remain undocumented at
  the endpoint level.
- No `sync_rejections` table/read path — a rejected operation's reason is returned synchronously in
  the same push response (§3 below); nothing is queryable after the fact yet.

**Sprint 36 (backlog.md M4 item 1) — `stock_movements`/`sales` pull, the "reporting parity across
devices" sync-api.md §6 has named since Phase 11 and never implemented until now.** Reports (M4 item
2, not yet built at the time this sprint ran — built the very next sprint, Sprint 37, corrected here
Sprint 74) reads its four figures entirely from the local caches this sprint fills — no
`reports.md` endpoint exists or is needed, per [FR-071](../../03-functional-requirements/functional-requirements.md#group-j--reports-core-four)'s
own offline-behaviour column ("computed from locally synced data"). Two real design points, both
already recorded in [backlog.md §5](../../17-sprints/backlog.md#5-m4--fully-decomposed-2026-08-16-now-that-m3-has-reached-this-point)'s
own decomposition and restated here as this module's own record:

- **A durable, per-entity-type resume cursor, unlike `products`.** `products`' own pull cursor is
  never persisted between sync cycles (§2 below, unchanged) — a small, near-static catalogue makes a
  full re-pull cheap every time. `stock_movements`/`sales` are an ever-growing transaction history;
  re-pulling the whole thing every sync cycle is real, avoidable cost. [sync-api.md §6](../../11-api/sync-api.md#6-pull--getsyncpull)'s
  own dated correction explains why this needed a second response field: `next_cursor` (always the
  last row actually returned, a stable resume point) and `has_more` (whether to keep paging *within
  this run*), rather than overloading a single `next_cursor` to mean both at once. Mobile persists the
  cursor in a new local-only `sync_cursors` table (§3).
- **Reports' Manager/Owner gate has no server call to enforce it against.** Once this pull exists,
  every device holds the same shop-wide `stock_movements`/`sales` data regardless of the signed-in
  user's role — [permission-matrix.md — Reports](../../05-personas/permission-matrix.md#reports)'s
  restriction is therefore necessarily a client-side presentation control when M4 item 2 builds the
  actual report screens, not a data-access boundary this module's own pull endpoint could add. Named
  here as the deliberate, narrow reasoning, not deferred silently to that later item.

## 2. Business rules

- [sync-api.md §5](../../11-api/sync-api.md#5-duplicate-detection--replays-are-free): no new
  idempotency mechanism is built here — `product.create`/`sale.create` push operations are handled
  by calling the **exact same service functions** (`products.service.createProduct`,
  `pos.service.createSale`) the direct endpoints already call, so their existing
  id-based idempotent-creation guarantee (Sprint 04/05) applies unchanged. Resubmitting an
  unresolved batch is safe by construction, not by anything new this module adds.
- [sync-api.md §2](../../11-api/sync-api.md#2-ordering--dependency-groups-not-raw-client-order):
  within one push request, operations are processed in the order `product.create`/`customer.create`,
  then `sale.create`, then `return.create`, then `return.approve`/`return.reject` — preserving each
  group's own relative submitted order, the collapsed subset of the full ordering, per §1.
- [sync-api.md §3](../../11-api/sync-api.md#3-partial-failure-semantics--every-operation-gets-its-own-verdict):
  one operation's rejection never fails the batch or blocks independent operations after it —
  enforced by processing each operation in its own `try`/`catch`, never letting one operation's
  thrown error abort the loop.
- [sync-api.md §4](../../11-api/sync-api.md#4-why-dependency_not_found-is-not-not_found): a
  `sale.create` operation whose `product_id` doesn't exist server-side yet, or a `return.create`
  operation whose `original_sale_id` doesn't exist server-side yet, is rejected with
  `DEPENDENCY_NOT_FOUND` — the one place this module's error handling genuinely diverges from the
  direct endpoints' own (`POST /sales`/`POST /returns` still return their plain `NOT_FOUND`/
  `ORIGINAL_SALE_NOT_FOUND` when called directly; only the sync-push context remaps them, since only
  there is "not synced yet" actually a plausible, retryable explanation).
- [returns/specification.md §2](../returns/specification.md#2-business-rules) (DR-017/018):
  `return.approve`/`return.reject` re-validate the acting user's role fresh, inside
  `returnsService` itself — necessary because this module's own push-endpoint permission gate is
  generic (any active role), not approve/reject-specific.
- [api-principles.md §4](../../11-api/api-principles.md#4-pagination--cursor-only): pull is
  cursor-only, `(updated_at, id)` for `products` (a Tier 1 table), `(created_at, id)` for
  `stock_movements` (Tier 2), `(completed_at, id)` for `sales` (Tier 2 — every synced sale is
  `status: 'completed'`, matching `GET /sales`' own cursor field, Sprint 36) — no offset pagination.
- **Mobile, Sprint 14: no pull cursor is persisted between sync runs for `products`.** Every call to
  `syncNow()` pages `products` from the start, upserting each row by `id` (idempotent — a re-pulled
  row simply overwrites the locally cached one, per schema-local.md's `products` divergence note). A
  persisted, resumable cursor is a real efficiency improvement `sync-api.md §6` anticipates, but
  M0's product-catalogue size makes it unnecessary, and skipping it avoids adding a new local table
  (and the schema migration that would require) against the founder's own already-installed,
  persistent app — a deliberate, named trade-off, not an oversight.
- **Mobile, Sprint 36: `stock_movements`/`sales` *do* persist a resume cursor**, in the new local
  `sync_cursors` table (§3) — the opposite trade-off from `products`, made for the opposite reason
  (an ever-growing transaction history, not a small static catalogue). Written once per entity type
  per `syncNow()` call, after that entity type's own pull loop finishes (`has_more` reaches `false`),
  not after every individual page — a crash mid-pull simply re-pulls that cycle's pages again next
  time, safe by the same upsert-by-`id` idempotency every pull entity type already relies on.
- A queued operation's `outbound_queue` row is only ever updated in response to that operation's
  own result in the push response — a network failure that never reaches the server (no response
  at all) leaves every affected row untouched, safe to resend in full on the next attempt.

## 3. Database tables and relationships

**Server:** no new table. Push writes through `products`/`stock_movements`/`sales`/
`sale_line_items`/`sale_payments`/`audit_log` exactly as the direct endpoints already do (Sprints
04, 05, 11, 12) — this module owns no storage of its own, only the batch/cursor mechanics around
calling existing service functions. Pull reads `products` unchanged; `stock_movements`/`sales`
(Sprint 36) read the same tables their own direct endpoints already do, tenant-scoped, no new query
logic beyond pagination (`stock_movements` reuses `stock-movements/repository.ts`'s own
`listStockMovements` unfiltered; `sales` gets a dedicated `sync/repository.ts#listSalesForSync`,
since the existing `GET /sales` listing deliberately excludes line items this pull needs).

**Mobile (Sprint 14):** no new local table. Push reads `outbound_queue` (already built,
backlog item 4) and updates each row's own `status`/`attempt_count`/`last_attempted_at`/
`rejection_reason` per its push result — the exact columns schema-local.md already defines for
this table's Sync Item state machine, none added. Pull upserts into the local `products` table
(already built) — no local pull-cursor table, per §2's named trade-off.

**Mobile (Sprint 36):** one new table, `sync_cursors` (`entity_type` text primary key, `cursor` text
nullable) — schema v6→v7, a non-destructive migration (`CREATE TABLE`, no existing data touched).
Pull upserts into the existing local `stock_movements`/`sale_line_items`/`Sales` tables (all already
built, M0/M2/M3) — only the columns those tables already have columns for are written; the
already-named M2 gap (`sales`/`sale_line_items` locally missing discount/tax fields) is unaffected,
since this sprint only adds read-cache rows through the columns that already exist.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/sync/push` | **Implemented Sprint 13, extended Sprint 32/33/35.** Request: `{ operations: [{ type, client_operation_id, payload }] }`, `type ∈ {'product.create', 'sale.create', 'customer.create', 'customer.update', 'return.create', 'return.approve', 'return.reject'}`, `payload` validated per-type — `product.create`/`sale.create`/`customer.create`/`return.create` against the exact same Zod schema their direct endpoint uses; `customer.update` against the same merge-aware schema `PATCH /customers/{id}` itself now uses, with `id` added (no URL in a push batch); `return.approve`/`return.reject` against a dedicated sync-only payload schema carrying `{ id }`/`{ id, reason }` (the same structural reason — [returns/specification.md §5](../returns/specification.md#5-validation-rules-client-and-server)). Response: `{ results: [{ client_operation_id, status: 'accepted' \| 'rejected', entity_id?, error? }] }`, one result per submitted operation, in the request's own original order. Requires any active role (`requirePermission`, Sprint 23) — sync is a device-level mechanism, not itself a permission-matrix.md capability, so the check here is simply "has an active, non-deactivated role at all," meaningfully blocking a revoked user even from syncing. |
| `GET /api/v1/sync/pull` | **Implemented Sprint 13** (`entity_type=products`), **extended Sprint 36** (`stock_movements`/`sales`), **extended Sprint 37** (`shop_settings`). `?entity_type=products\|stock_movements\|sales\|shop_settings&cursor=<opaque>&limit=<n, default 50, max 200>` → `{ data: [...], next_cursor }` for `products`; `{ data: [...], next_cursor, has_more }` for `stock_movements`/`sales` (sync-api.md §6's dated correction — `next_cursor` is always the last row seen, `has_more` says whether to keep paging now); `{ data: [{ low_stock_threshold_quantity }] \| [], next_cursor: null, has_more: false }` for `shop_settings` (never paginated — exactly one row per tenant). Any other `entity_type` value is rejected with `VALIDATION_FAILED` (422) — not a silent empty result. Requires any active role (Sprint 23), same reasoning as push — no role-specific filtering, per §1's Reports-gate note. |
| Every other entity type's pull, `sync_rejections`, the full six-group push ordering | **Already documented** in [sync-api.md](../../11-api/sync-api.md), **not implemented, and not needed yet** — see §1. |

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `operations` | Array, 1–200 elements |
| `operations[].type` | Enum: `'product.create'`, `'sale.create'`, `'customer.create'` (Sprint 32), `'return.create'`/`'return.approve'`/`'return.reject'` (Sprint 33), `'customer.update'` (Sprint 35) — any other value is rejected with `VALIDATION_FAILED` at the operation level (its own `results[]` entry, not a whole-batch 422) |
| `operations[].client_operation_id` | UUIDv4, required |
| `operations[].payload` | Validated per-type against the existing direct-endpoint schema — a payload failing that schema is rejected with `VALIDATION_FAILED` at the operation level |
| `entity_type` (pull) | Enum: `'products'`, `'stock_movements'`, `'sales'` (added Sprint 36), `'shop_settings'` (added Sprint 37) |
| `cursor` (pull) | Opaque, base64url; a malformed cursor is rejected with `VALIDATION_FAILED` (422) rather than silently treated as "no cursor" |
| `limit` (pull) | Integer, 1–200, default 50 |

## 6. Error handling and user-facing messages

Push: no whole-batch HTTP error for a per-operation failure — every operation gets its own
`accepted`/`rejected` verdict in a `200` response, per §2/sync-api.md §3. The request body itself
failing schema validation (e.g. not even an array) is still a whole-request `422 VALIDATION_FAILED`,
since there's no per-operation result to attach it to at that point. Pull: `422 VALIDATION_FAILED`
for an unsupported `entity_type` or a malformed `cursor`. No user-facing copy specified here — this
is a device-to-server sync mechanism with no mobile trigger yet (§1), so there is no screen to show
copy on this sprint.

## 7. Offline behaviour

This module *is* the mechanism that makes offline writes eventually durable server-side. As of
Sprint 14: a sync attempt with no connectivity fails the underlying HTTP call, which
`SyncRepository.syncNow()` lets propagate for a manual "Sync now" tap (surfaced as an inline error
on the home screen) but deliberately swallows for the automatic on-start trigger (§9) — an
auto-sync failing at launch must never block the home screen; it simply retries next launch or on
the next manual tap. `outbound_queue` rows themselves are never touched unless a server response
was actually received (an operation's own result decides its fate — §2), so a network failure
mid-push leaves the queue exactly as it was, safe to retry in full.

**Sprint 36:** the same "fails, propagates or is swallowed exactly as any other pull step" shape
applies to `stock_movements`/`sales` — a mid-pull network failure simply leaves that entity type's
persisted cursor at its last successfully-written value (§2), so the next sync cycle resumes from
there rather than either losing progress or silently skipping rows.

## 8. Realtime behaviour

None specified for V1 in this sprint's scope — pull is poll/pull-driven (sync-api.md §7's
connectivity/foreground/backstop-timer triggers), not a push subscription.

## 9. UI specification

No dedicated screen — `apps/mobile/lib/app/home_screen.dart` gained a sync-status line (`Not
synced yet this session.` / a per-run summary / an inline error) and a `sync_now_button`, per
[route-map.md](../../09-navigation/route-map.md)'s existing placement of cross-cutting status on
the app shell's own root screen (the same reasoning `store_context_ready`'s status line already
established, Sprint 08). No new route. An `autoSyncOnStartProvider` (a cached `FutureProvider`,
Riverpod's idiomatic "run once" mechanism) fires automatically the first time
`storeContextProvider` resolves in a given app session — not on every rebuild.

## 10. Test plan

**Sprint 13 scope:**
- Unit tests (`sync/service.test.ts`, mocking `products/service` and `pos/service`): a batch with
  one of each type calls both service functions and returns two `accepted` results in the request's
  original order; a `product.create` first / `sale.create` second batch still processes
  `product.create` first even when submitted in reverse order; a thrown `ApiError` from either
  service function is caught and turned into a `rejected` result rather than propagating; a
  `sale.create` whose product-lookup throws `NOT_FOUND` is remapped to `DEPENDENCY_NOT_FOUND` in the
  result; one operation's rejection doesn't stop the remaining operations from running.
- Unit tests (`sync/service.test.ts`, pull half, mocking `repository`): the returned cursor encodes
  the last row's `(updated_at, id)`; a full page returns a non-null `next_cursor`, a partial page
  returns `null`; a malformed cursor throws `VALIDATION_FAILED` rather than crashing.
- **Live verification, real database, throwaway tenants (deleted after):**
  1. `POST /sync/push` with one `product.create` and one `sale.create` (referencing that same
     product, submitted product-second/sale-first to prove reordering) — both `accepted`, the sale's
     stock movement and audit entry both exist (Sprint 11/12's own effects fire unchanged).
  2. `POST /sync/push` with a `sale.create` referencing a product id that doesn't exist —
     `DEPENDENCY_NOT_FOUND`, not `NOT_FOUND`.
  3. Replaying the identical push batch — both operations still `accepted`, no duplicate rows.
  4. `GET /sync/pull?entity_type=products&limit=1` twice, paging with the returned `next_cursor` —
     the second page returns the second product, not a repeat of the first; the final page's
     `next_cursor` is `null`.
  5. Cross-tenant: tenant B's pull returns none of tenant A's products.

**Sprint 14 scope (mobile):**
- Repository tests (`sync_repository_test.dart`, against a real in-memory Drift database): an
  accepted result marks its queue row `synced`; a `DEPENDENCY_NOT_FOUND` result marks it
  `failed_retrying` and increments `attempt_count`; any other rejection marks it `rejected` with
  `rejection_reason` set; both `queued` and `failed_retrying` rows are included in one push batch,
  `synced` rows are not; a sync with an empty queue never calls push at all; pull pages across
  multiple calls and upserts every row into the local `products` table; pulling an
  already-cached product updates it in place rather than duplicating it.
- Widget test (`widget_test.dart`): the home screen's initial sync-status line reads "Not synced
  yet this session"; tapping "Sync now" against a faked, empty-queue repository shows the resulting
  summary.

**Sprint 33 additions:**
- Unit tests (`sync/service.test.ts`, mocking `returns/service`): `return.create` dispatches to
  `returnsService.createReturn`; `return.approve`/`return.reject` dispatch to their matching
  `returnsService` functions, with `return.reject` carrying the `reason` through; a bad payload for
  any of the three is rejected the same way every other operation type's own bad-payload case
  already is; `return.create` processes after `sale.create` even when submitted first; a
  `return.create` whose `posService.getCompletedSaleForReturn` throws `ORIGINAL_SALE_NOT_FOUND` is
  remapped to `DEPENDENCY_NOT_FOUND` in the result.
- **Live verification, real database:** a `POST /sync/push` batch containing a `return.create`
  operation creates the row exactly as the direct endpoint would, immediately fetchable via
  `GET /returns/{id}` — [returns/specification.md §10](../returns/specification.md#10-test-plan)
  step 9.

**Sprint 35 additions:**
- Unit tests (`sync/service.test.ts`, mocking `customers/service`): `customer.update` dispatches to
  the same, now-merge-aware `customersService.updateCustomer`; a payload missing a required base
  field is rejected the same way every other operation type's own bad-payload case already is;
  `customer.update` processes before `sale.create` even when submitted after it, matching
  `customer.create`'s own ordering.
- **Live verification, real database:** a `POST /sync/push` batch containing a `customer.update`
  operation applies identically to the direct `PATCH` endpoint —
  [customers/specification.md §10](../customers/specification.md#10-test-plan) step 7.

**Sprint 36 additions:**
- Unit tests (`sync/service.test.ts`, mocking `stock-movements/repository`/`sync/repository`):
  `pullStockMovements`/`pullSales` return `has_more: true` and a non-null `next_cursor` when more
  rows exist beyond the requested limit; an empty page (no new rows since the caller's own cursor)
  echoes that cursor back rather than returning `null`; a truly-fresh pull (no cursor, no rows)
  returns `next_cursor: null`; the tenant-scoped, unfiltered query is passed through to the
  repository unchanged; `pullSales`' response includes `created_at` alongside `formatSale`'s own
  shape; a malformed cursor throws `VALIDATION_FAILED` for both, same as `pullProducts`.
- Repository tests (`sync_repository_test.dart`, real in-memory Drift database): pulls stock
  movements/sales across multiple pages and upserts them locally (a sale's line items land in
  `SaleLineItems` in the same iteration as their parent `Sales` row); the persisted `sync_cursors`
  row is read on the next `syncNow()` call, proving cross-cycle resumability; pulling an
  already-cached movement/sale updates it in place rather than duplicating it. The two new pull
  functions are optional, trailing constructor params (default to a no-op empty page) — every
  pre-existing 3-arg test call site needed no changes, the same precedent Sprint 34's
  `DriftSaleRepository` already established.
- **Live verification, real database, throwaway tenants (deleted after):** a product with opening
  stock, a completed sale (producing its own `sale` stock movement), and a manual `adjustment`
  movement are pulled back via `entity_type=stock_movements` across two pages (`limit=2` over 3
  rows) — `has_more`/`next_cursor` correct on every page, including the always-non-null last-row
  cursor on the final page and the caller's-own-cursor echo on a page with nothing new;
  `entity_type=sales` returns the completed sale with its line items intact; a second tenant sees
  zero of the first tenant's data via either pull (cross-tenant isolation); a malformed cursor and
  an unsupported `entity_type` both `422 VALIDATION_FAILED`. **24/24 checks passed.**

**Sprint 37 additions:**
- Unit tests (`sync/service.test.ts`, mocking `settings/repository`): `pullShopSettings` returns the
  tenant's row wrapped in the standard envelope with `next_cursor`/`has_more` always `null`/`false`;
  a tenant with no row returns an empty `data` array rather than throwing.
- Repository tests (`sync_repository_test.dart`, real in-memory Drift database): the pulled threshold
  and the role-probe result are both written into the new `ShopSettingsCache` table; a swallowed probe
  failure (`false`) never throws out of `syncNow()`; a `null` `shop_settings` pull (no server row)
  leaves a previously-cached threshold untouched rather than overwriting it with nothing; every
  pre-existing 3-through-5-arg `SyncRepository(...)` call site still works unchanged (two more
  optional trailing constructor params, same precedent §1 already established for Sprint 36's own
  two).
- **No live-HTTP verification of the mobile pull mechanics this sprint** — the server-side
  `pullShopSettings`/`low_stock_threshold_quantity` additions themselves *are* live-verified (11/11,
  [reports/specification.md §10](../reports/specification.md#10-test-plan)); the mobile half is
  local-only sync-cache plumbing, `flutter analyze`/`flutter test` is the verification bar, same
  position Sprint 30 already established for comparable mobile-only work.

**Sprint 39 addition:** `pullShopSettings` gains one more field, `receipt_footer_message`, read off
`receiptTemplateConfig`'s `footer_message` key (`null` when never configured or the JSON shape is
absent). `sync/service.test.ts` gains a case asserting it's present in the standard envelope; the
two pre-existing tests updated to expect the new key at `null`. Mobile: `sync_repository_test.dart`
gains two cases — the pulled footer message is written into `ShopSettingsCache`; unlike the
threshold, a real (non-null) settings pull **overwrites** a stale cached footer with `null` rather
than leaving it untouched, since "no footer configured" is a real, distinct state from "never
synced" for this field specifically (§1's own reasoning, restated in
`sync_repository.dart`'s `_refreshShopSettingsCache` doc comment). Live-verified as part of
[settings/specification.md §10](../settings/specification.md#10-test-plan)'s own 7/7 — this is a
field addition to an already-verified endpoint, not a new one.

**Explicitly deferred:** every other operation/entity type (§1), `sync_rejections`, the full
six-group push ordering (only `catalogue.*`/`trading_day.*`/`stock_movement.*` push remain
unbuilt), sync-api.md §7's full trigger set (connectivity listener, app foreground, background
timer), a persisted/resumable pull cursor for `products` specifically (§2, a deliberate, unchanged
trade-off, not an oversight).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [sync-api.md §1](../../11-api/sync-api.md#1-push--postsyncpush)–[§5](../../11-api/sync-api.md#5-duplicate-detection--replays-are-free) (push mechanics) | §2, §4, §10 | Met, for the two in-scope operation types only |
| [sync-api.md §6](../../11-api/sync-api.md#6-pull--getsyncpull) (cursor pull) | §4, §10 | Met, for `products`/`stock_movements`/`sales`/`shop_settings` (4 of 8 documented entity types) |
| [FR-071](../../03-functional-requirements/functional-requirements.md#group-j--reports-core-four)–[FR-074](../../03-functional-requirements/functional-requirements.md#group-j--reports-core-four) (Reports' own data dependency) | §1, §3, §10 | **Enabled, not yet consumed** — the local caches Reports needs now exist and stay current; M4 item 2 builds the report screens themselves |
| [milestones.md — M0 exit criterion](../../16-milestones/milestones.md#m0--walking-skeleton) ("...watch it sync...") | §9, §10 | Met — a device can now actually push its queue and pull products, on-device, observable via the home screen's own sync status |
| [sync-api.md §7](../../11-api/sync-api.md#7-what-triggers-a-sync-cycle) (sync-cycle triggers) | §9 | **Partially met** — automatic-once-per-session and manual triggers exist; connectivity-listener/app-foreground/background-timer triggers remain a named, deferred Phase 18 tuning decision |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | First version — written to drive Sprint 13's backend-only sync push/pull (backlog.md item 9). Scope deliberately narrow: two push operation types, one pull entity type, no mobile trigger, no `sync_rejections`. |
| 0.2.0 | 2026-08-13 | Sprint 14: mobile half built — `apps/mobile/lib/core/sync/` drains `outbound_queue` via push and refreshes local `products` via pull, triggered automatically once per session plus a manual "Sync now" button on the home screen. No pull-cursor persistence and no full trigger set (connectivity/foreground/timer) — both named, deliberate trade-offs, not oversights. |
| 0.3.0 | 2026-08-14 | Sprint 23: permission enforcement applied — both `POST /sync/push` and `GET /sync/pull` now require any active, non-deactivated role. |
| 0.4.0 | 2026-08-16 | Sprint 32 (backlog.md M3 item 2): `customer.create` added as a third push operation type, dispatching to `customersService.createCustomer` unchanged — ordered alongside `product.create`, both before `sale.create`, since a sale referencing a customer created in the same batch needs that customer to exist first. |
| 0.5.0 | 2026-08-16 | Sprint 33 (backlog.md M3 item 3): `return.create`/`return.approve`/`return.reject` added, ordered after `sale.create`. `return.approve`/`return.reject` use a dedicated sync-only payload schema (`{ id }`/`{ id, reason }`) distinct from their direct endpoints' own bodies, since a push batch has no URL to carry the target id — a structural difference, not an inconsistency. `ORIGINAL_SALE_NOT_FOUND` joins `NOT_FOUND` in the sync-context `DEPENDENCY_NOT_FOUND` remap. |
| 0.6.0 | 2026-08-16 | Sprint 35 (backlog.md M3 item 5): `customer.update` added — **this engine's first `.update` operation type of any kind** — ordered alongside `customer.create`, both before `sale.create`. Dispatches to the same, now-merge-aware `customersService.updateCustomer` `PATCH /customers/{id}` itself now uses, holding sync-api.md §1's "push calls the exact same service method as the direct endpoint" rule intact. |
| 0.7.0 | 2026-08-16 | Sprint 36 (backlog.md M4 item 1): `GET /sync/pull` gains `stock_movements`/`sales` entity types — the "reporting parity across devices" pull sync-api.md §6 has named since Phase 11 and this sprint finally implements, unblocking Reports (M4 item 2). New response fields `next_cursor`(always the last row seen)/`has_more` for these two types only, a dated correction to sync-api.md §6's own conflated semantics; mobile persists a per-entity-type resume cursor in a new local `sync_cursors` table (schema v6→v7), unlike `products`' own unchanged full-re-pull-every-cycle trade-off. Named, not silently deferred: Reports' Manager/Owner permission-matrix.md gate has no server call left to enforce it against once this data is on every device, so it will necessarily be client-side-only when M4 item 2 builds the report screens. Live-verified 24/24. |
| 0.8.0 | 2026-08-16 | Sprint 37 (backlog.md M4 item 2): `GET /sync/pull` gains a fourth entity type, `shop_settings` — deliberately minimal (`low_stock_threshold_quantity` only), never paginated (exactly one row per tenant). Closes Reports' second found gap: FR-074's low-stock report needs its threshold offline, and `shop_settings` had never been synced to any device despite being documented since Phase 11. Also closes the third gap §1 named at Sprint 36: mobile gains its first genuine client-side role-awareness, a probe against the already-existing `GET /users` endpoint (Manager/Owner-only), cached in a new local `ShopSettingsCache` table (schema v7→v8) alongside the threshold, fail-closed by default. Server-side additions live-verified 11/11; mobile half verified via `flutter analyze`/`flutter test` only (local-only plumbing, no live HTTP needed for it specifically). |
| 0.9.0 | 2026-08-17 | Sprint 39 (backlog.md M4 item 4): `shop_settings` pull gains a second field, `receipt_footer_message`, so `ReceiptFormatter` can print the Owner-configured footer message fully offline (FR-077/FR-078) — the same "extend the narrow read-only cache" shape §1 already anticipated. Mobile writes it into `ShopSettingsCache` (schema v8→v9), with one real distinction from the threshold's own behaviour: a genuine settings pull overwrites a stale cached footer with `null` (a real "not configured" state), rather than leaving it untouched the way a `null` *pull result entirely* still does for both fields. Verified as part of settings/specification.md §10's own 7/7 (a field addition to an already-verified endpoint). |
