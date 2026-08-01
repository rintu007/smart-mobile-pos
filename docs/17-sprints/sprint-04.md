# Sprint 04

> **Dates:** Started 2026-08-01
> **Milestone:** M0 — Walking Skeleton
> **Status:** Done — `POST /api/v1/products` implemented and demoed live against real infrastructure,
> including a cross-tenant RLS proof. Found and fixed a real, previously-latent bug in
> `requireSession` (see [implementation-log.md](../18-implementation/implementation-log.md)).

## Goal

A signed-in, onboarded user can create a product (name and price only) that's durably stored,
idempotently retryable, and provably isolated from every other tenant.

## Scope

Backlog item 5 from [backlog.md §1](backlog.md#1-m0--walking-skeleton-fully-decomposed) — server
side only. A real spec gap was found and fixed before writing code: `catalogue.md`'s already-approved
`POST /products` contract requires `category_id`/`unit_id`, but backlog.md's M1 row lists Categories
and Units as M1 scope, not M0 — so M0's endpoint can't require either yet. Documented as a dated
correction in [catalogue.md](../11-api/endpoints/catalogue.md) and scoped explicitly in the new
[Products module specification](../modules/products/specification.md), the same pattern Sprint 02
used for its own spec gaps.

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `POST /products` (name/price only) — server side | Products | 1.0 | 2 (done), 4 (done, Sprint 03) |

**Explicitly not in this sprint's scope:** the mobile local write path (Drift insert +
`outbound_queue` enqueue) that backlog.md item 5's own text bundles alongside the server endpoint —
no Flutter feature screen exists yet (Sprint 03 built only the Drift schema, not a feature on top of
it); named as deferred in the Products spec §4, not silently dropped.

## Capacity check

1.0 person-day of backlog scope against a ~3.75 person-day sprint budget — 2.75 person-days of
headroom, most of it consumed by the spec-gap resolution (§ above) and the real bug found live
(Risks), matching Sprint 02/03's precedent of allocating headroom to real findings rather than
padding scope.

## Reserved capacity

- [x] Defect capacity reserved: 1.0 person-day — every sprint that adds a Route Handler exercising
      auth for the first time has found a real bug so far (Sprint 02's bearer-token-vs-cookie bug,
      now this sprint's `requireSession` claim-location bug); budgeted accordingly rather than
      assumed clean.
- [x] Documentation capacity reserved: 0.5 person-days — the Products module specification, the
      `catalogue.md` correction, and this sprint document.

## Risks

- **A real, previously-latent bug in `requireSession`, found live:** `core/auth/session.ts` read
  `user.app_metadata.tenant_id`, but the Custom Access Token Hook
  (`supabase/sql/001_custom_access_token_hook.sql`) injects `tenant_id` as a **top-level** JWT
  claim, matching `current_tenant_id()`'s own SQL (`auth.jwt() ->> 'tenant_id'`) — not nested under
  `app_metadata`. `requireSession` had never actually been exercised by a real request before this
  sprint (`POST /api/v1/onboarding` only uses the tenant-agnostic `requireAuthenticatedUser`), so
  this sat invisible through Sprint 01/02/03 entirely. Found on the very first real call, fixed by
  decoding the verified token's payload directly instead of trusting the SDK's `User.app_metadata`
  field. See [implementation-log.md](../18-implementation/implementation-log.md) for the full story.
- **[R-10](../01-vision/risks-constraints-assumptions.md) (dependency abandonment)** — carried
  forward again, low likelihood, standing mention per prior sprints' risk registers.

## Definition of Done

Backend-only slice, same narrow subset as Sprint 02 (no mobile/offline/UI boxes — no Flutter
feature exists yet):

- [x] Module specification exists, all 11 sections, 🟢 Approved —
      [products/specification.md](../modules/products/specification.md)
- [x] Schema: `products` table (M0-minimal columns), RLS enabled
      (`supabase/sql/004_rls_products.sql`), applied to the live Supabase database and verified via
      the demo script's cross-tenant step
- [x] `POST /api/v1/products` matches
      [products/specification.md §4/§5](../modules/products/specification.md#4-api-contract) exactly
      — every input validated with Zod at the boundary (`src/modules/products/schema.ts`)
- [x] Endpoint is idempotent — replaying the same `id` returns the same row, not a duplicate
      (verified live, demo step 4)
- [x] Authentication enforced server-side — `requireSession`; `created_by` always comes from the
      verified session (resolved via `identityService.resolveUserId`), never trusted from the
      request body
- [x] Error responses use the standard envelope with `VALIDATION_FAILED`
- [x] Unit tests for the service layer (creates the row under the resolved user id, converts the
      stored `BigInt` price back to a plain number) — `src/modules/products/service.test.ts`, 2
      tests
- [x] Cross-tenant negative test: tenant B's session cannot read tenant A's `products` row — run
      live, passed (empty result)
- [ ] Tests pass **in CI** on an actual merged PR — not checked until that PR is actually open and
      green, per Sprint 01's own rule
- [x] No secret, token, or key written to logs
- [x] Module registry ([modules/README.md](../modules/README.md)) updated to reflect Products'
      build status, including the honest gap against its "Categories, Units" dependency and
      FR-032/FR-035

**Explicitly not in this sprint's DoD subset:** mobile/offline/UI boxes (no Flutter client exists),
`GET`/`PATCH`/`DELETE /products` (deferred past this sprint, per the specification's §4),
category/unit/barcode/SKU/HSN fields (M1 scope, per §1).

## Demo script

**Run 2026-08-01, all 7 steps passed** against the live database, via real HTTP requests to a local
dev server pointed at production Supabase (not a direct service-function call — Sprint 02's own
addendum rule):

1. Sign up and onboard a brand-new tenant A (reusing Sprint 02's onboarding flow). ✅
2. Sign up and onboard a second tenant B, for the cross-tenant check. ✅
3. `POST /api/v1/products` as tenant A — show a `201` with the correct `id`/`name`/`price_minor_units`. ✅ — this is where the `requireSession` bug (below) was first caught.
4. Replay the exact same request (same generated `id`) — show it returns the same product, not a
   duplicate. ✅
5. `POST /api/v1/products` with a missing `name` — show `422 VALIDATION_FAILED`. ✅
6. `POST /api/v1/products` with no bearer token — show `401 UNAUTHENTICATED`. ✅
7. As tenant B's session, attempt to read tenant A's `products` row directly by id — show it is
   denied (empty result). ✅

**A real bug found running step 3 against the live database:** `requireSession` returned `401
UNAUTHENTICATED — Session has no tenant_id claim` even for a freshly-onboarded, refreshed session
whose JWT genuinely carried the claim — because it read the claim from the wrong location
(`user.app_metadata.tenant_id` instead of the JWT's top-level `tenant_id`). Fixed in
`src/core/auth/session.ts`. See Risks above and implementation-log.md for the full account,
including why this had never surfaced before.

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) — a third real instance of "a function that
typechecks and passed every prior sprint's checks was never actually exercised by a real call,"
following the same shape as Sprint 02's addendum and worth its own entry given the pattern is now
three-for-three.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | Sprint 04 planned and built same-day: found and resolved a real spec gap (catalogue.md's full `POST /products` contract vs. backlog.md's M0-minimal scope) before writing code, wrote the Products module specification, implemented and demoed `POST /api/v1/products` live against real infrastructure including a cross-tenant RLS proof. Found and fixed a real, three-sprints-latent bug in `requireSession` (wrong JWT claim location) — its first-ever real exercise. |
