# Sprint 35

> **Dates:** 2026-08-16 – 2026-08-16 (single-day, same cadence as every prior sprint)
> **Milestone:** M3 — Customers, Returns & Refund, conflict-resolution field-merge (backlog item 5 — conflict-resolution field-merge, `customers` only)
> **Status:** Closed — M3 item 5 done. **M3 is now fully closed, all 5 items done.**

## Goal

Conflict-resolution field-merge, `customers` only — the sync engine's first `.update` operation
type of any kind, and [milestones.md — M3](../16-milestones/milestones.md)'s own hard exit
criterion: a field-edit conflict on a customer record (two devices, same field, different values)
surfaces in the exact business-language form
[conflict-resolution.md](../13-offline-sync/conflict-resolution.md) specifies —
[customers/specification.md §1c](../modules/customers/specification.md#1c-sprint-35--conflict-resolution-field-merge-m3-item-5-m3s-last-item).
M3's fifth and last item.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `customer.update` sync-push, `PATCH /customers/{id}` upgraded, `customer_field_conflicts`, conflict review/resolve, mobile edit + conflict screens | Customers | 3 | 1 (Customers, server), 2 (Customers, mobile) |

## Design decisions, found while writing the spec

Full detail in [customers/specification.md §1c](../modules/customers/specification.md#1c-sprint-35--conflict-resolution-field-merge-m3-item-5-m3s-last-item).

1. **`PATCH /customers/{id}` itself is upgraded, not superseded** — `customers.md`'s own Sprint 31
   implementation note had already forward-declared this exact requirement. Both the direct
   endpoint and `customer.update` call the identical, now-merge-aware `updateCustomer` service
   function, holding sync-api.md §1's "push calls the exact same service method" rule intact.
2. **A real design gap: `base_updated_at` alone cannot support the field-level 3-way merge** —
   the server has no field-level edit history for `customers`. Resolved by having the client send
   each field's own base value alongside its new value; `base_updated_at` itself is kept in the
   request for fidelity to conflict-resolution.md's own vocabulary but is mathematically subsumed
   by the per-field comparison, not a materially different code path.
3. **A genuine, dated contract break to `PATCH /customers/{id}`** (all four fields now required,
   not a true partial update) — judged safe since no mobile caller of `PATCH` ever existed before
   this sprint.
4. **A second real gap: the worked example attributes each candidate value to a named person**
   ("Priya set it to..."), which needed attribution no existing column captured. Resolved with one
   new column, `customers.updated_by`.
5. **Conflict review/resolution is online-only** — the same reasoning `settings.md`'s own
   online-only stance already established for a comparably rare, low-frequency administrative
   action.

## Capacity check

3 person-days against the ~3.75 person-day sprint budget.

## Reserved capacity

- [x] Defect capacity reserved: none used as rework — every design decision above was resolved at
      spec-writing time, before code; the exit-criterion scenario was live-verified end to end on
      the first attempt (18/18 checks).
- [x] Documentation capacity reserved: `customers/specification.md` §1c (and throughout),
      `sync-engine/specification.md`, `error-catalogue.md`, `permission-matrix.md`, module registry,
      backlog.md, implementation-log, README bumps.

## Risks

- **None new.** The local-write-plus-enqueue mechanism reuses `DriftCustomerRepository.createCustomer`'s
  own already-proven shape exactly; the merge algorithm is a pure function over data the request
  itself carries, no new server-side history/state mechanism.

## Definition of Done

- [x] Server: `customers.updated_by` column; new `customer_field_conflicts` table (migration + RLS).
- [x] `PATCH /customers/{id}` upgraded to the merge-aware shape; `customer.update` sync-push
      operation type (dispatching to the same service function); `GET /customers/conflicts`/
      `POST /customers/conflicts/{id}/resolve` (Manager/Owner, online-only).
- [x] `mergeCustomerFields` — the field-level 3-way merge (base/current/new), non-overlapping
      fields both apply, genuine same-field conflicts recorded not applied, already-matching
      values are silent no-ops.
- [x] `CONFLICT_RESOLUTION_VALUE_INVALID` added to error-catalogue.md; "Review/resolve a
      field-edit conflict" (Manager/Owner) added to permission-matrix.md.
- [x] Mobile: `CustomerEditScreen` (`/customers/:id/edit`, this sprint's first customer-edit UI at
      all), `ConflictsScreen` (`/customers/conflicts`, the worked example's exact two-choice
      prompt with named attribution), `CustomerRepository.updateCustomer`/`listConflicts`/
      `resolveConflict`, Till screen gains `pos_customer_conflicts_button` with a live badge.
- [x] Unit/widget tests: `customers/service.test.ts` (rewritten `updateCustomer` group plus new
      `listConflicts`/`resolveConflict` groups, 28 total customers tests), `sync/service.test.ts`
      (3 new cases). `drift_customer_repository_test.dart` (`updateCustomer`/`listConflicts`/
      `resolveConflict` groups, new), `customer_edit_screen_test.dart`/`conflicts_screen_test.dart`
      (new). Every existing fake `CustomerRepository` implementation updated for the three new
      interface methods.
- [x] `tsc --noEmit`/`eslint`/`vitest` (194 total web tests) all clean; `flutter analyze`/
      `flutter test` all clean; both production builds verified locally before pushing.
- [x] Live verification against the real database, throwaway tenants (deleted after) — 18/18
      checks, the exact worked-example scenario (Priya, Anil, Ramesh Kumar's phone number)
      provoked for real, end to end.
- [x] `customers/specification.md`, `sync-engine/specification.md`, `error-catalogue.md`,
      `permission-matrix.md` all updated in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

## Demo script

**Server, run 2026-08-16** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after — the exit criterion itself:

1. Create customer Ramesh Kumar (phone `9111111111`). ✅
2. Priya (Cashier, Device A) changes his phone to `9876543210` — applies cleanly (no concurrent
   edit). ✅
3. Anil (Manager, Device B), unaware, changes it to `9876500000` using the *original* base — `200`,
   but not applied; Priya's value stands. ✅
4. `GET /customers/conflicts` (Owner) → one row: field `phone`, "Priya set it to 9876543210," "Anil
   set it to 9876500000." ✅
5. A Cashier is denied the conflicts queue (`403`). ✅
6. Resolving with Anil's value → the customer's phone updates; the queue is now empty; a replayed
   resolve is an idempotent no-op. ✅
7. `POST /sync/push` with a `customer.update` operation applies identically to the direct
   endpoint. ✅
8. A non-overlapping field (name only) applies automatically alongside an already-settled phone,
   no new conflict. ✅
9. Cross-tenant RLS: tenant B sees none of tenant A's conflicts. ✅

**Unit tests, run 2026-08-16**: `vitest run` — 194/194 passing (16 new); `flutter test` — all
passing (exact count in the DoD above).

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this was the project's first
`.update` sync operation type, closing a gap named all the way back at M3's own decomposition
(Sprint 30/31 planning) — the field-level 3-way merge design, resolved entirely at spec-writing
time using only data the request itself carries, avoided what could easily have become a much
larger scope (a full audit-history mechanism) had the "base_updated_at alone" framing been taken
at face value instead of tested against the worked example concretely.

**M3 — Customers & Returns is now fully closed, all 5 backlog items done.** Per
[backlog.md §4](backlog.md#4-m3--fully-decomposed-2026-08-16-now-that-m2-has-reached-this-point),
the milestone's own exit criteria (a return completing correctly, a field-edit conflict surfacing
in business language) are both live-verified. M4 — Reports, Settings, and Release Readiness — is
the next milestone, per [milestones.md](../16-milestones/milestones.md).

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-16 | Sprint 35 planned and built same-day: conflict-resolution field-merge built and live-verified (18/18), the exact worked-example scenario provoked for real end to end. **M3 is now fully closed.** |
