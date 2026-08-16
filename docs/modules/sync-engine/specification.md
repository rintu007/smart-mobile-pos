# Module Specification — Offline Sync Engine

> **Status:** 🟢 Approved
> **Module:** Offline Sync Engine
> **Slice:** V1 — this document scopes only backlog.md item 9's M0-minimal cut, not the full
> [sync-api.md](../../11-api/sync-api.md) shape (§1)
> **Version:** 0.4.0
> **Last updated:** 2026-08-16
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
- Push handles three operation types (`product.create`, `sale.create`, and — added Sprint 32,
  [customers/specification.md §1a](../customers/specification.md#1a-sprint-32--customers-mobile-m3-item-2)
  — `customer.create`) — sync-api.md §2's full six-group ordering (`catalogue.*`, `customer.*`,
  `stock_movement.*`, `trading_day.*`, `sale.*`, `return.*`) still collapses to a handful of groups
  this sprint, since no other operation type has a client-facing write path yet. `customer.create`
  is ordered alongside `product.create`, both before `sale.create` — a sale created in the same
  batch as a customer it references needs that customer to exist first, the same dependency reason
  `product.create` already precedes `sale.create`. `stock_movement.*` push (`opening`/`adjustment`)
  in particular stays out of scope — Sprint 11 built `opening`/`sale` movements as **server-side
  side effects only**, per [inventory/specification.md §1](../inventory/specification.md#1-purpose-and-business-context);
  there is no public `POST /stock-movements` for a client to push to yet.
- Pull handles exactly one entity type (`products`) — sync-api.md §6 lists eight
  (`products`, `categories`, `units`, `customers`, `user_store_roles`, `shop_settings`,
  `sync_rejections`, cross-device `stock_movements`/`sales`); every other one is undocumented at
  the endpoint level until this sprint's minimal cut proves the cursor mechanism works at all.
- No `sync_rejections` table/read path — a rejected operation's reason is returned synchronously in
  the same push response (§3 below); nothing is queryable after the fact yet.

## 2. Business rules

- [sync-api.md §5](../../11-api/sync-api.md#5-duplicate-detection--replays-are-free): no new
  idempotency mechanism is built here — `product.create`/`sale.create` push operations are handled
  by calling the **exact same service functions** (`products.service.createProduct`,
  `pos.service.createSale`) the direct endpoints already call, so their existing
  id-based idempotent-creation guarantee (Sprint 04/05) applies unchanged. Resubmitting an
  unresolved batch is safe by construction, not by anything new this module adds.
- [sync-api.md §2](../../11-api/sync-api.md#2-ordering--dependency-groups-not-raw-client-order):
  within one push request, every `product.create`/`customer.create` operation is processed before
  every `sale.create` operation, preserving each group's own relative submitted order — the
  collapsed subset of the full ordering, per §1.
- [sync-api.md §3](../../11-api/sync-api.md#3-partial-failure-semantics--every-operation-gets-its-own-verdict):
  one operation's rejection never fails the batch or blocks independent operations after it —
  enforced by processing each operation in its own `try`/`catch`, never letting one operation's
  thrown error abort the loop.
- [sync-api.md §4](../../11-api/sync-api.md#4-why-dependency_not_found-is-not-not_found): a
  `sale.create` operation whose `product_id` doesn't exist server-side yet is rejected with
  `DEPENDENCY_NOT_FOUND`, not `NOT_FOUND` — the one place this module's error handling genuinely
  diverges from the direct endpoint's own (`POST /sales` still returns plain `NOT_FOUND` when
  called directly; only the sync-push context remaps it, since only there is "not synced yet"
  actually a plausible, retryable explanation).
- [api-principles.md §4](../../11-api/api-principles.md#4-pagination--cursor-only): pull is
  cursor-only, `(updated_at, id)` for `products` (a Tier 1 table) — no offset pagination.
- **Mobile, Sprint 14: no pull cursor is persisted between sync runs.** Every call to `syncNow()`
  pages `products` from the start, upserting each row by `id` (idempotent — a re-pulled row simply
  overwrites the locally cached one, per schema-local.md's `products` divergence note). A
  persisted, resumable cursor is a real efficiency improvement `sync-api.md §6` anticipates, but
  M0's product-catalogue size makes it unnecessary, and skipping it avoids adding a new local table
  (and the schema migration that would require) against the founder's own already-installed,
  persistent app — a deliberate, named trade-off, not an oversight.
- A queued operation's `outbound_queue` row is only ever updated in response to that operation's
  own result in the push response — a network failure that never reaches the server (no response
  at all) leaves every affected row untouched, safe to resend in full on the next attempt.

## 3. Database tables and relationships

**Server:** no new table. Push writes through `products`/`stock_movements`/`sales`/
`sale_line_items`/`sale_payments`/`audit_log` exactly as the direct endpoints already do (Sprints
04, 05, 11, 12) — this module owns no storage of its own, only the batch/cursor mechanics around
calling existing service functions. Pull reads `products` unchanged.

**Mobile (Sprint 14):** no new local table either. Push reads `outbound_queue` (already built,
backlog item 4) and updates each row's own `status`/`attempt_count`/`last_attempted_at`/
`rejection_reason` per its push result — the exact columns schema-local.md already defines for
this table's Sync Item state machine, none added. Pull upserts into the local `products` table
(already built) — no local pull-cursor table, per §2's named trade-off.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/sync/push` | **Implemented Sprint 13, extended Sprint 32.** Request: `{ operations: [{ type, client_operation_id, payload }] }`, `type ∈ {'product.create', 'sale.create', 'customer.create'}`, `payload` validated against the exact same Zod schema the direct endpoint uses (`createProductRequestSchema` / `createSaleRequestSchema` / `createCustomerRequestSchema`) — per sync-api.md §1's "push does not define a second, parallel request schema." Response: `{ results: [{ client_operation_id, status: 'accepted' \| 'rejected', entity_id?, error? }] }`, one result per submitted operation, in the request's own original order. Requires any active role (`requirePermission`, Sprint 23) — sync is a device-level mechanism, not itself a permission-matrix.md capability, so the check here is simply "has an active, non-deactivated role at all," meaningfully blocking a revoked user even from syncing. |
| `GET /api/v1/sync/pull` | **Implemented this sprint**, `entity_type=products` only. `?entity_type=products&cursor=<opaque>&limit=<n, default 50, max 200>` → `{ data: [...], next_cursor }`, per api-principles.md §4. Any other `entity_type` value is rejected with `VALIDATION_FAILED` (422) — not a silent empty result. Requires any active role (Sprint 23), same reasoning as push. |
| Every other entity type's pull, `sync_rejections`, the full six-group push ordering | **Already documented** in [sync-api.md](../../11-api/sync-api.md), **not implemented, and not needed this sprint** — see §1. |

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `operations` | Array, 1–200 elements |
| `operations[].type` | Enum: `'product.create'`, `'sale.create'`, `'customer.create'` (Sprint 32) — any other value is rejected with `VALIDATION_FAILED` at the operation level (its own `results[]` entry, not a whole-batch 422) |
| `operations[].client_operation_id` | UUIDv4, required |
| `operations[].payload` | Validated per-type against the existing direct-endpoint schema — a payload failing that schema is rejected with `VALIDATION_FAILED` at the operation level |
| `entity_type` (pull) | Enum: `'products'` only this sprint |
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

**Explicitly deferred:** every other operation/entity type (§1), `sync_rejections`, the full
six-group push ordering, sync-api.md §7's full trigger set (connectivity listener, app foreground,
background timer), a persisted/resumable pull cursor (§2).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [sync-api.md §1](../../11-api/sync-api.md#1-push--postsyncpush)–[§5](../../11-api/sync-api.md#5-duplicate-detection--replays-are-free) (push mechanics) | §2, §4, §10 | Met, for the two in-scope operation types only |
| [sync-api.md §6](../../11-api/sync-api.md#6-pull--getsyncpull) (cursor pull) | §4, §10 | Met, for `products` only |
| [milestones.md — M0 exit criterion](../../16-milestones/milestones.md#m0--walking-skeleton) ("...watch it sync...") | §9, §10 | Met — a device can now actually push its queue and pull products, on-device, observable via the home screen's own sync status |
| [sync-api.md §7](../../11-api/sync-api.md#7-what-triggers-a-sync-cycle) (sync-cycle triggers) | §9 | **Partially met** — automatic-once-per-session and manual triggers exist; connectivity-listener/app-foreground/background-timer triggers remain a named, deferred Phase 18 tuning decision |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | First version — written to drive Sprint 13's backend-only sync push/pull (backlog.md item 9). Scope deliberately narrow: two push operation types, one pull entity type, no mobile trigger, no `sync_rejections`. |
| 0.2.0 | 2026-08-13 | Sprint 14: mobile half built — `apps/mobile/lib/core/sync/` drains `outbound_queue` via push and refreshes local `products` via pull, triggered automatically once per session plus a manual "Sync now" button on the home screen. No pull-cursor persistence and no full trigger set (connectivity/foreground/timer) — both named, deliberate trade-offs, not oversights. |
| 0.3.0 | 2026-08-14 | Sprint 23: permission enforcement applied — both `POST /sync/push` and `GET /sync/pull` now require any active, non-deactivated role. |
| 0.4.0 | 2026-08-16 | Sprint 32 (backlog.md M3 item 2): `customer.create` added as a third push operation type, dispatching to `customersService.createCustomer` unchanged — ordered alongside `product.create`, both before `sale.create`, since a sale referencing a customer created in the same batch needs that customer to exist first. |
