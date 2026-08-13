import { createClient } from "@supabase/supabase-js";

// Service-role client — server-only, never exposed to any client bundle. Used exactly where an
// operation needs to act on Supabase Auth identities directly rather than through a user's own
// session (docs/modules/roles-permissions/specification.md §1: POST /users/invite creates the
// invitee's Auth identity via admin.inviteUserByEmail before any users row for them exists).
export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);
