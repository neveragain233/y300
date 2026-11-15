import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:y300/core/persistence/app_database.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_operation_failure.dart';

/// 漫画和小说共用的书架分类。
///
/// 共享表是唯一事实；两个模块的分类表保留同编号镜像行，现有 shelf item
/// 外键、按分类查询和移动分类事务继续直接工作。
class SharedShelfCategoryStore {
  const SharedShelfCategoryStore(this._dbFuture);

  final Future<Database> _dbFuture;

  Future<List<LibraryCategory>> loadCategories() async {
    final rows = await (await _dbFuture).query(
      AppDatabase.libraryShelfCategoriesTable,
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows
        .map(
          (row) => LibraryCategory(
            categoryId: row['category_id'] as String,
            name: row['name'] as String,
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              (row['created_at'] as num?)?.toInt() ?? 0,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<String> createCategory({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('分类名称不能为空');
    }
    final db = await _dbFuture;
    final now = DateTime.now();
    final categoryId = _newCategoryId();
    await db.transaction((txn) async {
      final count = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM ${AppDatabase.libraryShelfCategoriesTable}',
      );
      final sortOrder = (count.first['count'] as int?) ?? 0;
      final values = <String, Object?>{
        'category_id': categoryId,
        'name': trimmed,
        'sort_order': sortOrder,
        'created_at': now.millisecondsSinceEpoch,
      };
      await txn.insert(AppDatabase.libraryShelfCategoriesTable, values);
      await txn.insert(AppDatabase.categoriesTable, values);
      await txn.insert(AppDatabase.novelCategoriesTable, values);
    });
    return categoryId;
  }

  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('分类名称不能为空');
    }
    if (categoryId == 'default') {
      throw const LibraryOperationException(
        LibraryOperationFailureCode.defaultCategoryImmutable,
      );
    }
    final db = await _dbFuture;
    await db.transaction((txn) async {
      await txn.update(
        AppDatabase.libraryShelfCategoriesTable,
        <String, Object?>{'name': trimmed},
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
      );
      await txn.update(
        AppDatabase.categoriesTable,
        <String, Object?>{'name': trimmed},
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
      );
      await txn.update(
        AppDatabase.novelCategoriesTable,
        <String, Object?>{'name': trimmed},
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
      );
    });
  }

  Future<void> deleteCategory({required String categoryId}) async {
    if (categoryId == 'default') {
      throw const LibraryOperationException(
        LibraryOperationFailureCode.defaultCategoryImmutable,
      );
    }
    final db = await _dbFuture;
    await db.transaction((txn) async {
      await _moveOrphanedShelfItemsToDefault(
        txn,
        shelfTable: AppDatabase.shelfItemsTable,
        workColumn: 'comic_id',
        categoryId: categoryId,
      );
      await _moveOrphanedShelfItemsToDefault(
        txn,
        shelfTable: AppDatabase.novelShelfItemsTable,
        workColumn: 'novel_id',
        categoryId: categoryId,
      );
      await txn.delete(
        AppDatabase.categoriesTable,
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
      );
      await txn.delete(
        AppDatabase.novelCategoriesTable,
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
      );
      await txn.delete(
        AppDatabase.libraryShelfCategoriesTable,
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
      );
    });
  }

  Future<void> _moveOrphanedShelfItemsToDefault(
    Transaction txn, {
    required String shelfTable,
    required String workColumn,
    required String categoryId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await txn.rawUpdate(
      '''
      UPDATE $shelfTable
      SET category_id = 'default'
      WHERE category_id = ?
        AND $workColumn NOT IN (
          SELECT $workColumn FROM $shelfTable WHERE category_id = 'default'
        )
      ''',
      <Object>[categoryId],
    );
    await txn.rawUpdate(
      '''
      INSERT OR IGNORE INTO $shelfTable (
        category_id, $workColumn, added_at, sort_order
      )
      SELECT 'default', $workColumn, ?, sort_order
      FROM $shelfTable WHERE category_id = ?
      ''',
      <Object>[now, categoryId],
    );
    await txn.delete(
      shelfTable,
      where: 'category_id = ?',
      whereArgs: <Object>[categoryId],
    );
  }

  String _newCategoryId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 's${now}_${Random().nextInt(1 << 20)}';
  }
}
