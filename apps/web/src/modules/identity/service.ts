import { Prisma } from "@prisma/client";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { OnboardingRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

const UNIQUE_CONSTRAINT_VIOLATION = "P2002";

/**
 * Resolves the internal `users.id` (the `created_by` FK value every module's tables need) from the
 * verified session's `authUserId` (Supabase's own `auth.users.id`) — these are deliberately
 * different ids (docs/07-database/schema-server.md's `users.auth_user_id` column). Every module
 * needing `created_by` calls this rather than querying `users` directly, per
 * docs/08-folder-structure/layering-rules.md §2's sanctioned service-to-service cross-module path
 * (never repository-to-repository).
 */
export async function resolveUserId(authUserId: string): Promise<string> {
  const user = await repository.findUserByAuthId(authUserId);
  if (!user) {
    // Should be unreachable for a session that already passed requireSession (its tenant_id claim
    // only exists once a users row does) — a defensive 401, not a silent null, if it ever isn't.
    throw new ApiError(401, "UNAUTHENTICATED", "No user record for this session.");
  }
  return user.id;
}

/**
 * docs/11-api/endpoints/identity.md#onboarding.
 *
 * Retry behaviour, restated from the contract: the *same* tenant_id/store_id/user_id as a prior
 * (possibly successful) attempt is an idempotent replay — repository.createOnboarding's upserts
 * handle that. A *different* set of generated IDs from an identity that already has a `users` row
 * is a distinct logical operation, rejected with ALREADY_ONBOARDED, not silently merged.
 */
export async function onboard(authUserId: string, input: OnboardingRequest) {
  const existingUser = await repository.findUserByAuthId(authUserId);

  if (existingUser && existingUser.id !== input.user_id) {
    throw new ApiError(
      409,
      "ALREADY_ONBOARDED",
      "This identity has already completed onboarding under a different user id.",
    );
  }

  try {
    return await repository.createOnboarding({ ...input, authUserId });
  } catch (error) {
    // Concurrent double-submission: two requests with different generated IDs racing past the
    // findUserByAuthId check above before either commits. users.auth_user_id's own UNIQUE
    // constraint is the backstop — translated to the same ALREADY_ONBOARDED a sequential retry
    // would see, not a generic 500.
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === UNIQUE_CONSTRAINT_VIOLATION &&
      (error.meta?.target as string[] | undefined)?.includes("auth_user_id")
    ) {
      throw new ApiError(
        409,
        "ALREADY_ONBOARDED",
        "This identity has already completed onboarding (concurrent request).",
      );
    }
    throw error;
  }
}
