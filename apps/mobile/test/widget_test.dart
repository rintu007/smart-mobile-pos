import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/home_screen.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/database/database.dart';

void main() {
  testWidgets('home screen proves the local database opens and is queryable', (
    WidgetTester tester,
  ) async {
    // Pumps HomeScreen directly, not the full SmartPosXApp — since Sprint 06,
    // the app shell's router redirects through a Supabase-backed auth guard
    // before HomeScreen is ever reached, which is irrelevant to what this
    // test proves (the database opens and is queryable) and would require
    // faking Supabase's session storage for no benefit here.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(
            AppDatabase(NativeDatabase.memory()),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local database ready — 0 product(s) cached.'), findsOneWidget);
  });
}
