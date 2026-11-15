import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:y300/core/persistence/app_database.dart';
import 'package:y300/features/library_shared/data/services/shared_shelf_category_store.dart';
import 'package:y300/features/library_shared/domain/models/library_operation_failure.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SharedShelfCategoryStore store;

  setUp(() async {
    db = await AppDatabase.open(databaseName: inMemoryDatabasePath);
    store = SharedShelfCategoryStore(Future<Database>.value(db));
  });

  tearDown(() async {
    await db.close();
  });

  test('system type views exist on a fresh database', () async {
    final categories = await store.loadCategories();
    expect(categories.map((category) => category.categoryId), <String>[
      'comic-default',
      'novel-default',
    ]);
    expect(categories.map((category) => category.name), <String>['漫画', '小说']);
    expect(await db.query(AppDatabase.categoriesTable), hasLength(2));
    expect(await db.query(AppDatabase.novelCategoriesTable), hasLength(2));

    final comicCategories = await store.loadCategories(
      module: LibraryModuleKey.comic,
    );
    expect(
      comicCategories.map((category) => category.categoryId),
      <String>['comic-default'],
    );
    final novelCategories = await store.loadCategories(
      module: LibraryModuleKey.novel,
    );
    expect(
      novelCategories.map((category) => category.categoryId),
      <String>['novel-default'],
    );
  });

  test('create and rename update the shared row and both mirrors', () async {
    final categoryId = await store.createCategory(name: '追更');

    for (final table in <String>[
      AppDatabase.libraryShelfCategoriesTable,
      AppDatabase.categoriesTable,
      AppDatabase.novelCategoriesTable,
    ]) {
      final rows = await db.query(
        table,
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
      );
      expect(rows.single['name'], '追更');
    }

    await store.renameCategory(categoryId: categoryId, newName: '收藏追更');
    final categories = await store.loadCategories();
    expect(
      categories
          .singleWhere((category) => category.categoryId == categoryId)
          .name,
      '收藏追更',
    );
    expect(
      (await db.query(
        AppDatabase.novelCategoriesTable,
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
      )).single['name'],
      '收藏追更',
    );
  });

  test(
    'deleting a shared category moves items to each type view',
    () async {
      final categoryId = await store.createCategory(name: '共享');
      await db.insert(AppDatabase.comicsTable, <String, Object?>{
        'comic_id': 'comic:1',
        'source_tid': '1',
        'source_fid': '30',
        'title': '漫画',
        'created_at': 1,
        'updated_at': 1,
      });
      await db.insert(AppDatabase.shelfItemsTable, <String, Object?>{
        'category_id': categoryId,
        'comic_id': 'comic:1',
        'added_at': 1,
        'sort_order': 1,
      });
      await db.insert(AppDatabase.worksTable, <String, Object?>{
        'work_id': 'novel:1',
        'content_type': 'novel',
        'source_tid': '2',
        'source_fid': '49',
        'title': '小说',
        'updated_at': 1,
      });
      await db.insert(AppDatabase.novelShelfItemsTable, <String, Object?>{
        'category_id': categoryId,
        'novel_id': 'novel:1',
        'added_at': 1,
        'sort_order': 1,
      });

      await store.deleteCategory(categoryId: categoryId);

      expect(
        (await db.query(AppDatabase.shelfItemsTable)).single['category_id'],
        'comic-default',
      );
      expect(
        (await db.query(AppDatabase.novelShelfItemsTable))
            .single['category_id'],
        'novel-default',
      );
      for (final table in <String>[
        AppDatabase.libraryShelfCategoriesTable,
        AppDatabase.categoriesTable,
        AppDatabase.novelCategoriesTable,
      ]) {
        expect(
          await db.query(
            table,
            where: 'category_id = ?',
            whereArgs: <Object>[categoryId],
          ),
          isEmpty,
        );
      }
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test('system type views cannot be renamed or deleted', () async {
    for (final categoryId in <String>['comic-default', 'novel-default']) {
      await expectLater(
        store.renameCategory(categoryId: categoryId, newName: '改名'),
        throwsA(
          isA<LibraryOperationException>().having(
            (error) => error.code,
            'code',
            LibraryOperationFailureCode.defaultCategoryImmutable,
          ),
        ),
      );
      await expectLater(
        store.deleteCategory(categoryId: categoryId),
        throwsA(isA<LibraryOperationException>()),
      );
    }
  });
}
