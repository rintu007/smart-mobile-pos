import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pos/domain/entities/completed_sale.dart';
import '../../../pos/domain/entities/sale_detail.dart';
import '../../../pos/presentation/providers/pos_providers.dart';

/// `sales_history` has no domain/data layer of its own — per
/// mobile-structure.md §3, `pos` already owns the `Sale` concept and its
/// local table; these providers just expose `pos`'s own `SaleRepository`
/// read methods to this feature's screens rather than duplicating a
/// parallel entity/repository for no reason.
final salesHistoryListProvider = FutureProvider<List<CompletedSale>>((ref) {
  return ref.watch(saleRepositoryProvider).listCompletedSales();
});

final saleDetailProvider = FutureProvider.family<SaleDetail?, String>((
  ref,
  saleId,
) {
  return ref.watch(saleRepositoryProvider).getSaleDetail(saleId);
});
