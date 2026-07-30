import { createServerClient, type CookieOptions } from "@supabase/ssr";
import type { NextRequest, NextResponse } from "next/server";

type CookieToSet = { name: string; value: string; options: CookieOptions };

// Thin third-party wrapper only, per docs/08-folder-structure/backend-structure.md's `src/lib/`
// convention — no business logic lives here. Used exclusively by Route Handlers to verify the
// caller's session; never imported by anything that would end up in a client bundle (that
// boundary is enforced by the import-boundary CI rule, docs/12-security/secrets-management.md §3).

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
