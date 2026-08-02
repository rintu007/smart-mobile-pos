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

  return prisma.sale.create({
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
}
