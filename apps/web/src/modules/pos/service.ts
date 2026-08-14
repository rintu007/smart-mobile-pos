import { randomUUID } from "node:crypto";
import * as identityService from "@/modules/identity/service";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { CreateSaleRequest } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

// Exported for reuse by sales-invoices/service.ts (GET /sales/{id}, GET /sales/lookup) — the
// sanctioned cross-module service-to-service path (docs/08-folder-structure/layering-rules.md §2),
// so both modules render an identical sale shape rather than maintaining two copies of this
// BigInt/date formatting.
export function formatSale(sale: {
  id: string;
  status: string;
  provisionalInvoiceNumber: string;
  canonicalInvoiceNumber: bigint | null;
  financialYear: string | null;
  subtotalMinorUnits: bigint;
  grandTotalMinorUnits: bigint;
  completedAt: Date | null;
  lineItems: {
    productId: string;
    quantity: number;
    unitPriceMinorUnits: bigint;
    lineTotalMinorUnits: bigint;
  }[];
  payments: { method: string; amountMinorUnits: bigint }[];
}) {
  return {
    id: sale.id,
    status: sale.status,
    provisional_invoice_number: sale.provisionalInvoiceNumber,
    // docs/modules/sales-invoices/specification.md §1 — never actually null for a stored sale in
    // this implementation, but the conversion still guards `null` since the column itself is
    // nullable (matching schema-server.md exactly).
    canonical_invoice_number:
      sale.canonicalInvoiceNumber === null ? null : Number(sale.canonicalInvoiceNumber),
    financial_year: sale.financialYear,
    subtotal_minor_units: Number(sale.subtotalMinorUnits),
    grand_total_minor_units: Number(sale.grandTotalMinorUnits),
    line_items: sale.lineItems.map((item) => ({
      product_id: item.productId,
      quantity: item.quantity,
      unit_price_minor_units: Number(item.unitPriceMinorUnits),
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

  const lineItems = input.line_items.map((item) => {
    const product = productsById.get(item.product_id)!;
    const lineTotalMinorUnits = product.priceMinorUnits * BigInt(item.quantity);
    return {
      id: randomUUID(),
      productId: item.product_id,
      quantity: item.quantity,
      unitPriceMinorUnits: product.priceMinorUnits,
      lineTotalMinorUnits,
    };
  });

  const grandTotalMinorUnits = lineItems.reduce(
    (sum, item) => sum + item.lineTotalMinorUnits,
    BigInt(0),
  );

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

  const createdBy = await identityService.resolveUserId(authUserId);

  const sale = await repository.createSale({
    id: input.id,
    tenantId,
    storeId: input.store_id,
    createdBy,
    provisionalInvoiceNumber: input.provisional_invoice_number,
    subtotalMinorUnits: grandTotalMinorUnits,
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
