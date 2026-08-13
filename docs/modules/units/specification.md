# Module Specification — Units

> **Status:** 🟢 Approved
> **Module:** Units
> **Slice:** V1 — this document scopes only Sprint 18's minimal first cut, not the full V1 shape (§1)
> **Version:** 0.3.0
> **Last updated:** 2026-08-14
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 18](../../17-sprints/sprint-18.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1. Second M1 module, direct sibling of
[Categories](../categories/specification.md) (Sprint 17) — same shape, same scope cut, no
dependency between the two.

---

## 1. Purpose and business context

Lets a shop define the units its products are sold in (piece, kilogram, litre, …) and whether a
unit permits fractional quantities — [FR-037](../../03-functional-requirements/functional-requirements.md)
("a product's unit determines whether fractional sale quantities are accepted") and
[FR-038](../../03-functional-requirements/functional-requirements.md) (till-side quantity-entry
behaviour driven by that flag), both currently **unmet**: `products` has no `unit_id` column at
all yet, the same named gap `category_id` had before Sprint 17 (`products/specification.md §1`,
since Sprint 04). This module is the second of the two prerequisites Products has been waiting on;
extending `products` to actually require and use both `category_id` and `unit_id` is
[backlog.md item 3](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point),
a later, dependent sprint — not this one.

**Deliberately narrow scope, matching Categories' own precedent exactly:** this sprint builds
`POST /units` (create) and `GET /units` (list) only. `PATCH`/`DELETE /units` — already documented
in [catalogue.md](../../11-api/endpoints/catalogue.md), including the `UNIT_FRACTIONAL_FLAG_LOCKED`
conflict (`allows_fractional` becomes immutable once any product references the unit) and the
state-transition idempotency mechanism ([api-principles.md §3](../../11-api/api-principles.md#3-idempotency--two-mechanisms-matched-to-two-kinds-of-mutation))
that still doesn't exist anywhere in this codebase (Sprint 17 named this gap; it remains open,
not rebuilt or worked around here) — are deferred, named here rather than silently produced.
**Permission-checked as of Sprint 23**: `POST /units` requires Manager/Owner, `GET /units` any
role, per [roles-permissions/specification.md](../roles-permissions/specification.md) — the M1
item 7 retrofit this section originally named as still pending.

## 2. Business rules

- A unit belongs to exactly one tenant (`tenant_id`), shared across all of that tenant's stores —
  catalogue data is tenant-scoped, not store-scoped
  ([schema-server.md](../../07-database/schema-server.md) Context 2's own explicit design call,
  the same as `categories`/`products`).
- `name` and `symbol` are both required, non-empty. `allows_fractional` is a boolean, defaulting to
  `false` when omitted — matching [schema-server.md](../../07-database/schema-server.md)'s own
  `NOT NULL DEFAULT false`.
- **`allows_fractional`'s immutability rule is a `PATCH`-only concern, named but not enforced this
  sprint:** [catalogue.md](../../11-api/endpoints/catalogue.md) documents it becoming locked once a
  product references the unit, via `UNIT_FRACTIONAL_FLAG_LOCKED`. Since `PATCH /units` isn't built
  yet (§1) and `products.unit_id` doesn't exist yet either (backlog.md item 3), there is nothing for
  this rule to protect against this sprint — no code enforces it, and none is needed to.
- Creation is idempotent on the client-generated `id` ([ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md)):
  replaying the same request with the same `id` returns the original row unchanged — the same
  mechanism every M0/M1 creation endpoint already uses.
- No uniqueness constraint on `name` or `symbol` — two units with the same name/symbol are
  permitted (not required by any FR/BR/DR found; a real shop's own naming discipline governs this,
  not the schema), matching Categories' own precedent for `name`.

## 3. Database tables and relationships

`units`, per [schema-server.md](../../07-database/schema-server.md) Context 2 — this sprint
implements the table's **full** column list, matching Categories' own precedent: `id`, `tenant_id`,
`name`, `symbol`, `allows_fractional`, `created_at`, `created_by`. (`deactivated_at` exists in the
approved design for the `DELETE` endpoint's soft-delete, deferred alongside `PATCH`/`DELETE`
themselves — §1. `updated_at` is added when `PATCH` lands, since nothing before it can change a
unit.)

RLS: tenant-scoped, same template as every other M0/M1-minimal table
([supabase/sql/009_rls_units.sql](../../../supabase/sql/009_rls_units.sql)).

No FK from `products.unit_id` yet — that column doesn't exist until
[backlog.md item 3](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point).

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/units` | **Implemented Sprint 18.** Request: `{ id, name, symbol, allows_fractional? }` (defaults to `false`). Requires Manager/Owner (`requirePermission`, Sprint 23 — §2). |
| `GET /api/v1/units` | **Implemented this sprint.** Cursor-paginated per [api-principles.md §4](../../11-api/api-principles.md#4-pagination--cursor-only), `(created_at, id)` — same reasoning as Categories: a Tier 1 table normally cursors on `(updated_at, id)`, but `updated_at` doesn't exist yet (§3), so `created_at` is used until `PATCH` adds it. |
| `PATCH /api/v1/units/{id}`, `DELETE /api/v1/units/{id}` | **Already documented** in [catalogue.md](../../11-api/endpoints/catalogue.md), **not implemented, and not needed this sprint** — see §1. |

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `id` | UUIDv4, required — client-generated per [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) |
| `name` | Non-empty string, required, max 200 chars (matching `categories.name`'s own limit) |
| `symbol` | Non-empty string, required, max 20 chars |
| `allows_fractional` | Boolean, optional, defaults to `false` |

## 6. Error handling and user-facing messages

`VALIDATION_FAILED` (422) for schema failures, per
[error-catalogue.md](../../11-api/error-catalogue.md) — no new error code needed this sprint
(`UNIT_FRACTIONAL_FLAG_LOCKED` belongs to the deferred `PATCH` endpoint). No user-facing copy
specified here, same reasoning as every other backend-only M0/M1 sprint.

## 7. Offline behaviour

Same correction as [categories/specification.md §7](../categories/specification.md#7-offline-behaviour),
for the identical reason: the sync engine has no `unit.create` push operation type, so Sprint 20's
`/catalogue/units` creates a unit via a **direct, online-only** `POST /api/v1/units` call, caching
the result into a local Drift `Units` table on success. Reads are offline-capable (local cache);
writes are not. Named here and in [schema-local.md](../../07-database/schema-local.md)/
[route-map.md](../../09-navigation/route-map.md), not silently narrowed.

## 8. Realtime behaviour

None specified for V1 — no requirement found for live unit-list push to other devices.

## 9. UI specification

**Built Sprint 20.** `/catalogue/units` (route-map.md, Manager+) —
`apps/mobile/lib/features/catalogue/presentation/screens/units_screen.dart`: a name-ordered list
(empty state if none exist yet) with a FAB opening a dialog (name, symbol, an
"allows fractional quantities" checkbox) to create a new one. Same design-system reasoning as
`CategoriesScreen`. Also referenced from
[products/specification.md §9](../products/specification.md#9-ui-specification): `/catalogue/add`
now requires picking a unit created here.

## 10. Test plan

**Sprint 18 scope:**
- Unit tests: `POST /api/v1/units` creates exactly one row with the given `id`/`name`/`symbol`/
  `allows_fractional`; a retry with the identical `id` is a no-op (idempotent replay); validation
  rejects a missing/empty `name`/`symbol` and a malformed `id`; `GET /api/v1/units` returns a
  tenant's own units, cursor-paginated.
- **Real HTTP request required before this endpoint is marked done** — Sprint 02's addendum rule:
  live-verified against the real database, throwaway tenants deleted after, including a
  cross-tenant RLS proof (tenant B cannot read tenant A's units) and a cursor-pagination walk.

**Explicitly deferred:** `PATCH`/`DELETE /units`, `UNIT_FRACTIONAL_FLAG_LOCKED`,
`products.unit_id`, mobile UI.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [FR-037](../../03-functional-requirements/functional-requirements.md) (unit determines fractional-quantity acceptance) | §2, §3 | Partially met — the flag exists and is stored; nothing reads or enforces it yet (`products.unit_id`/till logic are later items) |
| [FR-038](../../03-functional-requirements/functional-requirements.md) (till-side quantity-entry behaviour driven by the flag) | — | **Not met this sprint** — needs `products.unit_id` (item 3) and mobile till UI (item 4/5) |
| [ADR-0007](../../adr/ADR-0007-client-generated-uuid-primary-keys.md) (client-generated UUID PKs, idempotent creation) | §2, §5 | Met |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | First version — written to drive Sprint 18's minimal `POST`/`GET /units`. Scope deliberately narrow: create+list only, no `PATCH`/`DELETE`, no permission enforcement, no mobile UI — mirrors Categories (Sprint 17) exactly. |
| 0.2.0 | 2026-08-14 | Sprint 20 (backlog item 4): mobile UI built — `/catalogue/units` list+create screen, local `Units` Drift table (read cache only). §7 corrected: creation calls the server directly (online-only), same reasoning as Categories' identical correction. |
| 0.3.0 | 2026-08-14 | Sprint 23: permission enforcement applied — `POST /units` now requires Manager/Owner, `GET /units` any role. |
