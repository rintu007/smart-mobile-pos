# Module Specification — Offline Sync Engine

> **Status:** 🟢 Approved
> **Module:** Offline Sync Engine
> **Slice:** V1 — this document scopes only backlog.md item 9's M0-minimal cut, not the full
> [sync-api.md](../../11-api/sync-api.md) shape (§1)
> **Version:** 0.1.0
> **Last updated:** 2026-08-13
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
(products: Sprint 04 backend / Sprint 07 mobile; sales: Sprint 05 backend / Sprint 09 mobile): this
sprint builds the **backend push/pull endpoints only**. Nothing in `apps/mobile` calls them yet —
the outbound queue still isn't drained, and no mobile sync trigger (connectivity listener, app
foreground, background timer, per [sync-api.md §7](../../11-api/sync-api.md#7-what-triggers-a-sync-cycle))
exists. That is the concrete next sprint, not this one — named here rather than implied.

**Narrower still than [sync-api.md](../../11-api/sync-api.md) itself**, even for the backend half:
- Push handles exactly two operation types (`product.create`, `sale.create`) — sync-api.md §2's
  full six-group ordering (`catalogue.*`, `customer.*`, `stock_movement.*`, `trading_day.*`,
  `sale.*`, `return.*`) collapses to two groups this sprint, since no other operation type has a
  client-facing write path yet. `stock_movement.*` push (`opening`/`adjustment`) in particular
  stays out of scope — Sprint 11 built `opening`/`sale` movements as **server-side side effects
  only**, per [inventory/specification.md §1](../inventory/specification.md#1-purpose-and-business-context);
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
  within one push request, every `product.create` operation is processed before every
  `sale.create` operation, preserving each group's own relative submitted order — the two-group
  collapse of the full ordering, per §1.
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

## 3. Database tables and relationships

No new table. Push writes through `products`/`stock_movements`/`sales`/`sale_line_items`/
`sale_payments`/`audit_log` exactly as the direct endpoints already do (Sprints 04, 05, 11, 12) —
this module owns no storage of its own, only the batch/cursor mechanics around calling existing
service functions. Pull reads `products` unchanged.

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/sync/push` | **Implemented this sprint.** Request: `{ operations: [{ type, client_operation_id, payload }] }`, `type ∈ {'product.create', 'sale.create'}`, `payload` validated against the exact same Zod schema the direct endpoint uses (`createProductRequestSchema` / `createSaleRequestSchema`) — per sync-api.md §1's "push does not define a second, parallel request schema." Response: `{ results: [{ client_operation_id, status: 'accepted' \| 'rejected', entity_id?, error? }] }`, one result per submitted operation, in the request's own original order. |
| `GET /api/v1/sync/pull` | **Implemented this sprint**, `entity_type=products` only. `?entity_type=products&cursor=<opaque>&limit=<n, default 50, max 200>` → `{ data: [...], next_cursor }`, per api-principles.md §4. Any other `entity_type` value is rejected with `VALIDATION_FAILED` (422) — not a silent empty result. |
| Every other entity type's pull, `sync_rejections`, the full six-group push ordering | **Already documented** in [sync-api.md](../../11-api/sync-api.md), **not implemented, and not needed this sprint** — see §1. |

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `operations` | Array, 1–200 elements |
| `operations[].type` | Enum: `'product.create'`, `'sale.create'` — any other value is rejected with `VALIDATION_FAILED` at the operation level (its own `results[]` entry, not a whole-batch 422) |
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

This module *is* the mechanism that makes offline writes eventually durable server-side — but per
§1, nothing in `apps/mobile` calls it yet, so no mobile-observable offline behaviour exists this
sprint. The endpoints themselves obviously require connectivity to be called at all, same as any
`POST`/`GET`.

## 8. Realtime behaviour

None specified for V1 in this sprint's scope — pull is poll/pull-driven (sync-api.md §7's
connectivity/foreground/backstop-timer triggers), not a push subscription.

## 9. UI specification

None this sprint — no mobile screen or background trigger exists yet (§1).

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

**Explicitly deferred:** every other operation/entity type (§1), `sync_rejections`, the mobile sync
trigger and outbound-queue drain (the concrete next sprint), the full six-group push ordering.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [sync-api.md §1](../../11-api/sync-api.md#1-push--postsyncpush)–[§5](../../11-api/sync-api.md#5-duplicate-detection--replays-are-free) (push mechanics) | §2, §4, §10 | Met, for the two in-scope operation types only |
| [sync-api.md §6](../../11-api/sync-api.md#6-pull--getsyncpull) (cursor pull) | §4, §10 | Met, for `products` only |
| [milestones.md — M0 exit criterion](../../16-milestones/milestones.md#m0--walking-skeleton) ("...watch it sync...") | §10 | Backend half met — the mobile trigger that would make this observable end to end is the next sprint |
| [sync-api.md §7](../../11-api/sync-api.md#7-what-triggers-a-sync-cycle) (sync-cycle triggers) | — | **Not met** — no mobile trigger exists yet (§1) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | First version — written to drive Sprint 13's backend-only sync push/pull (backlog.md item 9). Scope deliberately narrow: two push operation types, one pull entity type, no mobile trigger, no `sync_rejections`. |
