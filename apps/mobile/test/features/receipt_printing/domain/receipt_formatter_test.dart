import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pos/domain/entities/sale_detail.dart';
import 'package:mobile/features/receipt_printing/domain/receipt_formatter.dart';

void main() {
  const formatter = ReceiptFormatter();

  final sale = SaleDetail(
    id: 'sale-1',
    provisionalInvoiceNumber: 'DEV-2026-000042',
    completedAt: DateTime(2026, 7, 30, 14, 5),
    grandTotalMinorUnits: 6800,
    lines: const [
      SaleLineDetail(
        productId: 'p1',
        productName: 'Amul Milk 500ml',
        quantity: 1,
        unitPriceMinorUnits: 2800,
        lineTotalMinorUnits: 2800,
      ),
      SaleLineDetail(
        productId: 'p2',
        productName: 'Parle-G Biscuit 200g',
        quantity: 2,
        unitPriceMinorUnits: 2000,
        lineTotalMinorUnits: 4000,
      ),
    ],
  );

  test('formats the shop name, invoice number, and date', () {
    final doc = formatter.build(sale: sale, shopName: 'Sharma General Store');

    expect(doc.shopName, 'Sharma General Store');
    expect(doc.invoiceNumber, 'DEV-2026-000042');
    expect(doc.dateLabel, '30-Jul-2026');
  });

  test('formats every line item with plain (no ₹) amounts', () {
    final doc = formatter.build(sale: sale, shopName: 'Sharma General Store');

    expect(doc.lineItems, hasLength(2));
    expect(doc.lineItems[0].name, 'Amul Milk 500ml');
    expect(doc.lineItems[0].quantity, 1);
    expect(doc.lineItems[0].unitPriceLabel, '28.00');
    expect(doc.lineItems[0].lineTotalLabel, '28.00');
    expect(doc.lineItems[1].unitPriceLabel, '20.00');
    expect(doc.lineItems[1].lineTotalLabel, '40.00');
  });

  test('falls back to productId when productName is null', () {
    final saleWithMissingProduct = SaleDetail(
      id: sale.id,
      provisionalInvoiceNumber: sale.provisionalInvoiceNumber,
      completedAt: sale.completedAt,
      grandTotalMinorUnits: sale.grandTotalMinorUnits,
      lines: const [
        SaleLineDetail(
          productId: 'deleted-product',
          productName: null,
          quantity: 1,
          unitPriceMinorUnits: 100,
          lineTotalMinorUnits: 100,
        ),
      ],
    );

    final doc = formatter.build(sale: saleWithMissingProduct, shopName: 'Shop');

    expect(doc.lineItems.single.name, 'deleted-product');
  });

  test('total and payment labels reflect the grand total, cash-only', () {
    final doc = formatter.build(sale: sale, shopName: 'Sharma General Store');

    expect(doc.totalLabel, '68.00');
    expect(doc.paymentLabel, 'Paid (Cash)  68.00');
  });

  test('uses the default footer message unless one is provided', () {
    final defaultDoc = formatter.build(sale: sale, shopName: 'Shop');
    expect(defaultDoc.footerMessage, 'Thank you, visit again!');

    final customDoc = formatter.build(
      sale: sale,
      shopName: 'Shop',
      footerMessage: 'See you soon!',
    );
    expect(customDoc.footerMessage, 'See you soon!');
  });
}
