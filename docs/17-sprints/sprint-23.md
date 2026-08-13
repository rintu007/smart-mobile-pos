# Sprint 23

> **Dates:** 2026-08-14 – 2026-08-14 (single-day, same cadence as every prior sprint)
> **Milestone:** M1 — Full Catalogue & Inventory, Multi-Role (backlog item 7)
> **Status:** Closed

## Goal

Roles & Permissions in full: `user_store_roles`, role assignment (`GET/POST/PATCH/DELETE
/users*`), and permission enforcement retrofitted across every endpoint built so far — the one
deliberately-last M1 item, per
[dependency-graph.md §3](../16-milestones/dependency-graph.md#3-the-three-cross-cutting-concerns--deliberately-not-on-the-critical-path)'s
own "woven through every node, not sequential" framing.

## Scope

| Item | Module | Estimate (person-days) | Depends on |
| --- | --- | --- | --- |
| `user_store_roles` table, role assignment, enforcement retrofitted across every endpoint built so far | Roles & Permissions | 3.0 | 1–6 |

## Design decisions, found while writing the spec

Full detail in [roles-permissions/specification.md §1](../modules/roles-permissions/specification.md#1-purpose-and-business-context).
Three real gaps found and closed in the same pass, not deferred to a later sprint:

1. **Onboarding never assigned a role.** `POST /api/v1/onboarding` created `tenants`/`stores`/`users`
   rows but no `user_store_roles` row, since that table didn't exist before this sprint. Fixed:
   onboarding's own transaction now also creates one `owner` assignment for the onboarding user,
   reusing their own `user_id` as this row's id (a natural 1:1).
2. **`GET /audit-log` was never built.** Backlog item 7's own text lists "audit-log reads" as a
   retrofit target, but [audit-log/specification.md §1](../modules/audit-log/specification.md#1-purpose-and-business-context)
   had explicitly deferred that endpoint *because* Roles & Permissions didn't exist. Built this
   sprint, in the Audit Log module (its own spec updated alongside this one).
3. **`POST /users/invite`'s original mechanism was underspecified.** [identity.md](../11-api/endpoints/identity.md)
   described a "pending record, linked when the invitee completes signup" without ever specifying
   how. Supabase Admin's `inviteUserByEmail` resolves this concretely: it creates the (unconfirmed)
   Auth identity **synchronously**, returning its real `auth_user_id` immediately — the `users` row
   is created against that id in the same call, no separate linking step needed at all.

**Also found:** `POST /stock-movements`'s own client contract already excludes `movement_type:
'opening'` (Sprint 22); every product already receiving one `opening` movement automatically at
creation meant that no endpoint here needed to special-case an "Owner just onboarded, give them
stock too" scenario — the two sprints' own design decisions turned out to compose cleanly, not by
coordination, just by both following the same "don't build a write path with no live caller" rule.

## Capacity check

3.0 person-days against the ~3.75 person-day sprint budget — the largest single M1 item, closed in
the same single-day cadence as every smaller one before it.

## Reserved capacity

- [x] Defect capacity reserved: 0.5 person-day.
- [x] Documentation capacity reserved: `roles-permissions/specification.md` (new, all 11 sections),
      `audit-log/specification.md`, `identity.md`, `authorisation-model.md`, `error-catalogue.md`,
      seven other module specs corrected (products, categories, units, inventory, pos, sync-engine,
      company-store-setup), module registry, backlog.md, implementation-log, README bumps.

## Risks

- **This is the largest single M1 item (3.0 person-days) and touches the most existing files** of
  any sprint so far — mitigated by the fact that permission checks live entirely in Route Handlers
  (one line changed per file: `requireSession` → `requirePermission`), never inside the
  already-tested `service.ts` files, so no existing unit test needed to change.
- **A real external constraint, found live**: Supabase's own email-send rate limit on the founder's
  shared project blocked a second real `POST /users/invite` call mid-verification. Not a code
  defect — named and worked around by seeding the remaining test fixtures via a direct database
  insert instead, since the endpoints under test from that point on (`PATCH`/`DELETE`/`GET`) don't
  touch Supabase's mailer at all.
- **A real routing bug, found live**: `POST /users/invite` initially lived in `users/route.ts`,
  which Next.js's own dynamic-segment matching resolved `/users/invite` to `users/[id]/route.ts`
  (`id: "invite"`) instead of the intended static path — a `405`, not a `404`, since that file
  exists but only exports `DELETE`. Fixed with a static `users/invite/route.ts` sibling.
- **A real CI-only bug, found on this PR's own build check**: `core/auth/admin-client.ts`
  constructs its Supabase client at module-load time; every Route Handler now transitively imports
  it via `requirePermission`, so `next build`'s page-data collection step throws
  `supabaseKey is required` the moment `SUPABASE_SERVICE_ROLE_KEY` isn't set — which the `build`
  job's CI env never set, since no prior sprint's code ever needed it. Fixed by adding a
  placeholder value alongside the four that already exist there, the same pattern this exact job
  already used for `NEXT_PUBLIC_SUPABASE_ANON_KEY`.

## Definition of Done

- [x] `user_store_roles` table — new migration, RLS, `(user_id, store_id)` index.
- [x] `POST /api/v1/onboarding` — now also creates the initial `owner` role row, transactionally.
- [x] `GET /api/v1/users` (Manager, Owner), `POST /api/v1/users/invite` (Owner),
      `PATCH /api/v1/users/{id}/role` (Owner, `LAST_OWNER_CANNOT_BE_REMOVED`-guarded, versioned),
      `DELETE /api/v1/users/{id}` (Owner, `LAST_OWNER_CANNOT_BE_REMOVED`-guarded, Tier 1 soft
      delete) — all built and live-verified.
- [x] `GET /api/v1/audit-log` (Manager, Owner) — built, closing the Audit Log module's own named
      gap.
- [x] `core/auth/session.ts`'s `requirePermission` — resolves role fresh on every request (DR-017),
      retrofitted onto every existing Route Handler: products, categories, units, stock-movements
      (+ stock-balance), sales, sync push/pull, stores.
- [x] Every role-affecting write (invite, role change, deactivation) produces its own `audit_log`
      entry, per audit-model.md §1.
- [x] Unit tests: `roles/service.test.ts` (15 tests), `audit-log/service.test.ts` (4 tests).
- [x] `tsc --noEmit`/`eslint`/`vitest` (74 tests total across the web app) all clean.
- [x] Live verification against the real database, throwaway tenants deleted after — 12/12 checks
      for the full role-management chain, plus `POST /users/invite` itself confirmed separately
      (a real `201` with correct row creation) before a second real call hit Supabase's own
      email-send rate limit.
- [x] `roles-permissions/specification.md` (new), `audit-log/specification.md`, `identity.md`,
      `authorisation-model.md`, `error-catalogue.md`, and the seven other affected module specs all
      updated/corrected in this PR.
- [x] Module registry, backlog.md, implementation-log, READMEs updated in the same PR.

**Explicitly not in this sprint's DoD subset:** device revocation (`devices` table doesn't exist —
a continuing M0-wide gap), `PATCH /stores/{id}` (no code exists to retrofit permission onto), any
mobile UI for user/role management, a fourth system role.

## Demo script

**Server, run 2026-08-14** against the live database, via real HTTP requests to a local dev server
pointed at production Supabase, throwaway tenants deleted after:

1. Onboarding a fresh tenant → exactly one `user_store_roles` row, `role = 'owner'`. ✅
2. That Owner's `POST /products` (Manager/Owner-only) → succeeds. ✅
3. `POST /users/invite` (confirmed in an earlier pass this same session — real `201`, correct
   `role`/`id`, `users`/`user_store_roles`/two `audit_log` rows all created). ✅
4. A Cashier-role user's `POST /products` → `403 PERMISSION_DENIED`. ✅
5. The same Cashier's `GET /products` → succeeds (any-role endpoint). ✅
6. `PATCH /users/{id}/role` demoting the tenant's only Owner → `409
   LAST_OWNER_CANNOT_BE_REMOVED`; promoting the Cashier to Owner first, then demoting the original
   → succeeds. ✅
7. The original Owner's own already-issued, unrefreshed token → `403 PERMISSION_DENIED` on its very
   next request after being demoted — live proof of DR-017's "never cached, always resolved
   fresh." ✅
8. The new Owner's `GET /audit-log` → `200`, shows the `user_store_role.assigned` entries from
   step 6. ✅
9. `DELETE /users/{id}` deactivating the original user → their next `GET /products` call →
   `403 PERMISSION_DENIED` (deactivated, not merely role-insufficient). ✅
10. Cross-tenant RLS: tenant B's session reads zero of tenant A's `user_store_roles`/`audit_log`
    rows. ✅

**Unit tests, run 2026-08-14**: `vitest run` — 74/74 passing, including `EMAIL_ALREADY_REGISTERED`
(mocked `supabaseAdmin`, not re-tested live after the rate limit was hit).

## Retrospective

Recorded in [retrospective-log.md](retrospective-log.md) only if this sprint's execution surfaces a
concrete process change — not pre-judged here. Worth naming regardless: this is the fourth sprint
running (Sprints 20–23) where writing the module spec *before* code surfaced a real gap between an
already-written document's claims and what the system actually does — this time in three places at
once (onboarding's missing role, `GET /audit-log`'s premature "blocked" status, and `POST
/users/invite`'s underspecified mechanism), all inside a single module whose entire purpose is to
retrofit onto everything already built. Also the first sprint to hit a genuine *external* rate
limit during live verification (Supabase's own email quota) rather than a bug in this codebase —
handled by naming it and adjusting the verification approach, not by retrying blindly against the
founder's shared production project.

## Change Log

| Version | Date | Change |
| --- | --- | --- |
| 0.1.0 | 2026-08-14 | Sprint 23 planned and built same-day: `user_store_roles`, `GET/POST/PATCH/DELETE /users*`, `GET /audit-log`, and permission enforcement retrofitted across every existing endpoint. Three real gaps found and closed in the same pass (onboarding's missing role, `GET /audit-log` never built, invite mechanism underspecified). Live-verified 12/12 for the role-management chain; `POST /users/invite` confirmed separately before hitting Supabase's own email rate limit. A real routing bug (`/users/invite` resolving to `users/[id]`) found and fixed live. `vitest` 74/74. |
| 0.1.1 | 2026-08-14 | Fixed a real CI-only failure found on this PR's own `build` check: the new `core/auth/admin-client.ts` throws at module-load time without `SUPABASE_SERVICE_ROLE_KEY`, which the `build` job's CI env never set — added a placeholder, same pattern the job already used for the other four Supabase/DB env vars. |
