# Sprint 46

> **Dates:** 2026-08-19 – 2026-08-19 (single-day, same cadence as every prior sprint)
> **Milestone:** M4 — Reports, Settings, and Release Readiness (cross-cutting fix, not a numbered
> backlog item — closes finding M6 from Sprint 43's OWASP checklist review)
> **Status:** Closed.

## Goal

Close a third finding from Sprint 43's OWASP checklist review: `privacy.md §4`'s anonymise-not-delete
resolution for a customer erasure request has been fully designed since Phase 12, but had zero
implementation — confirmed by grep at the time, zero hits for `anonymi[sz]e`/`erasure`/`gdpr`
anywhere in either app. Like rate limiting (Sprint 45), this carried no production-configuration
risk and was safe to build immediately, unlike the RLS finding still open pending founder input.

## Design decisions, found while writing the spec

1. **Erasure needed its own explicit state marker, not an inferred one.** `assertHasIdentifier`
   already guarantees a normal customer always has at least one of `name`/`phone` — so "both null"
   is otherwise impossible, and could in principle have been used to infer "this customer was
   erased." A new explicit `erased_at` timestamp column was used instead, matching this schema's own
   consistent convention of explicit state markers (`deactivated_at`, `completed_at`, `resolved_at`)
   over inferred state — more auditable, and doesn't quietly repurpose a field's absence as a status
   signal.
2. **Owner-only, one level stricter than `DELETE`'s Manager+Owner gate.** Erasure is a real
   data-governance/legal-compliance action a shop's Owner should decide, not an ordinary
   back-office judgment call like deactivating a customer for business reasons — the same reasoning
   `audit-logging.md §4` already uses for its own Owner-only read gate.
3. **Erasure also sets `deactivated_at` if not already set — but never overwrites an existing,
   earlier deactivation timestamp.** An erased customer has no identifying data left for any real
   workflow (search, add to a new sale, the picker) to act on correctly, so leaving it nominally
   "active" would be a confusing half-state. Caught during implementation, before any test was
   written: an initial draft of `repository.eraseCustomer` unconditionally set `deactivatedAt` to
   "now," which would have silently overwritten a genuinely earlier deactivation date for a customer
   erased after already being deactivated — corrected before it reached the service layer, by having
   the service pass `null` (meaning "don't touch this field") whenever the customer was already
   deactivated; a dedicated unit test and a dedicated integration test both now assert this
   preservation directly, so a future regression here would be caught either way.
4. **A related, previously-unexposed gap found in the same pass: this API never surfaced
   deactivation status at all**, even though `DELETE /customers/{id}` has set `deactivated_at` since
   Sprint 31. Added `deactivated_at` to every customer response alongside the new `erased_at`, not
   only the new endpoint's own — a small, obviously-correct, closely-related fix.
5. **Mobile UI is explicitly out of scope.** No screen exists anywhere in this product for an Owner
   to *initiate* an erasure request — the realistic V1 flow is a customer's request reaching the
   Owner outside the app (a phone call, a message), with the Owner acting on it via a future admin
   surface. This item closes the server-side capability `privacy.md §4` already designed, not a new
   UI feature — real, separate, undiscussed scope, named rather than silently expanded into.

## Capacity check

No estimate was carried in the backlog for this item, since it was not a planned backlog line — a
same-day fix of a specific, already-flagged Sprint 43 finding, the same shape Sprint 44/45 both took.

## Reserved capacity

- [x] Defect capacity reserved: this closes a real, previously-flagged gap (Sprint 43 finding M6),
      not new discretionary scope. The `deactivatedAtIfUnset` bug (design decision #3) was found and
      fixed before it ever reached the integration suite.

## Risks

- **None for production data** — purely additive: a new nullable column, one new repository/service
  function pair reusing the exact idempotent-state-transition shape `deactivateCustomer` already
  established, and one new Route Handler. No existing endpoint's behaviour changes.
- **Legal/compliance review remains a separate, open item** — `privacy.md §2`'s "provisional,
  pending legal review" framing around DPDPA applicability is untouched by this sprint; this closes
  the engineering gap only, not that standing cross-phase item.

## Definition of Done

- [x] `apps/web/prisma/schema.prisma` + migration — `Customer.erasedAt`.
- [x] `customers/repository.ts`'s `eraseCustomer` — anonymises, preserves an existing
      `deactivatedAt` rather than overwriting it.
- [x] `customers/service.ts`'s `eraseCustomer` — idempotent no-op on an already-erased customer,
      `NOT_FOUND` on a nonexistent one; `formatCustomer` extended with `deactivated_at`/`erased_at`.
- [x] `apps/web/src/app/api/v1/customers/[id]/erase/route.ts` — `POST`, Owner only.
- [x] `apps/web/integration-tests/customer-erasure.test.ts` — 4 cases against a real Postgres
      connection: anonymisation + auto-deactivation, preserving an already-set `deactivated_at`,
      idempotent replay, and — the one property a mocked test can't demonstrate — that a historical
      sale referencing the erased customer keeps resolving correctly afterward.
- [x] `apps/web/src/modules/customers/service.test.ts` — 4 new mocked cases plus the pre-existing
      `createCustomer`/`deactivateCustomer` cases updated for the two new response fields.
- [x] Verified locally: full `test:integration` (94/94, 90 pre-existing + 4 new), full unit suite
      (215/215, 211 pre-existing + 4 new), `tsc`/`eslint` clean.
- [x] `privacy.md`, `customers.md`, `customers/specification.md`, `permission-matrix.md`,
      `owasp-checklist.md` all updated in the same PR.
- [x] backlog.md, implementation-log, `docs/README.md` updated in the same PR.

## Demo script

**Local, run 2026-08-19**, mirroring `pr.yml`'s `fast-integration` job exactly:

1. Fresh migration applied (`customers.erased_at` created). ✅
2. `pnpm --filter @smart-pos/web test:integration` → 94/94 passing (90 pre-existing + 4 new
   customer-erasure cases). ✅
3. `tsc --noEmit`/`eslint .`/`pnpm test` (215/215, 211 pre-existing + 4 new) all clean. ✅

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this surfaces a concrete process
change — not pre-judged here. Worth naming regardless: this is the third of Sprint 43's flagged
findings closed this way (after Sprint 45's rate limiting) — a design that was already fully
specified, sitting unbuilt for a long time, closed in a single focused pass once someone actually
checked whether the code matched the doc.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-19 | Sprint 46: customer-erasure anonymisation built (`POST /customers/{id}/erase`, Owner only), closing Sprint 43's finding M6. Found and fixed a real bug before it reached integration tests: an early draft would have overwritten an already-deactivated customer's genuine deactivation date. Found a related gap: `deactivated_at` had never been exposed in any customer API response at all — fixed in the same pass. 94/94 integration checks, 215/215 unit tests. |
