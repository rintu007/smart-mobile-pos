import { formatSale } from "@/modules/pos/service";
import type { Role } from "@/modules/roles/schema";
import { ApiError } from "@/core/errors/api-error";
import * as repository from "./repository";
import type { SaleCursor } from "./repository";
import type { LookupSaleQuery } from "./schema";

// Business rules live here, not in the Route Handler — docs/08-folder-structure/backend-structure.md §2.

function formatSaleSummary(sale: {
  id: string;
  status: string;
  provisionalInvoiceNumber: string;
  canonicalInvoiceNumber: bigint | null;
  financialYear: string | null;
  subtotalMinorUnits: bigint;
  grandTotalMinorUnits: bigint;
  completedAt: Date | null;
}) {
  return {
    id: sale.id,
    status: sale.status,
    provisional_invoice_number: sale.provisionalInvoiceNumber,
    canonical_invoice_number:
      sale.canonicalInvoiceNumber === null ? null : Number(sale.canonicalInvoiceNumber),
    financial_year: sale.financialYear,
    subtotal_minor_units: Number(sale.subtotalMinorUnits),
    grand_total_minor_units: Number(sale.grandTotalMinorUnits),
    completed_at: sale.completedAt?.toISOString() ?? null,
  };
}

/**
 * docs/modules/sales-invoices/specification.md#4-api-contract — GET /api/v1/sales/{id}.
 */
export async function getSaleDetail(tenantId: string, id: string) {
  const sale = await repository.findSaleWithDetails(tenantId, id);
  if (!sale) {
    throw new ApiError(404, "NOT_FOUND", `Sale ${id} not found.`);
  }
  return formatSale(sale);
}

/**
 * docs/modules/sales-invoices/specification.md#4-api-contract — GET /api/v1/sales/lookup.
 */
export async function lookupSale(tenantId: string, query: LookupSaleQuery) {
  const sale = await repository.findSaleByInvoiceNumber(tenantId, {
    provisionalInvoiceNumber: query.provisional_invoice_number,
    canonicalInvoiceNumber:
      query.canonical_invoice_number !== undefined
        ? BigInt(query.canonical_invoice_number)
        : undefined,
  });
  if (!sale) {
    throw new ApiError(404, "NOT_FOUND", "No sale matches the given invoice number.");
  }
  return formatSale(sale);
}

/**
 * docs/modules/sales-invoices/specification.md#2-business-rules — GET /api/v1/sales. Role-scoped,
 * not just permission-gated: a Cashier sees only sales they themselves created; Manager/Owner see
 * every sale, store-wide (sales.md's own "own device's trading day only" is unimplementable
 * without a `devices`/`trading_days` table — this is the closest faithful adaptation available).
 */
export async function listSales(
  tenantId: string,
  role: Role,
  userId: string,
  query: { cursor?: string; limit: number; date_from?: string; date_to?: string },
) {
  const decodedCursor = query.cursor ? decodeCursor(query.cursor) : null;
  const fetched = await repository.listSales(
    tenantId,
    {
      createdBy: role === "cashier" ? userId : undefined,
      dateFrom: query.date_from ? new Date(query.date_from) : undefined,
      dateTo: query.date_to ? new Date(query.date_to) : undefined,
    },
    decodedCursor,
    query.limit,
  );
  // Peek-and-trim, same reasoning every other list endpoint in this codebase already established.
  const hasMore = fetched.length > query.limit;
  const rows = hasMore ? fetched.slice(0, query.limit) : fetched;
  const lastRow = rows[rows.length - 1];
  const nextCursor = hasMore && lastRow ? encodeCursor(lastRow) : null;

  return {
    data: rows.map((sale) => formatSaleSummary(sale)),
    next_cursor: nextCursor,
  };
}

function encodeCursor(row: SaleCursor): string {
  return Buffer.from(`${row.completedAt.toISOString()}|${row.id}`).toString("base64url");
}

function decodeCursor(cursor: string): SaleCursor {
  let completedAtIso: string | undefined;
  let id: string | undefined;
  try {
    [completedAtIso, id] = Buffer.from(cursor, "base64url").toString("utf8").split("|");
  } catch {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  const completedAt = completedAtIso ? new Date(completedAtIso) : undefined;
  if (!completedAt || Number.isNaN(completedAt.getTime()) || !id) {
    throw new ApiError(422, "VALIDATION_FAILED", "Malformed cursor.");
  }

  return { completedAt, id };
}
