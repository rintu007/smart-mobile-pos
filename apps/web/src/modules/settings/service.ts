import * as repository from "./repository";
import * as identityService from "@/modules/identity/service";
import { ApiError } from "@/core/errors/api-error";
import type { UpdateSettingsRequest } from "./schema";
import type { Role } from "@/modules/roles/schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

/**
 * docs/modules/pos/specification.md §2 (Sprint 27/28) — the raw money-arithmetic fields other
 * modules' server-side computations need (Discount, Tax computation), not the role-shaped HTTP
 * response `getSettings` builds. Sanctioned cross-module service-to-service path
 * (docs/08-folder-structure/layering-rules.md §2), reused as-is by future callers rather than each
 * one re-deriving its own subset of `shop_settings`.
 */
export async function getMoneySettings(tenantId: string) {
  const settings = await repository.findSettings(tenantId);

  if (!settings) {
    throw new ApiError(404, "NOT_FOUND", "No settings exist for this tenant.");
  }

  return {
    roundingRule: settings.roundingRule,
    discountAutoApprovalThresholdMinorUnits: settings.discountAutoApprovalThresholdMinorUnits,
    // Added Sprint 33 (backlog.md M3 item 3) — Returns' own auto-approval check (DR-015) reuses this
    // same cross-module money-settings bundle, the same way Discount's own threshold already does.
    returnAutoApprovalThresholdMinorUnits: settings.returnAutoApprovalThresholdMinorUnits,
    taxMode: settings.taxMode,
    taxRateBasisPoints: settings.taxRateBasisPoints,
    pricingMode: settings.pricingMode,
  };
}

/**
 * docs/modules/settings/specification.md §4 — GET /api/v1/settings.
 *
 * Role-shaped, per settings.md's "Field-level read scope": both auto-approval thresholds are
 * present for Manager/Owner, omitted entirely (not merely zeroed) for a Cashier — a Cashier should
 * not be able to infer the exact figure that would trigger a Manager-approval requirement.
 */
export async function getSettings(tenantId: string, role: Role) {
  const settings = await repository.findSettings(tenantId);

  if (!settings) {
    // Should not occur for any tenant onboarded after Sprint 25 (identity/repository.ts's
    // onboarding transaction now always writes this row) — named for tenants onboarded before it,
    // docs/modules/settings/specification.md §6.
    throw new ApiError(404, "NOT_FOUND", "No settings exist for this tenant.");
  }

  const base = {
    tax_mode: settings.taxMode,
    tax_rate_basis_points: settings.taxRateBasisPoints,
    pricing_mode: settings.pricingMode,
    rounding_rule: settings.roundingRule,
    currency_code: settings.currencyCode,
    // Added Sprint 37 (backlog.md M4 item 2) — visible to everyone, same as tax_mode/pricing_mode
    // above: unlike the two auto-approval thresholds below, there's no "a Cashier could game this"
    // concern for a low-stock number.
    low_stock_threshold_quantity: settings.lowStockThresholdQuantity,
    printer_config: settings.printerConfig,
    receipt_template_config: settings.receiptTemplateConfig,
    updated_at: settings.updatedAt.toISOString(),
  };

  if (role === "cashier") {
    return base;
  }

  return {
    ...base,
    discount_auto_approval_threshold_minor_units: Number(
      settings.discountAutoApprovalThresholdMinorUnits,
    ),
    return_auto_approval_threshold_minor_units: Number(
      settings.returnAutoApprovalThresholdMinorUnits,
    ),
  };
}

/**
 * docs/modules/settings/specification.md §4 — PATCH /api/v1/settings. Owner-only (enforced by the
 * Route Handler's own `requirePermission` call, not here).
 */
export async function updateSettings(
  authUserId: string,
  tenantId: string,
  input: UpdateSettingsRequest,
) {
  const current = await repository.findSettings(tenantId);
  if (!current) {
    throw new ApiError(404, "NOT_FOUND", "No settings exist for this tenant.");
  }

  if (current.updatedAt.toISOString() !== input.base_updated_at) {
    throw new ApiError(
      409,
      "SETTINGS_CONFLICT",
      "Settings have changed since base_updated_at was read.",
    );
  }

  // DR-009: composition/unregistered shops carry no tax rate. Checked against the *resulting*
  // state (this request's fields, falling back to the current row), not just the fields present in
  // this particular request — docs/modules/settings/specification.md §5.
  const resultingTaxMode = input.tax_mode ?? current.taxMode;
  const resultingTaxRate = input.tax_rate_basis_points ?? current.taxRateBasisPoints;
  if (resultingTaxMode !== "standard" && resultingTaxRate !== 0) {
    throw new ApiError(
      422,
      "TAX_RATE_REQUIRES_STANDARD_MODE",
      "tax_rate_basis_points must be 0 unless tax_mode is 'standard'.",
    );
  }

  const data = {
    ...(input.tax_mode !== undefined && { taxMode: input.tax_mode }),
    ...(input.tax_rate_basis_points !== undefined && {
      taxRateBasisPoints: input.tax_rate_basis_points,
    }),
    ...(input.pricing_mode !== undefined && { pricingMode: input.pricing_mode }),
    ...(input.rounding_rule !== undefined && { roundingRule: input.rounding_rule }),
    ...(input.currency_code !== undefined && { currencyCode: input.currency_code }),
    ...(input.discount_auto_approval_threshold_minor_units !== undefined && {
      discountAutoApprovalThresholdMinorUnits: BigInt(
        input.discount_auto_approval_threshold_minor_units,
      ),
    }),
    ...(input.return_auto_approval_threshold_minor_units !== undefined && {
      returnAutoApprovalThresholdMinorUnits: BigInt(
        input.return_auto_approval_threshold_minor_units,
      ),
    }),
    ...(input.low_stock_threshold_quantity !== undefined && {
      lowStockThresholdQuantity: input.low_stock_threshold_quantity,
    }),
    // Added Sprint 39 (backlog.md M4 item 4) — Prisma's Json column accepts the plain object
    // directly, already validated/shaped by receiptTemplateConfigSchema (schema.ts).
    ...(input.receipt_template_config !== undefined && {
      receiptTemplateConfig: input.receipt_template_config,
    }),
  };

  const actorUserId = await identityService.resolveUserId(authUserId);
  // Every field this request actually intends to change, already JSON-safe (the raw Zod-parsed
  // input, not `data` above, which carries BigInt values `afterState`'s Json column can't hold) —
  // `base_updated_at`/`client_operation_id` aren't field changes themselves, so both are excluded.
  const changedFields: Record<string, unknown> = { ...input };
  delete changedFields.base_updated_at;
  delete changedFields.client_operation_id;
  for (const key of Object.keys(changedFields)) {
    if (changedFields[key] === undefined) delete changedFields[key];
  }

  const applied = await repository.updateSettingsIfUnchanged(
    tenantId,
    current.updatedAt,
    data,
    actorUserId,
    changedFields,
  );
  if (!applied) {
    // A concurrent PATCH landed between the read above and this write — the same outcome as the
    // base_updated_at check above, just caught at the database level instead of in JS.
    throw new ApiError(
      409,
      "SETTINGS_CONFLICT",
      "Settings have changed since base_updated_at was read.",
    );
  }

  // Owner always sees both threshold fields — getSettings' Cashier-only omission doesn't apply to
  // the caller of a call only an Owner can make.
  return getSettings(tenantId, "owner");
}
