import type { NextRequest, NextResponse } from "next/server";
import { createRouteHandlerSupabaseClient } from "@/lib/supabase/server";
import { ApiError } from "@/core/errors/api-error";

/**
 * Resolves the authenticated session for a Route Handler request.
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

export async function requireSession(
  request: NextRequest,
  response: NextResponse,
): Promise<AuthenticatedSession> {
  const supabase = createRouteHandlerSupabaseClient(request, response);
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

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
