# Module Specification — Categories

> **Status:** 🟢 Approved
> **Module:** Categories
> **Slice:** V1 — this document scopes only Sprint 17's minimal first cut, not the full V1 shape (§1)
> **Version:** 0.1.0
> **Last updated:** 2026-08-14
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 17](../../17-sprints/sprint-17.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1. First M1 module — see
[backlog.md item 1](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point).

---

## 1. Purpose and business context

Lets a shop organise its products into a single-level category structure — [FR-035](../../03-functional-requirements/functional-requirements.md)
("every product belongs to exactly one category, selected at creation") and
[FR-036](../../03-functional-requirements/functional-requirements.md) ("the POS product grid can be
filtered by category"), both currently **unmet**: `products` has no `category_id` column at all
yet (M0's own named gap, `products/specification.md §1`, since Sprint 04). This module is the
prerequisite Products itself has been waiting on; extending `products` to actually require and use
`category_id` is [backlog.md item 3](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point),
a later, dependent sprint — not this one.

**Deliberately narrow scope, matching M0's own products-module precedent (Sprint 04, "shipping
create-only first"):** this sprint builds `POST /categories` (create) and `GET /categories` (list)
only. `PATCH`/`DELETE /categories` — already documented in
[catalogue.md](../../11-api/endpoints/catalogue.md), including the `CATEGORY_IN_USE` conflict and
the state-transition idempotency mechanism ([api-principles.md §3](../../11-api/api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation))
neither of which exists anywhere in this codebase yet (no endpoint has needed
`idempotency_keys`/`client_operation_id`-based state-transition idempotency before — every M0
mutation so far has been a creation, not an edit) — are deferred, named here rather than silently
produced. No permission check beyond a valid, tenant-scoped session: [Roles & Permissions](../../17-sprints/backlog.md)
is its own later M1 item (item 7), deliberately last so it retrofits a stable surface — the same
scope boundary every M0 module already used for the identical reason.

## 2. Business rules

- A category belongs to exactly one tenant (`tenant_id`), shared across all of that tenant's
  stores — catalogue data is tenant-scoped, not store-scoped
  ([schema-server.md](../../07-database/schema-server.md) Context 2's own explicit design call,
  the same as `products`).
- `name` is required, non-empty — no other field exists on this table
  ([BR-018](../../02-business-requirements/business-requirements.md): "a single-level category
  structure," i.e. no parent/child nesting, ever, by design).
- Creation is idempotent on the client-generated `id` ([ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md)):
  replaying the same request with the same `id` returns the original row unchanged — the same
  mechanism every M0 creation endpoint already uses.
- No uniqueness constraint on `name` — two categories with the same name are permitted (not
  required by any FR/BR/DR found; a real shop's own naming discipline governs this, not the
  schema).

## 3. Database tables and relationships

`categories`, per [schema-server.md](../../07-database/schema-server.md) Context 2 — this sprint
implements the table's **full** column list, unlike `products`/`sales`/`stock_movements`'s own
M0-minimal subsets: `id`, `tenant_id`, `name`, `created_at`, `created_by`. (`deactivated_at` exists
in the approved design for the `DELETE` endpoint's soft-delete, deferred alongside `PATCH`/`DELETE`
themselves — §1. `updated_at` is added when `PATCH` lands, since nothing before it can change a
category.)

RLS: tenant-scoped, same template as every other M0-minimal table
([supabase/sql/008_rls_categories.sql](../../../supabase/sql/008_rls_categories.sql)).

No FK from `products.category_id` yet — that column doesn't exist until
[backlog.md item 3](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point).

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/categories` | **Implemented this sprint.** Request: `{ id, name }`. Requires a valid tenant-scoped session (`requireSession`) — no role/permission check yet (§2). |
| `GET /api/v1/categories` | **Implemented this sprint.** Cursor-paginated per [api-principles.md §4](../../11-api/api-principles.md#4-pagination--cursor-only), `(created_at, id)` — a Tier 1 table normally cursors on `(updated_at, id)`, but `updated_at` doesn't exist yet (§3), so `created_at` is used until `PATCH` adds it. |
| `PATCH /api/v1/categories/{id}`, `DELETE /api/v1/categories/{id}` | **Already documented** in [catalogue.md](../../11-api/endpoints/catalogue.md), **not implemented, and not needed this sprint** — see §1. |

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `id` | UUIDv4, required — client-generated per [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) |
| `name` | Non-empty string, required, max 200 chars (matching `products.name`'s own limit) |

## 6. Error handling and user-facing messages

`VALIDATION_FAILED` (422) for schema failures, per
[error-catalogue.md](../../11-api/error-catalogue.md) — no new error code needed this sprint
(`CATEGORY_IN_USE` belongs to the deferred `DELETE` endpoint). No user-facing copy specified here,
same reasoning as every other backend-only M0 sprint.

## 7. Offline behaviour

The server endpoint itself requires connectivity, same as any `POST`/`GET` — but per
[catalogue.md](../../11-api/endpoints/catalogue.md), `POST /categories` is documented as
**offline-capable** in the full V1 design (queued via `outbound_queue`). Mobile is out of scope
this sprint (§1, [backlog.md item 4](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point)) —
named, not silently deferred.

## 8. Realtime behaviour

None specified for V1 — no requirement found for live category-list push to other devices.

## 9. UI specification

None this sprint — `/catalogue/categories` (route-map.md, Manager+) is mobile scope,
[backlog.md item 4](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point),
not built yet.

## 10. Test plan

**Sprint 17 scope:**
- Unit tests: `POST /api/v1/categories` creates exactly one row with the given `id`/`name`; a
  retry with the identical `id` is a no-op (idempotent replay); validation rejects a missing/empty
  `name` and a malformed `id`; `GET /api/v1/categories` returns a tenant's own categories,
  cursor-paginated.
- **Real HTTP request required before this endpoint is marked done** — Sprint 02's addendum rule:
  live-verified against the real database, throwaway tenants deleted after, including a
  cross-tenant RLS proof (tenant B cannot read tenant A's categories) and a cursor-pagination walk.

**Explicitly deferred:** `PATCH`/`DELETE /categories`, `CATEGORY_IN_USE`, state-transition
idempotency, `products.category_id`, mobile UI.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [BR-018](../../02-business-requirements/business-requirements.md) (single-level category structure) | §2, §3 | Met — no nesting column exists, by design |
| [FR-035](../../03-functional-requirements/functional-requirements.md) (every product belongs to exactly one category) | — | **Not met this sprint** — `products.category_id` doesn't exist yet, tracked to backlog.md item 3 |
| [FR-036](../../03-functional-requirements/functional-requirements.md) (POS grid filterable by category) | — | **Not met this sprint** — needs both `products.category_id` (item 3) and the mobile catalogue UI (item 4/5) |
| [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) (client-generated UUID PKs, idempotent creation) | §2, §5 | Met |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | First version — written to drive Sprint 17's minimal `POST`/`GET /categories`. Scope deliberately narrow: create+list only, no `PATCH`/`DELETE`, no permission enforcement, no mobile UI — all named, matching M0's own products-module precedent exactly. |
