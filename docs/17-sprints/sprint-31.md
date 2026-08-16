# Sprint 31

> **Dates:** 2026-08-16 – 2026-08-16 (single-day, same cadence as every prior sprint)
> **Milestone:** M3 — Customers, Returns & Refund, conflict-resolution field-merge (backlog item 1 — Customers, server)
> **Status:** Closed — M3 item 1 done. M3 now has items 2–5 remaining.

## Goal

Customers (server): `customers` table, `sales.customer_id`, `POST`/`GET`/`PATCH`/`DELETE
/customers`, `GET /customers/{id}/purchase-history` — [customers.md](../11-api/endpoints/customers.md),
FR-050/051/052, the smallest module in this API by deliberate design. M3's first item, opened the
same day M3 was fully decomposed to item grain (backlog.md §4), now that M2 has fully closed.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `customers` table + RLS, `sales.customer_id`, full CRUD + purchase-history | Customers (basic) | 2.5 | — |

## Design decisions, found while writing the spec

Full detail in [customers/specification.md §1/§2](../modules/customers/specification.md#1-purpose-and-business-context).

1. **No design gap found** — `customers.md`, `schema-server.md`'s Context 4, and FR-050/051/052
   were already fully fixed in Phases 03/07/11, unchanged going into this sprint. Worth stating
   plainly rather than manufacturing a gap-hunt where none exists, the same honesty
   [sprint-29.md](sprint-29.md) modelled for Split Payment.
2. **`sales.customer_id` added nullable, with no caller yet.** `POST /sales` is not extended to
   accept it this sprint — that's [backlog.md M3 item 2](backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)'s
   mobile-checkout-wiring scope. The column exists and is ready for item 2 to populate, the same
   "column exists, nothing populates it yet" shape `trading_day_id` established in Sprint 26.
3. **`PATCH /customers/{id}` is plain last-write-wins this sprint, not conflict-aware.** No
   concurrent-offline-edit caller exists yet to make a merge policy meaningful — that's
   [M3 item 5](backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point)'s
   scope specifically. Building it now would be speculative abstraction against a caller that
   doesn't exist.
4. **`updatedAt` added to the `customers` table from the start**, unlike Category/Unit's own
   create-list-only cut — item 5's conflict-resolution merge policy needs it as a real column
   later, and adding it now avoids a second migration purely to bolt it on.

## Real bug found live, not by inspection

A Zod `.refine()` on `createCustomerRequestSchema`, enforcing "at least one of name/phone,"
followed [pos/schema.ts](../../apps/web/src/modules/pos/schema.ts)'s own precedent for the
mutually-exclusive discount fields. Live-testing (this sprint's own verification script) surfaced
the difference that precedent didn't share: a `.refine()` failure at the Route Handler's
`safeParse` boundary is indistinguishable from any other shape violation, so the endpoint always
returned the generic `VALIDATION_FAILED` — never the specific `CUSTOMER_IDENTIFIER_REQUIRED`
`customers.md` names for exactly this condition. Discount's `.refine()` has no named code to
preserve, so that precedent held there; this rule does, so it didn't transfer. Fixed by removing
the `.refine()` and relying solely on `service.ts`'s `assertHasIdentifier()` — matching this
codebase's own "business rules live in the service layer, not the Route Handler" convention for
any rule that needs a specific, documented error code. Full detail in
[customers/specification.md §5](../modules/customers/specification.md#5-validation-rules-client-and-server).

## A second real gap found and closed in the same PR

[permission-matrix.md](../05-personas/permission-matrix.md)'s Customers section never listed "edit"
or "deactivate" at all, despite `customers.md` already documenting `PATCH /customers/{id}`
(Cashier+) and `DELETE /customers/{id}` (Manager/Owner) since Phase 11. Added both rows, matching
customers.md's already-fixed decisions exactly rather than re-deciding them here — the same
"earlier phase's document gets the dated correction, not just a mention in the new one" pattern
this project has applied repeatedly (dependency-graph.md's missing Sales & Invoices node,
schema-local.md's stale immutability classification, and others).

## Capacity check

2.5 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day — spent on the `.refine()` error-code bug found live
      (above), caught before it shipped, not after.
- [x] Documentation capacity reserved: `customers/specification.md` (new), `customers.md`,
      `permission-matrix.md`, module registry, backlog.md, implementation-log, README bumps.

## Risks

- **None new.** Server-only, no live caller anywhere yet (mobile UI is item 2) — the same low-risk
  shape every backend-only sprint before Roles & Permissions had. The one real risk this sprint
  carried (a documented error code silently not firing) was caught by the sprint's own live
  verification script, not merely reasoned about from the code.

## Definition of Done

- [x] `customers` table (new migration + RLS, hand-edited partial unique index on
      `(tenant_id, phone) WHERE deactivated_at IS NULL`, matching schema-server.md exactly).
- [x] `sales.customer_id` (nullable, `ON DELETE SET NULL`, new migration).
- [x] `POST`/`GET`/`PATCH`/`DELETE /api/v1/customers`, `GET /api/v1/customers/{id}/purchase-history`
      built, permission-enforced (Cashier+ for create/edit/read, Manager/Owner for delete).
- [x] Unit tests: `customers/service.test.ts` (19 new tests) — creation with name-only/phone-only/
      both, `CUSTOMER_IDENTIFIER_REQUIRED`, `PHONE_ALREADY_ASSIGNED` on both create and update,
      idempotent deactivation, cursor pagination (both list endpoints), malformed-cursor rejection.
- [x] `tsc --noEmit`/`eslint`/`vitest` (146 tests total across the web app) all clean; production
      build verified locally with CI-style placeholder env before pushing.
- [x] Live verification against the real database, throwaway tenants deleted after — 12/12 checks,
      including the phone-collision, purchase-history-excludes-non-completed, idempotent-delete, and
      cross-tenant RLS checks.
- [x] `customers/specification.md` (new), `customers.md`, `permission-matrix.md` all updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** mobile UI, `customer.create`/`customer.update`
sync-push operation types and offline queuing, `POST /sales` accepting `customer_id`, the
conflict-resolution field-merge policy — all named, separate M3 items (2 and 5).

## Demo script

**Server, run 2026-08-16** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. `POST /customers` with only a phone → `201`. ✅
2. `POST /customers` with neither name nor phone → `422 CUSTOMER_IDENTIFIER_REQUIRED` (the specific
   code, not a generic validation failure — the live-found fix above). ✅
3. A second `POST /customers` with the same phone → `409 PHONE_ALREADY_ASSIGNED`. ✅
4. `GET /customers?phone=<number>` → exact match. ✅
5. `PATCH /customers/{id}` with a new name → `200`, phone unchanged. ✅
6. `PATCH /customers/{id}` moving phone onto another customer's already-assigned phone → `409
   PHONE_ALREADY_ASSIGNED`. ✅
7. A completed sale and a held sale both linked to the same customer (seeded directly — no
   `POST /sales` change this sprint) → `GET /customers/{id}/purchase-history` returns only the
   completed one. ✅
8. `DELETE /customers/{id}` as the Owner → `200`, `deactivated_at` set; a second `DELETE` → identical
   response, idempotent. ✅
9. `GET /customers` after deactivation → the customer is excluded. ✅
10. Cross-tenant RLS: a second tenant's `GET /customers` never resolves to the first tenant's
    customer. ✅

**Unit tests, run 2026-08-16**: `vitest run` — 146/146 passing (19 new).

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this sprint's `.refine()`
bug is a useful, narrow lesson rather than a broad one — Zod `.refine()` for a cross-field rule is
fine when the violation has no documented error code of its own (Discount's mutually-exclusive
fields), and wrong when it does (this sprint's `CUSTOMER_IDENTIFIER_REQUIRED`). The distinguishing
question going forward: does `error-catalogue.md` name a specific code for this exact condition? If
yes, the check belongs in the service layer, where the named `ApiError` can actually be thrown.

**M3 now has items 2–5 remaining: Customers (mobile), Returns & Refund (server), Returns & Refund
(mobile), conflict-resolution field-merge** — per
[backlog.md §4](backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | Sprint 31 planned and built same-day: Customers (server) built and live-verified (12/12). Found and fixed a real `.refine()` error-code bug live; corrected permission-matrix.md's missing edit/deactivate-customer rows in the same pass. |
