# Module Specification — Products

> **Status:** 🟢 Approved
> **Module:** Products (Categories, Units, Products in [scope-and-release-slices.md](../../01-vision/scope-and-release-slices.md)'s
> business-scoping grouping; tracked as its own row in the [module registry](../README.md), per
> [mobile-structure.md](../../08-folder-structure/mobile-structure.md)'s own note that the two
> groupings are different, valid axes over the same modules)
> **Slice:** V1 — this document scopes only M0's minimal first cut, not the full V1 shape (§1)
> **Version:** 0.1.0
> **Last updated:** 2026-08-01
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 04](../../17-sprints/sprint-04.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

Lets a shop record what it sells. [backlog.md item 5](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)
scopes M0 to **name and price only** — no category, unit, barcode, SKU, or HSN/SAC — because
Categories and Units are explicitly [M1 scope](../../17-sprints/backlog.md#2-m1m4--module-grain-only-decomposed-when-reached),
not M0. This is a real, named gap against the full V1 requirement, not an oversight:
[FR-032](../../03-functional-requirements/functional-requirements.md) requires category and unit as
required fields, and [FR-035](../../03-functional-requirements/functional-requirements.md) requires
every product to belong to exactly one category. M0 does not meet either yet — the same shape of
scope boundary the module registry already documents for Authentication's device revocation
("not yet built"). §11 states this plainly rather than claiming compliance this sprint doesn't earn.

## 2. Business rules

- A product belongs to exactly one tenant (`tenant_id`), never shared or copied across tenants.
- `price_minor_units` is a non-negative integer in minor currency units, never a decimal — per
  [ADR-0006](../../adr/ADR-0006-money-as-integer-minor-units.md).
- `name` is required, non-empty, max 200 characters — no other field is required at creation in M0
  (contrast with FR-032's full V1 requirement — see §1).
- Creation is idempotent on the client-generated `id` ([ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md)):
  replaying the same request with the same `id` returns the original row unchanged, never a
  duplicate or an error — same mechanism Sprint 02 already established for `POST /api/v1/onboarding`.
- No permission check beyond a valid, tenant-scoped session (§4) — [Roles & Permissions](../../17-sprints/backlog.md)
  is explicitly M1 scope, so the "Manager, Owner" permission [catalogue.md](../../11-api/endpoints/catalogue.md)
  documents for the full V1 endpoint cannot be enforced yet; this is a named scope boundary, the
  same pattern Sprint 02 used for Company & Store Setup's signing-up user getting no formal role.

## 3. Database tables and relationships

`products`, per [schema-server.md](../../07-database/schema-server.md) Context 2 — but this sprint
implements only a subset of that table's full column list: `id`, `tenant_id`, `name`,
`price_minor_units`, `created_at`, `updated_at`, `created_by`. **Not yet built:** `category_id`,
`unit_id`, `sku`, `barcode`, `hsn_sac_code`, `deactivated_at` — added once Categories/Units (M1)
exist for the first two to reference, and once M1's fuller Products scope needs the rest. This
mirrors exactly how `apps/web/prisma/schema.prisma` already treats `schema-server.md` as the full
target design, implemented incrementally sprint by sprint (its own header comment says so for
Sprint 01's `tenants`/`users` slice).

RLS: tenant-scoped, same template as `stores`
([supabase/sql/003_rls_stores.sql](../../../supabase/sql/003_rls_stores.sql)) — `products` has a
`tenant_id` column, so no special-casing is needed (contrast with `tenants` itself).

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/products` | **Implemented this sprint.** Request: `{ id, name, price_minor_units }` only — not the full shape [catalogue.md](../../11-api/endpoints/catalogue.md) documents (see that document's own dated correction note). Requires a valid tenant-scoped session (`requireSession`) — no role/permission check yet (§2). |
| `GET /products` | **Already documented**, not yet implemented — [catalogue.md](../../11-api/endpoints/catalogue.md). Deferred past this sprint, matching Sprint 02's precedent of shipping create-only first. |
| `PATCH /products/{id}`, `DELETE /products/{id}` | **Already documented**, not yet implemented — deferred past this sprint. |

**Also explicitly out of scope this sprint:** the mobile-side local write path (Drift insert +
`outbound_queue` enqueue) [backlog.md item 5](../../17-sprints/backlog.md#1-m0--walking-skeleton-fully-decomposed)'s
own text bundles alongside the server endpoint. No Flutter feature screen or data layer exists yet
(`apps/mobile/features/catalogue/` is still empty — [Sprint 03](../../17-sprints/sprint-03.md) built
only the Drift schema, not a feature on top of it). Building the server endpoint first, proven live,
is this sprint's actual scope; the mobile write path is a follow-up sprint's work, named here rather
than silently dropped.

## 5. Validation rules (client and server)

Request body for `POST /api/v1/products` (Zod schema, server-side):

| Field | Rule |
| --- | --- |
| `id` | UUIDv4, required — client-generated per [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) |
| `name` | Non-empty string, required, max 200 chars |
| `price_minor_units` | Non-negative integer, required |

## 6. Error handling and user-facing messages

`VALIDATION_FAILED` (422) for schema failures, per
[error-catalogue.md](../../11-api/error-catalogue.md) — no new error code needed this sprint (no
uniqueness constraint exists yet without `barcode`/`sku`). No user-facing copy specified here, same
reasoning as Company & Store Setup's spec §6 (backend-only sprint, no mobile screen yet).

## 7. Offline behaviour

The server endpoint itself requires connectivity, same as any `POST` — but per
[catalogue.md](../../11-api/endpoints/catalogue.md), `POST /products` is documented as
**offline-capable** in the full V1 design (queued via `outbound_queue`, per
[sync-api.md](../../11-api/sync-api.md)'s "Products created offline" dependency-ordering note). That
offline path is exactly the mobile local-write-path scope named as deferred in §4 — this sprint
proves only the direct online path.

## 8. Realtime behaviour

None specified for V1 (no requirement found for live product-list push to other devices in this
sprint's scope) — other devices see a new product via the next `GET /products` pull, once that
endpoint exists (§4).

## 9. UI specification

`apps/mobile/features/catalogue/` per [mobile-structure.md](../../08-folder-structure/mobile-structure.md) —
no screen built yet, same statement as Company & Store Setup's spec §9. Not a blocker: this sprint
(per its own capacity check, [sprint-04.md](../../17-sprints/sprint-04.md)) is backend-only.

## 10. Test plan

**Sprint 04 scope:**
- Unit test: `POST /api/v1/products` creates exactly one `products` row with the given `id`,
  `name`, `price_minor_units`.
- Unit test: a retry with the identical `id` is a no-op (idempotent replay), same mechanism as
  onboarding.
- Unit test: validation rejects a missing `name`, a negative `price_minor_units`, and a malformed
  `id`.
- Cross-tenant negative test: tenant A's session cannot read tenant B's `products` row — requires
  RLS (§3), run live against the real database, same proof style as Sprint 02's `stores` test.
- **Real HTTP request required before this endpoint is marked done** — Sprint 02's addendum rule
  ([retrospective-log.md](../../17-sprints/retrospective-log.md)): a unit-tested, typechecked
  service is not the same claim as a working HTTP endpoint.

**Explicitly deferred past Sprint 04:** `GET`/`PATCH`/`DELETE /products`, the mobile local write
path (§4), everything FR-032/FR-035 require beyond name/price (§1).

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-032](../../03-functional-requirements/functional-requirements.md) (name, price, unit, category required) | §5 | **Partially met** — name/price only; unit/category deferred to M1 (§1) |
| [FR-033](../../03-functional-requirements/functional-requirements.md) (SKU/barcode/HSN optional) | — | Not yet applicable — those fields don't exist in this sprint's schema slice (§3) |
| [FR-035](../../03-functional-requirements/functional-requirements.md) (every product belongs to exactly one category) | — | **Not met this sprint** — no category concept exists yet (§1); tracked to M1 |
| [ADR-0006](../../adr/ADR-0006-money-as-integer-minor-units.md) (money as integer minor units) | §2 | Met |
| [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) (client-generated UUID PKs, idempotent creation) | §2, §5 | Met |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-01 | First version — written to drive Sprint 04's implementation of `POST /api/v1/products`. Scope deliberately narrow (name/price only); FR-032/FR-035's category/unit requirement and the mobile local write path both named as not-yet-met rather than silently claimed. |
