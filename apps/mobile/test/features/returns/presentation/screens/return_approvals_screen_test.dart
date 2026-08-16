import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/returns/domain/entities/return_detail.dart';
import 'package:mobile/features/returns/domain/entities/return_summary.dart';
import 'package:mobile/features/returns/domain/repositories/return_repository.dart';
import 'package:mobile/features/returns/presentation/providers/return_providers.dart';
import 'package:mobile/features/returns/presentation/screens/return_approvals_screen.dart';

/// A fake, not a mock — same reasoning `_FakeSaleRepository` established.
class _FakeReturnRepository implements ReturnRepository {
  _FakeReturnRepository({this.approvals = const [], this.approvalsError});

  final List<ReturnSummary> approvals;
  final Object? approvalsError;

  @override
  Future<List<ReturnSummary>> listApprovals() async {
    if (approvalsError != null) throw approvalsError!;
    return approvals;
  }

  @override
  Future<ReturnDetail> createReturn({
    required String id,
    required String originalSaleId,
    required List<ReturnLineItemInput> lineItems,
  }) => throw UnimplementedError();

  @override
  Future<List<ReturnSummary>> listMine() => throw UnimplementedError();

  @override
  Future<ReturnDetail?> getDetail(String id) => throw UnimplementedError();

  @override
  Future<ReturnDetail> approveReturn(String id) => throw UnimplementedError();

  @override
  Future<ReturnDetail> rejectReturn(String id, String reason) => throw UnimplementedError();
}

Widget _wrap(ReturnRepository repository) {
  final router = GoRouter(
    initialLocation: '/returns/approvals',
    routes: [
      GoRoute(
        path: '/returns/approvals',
        builder: (context, state) => const ReturnApprovalsScreen(),
      ),
      GoRoute(path: '/returns/:id', builder: (context, state) => const SizedBox()),
    ],
  );
  return ProviderScope(
    overrides: [returnRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('renders the empty state when nothing is pending', (tester) async {
    await tester.pumpWidget(_wrap(_FakeReturnRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('returns_approvals_empty')), findsOneWidget);
  });

  testWidgets('renders one row per pending return', (tester) async {
    final summary = ReturnSummary(
      id: 'return-1',
      originalSaleId: 'sale-1',
      status: 'pending_approval',
      refundTotalMinorUnits: 2800,
      createdAt: DateTime(2026, 8, 16),
    );
    await tester.pumpWidget(_wrap(_FakeReturnRepository(approvals: [summary])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('returns_approval_row_return-1')), findsOneWidget);
  });

  testWidgets('surfaces a Cashier-style 403 as a plain error, not a hidden screen', (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeReturnRepository(approvalsError: Exception('403 PERMISSION_DENIED'))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load approvals'), findsOneWidget);
  });
}
