import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:y300/core/persistence/app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'v44 module categories migrate into shared mirrored categories',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'y300-shelf-cat-',
      );
      final path = p.join(directory.path, 'old.db');
      Database? db;
      addTearDown(() async {
        await db?.close();
        await directory.delete(recursive: true);
      });

      db = await AppDatabase.open(databaseName: path);
      // 还原 v44：没有共享分类表，模块分类表只有 default 与自定义分类。
      await db.execute('DROP TABLE ${AppDatabase.libraryShelfCategoriesTable}');
      await db.delete(
        AppDatabase.categoriesTable,
        where: 'category_id IN (?, ?)',
        whereArgs: <Object>['comic-default', 'novel-default'],
      );
      await db.delete(
        AppDatabase.novelCategoriesTable,
        where: 'category_id IN (?, ?)',
        whereArgs: <Object>['comic-default', 'novel-default'],
      );
      await db.insert(AppDatabase.categoriesTable, <String, Object?>{
        'category_id': 'default',
        'name': '默认',
        'sort_order': 0,
        'created_at': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert(AppDatabase.novelCategoriesTable, <String, Object?>{
        'category_id': 'default',
        'name': '默认',
        'sort_order': 0,
        'created_at': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert(AppDatabase.comicsTable, <String, Object?>{
        'comic_id': 'comic:1',
        'source_tid': '1',
        'source_fid': '30',
        'title': '漫画',
        'created_at': 1,
        'updated_at': 1,
      });
      await db.insert(AppDatabase.categoriesTable, <String, Object?>{
        'category_id': 'comic-category',
        'name': '漫画追更',
        'sort_order': 1,
        'created_at': 1,
      });
      await db.insert(AppDatabase.shelfItemsTable, <String, Object?>{
        'category_id': 'comic-category',
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
      await db.insert(AppDatabase.novelCategoriesTable, <String, Object?>{
        'category_id': 'novel-category',
        'name': '小说追更',
        'sort_order': 1,
        'created_at': 2,
      });
      await db.insert(AppDatabase.novelShelfItemsTable, <String, Object?>{
        'category_id': 'novel-category',
        'novel_id': 'novel:1',
        'added_at': 1,
        'sort_order': 1,
      });
      await db.execute('PRAGMA user_version = 44');
      await db.close();

      db = await AppDatabase.open(databaseName: path);

      final shared = await db.query(
        AppDatabase.libraryShelfCategoriesTable,
        orderBy: 'sort_order',
      );
      expect(
        shared.map((row) => row['name']),
        <String>['漫画', '小说', '漫画追更', '小说追更'],
      );
      final comicShared = shared.singleWhere((row) => row['name'] == '漫画追更');
      final novelShared = shared.singleWhere((row) => row['name'] == '小说追更');
      final sharedIds = shared.map((row) => row['category_id'] as String);
      expect(sharedIds, isNot(contains('default')));
      expect(
        (await db.query(AppDatabase.categoriesTable))
            .map((row) => row['category_id']),
        containsAll(<String>[
          'comic-default',
          'novel-default',
          comicShared['category_id'] as String,
          novelShared['category_id'] as String,
        ]),
      );
      expect(
        (await db.query(AppDatabase.novelCategoriesTable))
            .map((row) => row['category_id']),
        containsAll(<String>[
          'comic-default',
          'novel-default',
          comicShared['category_id'] as String,
          novelShared['category_id'] as String,
        ]),
      );
      expect(
        (await db.query(AppDatabase.shelfItemsTable)).single['category_id'],
        comicShared['category_id'] as String,
      );
      expect(
        (await db.query(AppDatabase.novelShelfItemsTable))
            .single['category_id'],
        novelShared['category_id'] as String,
      );
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    },
  );

  test('v45 default splits by type and drops duplicate home rows', () async {
    final directory = await Directory.systemTemp.createTemp('y300-shelf-v45-');
    final path = p.join(directory.path, 'old.db');
    Database? db;
    addTearDown(() async {
      await db?.close();
      await directory.delete(recursive: true);
    });

    db = await AppDatabase.open(databaseName: path);
    for (final table in <String>[
      AppDatabase.libraryShelfCategoriesTable,
      AppDatabase.categoriesTable,
      AppDatabase.novelCategoriesTable,
    ]) {
      await db.delete(
        table,
        where: 'category_id IN (?, ?)',
        whereArgs: <Object>['comic-default', 'novel-default'],
      );
      await db.insert(table, <String, Object?>{
        'category_id': 'default',
        'name': '默认',
        'sort_order': 0,
        'created_at': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.insert(table, <String, Object?>{
        'category_id': 'collection',
        'name': '收藏夹',
        'sort_order': 1,
        'created_at': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final id in <String>['comic:1', 'comic:2', 'comic:3']) {
      await db.insert(AppDatabase.comicsTable, <String, Object?>{
        'comic_id': id,
        'source_tid': id,
        'source_fid': '30',
        'title': id,
        'created_at': 1,
        'updated_at': 1,
      });
    }
    for (final id in <String>['novel:1', 'novel:2']) {
      await db.insert(AppDatabase.worksTable, <String, Object?>{
        'work_id': id,
        'content_type': 'novel',
        'source_tid': id,
        'source_fid': '49',
        'title': id,
        'updated_at': 1,
      });
    }
    await db.insert(AppDatabase.shelfItemsTable, <String, Object?>{
      'category_id': 'default',
      'comic_id': 'comic:1',
      'added_at': 2,
      'sort_order': 0,
    });
    await db.insert(AppDatabase.shelfItemsTable, <String, Object?>{
      'category_id': 'collection',
      'comic_id': 'comic:2',
      'added_at': 3,
      'sort_order': 0,
    });
    await db.insert(AppDatabase.shelfItemsTable, <String, Object?>{
      'category_id': 'default',
      'comic_id': 'comic:3',
      'added_at': 4,
      'sort_order': 1,
    });
    await db.insert(AppDatabase.shelfItemsTable, <String, Object?>{
      'category_id': 'collection',
      'comic_id': 'comic:3',
      'added_at': 5,
      'sort_order': 1,
    });
    await db.insert(AppDatabase.novelShelfItemsTable, <String, Object?>{
      'category_id': 'default',
      'novel_id': 'novel:1',
      'added_at': 2,
      'sort_order': 0,
    });
    await db.insert(AppDatabase.novelShelfItemsTable, <String, Object?>{
      'category_id': 'collection',
      'novel_id': 'novel:2',
      'added_at': 3,
      'sort_order': 0,
    });
    await db.execute('PRAGMA user_version = 45');
    await db.close();

    db = await AppDatabase.open(databaseName: path);

    final comics = await db.query(AppDatabase.shelfItemsTable);
    expect(
      comics.map((row) => (row['comic_id'], row['category_id'])),
      unorderedEquals(<(Object?, Object?)>[
        ('comic:1', 'comic-default'),
        ('comic:2', 'collection'),
        ('comic:3', 'collection'),
      ]),
    );
    final novels = await db.query(AppDatabase.novelShelfItemsTable);
    expect(
      novels.map((row) => (row['novel_id'], row['category_id'])),
      unorderedEquals(<(Object?, Object?)>[
        ('novel:1', 'novel-default'),
        ('novel:2', 'collection'),
      ]),
    );

    final shared = await db.query(
      AppDatabase.libraryShelfCategoriesTable,
      orderBy: 'sort_order',
    );
    expect(
      shared.map((row) => row['category_id']),
      <String>['comic-default', 'novel-default', 'collection'],
    );
    expect(
      shared.map((row) => row['sort_order']),
      <int>[0, 1, 2],
    );
    expect(
      shared.map((row) => row['category_id']),
      isNot(contains('default')),
    );
    for (final table in <String>[
      AppDatabase.categoriesTable,
      AppDatabase.novelCategoriesTable,
    ]) {
      final ids = (await db.query(table)).map((row) => row['category_id']);
      expect(ids, containsAll(<String>['comic-default', 'novel-default']));
      expect(ids, isNot(contains('default')));
    }
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
