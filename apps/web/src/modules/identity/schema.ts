import { z } from "zod";

// docs/11-api/endpoints/identity.md#onboarding — request body for POST /api/v1/onboarding.
// tenant_id/store_id/user_id are client-generated UUIDv4s (docs/adr/ADR-0007), the entity-creation
// idempotency mechanism (docs/11-api/api-principles.md §3).
export const onboardingRequestSchema = z.object({
  tenant_id: z.string().uuid(),
  store_id: z.string().uuid(),
  user_id: z.string().uuid(),
  tenant_name: z.string().trim().min(1).max(200),
  store_name: z.string().trim().min(1).max(200),
  store_address: z.string().trim().min(1).max(500).optional(),
  display_name: z.string().trim().min(1).max(200),
});

export type OnboardingRequest = z.infer<typeof onboardingRequestSchema>;
