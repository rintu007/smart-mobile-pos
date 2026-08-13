import { z } from "zod";

// docs/modules/categories/specification.md §5 — request body for POST /api/v1/categories.
export const createCategoryRequestSchema = z.object({
  id: z.string().uuid(),
  name: z.string().trim().min(1).max(200),
});

export type CreateCategoryRequest = z.infer<typeof createCategoryRequestSchema>;

// docs/modules/categories/specification.md §4 — query params for GET /api/v1/categories.
export const listCategoriesQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().positive().max(200).default(50),
});

export type ListCategoriesQuery = z.infer<typeof listCategoriesQuerySchema>;
