# Module Specification — Cash Drawer / Trading Day

> **Status:** 🟢 Approved
> **Module:** Cash Drawer / Day Close
> **Slice:** V1, minimal — `trading_days` table, `POST /trading-days/open`, `POST
> /trading-days/{id}/close`, `POST /trading-days/{id}/reopen`, `GET /trading-days/current`;
> `sales.trading_day_id` threaded through `POST /sales` but not yet gated (§1)
> **Version:** 0.1.1
> **Last updated:** 2026-08-20
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 26](../../17-sprints/sprint-26.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

[backlog.md M2 item 2](../../17-sprints/backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point):
cash-drawer reconciliation state, gating `POST /sales` on an open trading day. The item's own
decomposition already named a real, unresolved design gap rather than guessing at it upfront:
[schema-server.md](../../07-database/schema-server.md) scopes `trading_days` per `device_id`, but
no `devices` table exists anywhere in code (Authentication's device-registration slice remains
unbuilt, [module registry](../README.md)).

**The scoping decision, made now that this item's sprint is actually being planned:** this
implementation scopes "is there an open day" by **`(tenant_id, store_id)`, not per-device and not
per-user**. Three independent sources converge on this, not just the absence of `device_id`:

- [offline-workflows.md — Finding 2](../../06-workflows/offline-workflows.md#finding-2--trading-day-is-a-shared-store-level-concept-and-multi-device-shops-need-a-rule)'s
  own text: "a single physical cash drawer suggests one shared day-state" — the per-device design
  in schema-server.md is explicitly a *sidestep* of the multi-device conflict question, not a claim
  that per-device is the more physically correct model.
- [state-machines.md §"Trading Day"](../../06-workflows/state-machines.md#trading-day) states its
  own base assumption plainly: "this state machine assumes one Trading Day per store... correct for
  a single-device shop."
- [permission-matrix.md — Cash Drawer / Day Close](../../05-personas/permission-matrix.md#cash-drawer--day-close)
  grants **every role** open/close (Manager/Owner-only for reopen) — there is no per-user ownership
  semantic to preserve. A `(tenant, store, user)` scoping (the shape Sprint 24's `GET /sales`
  precedent might otherwise suggest) would let two different Cashiers on the same physical till both
  hold an "open day" simultaneously, splitting one drawer's `expected_cash` across two rows — a real
  correctness defect a single-device shop (V1's target, per personas.md) would hit immediately on
  a shift handoff. Store-level scoping avoids that outright and degrades to exactly "one open day
  per device" for the single-device case this project already treats as the acceptable V1 target.

This is a genuine deviation from schema-server.md's documented column (`device_id NOT NULL`), named
and dated here rather than silently substituted — `device_id` is dropped from this implementation's
`trading_days` table entirely, not renamed. Revisit when Authentication's device-registration slice
lands and multi-device shops become real V1 scope, not before.

**Status, 2026-08-20:** the first half of that trigger has landed — Sprint 55 built device
registration/revocation (`devices`, closing Sprint 43's OWASP finding). The second half has not:
multi-device shops are still not real V1 scope, no product decision has been made to change that,
and this section's own store-level scoping reasoning (shared drawer, shift handoffs) is unaffected
by `devices` existing. Not revisited here — named as a status update, not a design change.

**A second real gap, found writing this spec, not by inspection:** [audit-model.md §1](../../07-database/audit-model.md#1-what-triggers-an-audit-entry)
already names "Trading day opened / closed / reopened" as an audit trigger, and
[state-machines.md](../../06-workflows/state-machines.md#trading-day)'s own state diagram includes
a `Closed → Open` reopen transition (Manager/Owner only, DR-020) — but
[sales.md](../../11-api/endpoints/sales.md)'s endpoint table never listed a reopen endpoint at all.
Built this sprint, closing that gap rather than leaving the state machine's own diagram
unimplementable.

**The deliberate, dated decision *not* to gate `POST /sales` on an open trading day this sprint,
reversing this item's own pre-sprint planning note:** backlog.md's item 2 description (written
before this spec) anticipated wiring `TRADING_DAY_NOT_OPEN` into `POST /sales` in the same sprint,
reasoning that [item 5 (Split Payment)](../../17-sprints/backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point)
needs `sales.trading_day_id` to exist. On writing this spec, that reasoning is only half right:
item 5 needs the **column** to exist and be populated when supplied, not a **hard rejection** of
sales that omit it. Unlike every backend-only sprint before this one (Sprint 22's stock-movements,
Sprint 24/25's new read endpoints), enforcing `TRADING_DAY_NOT_OPEN` would modify an **already-live,
already-working** endpoint (`POST /sales`, proven end-to-end in Sprint 16) that the founder's mobile
app calls today without ever opening a trading day — the mobile till has no such screen yet. Shipping
the hard gate without the matching mobile change would regress the one real, demonstrated,
working end-to-end flow this project has, for a shop that isn't live with real customers yet. This
sprint instead: builds the full trading-day lifecycle as a real, tested, live-verified capability;
threads `trading_day_id` through `POST /sales` as an **optional** field, linked when supplied;
and defers the hard `TRADING_DAY_NOT_OPEN` rejection to the sprint that also updates the mobile till
screen to open a day first — named here explicitly, not silently dropped, the same "connective-tissue
work is easy to under-count" pattern backlog.md's own items 12/13 already established.

## 2. Business rules

- **One open trading day per `(tenant_id, store_id)` at a time** (§1), enforced at the database
  level by a partial unique index (`WHERE status = 'open'`) — a hand-edited addition to the
  generated migration, the same `DEFERRABLE`-FK precedent [Sprint 01](../../17-sprints/sprint-01.md)
  established for constraints Prisma's schema DSL can't express, chosen here because this is a
  genuine correctness/race-condition guard (two concurrent `POST /trading-days/open` calls), not
  merely a query-speed optimisation the way `user_store_roles`' own partial index was.
- **State machine**, exactly [state-machines.md — Trading Day](../../06-workflows/state-machines.md#trading-day):
  `NotYetOpened → Open` (open, set float), `Open → Closed` (close, reconcile),
  `Closed → Open` (reopen, Manager/Owner only). No other transition is valid.
- **`expected_cash_minor_units` is always server-computed**, never client-submitted — the sum of
  `sale_payments.amount_minor_units` where `method = 'cash'`, joined through `sales.trading_day_id`
  for this day's id, for sales with `status = 'completed'`. `variance_minor_units =
  counted_cash_minor_units - expected_cash_minor_units`. Per
  [api-principles.md §7](../../11-api/api-principles.md#7-the-server-recomputes-it-never-trusts-a-client-figure).
- **Closing an already-closed day is an idempotent no-op**, returning the existing closed state
  unchanged — the submitted `counted_cash_minor_units` on a replay is not re-applied, matching this
  API's general creation/state-transition idempotency stance
  ([api-principles.md §3](../../11-api/api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation))
  rather than silently re-running reconciliation math a second time.
- **Reopening an already-open day (the same day) is an idempotent no-op.** Reopening while a
  *different* day is already open at the store hits the same partial unique index as `open` and is
  rejected `TRADING_DAY_ALREADY_OPEN` — the invariant in §2's first bullet holds through reopen too,
  not just through open.
- [DR-020](../../03-functional-requirements/business-rules.md): reopening a closed day is
  Manager/Owner only.
- Every transition (open, close, reopen) writes its own `audit_log` entry in the same transaction,
  per [audit-model.md §1](../../07-database/audit-model.md#1-what-triggers-an-audit-entry) — three
  separate events on one row, so each entry gets a freshly generated id rather than reusing the
  trading day's own id (the 1:1-reuse pattern `stock_movements`/`sale.completed` used doesn't apply
  here, the same reasoning `deactivateUser`'s own audit write already established for a
  repeated-transition entity).

## 3. Database tables and relationships

New table: `trading_days`, matching [schema-server.md](../../07-database/schema-server.md)'s
documented shape **minus `device_id`** (§1's named deviation): `id`, `tenant_id`, `store_id`,
`status` (`'open'|'closed'`, no `CHECK` — application-code-enforced, matching `sales.status`'s own
precedent), `starting_float_minor_units`, `counted_cash_minor_units`, `expected_cash_minor_units`,
`variance_minor_units`, `closed_at`, `reopened_at`, `reopened_by`, plus the standard
`created_at`/`created_by`.

`sales` gains `trading_day_id` — nullable `UUID REFERENCES trading_days(id) ON DELETE RESTRICT`,
matching every other financial-ledger FK's `RESTRICT` convention. Nullable (not `NOT NULL`, as
schema-server.md's full design specifies) for the same reason `canonical_invoice_number` stayed
nullable in Sprint 24: the column exists and is populated by every code path that can populate it,
but the *hard requirement* isn't enforced yet (§1).

Hand-edited addition to the generated migration: `CREATE UNIQUE INDEX
"trading_days_one_open_per_store" ON "trading_days"("tenant_id", "store_id") WHERE "status" =
'open'` — the actual mechanism behind §2's first bullet.

RLS: tenant-scoped, same template as every other table
([supabase/sql/013_rls_trading_days.sql](../../../supabase/sql/013_rls_trading_days.sql)).

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/trading-days/open` | **Built this sprint.** Cashier, Manager, Owner. `id` (client-generated, creation-style idempotency), `starting_float_minor_units`. `store_id` resolved from the session (`requirePermission`'s own `storeId`), not client-supplied — simpler than `POST /sales`'s historical shape, no existing caller to stay compatible with. |
| `POST /api/v1/trading-days/{id}/close` | **Built this sprint.** Cashier, Manager, Owner. `counted_cash_minor_units`. Server computes `expected_cash_minor_units`/`variance_minor_units` (§2). |
| `POST /api/v1/trading-days/{id}/reopen` | **Built this sprint, closing a real gap** — named in state-machines.md/audit-model.md but never listed in sales.md's endpoint table (§1). Manager, Owner only. No request body. |
| `GET /api/v1/trading-days/current` | **Built this sprint.** Cashier, Manager, Owner. Returns `{ "trading_day": null }` when none is open at this store — a normal, expected state, not an error — or the open day's full shape. |
| `POST /api/v1/sales` | **Extended this sprint.** `trading_day_id` accepted as an **optional** field. When supplied, it's validated (must resolve to an **open** day under the caller's tenant **and** the request's `store_id`) and linked — an invalid/closed/foreign-store value is rejected with `TRADING_DAY_NOT_OPEN` even though the field itself isn't required. When omitted, no check runs at all — §1's named, deliberate deferral. |

Route files: `trading-days/open/route.ts`, `trading-days/current/route.ts` as static top-level
siblings of `trading-days/[id]/`, `[id]/close/route.ts` and `[id]/reopen/route.ts` as static children
under it — applying Sprint 23/24's own routing lesson proactively from the start, no dynamic/static
collision risk anywhere in this tree.

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `id` (open) | UUID v4 — Zod `.uuid()`. |
| `starting_float_minor_units` (open) | `.int().nonnegative()`. |
| `counted_cash_minor_units` (close) | `.int().nonnegative()`. |
| `trading_day_id` (POST /sales, new) | `.string().uuid().optional()`. |

## 6. Error handling and user-facing messages

| Code | HTTP | Cause |
| --- | --- | --- |
| `TRADING_DAY_ALREADY_OPEN` | 409 | Already reserved ([sales.md](../../11-api/endpoints/sales.md)), implemented this sprint: `POST /trading-days/open` (or `/reopen`) while a day is already open at this store — the partial unique index's `P2002`, translated. |
| `TRADING_DAY_NOT_OPEN` | 409 | Already reserved. **Reachable this sprint only when `trading_day_id` is supplied and invalid** — doesn't resolve to an open day under this tenant/store. **Not raised when the field is omitted entirely** (§1's named, deliberate deferral) — that's the half of this code's full V1 meaning that won't fire until the mobile-till sprint makes the field required. |
| `TRADING_DAY_NOT_CLOSED` | 409 | **New.** `POST /trading-days/{id}/reopen` targets a day whose `status` isn't `'closed'` and isn't already `'open'` either — unreachable given only two statuses exist, but named defensively rather than falling through to a generic 500 if a third status is ever added. |
| `NOT_FOUND` | 404 | `close`/`reopen` target a `trading_days.id` that doesn't exist under the caller's tenant. |
| `PERMISSION_DENIED` | 403 | Already reserved. `reopen` called by a Cashier. |
| `VALIDATION_FAILED` | 422 | Any Zod failure. |

## 7. Offline behaviour

`POST /trading-days/open` and `POST /trading-days/{id}/close` are both **offline-queued**
(`sales.md`'s own already-documented stance) — a Cashier can open/close their till without
connectivity, synced later via `POST /sync/push`. **Not built this sprint**: no `trading_day.open`/
`trading_day.close`/`trading_day.reopen` push-operation type exists yet in `sync/schema.ts`'s
operation union — these endpoints are online-only for now, the same "table/endpoint exists, sync
integration is a separate, named gap" shape Categories/Units' own online-only-creation precedent
already established. `GET /trading-days/current` is read-cached like every other read endpoint.

## 8. Realtime behaviour

None specified for V1 — no requirement found for a live push when a trading day's state changes on
another device. Matches every other module's own precedent (Roles & Permissions, Settings): the
next request re-resolves state fresh, no cross-session push.

## 9. UI specification

None this sprint — every endpoint built is called only by throwaway live-verification scripts so
far. The mobile till screen's own open-day check/prompt is explicitly deferred (§1), tracked as the
concrete next step before `TRADING_DAY_NOT_OPEN` can actually be enforced.

## 10. Test plan

- Unit tests (`trading-day/service.test.ts`): `openTradingDay` translates the partial-unique-index
  violation to `TRADING_DAY_ALREADY_OPEN`; `closeTradingDay` computes `expected_cash_minor_units`
  correctly from linked cash payments only (excluding `card`/`other` and sales linked to a
  *different* trading day), is idempotent on an already-closed day (second call doesn't
  re-compute); `reopenTradingDay` transitions closed→open, is idempotent on an already-open day,
  translates a conflicting-open-day race to `TRADING_DAY_ALREADY_OPEN`; `getCurrentTradingDay`
  returns `null` when none is open.
- **Live verification, real database, throwaway tenant (deleted after):**
  1. `POST /trading-days/open` → `201`, `GET /trading-days/current` reflects it.
  2. A second `POST /trading-days/open` (different `id`, same store) while the first is still open
     → `409 TRADING_DAY_ALREADY_OPEN`.
  3. Two `POST /sales` calls, one `trading_day_id` supplied and `cash`, one omitted entirely — both
     succeed (§1: no gate yet); the linked one's amount is included in the next close's
     `expected_cash_minor_units`, the unlinked one's is not.
  4. `POST /trading-days/{id}/close` with `counted_cash_minor_units` equal to the linked sale's
     amount → `variance_minor_units: 0`.
  5. Replaying the same close call → identical response, no re-computation (idempotent).
  6. `POST /trading-days/{id}/reopen` as a Cashier → `403 PERMISSION_DENIED`; as the Owner → `200`,
     `GET /trading-days/current` reflects it open again.
  7. `POST /trading-days/open` again (a genuinely new day) after the reopened one is closed a second
     time → succeeds, confirming the partial unique index correctly allows a new open day once the
     previous one is closed.
  8. Cross-tenant RLS: tenant B's `GET /trading-days/current` never resolves to tenant A's open day.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [state-machines.md — Trading Day](../../06-workflows/state-machines.md#trading-day) (full state machine incl. reopen) | §2, §4 | Met |
| [offline-workflows.md — Finding 2](../../06-workflows/offline-workflows.md#finding-2--trading-day-is-a-shared-store-level-concept-and-multi-device-shops-need-a-rule) | §1 | Resolved for V1's single-device target via store-level scoping, named explicitly as a deviation from schema-server.md's per-device column |
| [DR-020](../../03-functional-requirements/business-rules.md) (reopen is Manager/Owner only) | §2, §4, §6 | Met |
| [permission-matrix.md — Cash Drawer / Day Close](../../05-personas/permission-matrix.md#cash-drawer--day-close) | §4 | Met |
| [audit-model.md §1](../../07-database/audit-model.md#1-what-triggers-an-audit-entry) (open/close/reopen audited) | §2, §10 | Met |
| `sales.md`'s `TRADING_DAY_NOT_OPEN` gate | §1, §4, §6 | **Not met this sprint, named explicitly** — deferred to the sprint pairing this with the mobile till's own open-day flow |
| Offline queuing of open/close (sales.md) | §7 | **Not met this sprint, named explicitly** — no sync push-operation type yet |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | First version — written to drive Sprint 26's implementation of Cash Drawer / Trading Day (backlog.md M2 item 2): `trading_days` table (store-scoped, not device-scoped — a named deviation from schema-server.md), `POST /trading-days/open`, `POST /trading-days/{id}/close`, `POST /trading-days/{id}/reopen` (closing a real gap sales.md never listed), `GET /trading-days/current`. `POST /sales` gains an optional `trading_day_id` but deliberately no hard `TRADING_DAY_NOT_OPEN` gate yet — reversing this item's own pre-sprint planning note, to avoid regressing the one live, working end-to-end sale flow this project has ahead of the matching mobile till change. |
| 0.1.1 | 2026-08-20 | Status update, no design change: Sprint 55 built device registration/revocation, landing the first half of this section's own "revisit when..." trigger. The second half (multi-device shops becoming real V1 scope) hasn't — store-level scoping is unchanged. |
