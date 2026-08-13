import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/catalogue/domain/entities/category.dart';
import 'package:mobile/features/catalogue/domain/repositories/category_repository.dart';
import 'package:mobile/features/catalogue/presentation/providers/category_providers.dart';
import 'package:mobile/features/catalogue/presentation/screens/categories_screen.dart';

/// A fake, not a mock — same reasoning as `_FakeProductRepository`.
class _FakeCategoryRepository implements CategoryRepository {
  final List<Category> _categories = [];
  bool createCalled = false;

  @override
  Future<Category> createCategory({required String id, required String name}) async {
    createCalled = true;
    final category = Category(id: id, name: name);
    _categories.add(category);
    return category;
  }

  @override
  Future<List<Category>> listAll() async => List.of(_categories);

  @override
  Future<void> refreshFromServer() async {}
}

Widget _wrap(CategoryRepository repository) {
  return ProviderScope(
    overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: CategoriesScreen()),
  );
}

void main() {
  testWidgets('shows the empty state when there are no categories yet', (tester) async {
    await tester.pumpWidget(_wrap(_FakeCategoryRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('categories_empty')), findsOneWidget);
  });

  testWidgets('creating a category via the dialog adds it to the list', (tester) async {
    final repository = _FakeCategoryRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_category_fab')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('category_name_field')), 'Dairy');
    await tester.tap(find.byKey(const Key('category_dialog_save_button')));
    await tester.pumpAndSettle();

    expect(repository.createCalled, isTrue);
    expect(find.byKey(const Key('categories_list')), findsOneWidget);
    expect(find.text('Dairy'), findsOneWidget);
  });

  testWidgets('the dialog rejects an empty name', (tester) async {
    final repository = _FakeCategoryRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_category_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_dialog_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a category name.'), findsOneWidget);
    expect(repository.createCalled, isFalse);
  });
}
