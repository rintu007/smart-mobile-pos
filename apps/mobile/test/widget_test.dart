import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('home screen proves the local database opens and is queryable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(
            AppDatabase(NativeDatabase.memory()),
          ),
        ],
        child: const SmartPosXApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local database ready — 0 product(s) cached.'), findsOneWidget);
  });
}
