# Sprint 12

> **Dates:** 2026-08-13 – 2026-08-13 (single-day, same pattern as Sprints 02–11)
> **Milestone:** M0 — Walking Skeleton (backlog item 8)
> **Status:** Closed

## Goal

Write one audit-log entry, in the same transaction as the sale itself, every time a sale
completes — [backlog.md item 8](backlog.md#1-m0--walking-skeleton-fully-decomposed) ("Audit log:
one entry per completed sale, per DR-025"), the last piece
[milestones.md — M0](../16-milestones/milestones.md#m0--walking-skeleton)'s exit criterion needs
before item 11's end-to-end proof can be attempted honestly.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| Audit log: one entry per completed sale, same transaction as the sale | Audit Log | 1.0 | 6 (POS core loop, done Sprint 09) |

Backend-only, server side — no mobile UI, no read endpoint. See
[audit-log/specification.md §1](../modules/audit-log/specification.md#1-purpose-and-business-context)
for the exact cut and the real gap it names (stock-movement audit coverage, from Sprint 11, remains
unbuilt after this sprint too).

## Capacity check

1.0 person-day against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `audit-log/specification.md` (new), backlog.md, module
      registry, implementation-log, README bumps — inside the estimate above.

## Risks

- **Scope temptation, named directly**: audit-model.md §1 lists ten trigger types; this sprint
  builds one. The stock-movement gap in particular is now visible in a way it wasn't before Sprint
  11 landed — flagged here as the concrete next candidate rather than expanded into mid-sprint,
  matching [inventory/specification.md](../modules/inventory/specification.md)'s own precedent of
  naming rather than silently absorbing adjacent scope.
- **No new device-target or atomicity-pattern risk** — same explicit `prisma.$transaction` approach
  Sprint 11 already established and verified live.

## Definition of Done

- [x] `audit-log/specification.md` (new), all 11 sections, 🟢 Approved.
- [x] `audit_log` table (full schema-server.md column shape — this table was already this narrow),
      RLS enabled (`supabase/sql/007_rls_audit_log.sql`), applied to the live Supabase database.
- [x] `POST /api/v1/sales` writes exactly one `audit_log` row (`action = 'sale.completed'`) in the
      same transaction as the sale and its stock movements.
- [x] `tsc --noEmit` / `eslint` clean; existing unit tests (18/18) still pass unchanged.
- [x] Live verification against the real database, throwaway tenants deleted after — audit-entry
      shape, idempotent replay, and a cross-tenant RLS proof on `audit_log` itself.
- [x] No secret, token, or key written to logs or committed to source.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** every other audit-model.md §1 trigger,
`GET /audit-log`, any mobile UI, M0's own remaining items (9–11).

## Demo script

**Run 2026-08-13** against the live database, via real HTTP requests to a local dev server pointed
at production Supabase, throwaway tenants deleted after:

1. Onboard tenant A. ✅
2. Onboard tenant B, for the cross-tenant check. ✅
3. `POST /api/v1/products` then `POST /api/v1/sales` as tenant A — exactly one `audit_log` row,
   `action = 'sale.completed'`, `entity_type = 'sale'`, correct `entity_id`/`actor_user_id`/
   `store_id`, `before_state` null, `after_state` matching the sale's computed totals. ✅
4. Replay the identical sale-creation request — still exactly one `audit_log` row. ✅
5. As tenant B's session, read `audit_log` filtered to tenant A's sale directly via PostgREST —
   zero rows returned. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | Sprint 12 planned and built same-day: `audit-log/specification.md` written first, `audit_log` table + RLS added, one `sale.completed` entry wired into `POST /sales`'s existing transaction, live-verified against the real database including a cross-tenant RLS proof. Named the stock-movement audit-coverage gap directly rather than silently expanding scope to cover it. |
