import { randomUUID } from "node:crypto";
import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

// docs/modules/sales-invoices/specification.md §2 — India's financial year rolls over April 1,
// represented by its starting calendar year (e.g. FY2026-27 -> "2026"), matching mobile's own
// InvoiceNumberGenerator._financialYearFor exactly (identifiers.md §3). Uses UTC, not IST, for the
// month boundary — consistent with every other timestamp in this system being stored/reasoned
// about in UTC (Timestamptz); a named simplification, not a claim of precise IST rollover, same
// provisional status as everything else tied to OD-01's still-unconfirmed launch market.
function financialYearFor(date: Date): string {
  const startYear = date.getUTCMonth() >= 3 ? date.getUTCFullYear() : date.getUTCFullYear() - 1;
  return startYear.toString();
}

export function findSaleById(id: string) {
  return prisma.sale.findUnique({
    where: { id },
    include: { lineItems: true, payments: true },
  });
}

export function findProductsByIds(tenantId: string, ids: string[]) {
  return prisma.product.findMany({
    where: { tenantId, id: { in: ids }, deactivatedAt: null },
  });
}

export interface CreateSaleInput {
  id: string;
  tenantId: string;
  storeId: string;
  createdBy: string;
  provisionalInvoiceNumber: string;
  subtotalMinorUnits: bigint;
  grandTotalMinorUnits: bigint;
  lineItems: {
    id: string;
    productId: string;
    quantity: number;
    unitPriceMinorUnits: bigint;
    lineTotalMinorUnits: bigint;
  }[];
  payment: { id: string; method: string; amountMinorUnits: bigint };
}

export function createSale(input: CreateSaleInput) {
  const completedAt = new Date();
  const financialYear = financialYearFor(completedAt);

  // Wrapped in a transaction with one `sale` stock movement per line item (backlog.md item 7) —
  // no FK relation exists from `sales` to `stock_movements` (schema-server.md only links them
  // loosely via `reference_type`/`reference_id`, since a reference can be a sale or a return), so
  // this can't use Prisma's nested-relation-write sugar the way `lineItems`/`payments` do; an
  // explicit `$transaction` gets the same atomicity. Each movement reuses its line item's own id,
  // the same 1:1 idempotency-key reuse products/repository.ts's opening movement established —
  // this function itself is only ever called once per genuinely new sale (service.ts's own
  // `findSaleById` replay check happens before this is reached), so no upsert is needed here.
  return prisma.$transaction(async (tx) => {
    // ADR-0008's canonical half (backlog.md item 8): an atomic per-(tenant, financial_year)
    // counter, incremented in the same transaction as the sale itself — gapless by construction,
    // since a rollback here (e.g. a later step in this same transaction failing) rolls the
    // increment back too. `nextValue` after this upsert is always "the number to hand out next
    // time"; the number assigned to *this* sale is one less than that, whether the row was just
    // created (starts at 2, so this sale gets 1) or already existed (incremented, so this sale
    // gets the pre-increment value).
    const sequence = await tx.invoiceSequence.upsert({
      where: { tenantId_financialYear: { tenantId: input.tenantId, financialYear } },
      create: { id: randomUUID(), tenantId: input.tenantId, financialYear, nextValue: BigInt(2) },
      update: { nextValue: { increment: 1 } },
    });
    const canonicalInvoiceNumber = sequence.nextValue - BigInt(1);

    const sale = await tx.sale.create({
      data: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        status: "completed",
        provisionalInvoiceNumber: input.provisionalInvoiceNumber,
        canonicalInvoiceNumber,
        financialYear,
        subtotalMinorUnits: input.subtotalMinorUnits,
        grandTotalMinorUnits: input.grandTotalMinorUnits,
        completedAt,
        createdBy: input.createdBy,
        lineItems: {
          create: input.lineItems.map((item) => ({
            id: item.id,
            productId: item.productId,
            quantity: item.quantity,
            unitPriceMinorUnits: item.unitPriceMinorUnits,
            lineTotalMinorUnits: item.lineTotalMinorUnits,
          })),
        },
        payments: {
          create: {
            id: input.payment.id,
            method: input.payment.method,
            amountMinorUnits: input.payment.amountMinorUnits,
          },
        },
      },
      include: { lineItems: true, payments: true },
    });

    // DR-005: never blocked even when it would take a balance negative — matching
    // inventory.md's "why oversell is not an error here".
    await tx.stockMovement.createMany({
      data: input.lineItems.map((item) => ({
        id: item.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        productId: item.productId,
        quantityDelta: -item.quantity,
        movementType: "sale",
        referenceType: "sale",
        referenceId: input.id,
        createdBy: input.createdBy,
      })),
    });

    // DR-025 (backlog.md item 8): one audit entry per completed sale, in the same transaction as
    // the sale itself — docs/modules/audit-log/specification.md. Reuses the sale's own id as this
    // row's id, the same 1:1 idempotency-key reuse the stock movements above already established.
    // No `beforeState` — this is a creation event, there is no prior state to snapshot.
    await tx.auditLog.create({
      data: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        actorUserId: input.createdBy,
        action: "sale.completed",
        entityType: "sale",
        entityId: input.id,
        afterState: {
          id: input.id,
          status: "completed",
          provisional_invoice_number: input.provisionalInvoiceNumber,
          canonical_invoice_number: Number(canonicalInvoiceNumber),
          subtotal_minor_units: Number(input.subtotalMinorUnits),
          grand_total_minor_units: Number(input.grandTotalMinorUnits),
          completed_at: completedAt.toISOString(),
        },
      },
    });

    return sale;
  });
}
