import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/home_screen.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/core/storage/storage_providers.dart';
import 'package:mobile/core/store_context/store_context_providers.dart';
import 'package:mobile/core/sync/sync_dto.dart';
import 'package:mobile/core/sync/sync_providers.dart';
import 'package:mobile/core/sync/sync_repository.dart';
import 'package:mobile/features/reports/presentation/providers/reports_providers.dart';

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
          // Sprint 54 — otherwise touches disk_space_2's real platform channel, unavailable here.
          isStorageCriticallyLowProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local database ready — 0 product(s) cached.'), findsOneWidget);
    expect(find.text('Not synced yet this session.'), findsOneWidget);
  });

  // Sprint 38 (backlog.md M4 item 3) — unlike Reports, the Settings entry
  // point is always visible (Pattern B, settings_screen.dart's own
  // docstring): no probe to override here, since none gates it.
  testWidgets('always shows the Settings entry point', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
          storeContextProvider.overrideWith((ref) async => 'fake-store-id'),
          autoSyncOnStartProvider.overrideWith((ref) async {}),
          // Sprint 54 — otherwise touches disk_space_2's real platform channel, unavailable here.
          isStorageCriticallyLowProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('go_to_settings_button')), findsOneWidget);
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
          // Sprint 54 — otherwise touches disk_space_2's real platform channel, unavailable here.
          isStorageCriticallyLowProvider.overrideWith((ref) async => false),
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

  // Sprint 37 (backlog.md M4 item 2) — docs/modules/reports/specification.md
  // §1's "visibility, not an error state" design decision.
  testWidgets('shows the Reports entry point when canViewReportsProvider resolves true', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
          storeContextProvider.overrideWith((ref) async => 'fake-store-id'),
          autoSyncOnStartProvider.overrideWith((ref) async {}),
          // Sprint 54 — otherwise touches disk_space_2's real platform channel, unavailable here.
          isStorageCriticallyLowProvider.overrideWith((ref) async => false),
          canViewReportsProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('go_to_reports_button')), findsOneWidget);
  });

  testWidgets('hides the Reports entry point when canViewReportsProvider resolves false', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
          storeContextProvider.overrideWith((ref) async => 'fake-store-id'),
          autoSyncOnStartProvider.overrideWith((ref) async {}),
          // Sprint 54 — otherwise touches disk_space_2's real platform channel, unavailable here.
          isStorageCriticallyLowProvider.overrideWith((ref) async => false),
          canViewReportsProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('go_to_reports_button')), findsNothing);
  });

  testWidgets('hides the Reports entry point (fail-closed) while the probe is still resolving', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
          storeContextProvider.overrideWith((ref) async => 'fake-store-id'),
          autoSyncOnStartProvider.overrideWith((ref) async {}),
          // Sprint 54 — otherwise touches disk_space_2's real platform channel, unavailable here.
          isStorageCriticallyLowProvider.overrideWith((ref) async => false),
          // A never-completing Future (no Timer involved, unlike
          // Future.delayed) so the test doesn't leave a pending timer behind.
          canViewReportsProvider.overrideWith((ref) => Completer<bool>().future),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('go_to_reports_button')), findsNothing);
  });

  // Sprint 54 (docs/13-offline-sync/failure-scenarios.md §3, tier 3).
  testWidgets('shows the low-storage warning when the probe reports critically low', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
          storeContextProvider.overrideWith((ref) async => 'fake-store-id'),
          autoSyncOnStartProvider.overrideWith((ref) async {}),
          isStorageCriticallyLowProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('low_storage_warning')), findsOneWidget);
    expect(
      find.text('Storage is almost full. Sales may stop saving reliably — free up space now.'),
      findsOneWidget,
    );
  });

  testWidgets('hides the low-storage warning when the probe reports comfortable free space', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
          storeContextProvider.overrideWith((ref) async => 'fake-store-id'),
          autoSyncOnStartProvider.overrideWith((ref) async {}),
          isStorageCriticallyLowProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('low_storage_warning')), findsNothing);
  });
}
