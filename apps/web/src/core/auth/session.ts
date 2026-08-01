import type { NextRequest } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { ApiError } from "@/core/errors/api-error";

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
 * Resolves the authenticated (but not yet tenant-scoped) identity for a Route Handler request.
 *
 * Implements only step 1 of docs/12-security/authorisation-model.md §2's evaluation order: verify
 * the JWT. Deliberately does **not** require a `tenant_id` claim — this is the one auth check used
 * by `POST /api/v1/onboarding` (docs/11-api/endpoints/identity.md#onboarding), whose entire purpose
 * is to be callable by an identity that does not have one yet. Every other Route Handler wants
 * `requireSession` below instead.
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

  const tenantId = (user.app_metadata as { tenant_id?: string } | null)?.tenant_id;

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
