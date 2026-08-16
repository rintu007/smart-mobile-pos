import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/customers/domain/entities/customer.dart';
import 'package:mobile/features/customers/domain/repositories/customer_repository.dart';
import 'package:mobile/features/customers/presentation/providers/customer_providers.dart';
import 'package:mobile/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';

class _FakeCustomerRepository implements CustomerRepository {
  _FakeCustomerRepository({this.customer, this.history = const []});

  final Customer? customer;
  final List<CompletedSale> history;

  @override
  Future<Customer?> findById(String id) async => customer;

  @override
  Future<List<CompletedSale>> getPurchaseHistory(String customerId) async => history;

  @override
  Future<List<Customer>> searchByPhone(String query) => throw UnimplementedError();

  @override
  Future<Customer> createCustomer({required String id, String? name, String? phone}) =>
      throw UnimplementedError();

  @override
  Future<void> refreshFromServer() => throw UnimplementedError();
}

Widget _wrap(_FakeCustomerRepository repository, {String customerId = 'customer-1'}) {
  return ProviderScope(
    overrides: [customerRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: CustomerDetailScreen(customerId: customerId)),
  );
}

void main() {
  testWidgets('renders "Customer not found" when the id does not resolve', (tester) async {
    await tester.pumpWidget(_wrap(_FakeCustomerRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer_detail_not_found')), findsOneWidget);
  });

  testWidgets('renders name/phone and purchase history', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeCustomerRepository(
          customer: const Customer(id: 'customer-1', name: 'Ramesh Kumar', phone: '9876543210'),
          history: [
            CompletedSale(
              id: 'sale-1',
              provisionalInvoiceNumber: 'DEV001-2026-000001',
              grandTotalMinorUnits: 3500,
              completedAt: DateTime(2026, 8, 12, 14, 30),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.byKey(const Key('customer_history_sale_sale-1')), findsOneWidget);
    expect(find.text('\u{20B9}35.00'), findsOneWidget);
    expect(find.byKey(const Key('customer_history_empty')), findsNothing);
  });

  testWidgets('renders "No purchases yet" when history is empty', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeCustomerRepository(
          customer: const Customer(id: 'customer-1', phone: '9876543210'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer_history_empty')), findsOneWidget);
  });
}
