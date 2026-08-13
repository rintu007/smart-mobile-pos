# Module Specification — Roles & Permissions

> **Status:** 🟢 Approved
> **Module:** Roles & Permissions
> **Slice:** V1 — `user_store_roles` table, `user` invite/role-change/deactivate/list, and
> permission enforcement retrofitted across every endpoint built so far (§1)
> **Version:** 0.2.0
> **Last updated:** 2026-08-14
> **Owner:** CTO
> **Approved by:** CTO (self-reviewed against completeness of all 11 sections — solo-founder compensating control, per [repository-setup.md §3](../../15-github-project/repository-setup.md#3-the-honest-gap--solo-founder-review-stated-plainly-rather-than-worked-around))

All eleven sections per [documentation-standards.md §7](../../00-governance/documentation-standards.md#7-module-specification-template).
Written to drive [Sprint 23](../../17-sprints/sprint-23.md) — specification before code, per
[docs/README.md](../../README.md)'s non-negotiable rule #1.

---

## 1. Purpose and business context

[Backlog.md item 7](../../17-sprints/backlog.md#2-m1--fully-decomposed-2026-08-14-now-that-m0-has-reached-this-point):
"`user_store_roles` table, role assignment, enforcement retrofitted across every endpoint built so
far... the one deliberately-last item so it retrofits a stable surface rather than a moving one."
[dependency-graph.md §3](../../16-milestones/dependency-graph.md#3-the-three-cross-cutting-concerns--deliberately-not-on-the-critical-path)
already named this as one of three cross-cutting concerns "woven through every node, not
sequential" — this sprint is where that weaving actually happens, now that the surface (products,
categories, units, stock-movements, sales, sync, stores) is stable enough to retrofit once instead
of repeatedly.

[permission-matrix.md](../../05-personas/permission-matrix.md) and
[authorisation-model.md](../../12-security/authorisation-model.md) already fully designed this in
Phase 05/12 — three fixed roles (Cashier, Manager, Owner), a 7-step fail-closed evaluation order,
and a 4-layer defence-in-depth enforcement table. This sprint is that design's first real
implementation, not a new design.

**Three real gaps found while writing this spec, closed in the same pass:**

1. **Onboarding never assigns a role.** `POST /api/v1/onboarding` (Sprint 02) creates `tenants`,
   `stores`, and `users` rows but — correctly, per [identity.md](../../11-api/endpoints/identity.md)'s
   own explicit note — creates no `user_store_roles` row, since that table didn't exist. It now
   does. Onboarding is extended, in the same transaction, to assign the onboarding user the
   `owner` role at their new store — otherwise the very first user in any tenant would have no
   role at all, and every permission check this sprint adds would lock them out of their own shop.
2. **`GET /audit-log` was never built.** Backlog item 7's own text lists "audit-log reads" as one
   of the endpoints needing enforcement retrofitted onto it — but
   [audit-log/specification.md §1](../audit-log/specification.md#1-purpose-and-business-context)
   explicitly deferred that endpoint *because* Roles & Permissions didn't exist yet. Now that it
   does, this is the natural, already-named moment to close it — built this sprint as part of the
   Audit Log module (its own spec, updated alongside this one), not folded into this module.
3. **`POST /users/invite`'s original mechanism was underspecified.** [identity.md](../../11-api/endpoints/identity.md)
   originally described it as "creates a pending user record; actual Supabase Auth identity is
   established when the invitee completes signup" — without ever specifying *how* that later
   linking would actually work. Supabase Admin's `inviteUserByEmail` resolves this for real: it
   creates the (unconfirmed) Auth identity **synchronously** and returns its `auth_user_id`
   immediately, which this sprint's `users` row is created against directly, in the same call — no
   separate "pending" state or later linking step is needed at all. "The invitee completes signup"
   now just means they set a password and start using an identity that already fully exists in our
   system. `identity.md` is corrected to describe this concretely (§4).

**Deliberately still out of scope:** `PATCH /stores/{id}`, `GET /devices`/`PATCH
/devices/{id}/revoke` (no `devices` table/model exists in code yet — an M0-wide gap this sprint
does not close, named again, not newly found), and a fourth system role (`authorisation-model.md`
§4 already rejected that as speculative generality). No mobile UI — every endpoint this sprint
builds is a back-office, Owner/Manager action; the till itself needs nothing from this module
beyond the permission check already gating what it can call.

## 2. Business rules

- [DR-019](../../03-functional-requirements/business-rules.md)–[DR-021](../../03-functional-requirements/business-rules.md):
  the three role permission sets, exactly as [permission-matrix.md](../../05-personas/permission-matrix.md)
  enumerates them. This spec does not re-derive that matrix; §5 below states, per endpoint, which
  row of it that endpoint enforces.
- [DR-017](../../03-functional-requirements/business-rules.md): every permission check is
  evaluated server-side at the time an operation is actually applied — never trusted from a
  client-reported role. Enforced by construction: the resolved role is looked up fresh from
  `user_store_roles` on every request (§4), never cached across requests or read from the JWT.
- A role assignment is immutable once written and never edited in place — `PATCH /users/{id}/role`
  writes a **new** `user_store_roles` row and sets `revoked_at` on the prior active one, both in one
  transaction, the same "new row, never an edit" reasoning `stock_movements`/`audit_log` already
  established.
- **`LAST_OWNER_CANNOT_BE_REMOVED`**: a tenant's store may never end up with zero active Owners.
  Enforced before `PATCH /users/{id}/role` (changing the last Owner away from `owner`) and before
  `DELETE /users/{id}` (deactivating the last Owner) — both check `countActiveOwners` first and
  reject rather than allow an unrecoverable lockout.
- A deactivated user (`users.deactivated_at IS NOT NULL`) has **no** active permission regardless of
  what `user_store_roles` still says — role resolution joins against `users.deactivated_at IS NULL`
  as well as `revoked_at IS NULL`, so deactivating a user is sufficient by itself; a separate write
  to revoke their role row is not required and this sprint does not perform one (a deliberate
  simplification over a "revoke on deactivate too" alternative — one less write, same effective
  result, and the role history stays intact for audit purposes).
- Every role-affecting write built **this sprint** (`user.created` on invite, `user_store_role`
  assignment on invite/role change, `user.deactivated` on deactivation) produces its own
  `audit_log` entry in the same transaction — [audit-model.md §1](../../07-database/audit-model.md#1-what-triggers-an-audit-entry)
  already names "Role assigned or revoked" and "User created or deactivated" as triggers; this
  sprint is the first code to actually produce them. **Named exception:** onboarding's own
  bootstrap `owner` assignment (§4) writes no audit entry — extending onboarding was scoped to
  "add the missing role row" only (§1), matching how narrowly Sprint 12 itself scoped
  `sale.completed`'s own audit coverage; a real, small, continuing gap in the same shape as that
  sprint's own named one, not silently claimed as covered.

## 3. Database tables and relationships

New table: `user_store_roles`, matching [schema-server.md](../../07-database/schema-server.md)'s
documented shape in full: `id`, `tenant_id`, `user_id`, `store_id`, `role`
(`'cashier'|'manager'|'owner'`), `assigned_by`, `created_at`, `revoked_at`. **Deviates from
schema-server.md:** the documented partial index `(user_id, store_id) WHERE revoked_at IS NULL` is
built here as an ordinary (non-partial) `(user_id, store_id)` index instead — Prisma's schema DSL
has no partial-index syntax (the same gap `DEFERRABLE` foreign keys hit at Sprint 01, resolved the
same way in principle, but not worth a hand-edited migration for an index that's a size/speed
optimisation, not a correctness requirement, at this project's current scale). No `CHECK` constraint
on `role`, matching `stock_movements.movement_type`'s own established precedent of relying on
application code (Zod) rather than a hand-edited migration.

`users` gains no new column. The onboarding bootstrap's `user_store_roles` row reuses `user_id` as
its own `id` — a 1:1 relationship (this call creates exactly one user and exactly one initial role
for them), the same "reuse an existing id for a natural 1:1" pattern `stock_movements` already
established for its own opening-movement/product-creation reuse.

RLS: tenant-scoped, same template as every other table
([supabase/sql/010_rls_user_store_roles.sql](../../../supabase/sql/010_rls_user_store_roles.sql)).

## 4. API contract

| Method & path | Status |
| --- | --- |
| `POST /api/v1/onboarding` | **Extended this sprint.** Now also creates one `user_store_roles` row (`role: 'owner'`) for the onboarding user, in the same transaction as the tenant/store/user rows. Request/response shape unchanged. |
| `GET /api/v1/users` | **Built this sprint.** Manager, Owner. Lists this tenant's users at their one store, each with their current active role (`null` if none/deactivated). Cursor-paginated on `(created_at, id)` — Tier 2, `users` has no `updated_at`. |
| `POST /api/v1/users/invite` | **Built this sprint.** Owner only. `id` (client-generated UUID, the new `users` row's id — doubles as the idempotency key), `email`, `display_name`, `role`. Creates the Supabase Auth identity via `admin.inviteUserByEmail` (§1, point 3), then the `users` row (using the identity's real, immediately-known `auth_user_id`) and its initial `user_store_roles` row, all in one transaction. `store_id`/`assigned_by` resolved server-side, never from the request. |
| `PATCH /api/v1/users/{id}/role` | **Built this sprint.** Owner only. `id` in the path is the target `users.id`; body carries `id` (client-generated UUID for the new `user_store_roles` row, the idempotency key) and `role`. Revokes the prior active assignment and creates the new one, transactionally. `LAST_OWNER_CANNOT_BE_REMOVED` guarded. |
| `DELETE /api/v1/users/{id}` | **Built this sprint.** Owner only. Sets `deactivated_at` (Tier 1 soft delete, per [ADR-0009](../../adr/ADR-0009-soft-delete-for-reference-data-no-delete-for-ledger-data.md)) — never a hard delete, no change to `user_store_roles` rows themselves (§2). `LAST_OWNER_CANNOT_BE_REMOVED` guarded. |
| `POST /api/v1/products`, `POST /api/v1/categories`, `POST /api/v1/units`, `POST /api/v1/stock-movements` | **Enforcement retrofitted this sprint.** Manager, Owner — "Create/edit a product, category, or unit" / "Record a stock adjustment" ([permission-matrix.md](../../05-personas/permission-matrix.md)). |
| `GET /api/v1/products`, `GET /api/v1/categories`, `GET /api/v1/units`, `GET /api/v1/products/{id}/stock-balance`, `GET /api/v1/stores` | **Enforcement retrofitted this sprint.** Cashier, Manager, Owner — "any authenticated role" per each endpoint's own already-documented Permission column. |
| `GET /api/v1/stock-movements` | **Enforcement retrofitted this sprint.** Manager, Owner — [inventory.md](../../11-api/endpoints/inventory.md)'s own already-documented Permission column, more specific than the general catalogue-view row. |
| `POST /api/v1/sales` | **Enforcement retrofitted this sprint.** Cashier, Manager, Owner — "Complete a sale" ([permission-matrix.md](../../05-personas/permission-matrix.md)). |
| `POST /api/v1/sync/push`, `GET /api/v1/sync/pull` | **Enforcement retrofitted this sprint.** Cashier, Manager, Owner (any active role) — sync is a device-level mechanism, not itself a listed capability in the permission matrix; the check here is "has an active, non-deactivated role at all," which meaningfully blocks a revoked/deactivated user even from syncing. |
| `GET /api/v1/audit-log` | **Built this sprint**, in the Audit Log module (its own spec) — Manager, Owner. |

No permission check exists yet for `PATCH /stores/{id}` or any `devices` endpoint — neither is built
in code (§1).

## 5. Validation rules (client and server)

| Field | Rule |
| --- | --- |
| `id` (invite, role-change) | UUID v4 — Zod `.uuid()`. |
| `email` (invite) | Zod `.email()`. |
| `display_name` (invite) | `.trim().min(1).max(200)`, same convention as every other display-name field in this codebase. |
| `role` (invite, role-change) | Zod `.enum(["cashier", "manager", "owner"])`. |
| `cursor`/`limit` (list users) | Same `.int().positive().max(200).default(50)` convention as every other list endpoint. |

**The permission check itself is not a per-field Zod rule** — it is a separate, request-wide gate
(`requirePermission`, §4/§6) evaluated in the Route Handler before the handler's own body-parsing
logic runs, matching [authorisation-model.md §3](../../12-security/authorisation-model.md#3-enforcement-points--three-not-one-deliberately-redundant)'s
own stated ordering ("evaluated **before** the handler's own logic runs").

## 6. Error handling and user-facing messages

| Code | HTTP | Cause |
| --- | --- | --- |
| `PERMISSION_DENIED` | 403 | Already reserved (cross-cutting, [error-catalogue.md](../../11-api/error-catalogue.md)), implemented this sprint: the resolved role (or its absence) does not satisfy the endpoint's required role set. |
| `LAST_OWNER_CANNOT_BE_REMOVED` | 409 | Already reserved ([identity.md](../../11-api/endpoints/identity.md)), implemented this sprint: `PATCH /users/{id}/role` or `DELETE /users/{id}` would leave zero active Owners. |
| `EMAIL_ALREADY_REGISTERED` | 409 | **New.** `POST /users/invite`'s `email` already has a Supabase Auth identity (Supabase Admin's own duplicate-email rejection, translated to a named code rather than surfaced as a raw provider error). |
| `NOT_FOUND` | 404 | `PATCH /users/{id}/role`/`DELETE /users/{id}` target a `users.id` that doesn't exist under the caller's tenant. |
| `VALIDATION_FAILED` | 422 | Any Zod failure on the three new endpoints' request shape. |

**`requirePermission`'s own failure is fail-closed at every step**, per
[authorisation-model.md §2](../../12-security/authorisation-model.md#2-evaluation-order--every-request-in-this-sequence-fail-closed-at-every-step):
no active role resolved → `PERMISSION_DENIED`, not a silent "treat as Cashier" default; an
unexpected exception during resolution propagates as `500 INTERNAL`, never caught and treated as
"allow."

## 7. Offline behaviour

All five endpoints this sprint builds are **online-only, back-office actions** — no mobile screen
calls any of them this sprint (§9), matching `categories`/`units`' own online-only-write precedent
even before a mobile UI exists for either. Permission enforcement itself has no offline dimension
of its own: every retrofitted endpoint's *existing* offline/online behaviour (documented in that
module's own §7) is unchanged — a permission check added in front of an already-online-only
endpoint doesn't change its connectivity story, and `POST /sync/push`'s own queued-offline-operation
model is unchanged too, just now also checked for an active role at push time.

## 8. Realtime behaviour

None specified for V1 — no requirement found for a live push when a role changes mid-session. A
user whose role changes (or is revoked) keeps whatever the client already fetched until their next
request, at which point the fresh `requirePermission` check reflects the change — the same "next
request re-evaluates" reasoning [authorisation-model.md §2](../../12-security/authorisation-model.md#2-evaluation-order--every-request-in-this-sequence-fail-closed-at-every-step)
already states (no caching across requests).

## 9. UI specification

None this sprint — every endpoint built is a back-office action with no mobile screen yet
(`/settings/users` or similar, per a future route-map.md addition, is not built). The till itself
needs no new UI: its own existing screens simply start receiving `403 PERMISSION_DENIED` for
actions their role can't perform, a case [state-presentation.md §3](../../10-design-system/state-presentation.md#3-error)
already has generic handling for; a dedicated permission-denied UI treatment
([patterns.md §6](../../10-design-system/patterns.md#6-permission-denied)) remains a future mobile
sprint's concern, not this one's.

## 10. Test plan

- Unit tests (`roles/service.test.ts`): `resolveActiveRole` returns `null` for no assignment and for
  a deactivated user even with an active assignment; `inviteUser` rejects a duplicate email with
  `EMAIL_ALREADY_REGISTERED`, creates the user+role transactionally otherwise; `changeRole` rejects
  removing the last Owner with `LAST_OWNER_CANNOT_BE_REMOVED`, is idempotent on the new assignment's
  own `id`; `deactivateUser` rejects deactivating the last Owner, otherwise sets `deactivated_at`;
  `listUsers` passes through pagination correctly.
- Unit tests (`audit-log/service.test.ts`): filters/pagination pass through correctly; malformed
  cursor rejected.
- **Live verification, real database, throwaway tenants (deleted after) — 12/12 checks passed**,
  plus `POST /users/invite` itself confirmed separately (below):
  1. Onboarding a fresh tenant → exactly one `user_store_roles` row, `role = 'owner'`, for the
     onboarding user.
  2. That Owner calling `POST /products` (a Manager/Owner-only endpoint) succeeds.
  3. A Cashier-role user calling the same endpoint → `403 PERMISSION_DENIED`.
  4. The same Cashier calling `GET /products` → succeeds (a Cashier-allowed endpoint).
  5. `PATCH /users/{id}/role` demoting the tenant's only Owner → `409
     LAST_OWNER_CANNOT_BE_REMOVED`; promoting the Cashier to Owner first, then demoting the
     original Owner → succeeds.
  6. **The original Owner's own already-issued access token**, unchanged and unrefreshed, now
     resolves as their new (demoted) role on its very next request — `403 PERMISSION_DENIED` on
     `GET /audit-log` — live proof of DR-017: role is never cached or JWT-carried, only ever
     resolved fresh from `user_store_roles` at request time.
  7. The newly promoted Owner's `GET /audit-log` → `200`, shows the `user_store_role.assigned`
     entries from the two role changes above.
  8. `DELETE /users/{id}` deactivating the original user → their next `GET /products` call (an
     any-role endpoint) → `403 PERMISSION_DENIED` (deactivated, not merely role-insufficient).
  9. Cross-tenant RLS: tenant B's session reads zero of tenant A's `user_store_roles`/`audit_log`
     rows via `GET /users`/`GET /audit-log`.

  **`POST /users/invite` itself** (permission gate, Zod validation, the Supabase Admin call, and
  transactional row/audit creation) was confirmed live earlier in this same verification session —
  a real `201`, correct `role`/`id` in the response, `users`/`user_store_roles`/two `audit_log` rows
  all created correctly. A **second** real invite call, made to test `EMAIL_ALREADY_REGISTERED`,
  instead hit Supabase's own email-send rate limit (`over_email_send_rate_limit`) — a genuine,
  shared-project external constraint (the founder's real Supabase project, not a disposable test
  one), not a code defect. Rather than retry against it repeatedly, the remaining checks above (2-9)
  seed their second tenant-A member via a direct database insert instead of a second real invite —
  those checks exercise `PATCH`/`DELETE`/`GET`, none of which touch Supabase's mailer, so the
  substitution doesn't weaken what they prove. `EMAIL_ALREADY_REGISTERED`'s own translation logic is
  covered by `roles/service.test.ts`'s mocked-`supabaseAdmin` unit test instead.

## 11. Traceability

| Requirement | Covered by | Status |
| --- | --- | --- |
| [DR-017](../../03-functional-requirements/business-rules.md) (server-side, never client-trusted permission check) | §2, §6 | Met |
| [DR-019](../../03-functional-requirements/business-rules.md)–[DR-021](../../03-functional-requirements/business-rules.md) (three role permission sets) | §4, §10 | Met, for every endpoint that exists in code (§1's named exceptions aside) |
| [permission-matrix.md](../../05-personas/permission-matrix.md) (48-cell matrix) | §4 | Met for the subset of capabilities that have a built endpoint; unbuilt capabilities (returns, reports, settings, day-close, devices) have no endpoint to enforce against yet |
| [authorisation-model.md §2](../../12-security/authorisation-model.md#2-evaluation-order--every-request-in-this-sequence-fail-closed-at-every-step) (7-step fail-closed order) | §2, §6 | Met for steps 1, 3, 4, 5, 7 (JWT, tenant, role, endpoint permission, RLS) — step 2 (device revocation) remains unmet, no `devices` table exists; step 6 (business-rule-specific checks) is each module's own pre-existing concern, unchanged |
| [audit-model.md §1](../../07-database/audit-model.md#1-what-triggers-an-audit-entry) (role/user changes audited) | §2, §10 | Met |

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | First version — written to drive Sprint 23's implementation of Roles & Permissions (backlog.md item 7): `user_store_roles` table, `GET/POST/PATCH/DELETE /users*`, permission enforcement retrofitted across every existing endpoint. Three real gaps found and closed in the same pass: onboarding never assigned a role, `GET /audit-log` was named as a retrofit target but never built, and `POST /users/invite`'s original "pending record" mechanism is resolved concretely via Supabase Admin's synchronous `inviteUserByEmail`. |
| 0.2.0 | 2026-08-14 | §4/§10 corrected after implementation and live verification: a real routing bug was found and fixed (`POST /users/invite` initially lived under `users/route.ts`, which Next.js resolved to `/users`, not `/users/invite` — a static `users/invite/route.ts` sibling was needed, since Next matches a static segment only when a file for it exists, otherwise falling through to `users/[id]`). Live verification also found a real external constraint: a second real `POST /users/invite` call (to test `EMAIL_ALREADY_REGISTERED`) hit Supabase's own email-send rate limit on the founder's shared project — the first real call had already succeeded correctly; §10 updated to state exactly what was proven live (12/12 for the role-management chain) versus what the invite endpoint itself proved separately before the rate limit was hit. |
