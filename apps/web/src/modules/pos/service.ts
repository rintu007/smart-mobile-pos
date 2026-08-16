import { randomUUID } from "node:crypto";
import * as identityService from "@/modules/identity/service";
import * as rolesService from "@/modules/roles/service";
import * as settingsService from "@/modules/settings/service";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { CreateSaleRequest } from "./schema";

// docs/modules/trading-day/specification.md §1 — full-V1-shape rejection of an unresolvable
// trading_day_id: distinct from "no store found" (NOT_FOUND) because the day may genuinely exist
// under this tenant, just not open (or not at this store) right now.
async function assertTradingDayOpenIfProvided(
  tenantId: string,
  storeId: string,
  tradingDayId: string | undefined,
) {
  if (tradingDayId === undefined) return;
  const tradingDay = await repository.findOpenTradingDayById(tenantId, storeId, tradingDayId);
  if (!tradingDay) {
    throw new ApiError(
      409,
      "TRADING_DAY_NOT_OPEN",
      "trading_day_id does not refer to an open trading day at this store.",
    );
  }
}

// docs/07-database/money-and-tax.md §1/§2 — ROUND(numerator/denominator, rounding_rule), computed
// over BigInt to stay exact (ADR-0006: money is never floating-point). Both inputs are always
// non-negative in every caller this sprint (a discount can't be negative).
function roundFraction(numerator: bigint, denominator: bigint, roundingRule: string): bigint {
  const quotient = numerator / denominator;
  const remainder = numerator % denominator;
  const twiceRemainder = remainder * BigInt(2);

  if (twiceRemainder < denominator) return quotient;
  if (twiceRemainder > denominator) return quotient + BigInt(1);
  // Exactly half: round_half_up rounds away from zero (always up here, values are non-negative);
  // round_half_even rounds to the nearest even quotient.
  if (roundingRule === "round_half_even") {
    return quotient % BigInt(2) === BigInt(0) ? quotient : quotient + BigInt(1);
  }
  return quotient + BigInt(1);
}

// docs/modules/pos/specification.md §2 (Sprint 27) — DR-011: a line's discount is either a percent
// or a fixed amount, never both (already rejected at the schema layer, re-asserted here since this
// function has no other way to signal "neither supplied" than falling through to zero). A flat
// discount may not exceed the line's own pre-discount subtotal.
function computeLineDiscount(
  lineSubtotalMinorUnits: bigint,
  discountPercentBasisPoints: number | undefined,
  discountAmountMinorUnits: number | undefined,
  roundingRule: string,
): bigint {
  if (discountPercentBasisPoints !== undefined) {
    return roundFraction(
      lineSubtotalMinorUnits * BigInt(discountPercentBasisPoints),
      BigInt(10000),
      roundingRule,
    );
  }
  if (discountAmountMinorUnits !== undefined) {
    const amount = BigInt(discountAmountMinorUnits);
    if (amount > lineSubtotalMinorUnits) {
      throw new ApiError(
        422,
        "VALIDATION_FAILED",
        "discount_amount_minor_units cannot exceed the line's own subtotal.",
      );
    }
    return amount;
  }
  return BigInt(0);
}

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

// Exported for reuse by sales-invoices/service.ts (GET /sales/{id}, GET /sales/lookup) — the
// sanctioned cross-module service-to-service path (docs/08-folder-structure/layering-rules.md §2),
// so both modules render an identical sale shape rather than maintaining two copies of this
// BigInt/date formatting.
export function formatSale(sale: {
  id: string;
  status: string;
  tradingDayId: string | null;
  provisionalInvoiceNumber: string;
  canonicalInvoiceNumber: bigint | null;
  financialYear: string | null;
  subtotalMinorUnits: bigint;
  discountTotalMinorUnits: bigint;
  grandTotalMinorUnits: bigint;
  completedAt: Date | null;
  lineItems: {
    productId: string;
    quantity: number;
    unitPriceMinorUnits: bigint;
    lineDiscountMinorUnits: bigint;
    lineTotalMinorUnits: bigint;
  }[];
  payments: { method: string; amountMinorUnits: bigint }[];
}) {
  return {
    id: sale.id,
    status: sale.status,
    trading_day_id: sale.tradingDayId,
    provisional_invoice_number: sale.provisionalInvoiceNumber,
    // docs/modules/sales-invoices/specification.md §1 — never actually null for a stored sale in
    // this implementation, but the conversion still guards `null` since the column itself is
    // nullable (matching schema-server.md exactly).
    canonical_invoice_number:
      sale.canonicalInvoiceNumber === null ? null : Number(sale.canonicalInvoiceNumber),
    financial_year: sale.financialYear,
    // Sprint 27 correction: post-discount, pre-tax — docs/modules/pos/specification.md §1/§2.
    subtotal_minor_units: Number(sale.subtotalMinorUnits),
    discount_total_minor_units: Number(sale.discountTotalMinorUnits),
    grand_total_minor_units: Number(sale.grandTotalMinorUnits),
    line_items: sale.lineItems.map((item) => ({
      product_id: item.productId,
      quantity: item.quantity,
      unit_price_minor_units: Number(item.unitPriceMinorUnits),
      discount_minor_units: Number(item.lineDiscountMinorUnits),
      line_total_minor_units: Number(item.lineTotalMinorUnits),
    })),
    payments: sale.payments.map((payment) => ({
      method: payment.method,
      amount_minor_units: Number(payment.amountMinorUnits),
    })),
    completed_at: sale.completedAt?.toISOString() ?? null,
  };
}

