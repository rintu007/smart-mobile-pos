import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/store_context/store_context_providers.dart';
import '../../data/data_sources/returns_api.dart' as api;
import '../../data/repositories/drift_return_repository.dart';
import '../../domain/entities/return_detail.dart';
import '../../domain/entities/return_summary.dart';
import '../../domain/repositories/return_repository.dart';

/// Manual (non-code-generated) Riverpod syntax, matching `customer_providers.dart`.
final returnRepositoryProvider = Provider<ReturnRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return DriftReturnRepository(
    ref.watch(appDatabaseProvider),
    () => api.fetchMyReturns(dio),
    () => api.fetchApprovals(dio),
    (id) => api.fetchReturnById(dio, id),
  );
});

/// This device's own filed returns (`/returns/new`'s own history isn't
/// shown anywhere yet — this backs a possible future list, kept simple and
/// consistent with the repository's own shape rather than left unexposed).
final myReturnsProvider = FutureProvider.autoDispose<List<ReturnSummary>>((ref) {
  return ref.watch(returnRepositoryProvider).listMine();
});

/// The Manager/Owner approval queue (`/returns/approvals`).
final approvalsProvider = FutureProvider.autoDispose<List<ReturnSummary>>((ref) {
  return ref.watch(returnRepositoryProvider).listApprovals();
});

/// The Till's own badge count — `pending_approval` rows in whatever
/// `listApprovals()` resolved to (already scoped to nothing for a Cashier,
/// whose own fetch 403s and is swallowed inside the repository itself, per
/// specification.md §1b).
final pendingApprovalsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final approvals = await ref.watch(approvalsProvider.future);
  return approvals.where((r) => r.status == 'pending_approval').length;
});

/// A single return's detail (`/returns/:id`).
final returnDetailProvider = FutureProvider.autoDispose.family<ReturnDetail?, String>((ref, id) {
  return ref.watch(returnRepositoryProvider).getDetail(id);
});

/// Drives `NewReturnScreen`'s submit action — same `AsyncNotifier` shape
/// (and the same non-`async` `build()` fix) as `CreateCustomerController`.
class CreateReturnController extends AsyncNotifier<ReturnDetail?> {
  @override
  FutureOr<ReturnDetail?> build() => null;

  Future<void> createReturn({
    required String originalSaleId,
    required List<ReturnLineItemInput> lineItems,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(returnRepositoryProvider)
          .createReturn(id: const Uuid().v4(), originalSaleId: originalSaleId, lineItems: lineItems),
    );
    if (!state.hasError) {
      ref.invalidate(myReturnsProvider);
      ref.invalidate(approvalsProvider);
    }
  }
}

final createReturnControllerProvider = AsyncNotifierProvider<CreateReturnController, ReturnDetail?>(
  CreateReturnController.new,
);

/// Drives the approve action from both `NewReturnScreen`'s inline prompt and
/// `ReturnDetailScreen`'s own button.
class ApproveReturnController extends AsyncNotifier<ReturnDetail?> {
  @override
  FutureOr<ReturnDetail?> build() => null;

  Future<void> approveReturn(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(returnRepositoryProvider).approveReturn(id));
    if (!state.hasError) {
      ref.invalidate(approvalsProvider);
      ref.invalidate(returnDetailProvider(id));
    }
  }
}

final approveReturnControllerProvider =
    AsyncNotifierProvider<ApproveReturnController, ReturnDetail?>(ApproveReturnController.new);

/// Drives the reject action from `ReturnDetailScreen`.
class RejectReturnController extends AsyncNotifier<ReturnDetail?> {
  @override
  FutureOr<ReturnDetail?> build() => null;

  Future<void> rejectReturn(String id, String reason) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(returnRepositoryProvider).rejectReturn(id, reason));
    if (!state.hasError) {
      ref.invalidate(approvalsProvider);
      ref.invalidate(returnDetailProvider(id));
    }
  }
}

final rejectReturnControllerProvider =
    AsyncNotifierProvider<RejectReturnController, ReturnDetail?>(RejectReturnController.new);
