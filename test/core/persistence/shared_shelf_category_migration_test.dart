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
      await db.execute('DROP TABLE ${AppDatabase.libraryShelfCategoriesTable}');
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
      expect(shared.map((row) => row['name']), <String>['默认', '漫画追更', '小说追更']);
      final comicShared = shared.singleWhere((row) => row['name'] == '漫画追更');
      final novelShared = shared.singleWhere((row) => row['name'] == '小说追更');
      expect(
        (await db.query(AppDatabase.categoriesTable))
            .map((row) => row['category_id']),
        containsAll(<String>[
          'default',
          comicShared['category_id'] as String,
          novelShared['category_id'] as String,
        ]),
      );
      expect(
        (await db.query(AppDatabase.novelCategoriesTable))
            .map((row) => row['category_id']),
        containsAll(<String>[
          'default',
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
}
