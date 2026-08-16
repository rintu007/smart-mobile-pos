import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/customers/domain/entities/customer.dart';
import 'package:mobile/features/customers/domain/entities/customer_field_conflict.dart';
import 'package:mobile/features/customers/domain/repositories/customer_repository.dart';
import 'package:mobile/features/customers/presentation/providers/customer_providers.dart';
import 'package:mobile/features/customers/presentation/screens/customer_edit_screen.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';

/// A fake, not a mock — same reasoning `_FakeSaleRepository` established.
class _FakeCustomerRepository implements CustomerRepository {
  _FakeCustomerRepository(this.customer);

  final Customer? customer;
  String? lastUpdatedId;
  String? lastUpdatedName;
  String? lastUpdatedPhone;

  @override
  Future<Customer?> findById(String id) async => customer;

  @override
  Future<Customer> updateCustomer({required String id, String? name, String? phone}) async {
    lastUpdatedId = id;
    lastUpdatedName = name;
    lastUpdatedPhone = phone;
    return Customer(id: id, name: name, phone: phone);
  }

  @override
  Future<Customer> createCustomer({required String id, String? name, String? phone}) =>
      throw UnimplementedError();

  @override
  Future<List<Customer>> searchByPhone(String query) => throw UnimplementedError();

  @override
  Future<void> refreshFromServer() => throw UnimplementedError();

  @override
  Future<List<CompletedSale>> getPurchaseHistory(String customerId) => throw UnimplementedError();

  @override
  Future<List<CustomerFieldConflict>> listConflicts() => throw UnimplementedError();

  @override
  Future<void> resolveConflict({required String conflictId, required String? resolvedValue}) =>
      throw UnimplementedError();
}

Widget _wrap(_FakeCustomerRepository repository, {String customerId = 'customer-1'}) {
  final router = GoRouter(
    initialLocation: '/customers/$customerId',
    routes: [
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) => Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => context.push('/customers/${state.pathParameters['id']}/edit'),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/customers/:id/edit',
        builder: (context, state) =>
            CustomerEditScreen(customerId: state.pathParameters['id']!),
      ),
    ],
  );
  return ProviderScope(
    overrides: [customerRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _navigateToEdit(WidgetTester tester) async {
  await tester.tap(find.text('Edit'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pre-fills the fields from the local cache', (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeCustomerRepository(const Customer(id: 'customer-1', name: 'Ramesh Kumar', phone: '9111111111'))),
    );
    await tester.pumpAndSettle();
    await _navigateToEdit(tester);

    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.text('9111111111'), findsOneWidget);
  });

  testWidgets('renders "Customer not found" for a missing id', (tester) async {
    await tester.pumpWidget(_wrap(_FakeCustomerRepository(null)));
    await tester.pumpAndSettle();
    await _navigateToEdit(tester);

    expect(find.byKey(const Key('customer_edit_not_found')), findsOneWidget);
  });

  testWidgets('saving calls updateCustomer with the edited values', (tester) async {
    final repository = _FakeCustomerRepository(
      const Customer(id: 'customer-1', name: 'Ramesh Kumar', phone: '9111111111'),
    );
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    await _navigateToEdit(tester);

    await tester.enterText(find.byKey(const Key('customer_edit_phone_field')), '9876543210');
    await tester.tap(find.byKey(const Key('customer_edit_save_button')));
    await tester.pumpAndSettle();

    expect(repository.lastUpdatedId, 'customer-1');
    expect(repository.lastUpdatedName, 'Ramesh Kumar');
    expect(repository.lastUpdatedPhone, '9876543210');
  });
}
