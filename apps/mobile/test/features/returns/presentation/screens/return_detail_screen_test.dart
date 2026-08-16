import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/returns/domain/entities/return_detail.dart';
import 'package:mobile/features/returns/domain/entities/return_summary.dart';
import 'package:mobile/features/returns/domain/repositories/return_repository.dart';
import 'package:mobile/features/returns/presentation/providers/return_providers.dart';
import 'package:mobile/features/returns/presentation/screens/return_detail_screen.dart';

/// A fake, not a mock — same reasoning `_FakeSaleRepository` established.
class _FakeReturnRepository implements ReturnRepository {
  _FakeReturnRepository(this._byId);

  final Map<String, ReturnDetail> _byId;
  String? lastApprovedId;
  String? lastRejectedId;
  String? lastRejectedReason;

  @override
  Future<ReturnDetail?> getDetail(String id) async => _byId[id];

  @override
  Future<ReturnDetail> approveReturn(String id) async {
    lastApprovedId = id;
    final existing = _byId[id]!;
    final updated = ReturnDetail(
      id: existing.id,
      originalSaleId: existing.originalSaleId,
      status: 'completed',
      refundTotalMinorUnits: existing.refundTotalMinorUnits,
      completedAt: DateTime(2026, 8, 16),
      createdAt: existing.createdAt,
      lineItems: existing.lineItems,
    );
    _byId[id] = updated;
    return updated;
  }

  @override
  Future<ReturnDetail> rejectReturn(String id, String reason) async {
    lastRejectedId = id;
    lastRejectedReason = reason;
    final existing = _byId[id]!;
    final updated = ReturnDetail(
      id: existing.id,
      originalSaleId: existing.originalSaleId,
      status: 'rejected',
      refundTotalMinorUnits: existing.refundTotalMinorUnits,
      createdAt: existing.createdAt,
      lineItems: existing.lineItems,
    );
    _byId[id] = updated;
    return updated;
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
  Future<List<ReturnSummary>> listApprovals() => throw UnimplementedError();
}

ReturnDetail _pendingReturn({String id = 'return-1'}) => ReturnDetail(
  id: id,
  originalSaleId: 'sale-1',
  status: 'pending_approval',
  refundTotalMinorUnits: 2800,
  createdAt: DateTime(2026, 8, 16),
  lineItems: const [
    ReturnLineItem(originalSaleLineItemId: 'line-1', quantity: 1, refundAmountMinorUnits: 2800),
  ],
);

Widget _wrap(_FakeReturnRepository repository, {String returnId = 'return-1'}) {
  return ProviderScope(
    overrides: [returnRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: ReturnDetailScreen(returnId: returnId)),
  );
}

void main() {
  testWidgets('renders "Return not found" for a missing id', (tester) async {
    await tester.pumpWidget(_wrap(_FakeReturnRepository({})));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('return_detail_not_found')), findsOneWidget);
  });

  testWidgets('shows approve/reject only while pending_approval', (tester) async {
    await tester.pumpWidget(_wrap(_FakeReturnRepository({'return-1': _pendingReturn()})));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('returns_approve_button')), findsOneWidget);
    expect(find.byKey(const Key('returns_reject_button')), findsOneWidget);
  });

  testWidgets('does not show approve/reject once completed', (tester) async {
    final completed = ReturnDetail(
      id: 'return-1',
      originalSaleId: 'sale-1',
      status: 'completed',
      refundTotalMinorUnits: 2800,
      completedAt: DateTime(2026, 8, 16),
      createdAt: DateTime(2026, 8, 16),
      lineItems: const [],
    );
    await tester.pumpWidget(_wrap(_FakeReturnRepository({'return-1': completed})));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('returns_approve_button')), findsNothing);
  });

  testWidgets('tapping Approve calls the repository', (tester) async {
    final repository = _FakeReturnRepository({'return-1': _pendingReturn()});
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('returns_approve_button')));
    await tester.pumpAndSettle();

    expect(repository.lastApprovedId, 'return-1');
  });

  testWidgets('rejecting requires a reason, then calls the repository', (tester) async {
    final repository = _FakeReturnRepository({'return-1': _pendingReturn()});
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('returns_reject_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('returns_reject_reason_field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('returns_reject_reason_field')),
      'Customer changed mind',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('returns_reject_submit_button')));
    await tester.pumpAndSettle();

    expect(repository.lastRejectedId, 'return-1');
    expect(repository.lastRejectedReason, 'Customer changed mind');
  });
}
