import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/customers/domain/entities/customer.dart';
import 'package:mobile/features/customers/domain/repositories/customer_repository.dart';
import 'package:mobile/features/customers/presentation/providers/customer_providers.dart';
import 'package:mobile/features/customers/presentation/screens/customers_screen.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';

class _FakeCustomerRepository implements CustomerRepository {
  _FakeCustomerRepository([this._customers = const []]);

  final List<Customer> _customers;

  @override
  Future<List<Customer>> searchByPhone(String query) async {
    if (query.isEmpty) return _customers;
    return _customers.where((c) => (c.phone ?? '').startsWith(query)).toList();
  }

  @override
  Future<Customer> createCustomer({required String id, String? name, String? phone}) =>
      throw UnimplementedError();

  @override
  Future<Customer?> findById(String id) => throw UnimplementedError();

  @override
  Future<void> refreshFromServer() async {}

  @override
  Future<List<CompletedSale>> getPurchaseHistory(String customerId) => throw UnimplementedError();
}

Widget _wrap(List<Customer> customers) {
  return ProviderScope(
    overrides: [
      customerRepositoryProvider.overrideWithValue(_FakeCustomerRepository(customers)),
    ],
    child: const MaterialApp(home: CustomersScreen()),
  );
}

void main() {
  testWidgets('renders "No customers yet" when the list is empty', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customers_empty')), findsOneWidget);
  });

  testWidgets('renders each customer\'s name/phone', (tester) async {
    await tester.pumpWidget(
      _wrap(const [
        Customer(id: 'customer-1', name: 'Ramesh Kumar', phone: '9876543210'),
        Customer(id: 'customer-2', phone: '9111111111'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customers_row_customer-1')), findsOneWidget);
    expect(find.byKey(const Key('customers_row_customer-2')), findsOneWidget);
    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.text('9111111111'), findsOneWidget);
    expect(find.byKey(const Key('customers_empty')), findsNothing);
  });

  testWidgets('typing in the search field filters by phone', (tester) async {
    await tester.pumpWidget(
      _wrap(const [
        Customer(id: 'customer-1', name: 'Ramesh Kumar', phone: '9876543210'),
        Customer(id: 'customer-2', phone: '9111111111'),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('customers_search_field')), '987');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customers_row_customer-1')), findsOneWidget);
    expect(find.byKey(const Key('customers_row_customer-2')), findsNothing);
  });
}
