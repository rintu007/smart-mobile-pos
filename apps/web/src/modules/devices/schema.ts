import { z } from "zod";

// docs/11-api/endpoints/identity.md#devices — request body for POST /api/v1/auth/register-device.
// `client_device_id` is client-generated, fresh per install, never derived from a stable hardware
// identifier (docs/07-database/identifiers.md §4) — a plain string, not constrained to a UUID
// shape, since this project never actually specifies the exact generation mechanism as a UUID.
export const registerDeviceRequestSchema = z.object({
  client_device_id: z.string().trim().min(1).max(200),
});

export type RegisterDeviceRequest = z.infer<typeof registerDeviceRequestSchema>;
