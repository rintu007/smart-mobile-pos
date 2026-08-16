import { z } from "zod";

// docs/modules/settings/specification.md §2 — the three fixed enums, matching shop_settings'
// CHECK-free (application-code-enforced) columns, same precedent stock_movements/sales established.
export const TAX_MODES = ["standard", "composition", "unregistered"] as const;
export type TaxMode = (typeof TAX_MODES)[number];

export const PRICING_MODES = ["inclusive", "exclusive"] as const;
export type PricingMode = (typeof PRICING_MODES)[number];

export const ROUNDING_RULES = ["round_half_up", "round_half_even"] as const;
export type RoundingRule = (typeof ROUNDING_RULES)[number];

// docs/modules/settings/specification.md §5 — request body for PATCH /api/v1/settings.
// `.strict()` deliberately rejects `printer_config`/`receipt_template_config` (and any other
// unrecognized key) as a Zod validation failure — §1/§4's dated deferral, not silently ignored.
export const updateSettingsRequestSchema = z
  .object({
    client_operation_id: z.string().uuid(),
    base_updated_at: z.string().datetime(),
    tax_mode: z.enum(TAX_MODES).optional(),
    tax_rate_basis_points: z.number().int().min(0).max(10000).optional(),
    pricing_mode: z.enum(PRICING_MODES).optional(),
    rounding_rule: z.enum(ROUNDING_RULES).optional(),
    currency_code: z.string().trim().length(3).optional(),
    discount_auto_approval_threshold_minor_units: z.number().int().min(0).optional(),
    return_auto_approval_threshold_minor_units: z.number().int().min(0).optional(),
    // Added Sprint 37 (backlog.md M4 item 2) — docs/modules/reports/specification.md §1's own
    // found gap: BR-024/BR-045 need a configurable low-stock threshold and none existed anywhere.
    low_stock_threshold_quantity: z.number().int().min(0).optional(),
  })
  .strict();

export type UpdateSettingsRequest = z.infer<typeof updateSettingsRequestSchema>;
