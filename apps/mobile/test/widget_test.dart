import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/home_screen.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/core/store_context/store_context_providers.dart';
import 'package:mobile/core/sync/sync_dto.dart';
import 'package:mobile/core/sync/sync_providers.dart';
import 'package:mobile/core/sync/sync_repository.dart';

void main() {
  testWidgets('home screen proves the local database opens and is queryable', (
    WidgetTester tester,
  ) async {
    // Pumps HomeScreen directly, not the full SmartPosXApp — since Sprint 06,
    // the app shell's router redirects through a Supabase-backed auth guard
    // before HomeScreen is ever reached, which is irrelevant to what this
    // test proves (the database opens and is queryable) and would require
    // faking Supabase's session storage for no benefit here. Since Sprint 08,
    // HomeScreen also watches `storeContextProvider`, which would otherwise
    // touch the (uninitialized, in this test) Supabase client and a real
    // network call — overridden with a fixed value for the same reason.
    // Since Sprint 14, HomeScreen also watches `autoSyncOnStartProvider`,
    // which would otherwise issue a real `GET /sync/pull` the moment
    // `storeContextProvider` resolves — overridden to a no-op for the same
    // reason.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(
            AppDatabase(NativeDatabase.memory()),
          ),
          storeContextProvider.overrideWith((ref) async => 'fake-store-id'),
          autoSyncOnStartProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local database ready — 0 product(s) cached.'), findsOneWidget);
    expect(find.text('Not synced yet this session.'), findsOneWidget);
  });

  testWidgets('tapping "Sync now" shows the resulting summary', (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final fakeRepository = SyncRepository(
      db,
      (operations) async => const SyncPushResponse([]),
      ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          storeContextProvider.overrideWith((ref) async => 'fake-store-id'),
          autoSyncOnStartProvider.overrideWith((ref) async {}),
          syncRepositoryProvider.overrideWithValue(fakeRepository),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sync_now_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Synced — nothing queued, 0 product(s) pulled.'),
      findsOneWidget,
    );
  });
}
