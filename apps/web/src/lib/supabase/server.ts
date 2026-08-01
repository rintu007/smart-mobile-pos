import { createServerClient, type CookieOptions } from "@supabase/ssr";
import type { NextRequest, NextResponse } from "next/server";

type CookieToSet = { name: string; value: string; options: CookieOptions };

// Thin third-party wrapper only, per docs/08-folder-structure/backend-structure.md's `src/lib/`
// convention — no business logic lives here. Never imported by anything that would end up in a
// client bundle (that boundary is enforced by the import-boundary CI rule,
// docs/12-security/secrets-management.md §3).
//
// NOT currently used by the mobile API (app/api/v1/*) -- src/core/auth/session.ts verifies a
// bearer token directly instead, since a mobile client sends `Authorization: Bearer <token>`, not
// cookies, and this cookie-based @supabase/ssr client does not read that header at all (found by
// actually sending a real HTTP request, not by typecheck/build). This file remains for its
// documented future purpose: the web admin's own Server Actions (backend-structure.md §1), which
// genuinely are cookie/browser-session based. Not dead code -- just not wired up yet.

export function createRouteHandlerSupabaseClient(
  request: NextRequest,
  response: NextResponse,
) {
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet: CookieToSet[]) => {
          for (const { name, value, options } of cookiesToSet) {
            response.cookies.set(name, value, options);
          }
        },
      },
    },
  );
}