/**
 * docs/modules/pos/specification.md#4-api-contract.
 *
 * Idempotent replay (§2 of the spec) is checked *before* any recompute — a price that legitimately
 * moved after a first successful call must never turn a replay of the same `id` into a spurious
 * `PRICE_MISMATCH`. Every price/total figure is server-computed from current `products` rows, never
 * trusted from the request — docs/11-api/api-principles.md §7.
 */
export async function createSale(
  authUserId: string,
  tenantId: string,
  input: CreateSaleRequest,
) {
  const existing = await repository.findSaleById(input.id);
  if (existing) {
    return formatSale(existing);
  }

  await assertTradingDayOpenIfProvided(tenantId, input.store_id, input.trading_day_id);

  const productIds = input.line_items.map((item) => item.product_id);
  const products = await repository.findProductsByIds(tenantId, productIds);
  const productsById = new Map(products.map((product) => [product.id, product]));

  for (const item of input.line_items) {
    const product = productsById.get(item.product_id);
    if (!product) {
      throw new ApiError(404, "NOT_FOUND", `Product ${item.product_id} not found.`);
    }
    if (BigInt(item.client_unit_price_minor_units) !== product.priceMinorUnits) {
      throw new ApiError(
        409,
        "PRICE_MISMATCH",
        `Product ${item.product_id}'s cached price is stale.`,
        {
          product_id: item.product_id,
          current_price_minor_units: Number(product.priceMinorUnits),
        },
      );
    }
  }

  const { roundingRule, discountAutoApprovalThresholdMinorUnits } =
    await settingsService.getMoneySettings(tenantId);

  const lineItems = input.line_items.map((item) => {
    const product = productsById.get(item.product_id)!;
    const lineSubtotalMinorUnits = product.priceMinorUnits * BigInt(item.quantity);
    const lineDiscountMinorUnits = computeLineDiscount(
      lineSubtotalMinorUnits,
      item.discount_percent_basis_points,
      item.discount_amount_minor_units,
      roundingRule,
    );
    return {
      id: randomUUID(),
      productId: item.product_id,
      quantity: item.quantity,
      unitPriceMinorUnits: product.priceMinorUnits,
      lineDiscountMinorUnits,
      // No tax yet (M2 item 4) — a line's total is its post-discount, pre-tax value.
      lineTotalMinorUnits: lineSubtotalMinorUnits - lineDiscountMinorUnits,
    };
  });

  const discountTotalMinorUnits = lineItems.reduce(
    (sum, item) => sum + item.lineDiscountMinorUnits,
    BigInt(0),
  );
  // Sprint 27 correction: subtotal is post-discount, pre-tax (money-and-tax.md's fixed formula) —
  // grand_total equals it exactly until Tax computation (M2 item 4) adds a tax_total on top.
  const subtotalMinorUnits = lineItems.reduce(
    (sum, item) => sum + item.lineTotalMinorUnits,
    BigInt(0),
  );
  const grandTotalMinorUnits = subtotalMinorUnits;

  const createdBy = await identityService.resolveUserId(authUserId);

  // DR-012: a discount over the shop's auto-approval threshold needs authority beyond an ordinary
  // Cashier — the caller's own role if it's already Manager/Owner (DR-020), or a named
  // discount_approved_by resolving the same way, checked fresh at request time (DR-017), matching
  // Finding 1's own offline-approval integrity model, not a stronger live-proof claim.
  if (discountTotalMinorUnits > discountAutoApprovalThresholdMinorUnits) {
    const callerRole = await rolesService.resolveActiveRole(tenantId, createdBy, input.store_id);
    const approverRole = input.discount_approved_by
      ? await rolesService.resolveActiveRole(tenantId, input.discount_approved_by, input.store_id)
      : null;
    const authorisedRole =
      callerRole === "manager" || callerRole === "owner"
        ? callerRole
        : approverRole === "manager" || approverRole === "owner"
          ? approverRole
          : null;
    if (!authorisedRole) {
      throw new ApiError(
        409,
        "DISCOUNT_REQUIRES_APPROVAL",
        "This discount exceeds the shop's auto-approval threshold and has no valid Manager/Owner approval.",
        { discount_total_minor_units: Number(discountTotalMinorUnits) },
      );
    }
  }

  // Zod's `.length(1)` guarantees exactly one element at runtime but doesn't narrow the array's
  // static type to a tuple, hence the explicit check TypeScript needs here.
  const [payment] = input.payments;
  if (!payment) {
    throw new ApiError(422, "VALIDATION_FAILED", "Exactly one payment is required.");
  }
  if (BigInt(payment.amount_minor_units) !== grandTotalMinorUnits) {
    throw new ApiError(
      409,
      "PAYMENT_AMOUNT_MISMATCH",
      "Payment amount does not equal the computed grand total.",
      { grand_total_minor_units: Number(grandTotalMinorUnits) },
    );
  }

  const sale = await repository.createSale({
    id: input.id,
    tenantId,
    storeId: input.store_id,
    createdBy,
    tradingDayId: input.trading_day_id,
    provisionalInvoiceNumber: input.provisional_invoice_number,
    subtotalMinorUnits,
    discountTotalMinorUnits,
    grandTotalMinorUnits,
    lineItems,
    payment: {
      id: randomUUID(),
      method: payment.method,
      amountMinorUnits: BigInt(payment.amount_minor_units),
    },
  });

  return formatSale(sale);
}
