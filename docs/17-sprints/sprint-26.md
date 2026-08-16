# Sprint 26

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M2 — Full POS Loop (backlog item 2 — Cash Drawer / Trading Day)
> **Status:** Closed — M2 item 2 done. M2 now has items 3–6 remaining.

## Goal

Cash Drawer / Trading Day: `trading_days` table, `POST /trading-days/open`, `POST
/trading-days/{id}/close`, `GET /trading-days/current` — resolving the real, unresolved scoping
question backlog.md's own item 2 description already named (no `devices` table exists, so
schema-server.md's per-device design can't be built as documented) rather than guessing at it
during decomposition.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `trading_days` table, open/close/current endpoints, `POST /sales` trading-day integration | Cash Drawer / Trading Day | 2.5 | — |

## Design decisions, found while writing the spec

Full detail in [trading-day/specification.md §1](../modules/trading-day/specification.md#1-purpose-and-business-context).

1. **Scoped per-`(tenant_id, store_id)`, not per-device and not per-`(tenant, store, user)`.**
   Pre-sprint research (done ahead of this spec) suggested `(tenant, store, user)` as the closest
   substitute for the missing `device_id`, matching Sprint 24's own "own device" → "own sales
   created" adaptation. Writing the spec found a better answer: [offline-workflows.md — Finding
   2](../06-workflows/offline-workflows.md#finding-2--trading-day-is-a-shared-store-level-concept-and-multi-device-shops-need-a-rule)
   already states "a single physical cash drawer suggests one shared day-state," and
   [state-machines.md](../06-workflows/state-machines.md#trading-day) already states its own base
   assumption is "one Trading Day per store." A `(tenant, store, user)` scoping would have let two
   Cashiers on one physical till both hold an "open day" simultaneously — a real correctness defect
   store-level scoping avoids outright, and one this project's own prior documentation had already
   flagged the shape of.
2. **A real gap found, not by inspection**: [audit-model.md §1](../../07-database/audit-model.md#1-what-triggers-an-audit-entry)
   already names "Trading day opened / closed / reopened" as an audit trigger, and
   [state-machines.md](../06-workflows/state-machines.md#trading-day)'s own diagram includes a
   `Closed → Open` reopen transition (Manager/Owner only, DR-020) — but sales.md's endpoint table
   never listed a reopen endpoint at all. Built this sprint, closing that gap.
3. **The `TRADING_DAY_NOT_OPEN` hard gate on `POST /sales` is deliberately deferred, reversing this
   item's own pre-sprint plan.** Backlog.md's item 2 description (written before this spec)
   anticipated wiring the gate in the same sprint, reasoning that item 5 (Split Payment) needs
   `sales.trading_day_id` to exist. Writing the spec found that reasoning only half right: item 5
   needs the column to exist and populate when supplied, not a hard rejection of sales that omit
   it. Enforcing the gate now would modify an already-live, already-working endpoint (`POST
   /sales`, proven end-to-end in Sprint 16) that the founder's mobile app calls today without ever
   opening a trading day — the mobile till has no such screen yet. Shipping the hard gate without
   the matching mobile change would regress the one real, demonstrated, working end-to-end flow
   this project has, for a shop that isn't live with real customers yet. Deferred instead to the
   sprint that also updates the mobile till screen — named explicitly, not silently dropped.

## Capacity check

2.5 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — used (see Risks below, one real bug found).
- [x] Documentation capacity reserved: `trading-day/specification.md` (all 11 sections),
      `sales.md`, `error-catalogue.md`, module registry, backlog.md, implementation-log, README
      bumps.

## Risks

- **One real bug found live, fixed before merge:** the hand-edited partial unique index
  (`trading_days_one_open_per_store`) correctly fired on a second concurrent `open`, but the
  service-layer translation compared `error.meta?.target` against the index's own name — Prisma
  actually reports it as the column-name array (`["tenant_id", "store_id"]`) for this kind of
  raw-SQL constraint, not the index name. Found by running the live-verification script and getting
  a raw `500` instead of the expected `409`, not by inspection; fixed by checking for both column
  names in the array instead.
- **A hand-edited migration, same shape as Sprint 01's `DEFERRABLE` FK precedent**: the partial
  unique index enforcing "one open day per store" isn't expressible in Prisma's schema DSL, so it
  was added by hand to the generated migration and verified directly against `pg_indexes` (not
  merely assumed to have applied) before proceeding — the same "verify the thing you just applied,
  don't trust the apply step" lesson Sprint 25's own RLS bug already taught.
- **Trading Day is intentionally left non-functional as a hard gate this sprint** — see design
  decision 3 above. `POST /sales` will keep working exactly as it does today until a future sprint
  pairs the gate with the mobile till's own open-day flow.

## Definition of Done

- [x] `trading_days` table (new migration + RLS + hand-edited partial unique index) — scoped
      per-`(tenant_id, store_id)`, `device_id` dropped entirely (named deviation).
- [x] `sales.trading_day_id` — nullable, linked when supplied.
- [x] `POST /api/v1/trading-days/open` — creation-style idempotency, `TRADING_DAY_ALREADY_OPEN` on
      conflict.
- [x] `POST /api/v1/trading-days/{id}/close` — server-computed `expected_cash_minor_units`/
      `variance_minor_units`, idempotent on replay.
- [x] `POST /api/v1/trading-days/{id}/reopen` — Manager/Owner only, closing a real gap sales.md
      never listed.
- [x] `GET /api/v1/trading-days/current` — `{ "trading_day": null }` when none is open, never an
      error.
- [x] `POST /api/v1/sales` extended with an optional `trading_day_id`, validated when supplied, no
      hard gate when omitted (design decision 3).
- [x] Unit tests: `trading-day/service.test.ts` (13 new tests), `pos/service.test.ts` extended (3
      new tests for the trading-day integration).
- [x] `tsc --noEmit`/`eslint`/`vitest` (112 tests total across the web app) all clean; production
      build verified locally with CI-style placeholder env before pushing.
- [x] Live verification against the real database, throwaway tenants deleted after — 26/26 checks.
- [x] `trading-day/specification.md`, `sales.md`, `error-catalogue.md` all updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** the `TRADING_DAY_NOT_OPEN` hard gate (design
decision 3), offline queuing for open/close/reopen (no `sync/push` operation type exists for any of
the three), any mobile UI (till-screen open-day flow, day-close reconciliation screen).

## Demo script

**Server, run 2026-08-14** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. `POST /trading-days/open` → `201`; `GET /trading-days/current` reflects it. ✅
2. A second `open` (different id, same store) while the first is open → `409
   TRADING_DAY_ALREADY_OPEN`. ✅
3. Two `POST /sales` calls, one with `trading_day_id` supplied (cash), one omitting it entirely —
   both succeed (no gate yet, design decision 3). ✅
4. `POST /sales` with an invalid `trading_day_id` → `409 TRADING_DAY_NOT_OPEN` (the field, when
   supplied, is still genuinely validated). ✅
5. `POST /trading-days/{id}/close` with `counted_cash_minor_units` equal to the linked sale's
   amount → `expected_cash_minor_units` correctly counts only the linked sale, `variance_minor_units:
   0`. ✅
6. Replaying the same close with a different `counted_cash_minor_units` → identical response,
   original value unchanged (idempotent). ✅
7. `POST /trading-days/{id}/reopen` as a Cashier → `403 PERMISSION_DENIED`; as the Owner → `200`,
   `GET /trading-days/current` reflects it open again. ✅
8. Closing the reopened day, then opening a genuinely new one → succeeds, confirming the partial
   unique index correctly releases once the prior day closes. ✅
9. Cross-tenant RLS: tenant B's `GET /trading-days/current` never resolves to tenant A's open day.
   ✅

**Unit tests, run 2026-08-14**: `vitest run` — 112/112 passing.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the first sprint
where a *pre-sprint research pass* (done specifically to unblock planning) got overridden by the
actual spec-writing that followed it — the research recommended `(tenant, store, user)` scoping,
matching Sprint 24's precedent shape, but writing the spec against this project's own existing
Phase 06 documentation (Finding 2, the state-machine's base assumption) found a better-supported
answer. Worth naming as a healthy pattern, not a wasted research pass: the research correctly
surfaced the real gap and the tradeoffs; the spec-writing step is where the final call gets made
against the fuller documentary record, and that division of labor worked as intended here. Also the
second sprint running (after Sprint 25's RLS bug) where a *verification script itself*, not the
product code, needed its own fix mid-verification — worth continuing to name explicitly rather than
treating hand-rolled scripts as automatically trustworthy just because they're "just verification."

M2 — Full POS Loop now has items 3–6 remaining: Discount, Tax computation, Split Payment,
Hold/Resume, per [backlog.md §3](backlog.md#3-m2--fully-decomposed-2026-08-14-now-that-m1-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 26 planned and built same-day: `trading_days` table (store-scoped, overriding pre-sprint research's per-user guess), `POST /trading-days/open`/`{id}/close`/`{id}/reopen` (new), `GET /trading-days/current` built and live-verified (26/26). `POST /sales` gains an optional `trading_day_id`; the `TRADING_DAY_NOT_OPEN` hard gate deliberately deferred to avoid regressing the one live, working end-to-end sale flow this project has. One real bug found live and fixed: the partial unique index's P2002 violation reports column names, not the index name, in `meta.target`. |
