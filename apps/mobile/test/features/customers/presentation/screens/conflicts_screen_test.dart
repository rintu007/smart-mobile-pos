import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/customers/domain/entities/customer.dart';
import 'package:mobile/features/customers/domain/entities/customer_field_conflict.dart';
import 'package:mobile/features/customers/domain/repositories/customer_repository.dart';
import 'package:mobile/features/customers/presentation/providers/customer_providers.dart';
import 'package:mobile/features/customers/presentation/screens/conflicts_screen.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';

/// A fake, not a mock — same reasoning `_FakeSaleRepository` established.
class _FakeCustomerRepository implements CustomerRepository {
  _FakeCustomerRepository({this.conflicts = const [], this.conflictsError});

  final List<CustomerFieldConflict> conflicts;
  final Object? conflictsError;
  String? lastResolvedId;
  String? lastResolvedValue;

  @override
  Future<List<CustomerFieldConflict>> listConflicts() async {
    if (conflictsError != null) throw conflictsError!;
    return conflicts;
  }

  @override
  Future<void> resolveConflict({required String conflictId, required String? resolvedValue}) async {
    lastResolvedId = conflictId;
    lastResolvedValue = resolvedValue;
  }

  @override
  Future<Customer> createCustomer({required String id, String? name, String? phone}) =>
      throw UnimplementedError();

  @override
  Future<Customer?> findById(String id) => throw UnimplementedError();

  @override
  Future<List<Customer>> searchByPhone(String query) => throw UnimplementedError();

  @override
  Future<void> refreshFromServer() => throw UnimplementedError();

  @override
  Future<List<CompletedSale>> getPurchaseHistory(String customerId) => throw UnimplementedError();

  @override
  Future<Customer> updateCustomer({required String id, String? name, String? phone}) =>
      throw UnimplementedError();
}

Widget _wrap(_FakeCustomerRepository repository) {
  return ProviderScope(
    overrides: [customerRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: ConflictsScreen()),
  );
}

const _conflict = CustomerFieldConflict(
  id: 'conflict-1',
  customerId: 'customer-1',
  customerName: 'Ramesh Kumar',
  field: 'phone',
  currentValue: '9876543210',
  currentSetByName: 'Priya',
  attemptedValue: '9876500000',
  attemptedSetByName: 'Anil',
);

void main() {
  testWidgets('renders the empty state when nothing is unresolved', (tester) async {
    await tester.pumpWidget(_wrap(_FakeCustomerRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer_conflicts_empty')), findsOneWidget);
  });

  testWidgets('renders one row per conflict', (tester) async {
    await tester.pumpWidget(_wrap(_FakeCustomerRepository(conflicts: const [_conflict])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer_conflict_row_conflict-1')), findsOneWidget);
  });

  testWidgets('surfaces a Cashier-style 403 as a plain error, not a hidden screen', (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeCustomerRepository(conflictsError: Exception('403 PERMISSION_DENIED'))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load conflicts'), findsOneWidget);
  });

  testWidgets('tapping a row expands the worked-example prompt with both named choices', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_FakeCustomerRepository(conflicts: const [_conflict])));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('customer_conflict_row_conflict-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer_conflict_choice_current_conflict-1')), findsOneWidget);
    expect(find.byKey(const Key('customer_conflict_choice_attempted_conflict-1')), findsOneWidget);
    expect(find.textContaining('Priya set it to 9876543210'), findsOneWidget);
    expect(find.textContaining('Anil set it to 9876500000'), findsOneWidget);
  });

  testWidgets('tapping a choice resolves the conflict', (tester) async {
    final repository = _FakeCustomerRepository(conflicts: const [_conflict]);
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('customer_conflict_row_conflict-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer_conflict_choice_attempted_conflict-1')));
    await tester.pumpAndSettle();

    expect(repository.lastResolvedId, 'conflict-1');
    expect(repository.lastResolvedValue, '9876500000');
  });
}
