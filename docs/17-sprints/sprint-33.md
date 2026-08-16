# Sprint 33

> **Dates:** 2026-08-16 – 2026-08-16 (single-day, same cadence as every prior sprint)
> **Milestone:** M3 — Customers, Returns & Refund, conflict-resolution field-merge (backlog item 3 — Returns & Refund, server)
> **Status:** Closed — M3 item 3 done. M3 now has items 4–5 remaining.

## Goal

Returns & Refund (server): `returns`/`return_line_items` tables, `POST /returns` (auto-approve vs.
`pending_approval`, DR-013–016), a `return` stock movement, `GET /returns/{id}`/`GET /returns`/
`GET /returns/approvals`, `POST /returns/{id}/approve`/`reject`, and the `return.create`/
`return.approve`/`return.reject` sync-push operation types —
[returns/specification.md](../modules/returns/specification.md). M3's third item, per
[backlog.md §4](backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point).

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `returns`/`return_line_items` tables, all five `POST`/`GET /returns*` endpoints, `return` stock movement, sync-push types | Returns & Refund (server) | 3 | 1 (Customers, server) |

## Design decisions, found while writing the spec

Full detail in [returns/specification.md §1](../modules/returns/specification.md#1-purpose-and-business-context).

1. **`returns` needed a `created_by`/`created_at` column pair schema-server.md's Context 6 table
   never listed.** `GET /returns`' own documented Cashier "own device only" scope is unimplementable
   without a column recording who filed the return — the same `created_by`-as-device-substitute
   adaptation `sales-invoices/specification.md` already made. Added as a dated correction.
2. **The documented separate `client_operation_id UNIQUE` column has no working precedent anywhere
   else in this schema.** Every other client-generated-idempotency table (`sales`, `trading_days`,
   `customers`) reuses its own `id` as the sole idempotency key. Dropped in favour of `id` alone,
   the same category of named deviation Sprint 22 made for `movement_type: 'opening'` and Sprint 26
   made for `trading_days.device_id`.
3. **Only 3 of the documented 5 `status` values are reachable this sprint** —
   `initiated`/`approved` are documented-but-unreachable, the same shape Sprint 22 already
   established for `movement_type: 'opening'`.
4. **`reject`'s `reason` has no column** — captured in the rejection's own `audit_log` entry
   (`after_state.reason`) instead of a dedicated schema column.
5. **DR-014's per-unit-price rounding ambiguity, resolved**: a full-remaining-quantity return
   refunds the exact remaining amount (no division, no drift); a genuine partial return uses
   `roundFraction` (exported from `pos/service.ts` for this reuse) proportionally against the
   line's original total.
6. **Cross-module sale/line-item reads go through a new `posService.getCompletedSaleForReturn`**,
   service-to-service — following Sprint 32's own `customerExists` precedent, not
   `products/repository.ts`'s older, separately-named repository-layer shortcut.
7. **DR-017/018's actual mechanism**: `approveReturn`/`rejectReturn` re-resolve the acting user's
   role fresh from `user_store_roles`, unconditionally — necessary for the sync-push path, whose own
   Route Handler gate is generic (any active role) rather than approve/reject-specific, closing the
   real gap [offline-workflows.md Finding 1](../06-workflows/offline-workflows.md#finding-1--offline-approvals-are-provisional-until-sync-and-that-needs-a-defined-ux)
   named.

## Capacity check

3 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: none used as rework — no bug found post-implementation this sprint,
      the design decisions above were resolved at spec-writing time, before code.
- [x] Documentation capacity reserved: `returns/specification.md` (new), `sync-engine/specification.md`,
      `pos/specification.md`, module registry, backlog.md, implementation-log, READMEs.

## Risks

- **None new.** The stock-movement/audit-log transaction pattern reuses `pos/repository.ts`'s
  `createSale` and `trading-day/repository.ts`'s own already-proven shape exactly; the sync-push
  extension is additive, the same low-risk shape every prior operation-type addition has been.

## Definition of Done

- [x] `returns`/`return_line_items` Prisma models + migration (`20260816080639_add_returns_m3`),
      applied live; RLS (`supabase/sql/015_rls_returns.sql`), applied live —
      `return_line_items` deliberately has no independent RLS, mirroring `sale_line_items`'s own
      precedent.
- [x] `returns/schema.ts`, `returns/repository.ts`, `returns/service.ts` — `createReturn`
      (idempotent replay, DR-013 quantity check, DR-014 refund computation, DR-015 auto-approve/
      pending_approval split), `getReturnDetail`, `approveReturn`/`rejectReturn` (idempotent
      state-transition, DR-017/018 role re-check), `listReturns` (Cashier `created_by`-scoped,
      Manager/Owner store-wide), `listApprovals` (`status` forced to `pending_approval`).
- [x] Route Handlers: `returns/route.ts` (POST, GET), `returns/approvals/route.ts` (GET),
      `returns/[id]/route.ts` (GET), `returns/[id]/approve/route.ts`, `returns/[id]/reject/route.ts`.
- [x] `pos/service.ts` gains `getCompletedSaleForReturn` (new export) and `roundFraction` (existing
      helper, made public) for `returnsService`'s own reuse.
- [x] `settings/service.ts`'s `getMoneySettings` extended with `returnAutoApprovalThresholdMinorUnits`.
- [x] Sync engine: `return.create`/`return.approve`/`return.reject` operation types
      (`sync/schema.ts`, `sync/service.ts`, `TYPE_ORDER`), `return.create`'s
      `ORIGINAL_SALE_NOT_FOUND` remapped to `DEPENDENCY_NOT_FOUND` in the sync-push context, the
      same shape `sale.create`'s own `NOT_FOUND` remap already established.
- [x] Unit tests: `returns/service.test.ts` (24 new cases, including the exact-vs-proportional
      rounding distinction on a deliberately-not-evenly-divisible line), `sync/service.test.ts`
      (9 new cases). `pos/service.test.ts` fixture updated for the new settings field.
- [x] `tsc --noEmit`/`eslint`/`vitest` (182 total web tests) all clean; production build verified
      locally before live verification.
- [x] Live verification against the real database, throwaway tenants (deleted after) — 22/22 checks.
- [x] `returns/specification.md` (new), `sync-engine/specification.md`, `pos/specification.md` all
      updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** mobile UI (`/returns/new`, `/returns/:id`,
`/returns/approvals`), local `returns`/`return_line_items` Drift tables, outbound-queue enqueue —
all named, M3 item 4's scope specifically.

## Demo script

**Server, run 2026-08-16** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. A completed sale with 3 line items (one below the return threshold, two above). ✅
2. A partial return of the below-threshold line (1 of 3 units) auto-completes, refund exact
   (5000 minor units), stock balance reflects it immediately. ✅
3. A full return of an above-threshold line creates a `pending_approval` return, no stock movement
   yet. ✅
4. Requesting more than the remaining quantity on the partially-returned line → `409
   RETURN_QUANTITY_EXCEEDS_SOLD`. ✅
5. Approving the pending return as a Cashier → `403 PERMISSION_DENIED`; as the Manager → `200
   completed`, stock movement now present. ✅
6. A replayed approve is an idempotent no-op. ✅
7. A fresh pending return, rejected with a reason → `200 rejected`; a follow-up approve on it →
   `409 RETURN_ALREADY_DECIDED`. ✅
8. `GET /returns` — the filing Cashier sees their own 3 returns; a different Cashier sees none of
   them; the Manager sees all 3. ✅
9. `GET /returns/approvals` — empty once both pending returns are decided, ignoring a `status`
   query override. ✅
10. `POST /sync/push` with a `return.create` operation → `accepted`, immediately fetchable via
    `GET /returns/{id}`. ✅
11. Cross-tenant RLS: tenant B cannot resolve tenant A's return. ✅

**Unit tests, run 2026-08-16**: `vitest run` — 182/182 passing (33 new: 24 in
`returns/service.test.ts`, 9 in `sync/service.test.ts`).

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: writing the specification
before any code surfaced two real, load-bearing gaps in schema-server.md's own Context 6 design
(the missing `created_by`/`created_at` pair, the redundant `client_operation_id` column) that would
otherwise have been discovered mid-implementation or, worse, shipped silently — the DR-014 rounding
ambiguity in particular would have been easy to get wrong in a way that only surfaces as a
customer-facing pocket-change discrepancy months later, not a test failure. The spec-first discipline
paid for itself concretely this sprint, not just procedurally.

**M3 now has items 4–5 remaining: Returns & Refund (mobile), conflict-resolution field-merge** — per
[backlog.md §4](backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | Sprint 33 planned and built same-day: Returns & Refund (server) built and live-verified (22/22). Two real schema-server.md gaps found and corrected while writing the spec, before code. |
