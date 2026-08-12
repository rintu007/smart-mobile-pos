import { prisma } from "@/core/db/client";

// Prisma queries only, no business logic — docs/08-folder-structure/backend-structure.md §2.

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

  // Wrapped in a transaction with one `sale` stock movement per line item (backlog.md item 7) —
  // no FK relation exists from `sales` to `stock_movements` (schema-server.md only links them
  // loosely via `reference_type`/`reference_id`, since a reference can be a sale or a return), so
  // this can't use Prisma's nested-relation-write sugar the way `lineItems`/`payments` do; an
  // explicit `$transaction` gets the same atomicity. Each movement reuses its line item's own id,
  // the same 1:1 idempotency-key reuse products/repository.ts's opening movement established —
  // this function itself is only ever called once per genuinely new sale (service.ts's own
  // `findSaleById` replay check happens before this is reached), so no upsert is needed here.
  return prisma.$transaction(async (tx) => {
    const sale = await tx.sale.create({
      data: {
        id: input.id,
        tenantId: input.tenantId,
        storeId: input.storeId,
        status: "completed",
        provisionalInvoiceNumber: input.provisionalInvoiceNumber,
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

    return sale;
  });
}
