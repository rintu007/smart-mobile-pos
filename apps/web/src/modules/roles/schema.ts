import { z } from "zod";

// docs/modules/roles-permissions/specification.md §1 — the three fixed system roles
// (permission-matrix.md), no fourth invented.
export const ROLES = ["cashier", "manager", "owner"] as const;
export type Role = (typeof ROLES)[number];

// docs/modules/roles-permissions/specification.md §5 — request body for POST /api/v1/users/invite.
export const inviteUserRequestSchema = z.object({
  id: z.string().uuid(),
  email: z.string().trim().email(),
  display_name: z.string().trim().min(1).max(200),
  role: z.enum(ROLES),
});

export type InviteUserRequest = z.infer<typeof inviteUserRequestSchema>;

// docs/modules/roles-permissions/specification.md §5 — request body for
// PATCH /api/v1/users/{id}/role.
export const changeRoleRequestSchema = z.object({
  id: z.string().uuid(),
  role: z.enum(ROLES),
});

export type ChangeRoleRequest = z.infer<typeof changeRoleRequestSchema>;

// docs/modules/roles-permissions/specification.md §5 — query params for GET /api/v1/users.
export const listUsersQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
});

export type ListUsersQuery = z.infer<typeof listUsersQuerySchema>;
