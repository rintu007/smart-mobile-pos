import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/store_context/store_context_providers.dart';
import '../../../pos/domain/entities/completed_sale.dart';
import '../../data/data_sources/customers_api.dart' as api;
import '../../data/repositories/drift_customer_repository.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_field_conflict.dart';
import '../../domain/repositories/customer_repository.dart';

/// Manual (non-code-generated) Riverpod syntax, matching `category_providers.dart`.
final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return DriftCustomerRepository(
    ref.watch(appDatabaseProvider),
    () => api.fetchCustomers(dio),
    (customerId) => api.fetchPurchaseHistory(dio, customerId),
    () => api.fetchConflicts(dio),
    (conflictId, resolvedValue) => api.resolveConflict(dio, conflictId, resolvedValue),
  );
});

/// The search query driving both `CustomerPickerSheet` and `CustomersScreen`
/// — a phone prefix, FR-052. Plain `Notifier`, this codebase's Riverpod 3.x
/// convention.
class CustomerSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final customerSearchQueryProvider =
    NotifierProvider<CustomerSearchQueryController, String>(CustomerSearchQueryController.new);

/// Cache-first, best-effort-refresh — same shape `categoriesListProvider`
/// already established: a failed [CustomerRepository.refreshFromServer]
/// (offline, cold Supabase project) is swallowed so this still resolves with
/// whatever's cached.
final customerSearchResultsProvider = FutureProvider.autoDispose<List<Customer>>((ref) async {
  final repository = ref.watch(customerRepositoryProvider);
  try {
    await repository.refreshFromServer();
  } catch (_) {
    // Deliberately swallowed — see docstring above.
  }
  final query = ref.watch(customerSearchQueryProvider);
  return repository.searchByPhone(query);
});

/// A single customer's purchase history (`/customers/:id`) — live, on
/// demand, no local cache (customer_repository.dart's own docstring).
final customerPurchaseHistoryProvider =
    FutureProvider.autoDispose.family<List<CompletedSale>, String>((ref, customerId) {
      return ref.watch(customerRepositoryProvider).getPurchaseHistory(customerId);
    });

/// A single cached customer by id — `CustomerDetailScreen`'s header and the
/// till's own "attached customer" chip label after a resume, when
/// `CartState` only carries the id.
final customerByIdProvider = FutureProvider.autoDispose.family<Customer?, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).findById(id);
});

/// Drives `CustomerPickerSheet`'s inline "add new customer" form — same
/// `AsyncNotifier` shape (and the same non-`async` `build()` fix) as
/// `CreateCategoryController`.
class CreateCustomerController extends AsyncNotifier<Customer?> {
  @override
  FutureOr<Customer?> build() => null;

  Future<void> createCustomer({String? name, String? phone}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(customerRepositoryProvider)
          .createCustomer(id: const Uuid().v4(), name: name, phone: phone),
    );
    if (!state.hasError) {
      ref.invalidate(customerSearchResultsProvider);
    }
  }
}

final createCustomerControllerProvider =
    AsyncNotifierProvider<CreateCustomerController, Customer?>(CreateCustomerController.new);

/// Drives `CustomerEditScreen` — same `AsyncNotifier` shape as
/// `CreateCustomerController`. `updateCustomer`'s own local-write-plus-
/// enqueue never throws for connectivity reasons (customer_repository.dart's
/// own docstring), so this only ever fails on a genuine local error.
class UpdateCustomerController extends AsyncNotifier<Customer?> {
  @override
  FutureOr<Customer?> build() => null;

  Future<void> updateCustomer({required String id, String? name, String? phone}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(customerRepositoryProvider).updateCustomer(id: id, name: name, phone: phone),
    );
    if (!state.hasError) {
      ref.invalidate(customerByIdProvider(id));
      ref.invalidate(customerSearchResultsProvider);
    }
  }
}

final updateCustomerControllerProvider =
    AsyncNotifierProvider<UpdateCustomerController, Customer?>(UpdateCustomerController.new);

/// `/customers/conflicts` — live, on demand. `ConflictsScreen`'s own list;
/// a Cashier's own fetch throws (server `403`), surfaced as the plain error
/// state every other list screen already uses, per §1c.
final conflictsProvider = FutureProvider.autoDispose<List<CustomerFieldConflict>>((ref) {
  return ref.watch(customerRepositoryProvider).listConflicts();
});

/// The Till's own badge count — the same fetch as [conflictsProvider], but
/// with the `403` swallowed rather than surfaced, per §1c: the *correct*
/// behaviour (no badge for a Cashier) falls out of the existing
/// error-swallowing convention `pendingApprovalsCountProvider` already
/// established for Returns, not a new role check.
final pendingConflictsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final conflicts = await ref.watch(customerRepositoryProvider).listConflicts();
    return conflicts.length;
  } catch (_) {
    return 0;
  }
});

/// Drives `ConflictsScreen`'s resolve action.
class ResolveConflictController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> resolveConflict({required String conflictId, required String? resolvedValue}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(customerRepositoryProvider)
          .resolveConflict(conflictId: conflictId, resolvedValue: resolvedValue),
    );
  }
}

final resolveConflictControllerProvider =
    AsyncNotifierProvider<ResolveConflictController, void>(ResolveConflictController.new);
