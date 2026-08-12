# Module Specification — Audit Log

> **Status:** 🟢 Approved
> **Module:** Audit Log
> **Slice:** V1 — this document scopes only backlog.md item 8's M0-minimal cut, not the full V1
> shape (§1)
> **Version:** 0.1.0
> **Last updated:** 2026-08-13
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 12](../../17-sprints/sprint-12.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Writes one audit-log entry the moment a sale completes —
[backlog.md item 8](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed) ("Audit
log: one entry per completed sale, per DR-025"), the last of M0's three atomically-written-alongside
concerns (a sale, its stock movement (Sprint 11), and now its audit entry).
[milestones.md — M0](../../16-milestones/milestones.md#m0--walking-skeleton)'s exit criterion
requires "an audit-log entry and a stock-ledger entry both present and correct" for the one
completed sale in the walking-skeleton demo — this is that requirement's audit half.

**Deliberately narrow scope, found while writing this spec:** [audit-model.md §1](../../07-database/audit-model.md#1-what-triggers-an-audit-entry)
and [DR-025](../../03-functional-requirements/business-rules.md) together describe a much larger
trigger list — stock movements, returns, trading-day transitions, role/device/settings/user
changes — of which this sprint writes exactly one: `sale.completed`. **A real, now-visible gap**:
Sprint 11 already writes `stock_movements` rows (`opening` and `sale`), and audit-model.md §1's own
first trigger row is "Stock movement recorded (any type)" — so every stock movement created since
Sprint 11 has zero audit coverage, and will continue to after this sprint too. Not fixed here,
because backlog item 8's own estimate (1 person-day) scopes to sale completion only, matching
M0's own exit criterion's literal wording ("an audit-log entry... for the completed sale"), and
expanding scope mid-item is exactly the kind of silent scope creep this project's practice avoids.
Named directly here instead, as the concrete next candidate once M0's own remaining items close.

Also out of scope: any `GET /audit-log` read endpoint (audit-model.md §3's Owner/Manager-only read
restriction needs Roles & Permissions, which doesn't exist — M1 scope), and any mobile UI (this is
an online-only reporting surface per audit-model.md §3, never a till feature).

## 2. Business rules

- [DR-025](../../03-functional-requirements/business-rules.md): a completed sale produces exactly
  one corresponding audit-log entry, created within the same transaction as the sale itself —
  enforced here via an explicit `prisma.$transaction` wrapping both writes (verified live, §10).
- An audit-log entry is immutable once written — by construction (no update/delete code path
  exists), the same reasoning `stock_movements` already established
  ([inventory/specification.md §2](../inventory/specification.md#2-business-rules)); no explicit
  database-level `REVOKE` is added, matching that module's own stated precedent rather than
  introducing a stricter guarantee for this table alone.
- Per [audit-model.md §2](../../07-database/audit-model.md#2-what-is-stored-per-entry), no secret
  or credential reaches `after_state` — trivially true this sprint, since the snapshot is built from
  fields (`status`, invoice number, totals, timestamp) that were never secrets to begin with.

## 3. Database tables and relationships

New table: `audit_log`, an M0-minimal slice of
[schema-server.md](../../07-database/schema-server.md) Context 1. Implements every documented
column: `id`, `tenant_id`, `store_id` (nullable), `actor_user_id`, `action`, `entity_type`,
`entity_id`, `before_state`, `after_state`, `created_at` — this table's full column shape is
already this narrow in the approved design, unlike `products`/`sales`/`stock_movements`, which each
omit real columns their schema-server.md counterpart has. The only thing narrowed this sprint is
**which actions ever populate a row**, not the row's own shape (§1).

`before_state` is always `null` this sprint — `sale.completed` is a creation event, and a fresh
insert has no prior state to snapshot; `before_state` becomes meaningful once a future sprint audits
a *transition* (e.g. `sale.cancelled`, a status change with genuine before/after states).

RLS: tenant-scoped, same template as every other M0-minimal table
([supabase/sql/007_rls_audit_log.sql](../../../supabase/sql/007_rls_audit_log.sql)).

## 4. API contract

No new endpoint. `POST /api/v1/sales` is the only API surface this sprint touches, and its
request/response shape is unchanged — the audit entry it now also writes is invisible to the
caller, same as Sprint 11's stock movement. `GET /audit-log` (audit-model.md §3's read surface)
remains undocumented at the endpoint-contract level and unbuilt (§1).

## 5. Validation rules (client and server)

None new — every field on the audit-log row is derived entirely from already-validated `POST
/sales` input (§4/§5 of [pos/specification.md](../pos/specification.md)), never from new request
input.

## 6. Error handling and user-facing messages

None new. An audit-log write is never independently rejectable; it either commits with the sale or
the whole transaction (sale, stock movements, and audit entry together) rolls back.

## 7. Offline behaviour

Rides `POST /sales`'s own connectivity model unchanged (currently requires connectivity; no mobile
offline queue path calls it yet). No independent offline behaviour exists for this module.

## 8. Realtime behaviour

None specified for V1 in this sprint's scope — audit-model.md §3 describes this as an
online-only, API-read reporting surface, not a live-push feature.

## 9. UI specification

None this sprint — no `GET /audit-log` endpoint and no mobile screen exist yet (§1).

## 10. Test plan

**Sprint 12 scope:**
- No new unit tests were needed in `pos/service.test.ts` — that file mocks `./repository` entirely,
  and the audit-log write lives inside `repository.ts`'s own transaction, matching Sprint 11's
  stock-movement precedent (proven live instead, not unit-mocked).
- **Live verification, real database, throwaway tenants (deleted after):**
  1. `POST /sales` for a real sale → exactly one `audit_log` row exists, `action = 'sale.completed'`,
     `entity_type = 'sale'`, `entity_id` = the sale's id, `actor_user_id` = the creating user,
     `store_id` = the sale's store, `before_state` is `null`, `after_state` matches the sale's own
     computed totals.
  2. Replaying the identical sale-creation request → still exactly one `audit_log` row (idempotent,
     via `service.ts`'s existing `findSaleById` short-circuit — `repository.createSale` is never
     called a second time, so no second insert is attempted).
  3. Cross-tenant RLS: a second tenant's session reads zero of the first tenant's `audit_log` rows
     via PostgREST directly.

**Explicitly deferred:** every other audit-model.md §1 trigger (§1's named gap), `GET /audit-log`,
any mobile UI.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [DR-025](../../03-functional-requirements/business-rules.md) (sale produces exactly one audit entry, same transaction) | §2, §10 | Met, for `sale.completed` only — **not met** for stock movements/returns/trading-day/role/device/settings/user changes (§1) |
| [milestones.md — M0 exit criterion](../../16-milestones/milestones.md#m0--walking-skeleton) (audit-log entry present and correct for the completed sale) | §10 | Met |
| [audit-model.md §2](../../07-database/audit-model.md#2-what-is-stored-per-entry) (actor/action/entity/timestamp/before-after stored) | §3, §10 | Met |
| [audit-model.md §3](../../07-database/audit-model.md#3-who-can-read-it) (Owner/Manager-only read) | — | **Not met this sprint** — no read endpoint exists yet, named future scope (§1) |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-13 | First version — written to drive Sprint 12's minimal `sale.completed` audit-log write (backlog.md item 8). Scope deliberately narrow: one trigger only, no read endpoint, no mobile UI. Named a real, now-visible gap: `stock_movements` (Sprint 11) has no audit coverage, and won't after this sprint either. |
