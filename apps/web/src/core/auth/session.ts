import type { NextRequest } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { ApiError } from "@/core/errors/api-error";
import * as identityService from "@/modules/identity/service";
import * as storesService from "@/modules/stores/service";
import * as rolesService from "@/modules/roles/service";
import type { Role } from "@/modules/roles/schema";

// The mobile API contract (app/api/v1/*) is called with `Authorization: Bearer <token>`, never
// cookies -- a mobile client has no cookie jar in the browser-session sense. Cookie-based
// @supabase/ssr (src/lib/supabase/server.ts) is the right tool for the *web admin's* own Server
// Actions later (per docs/08-folder-structure/backend-structure.md), but it silently does not
// read an incoming Authorization header at all -- found only by actually sending a real HTTP
// request with a real bearer token and getting an unexpected 401, not by typecheck/build/service
// -level testing, none of which exercise the HTTP layer. A plain (non-SSR) client verifying the
// extracted token directly via `auth.getUser(token)` is the correct mechanism here.
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

function extractBearerToken(request: NextRequest): string {
  const header = request.headers.get("authorization");
  const token = header?.startsWith("Bearer ") ? header.slice("Bearer ".length) : undefined;

  if (!token) {
    throw new ApiError(401, "UNAUTHENTICATED", "No valid session token presented.");
  }

  return token;
}

/**
 * Reads the `tenant_id` claim the Custom Access Token Hook injects
 * (`supabase/sql/001_custom_access_token_hook.sql`: `jsonb_set(claims, '{tenant_id}', ...)`) —
 * a **top-level** JWT claim, sibling to `sub`/`email`/`app_metadata`, not nested inside
 * `app_metadata`. `current_tenant_id()`'s own SQL reads it the same way (`auth.jwt() ->> 'tenant_id'`).
 * `supabase-js`'s `getUser()` return type has no field for an arbitrary custom top-level claim, so
 * this decodes the (already-verified-by-getUser) token's payload directly rather than trusting
 * `user.app_metadata` — the bug this replaces. Found only by `POST /api/v1/products` actually
 * sending this session through `requireSession` for the first time ever (Sprint 04) — `requireSession`
 * had never been exercised by a real request before, only `requireAuthenticatedUser` (onboarding).
 */
function decodeTenantIdClaim(token: string): string | undefined {
  const payload = token.split(".")[1];
  if (!payload) return undefined;
  const json = Buffer.from(payload, "base64url").toString("utf8");
  const claims = JSON.parse(json) as { tenant_id?: string };
  return claims.tenant_id;
}

/**
 * Resolves the authenticated (but not yet tenant-scoped) identity for a Route Handler request.
 *
 * Implements only step 1 of docs/12-security/authorisation-model.md §2's evaluation order: verify
 * the JWT. Deliberately does **not** require a `tenant_id` claim — this is the one auth check used
 * by `POST /api/v1/onboarding` (docs/11-api/endpoints/identity.md#onboarding), whose entire purpose
 * is to be callable by an identity that does not have one yet. Every other Route Handler wants
 * `requireSession` below instead.
 *
 * **Proof status:** exercised by real requests since Sprint 02 (onboarding's own live demo) — the
 * proven half of this file (docs/17-sprints/retrospective-log.md's Sprint 04 entry: a file being
 * proven live doesn't mean every export in it is).
 */
export async function requireAuthenticatedUser(
  request: NextRequest,
): Promise<{ authUserId: string }> {
  const token = extractBearerToken(request);
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(token);

  if (error || !user) {
    throw new ApiError(401, "UNAUTHENTICATED", "No valid session token presented.");
  }

  return { authUserId: user.id };
}

/**
 * Resolves the authenticated, tenant-scoped session for a Route Handler request.
 *
 * Implements steps 1 and 3 of docs/12-security/authorisation-model.md §2's evaluation order:
 * (1) verify the JWT, (3) resolve `tenant_id` from its claim. Steps 2 (device revocation) and 4
 * (current role via `user_store_roles`) are not implemented yet — those tables don't exist until
 * a later sprint (docs/17-sprints/backlog.md, items 3+) adds them. This function is the one place
 * those steps are added to later, so no Route Handler needs to change when they land.
 *
 * **Proof status:** exercised by a real request for the first time in Sprint 04
 * (`POST /api/v1/products`) — unexercised through Sprint 01–03, which is exactly how its
 * wrong-claim-location bug (fixed this sprint) sat invisible that whole time.
 */
export interface AuthenticatedSession {
  authUserId: string;
  tenantId: string;
}

export async function requireSession(request: NextRequest): Promise<AuthenticatedSession> {
  const token = extractBearerToken(request);
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(token);

  if (error || !user) {
    throw new ApiError(401, "UNAUTHENTICATED", "No valid session token presented.");
  }

  const tenantId = decodeTenantIdClaim(token);

  if (!tenantId) {
    // The Custom Access Token Hook (supabase/sql/001_custom_access_token_hook.sql) failed to
    // resolve a tenant_id for this auth user — a users row doesn't exist for them yet, or the
    // hook isn't wired up in this Supabase project's Dashboard. Distinct from a missing session
    // entirely, per docs/12-security/threat-model.md's TB-4 row (claim tampering is a spoofing
    // risk; a genuinely absent claim is a provisioning gap, not an attack).
    throw new ApiError(401, "UNAUTHENTICATED", "Session has no tenant_id claim.");
  }

  return { authUserId: user.id, tenantId };
}

/**
 * Resolves the authenticated, tenant-scoped, **role-checked** session for a Route Handler request
 * — the "one place those steps are added to later" `requireSession`'s own docstring already
 * promised. Implements steps 1, 3, 4, and 5 of
 * docs/12-security/authorisation-model.md §2's evaluation order: (1)/(3) via `requireSession`
 * above, (4) resolve the current role from `user_store_roles` (docs/modules/roles-permissions/specification.md),
 * (5) check it against `allowedRoles` — the static per-endpoint permission table, expressed here as
 * this function's own call-site argument rather than a separate lookup table, since every Route
 * Handler already names its own required roles inline. Step 2 (device revocation) remains
 * unimplemented — no `devices` table exists in code yet, a continuing, named gap (module registry).
 *
 * Fail-closed throughout (DR-017): no active role resolved, or the resolved role isn't in
 * `allowedRoles`, both throw `403 PERMISSION_DENIED` — never a silent allow.
 *
 * **Accepted redundancy:** this re-resolves `userId`/`storeId` via `identityService`/`storesService`,
 * which the called service function almost always resolves again for its own purposes — a second
 * round trip per request, not eliminated by threading the values through, to avoid changing every
 * existing service function's signature for a low-traffic, single-founder-scale product
 * (docs/modules/roles-permissions/specification.md §2).
 */
export interface AuthorizedSession extends AuthenticatedSession {
  userId: string;
  storeId: string;
  role: Role;
}

export async function requirePermission(
  request: NextRequest,
  allowedRoles: readonly Role[],
): Promise<AuthorizedSession> {
  const session = await requireSession(request);
  const userId = await identityService.resolveUserId(session.authUserId);
  const storeId = await storesService.getPrimaryStoreId(session.tenantId);
  const role = await rolesService.resolveActiveRole(session.tenantId, userId, storeId);

  if (!role) {
    throw new ApiError(403, "PERMISSION_DENIED", "No active role assigned at this store.");
  }
  if (!allowedRoles.includes(role)) {
    throw new ApiError(403, "PERMISSION_DENIED", `Role '${role}' cannot perform this action.`);
  }

  return { ...session, userId, storeId, role };
}
