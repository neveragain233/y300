import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../app_database_tables.dart';
import '../library_shelf_category_constants.dart';
import 'migration_helpers.dart';

/// Phase 1: 统一状态表（未读/下载/书签/标签/显示配置）。
Future<void> createLibraryStateTables(Database db) async {
  await db.execute('''
      CREATE TABLE IF NOT EXISTS $libraryWorkStateTable (
        content_type TEXT NOT NULL,
        work_id TEXT NOT NULL,
        last_read_episode_id TEXT,
        last_read_at INTEGER,
        check_updated_at INTEGER,
        fetched_updated_at INTEGER,
        intro_text TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (content_type, work_id)
      )
    ''');

  await db.execute('''
      CREATE TABLE IF NOT EXISTS $libraryEpisodeStateTable (
        content_type TEXT NOT NULL,
        episode_id TEXT NOT NULL,
        work_id TEXT NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        read_state_version INTEGER NOT NULL DEFAULT 0,
        is_downloaded INTEGER NOT NULL DEFAULT 0,
        is_bookmarked INTEGER NOT NULL DEFAULT 0,
        read_at INTEGER,
        downloaded_at INTEGER,
        PRIMARY KEY (content_type, episode_id)
      )
    ''');

  await db.execute('''
      CREATE TABLE IF NOT EXISTS $libraryTagsTable (
        tag_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

  await db.execute('''
      CREATE TABLE IF NOT EXISTS $libraryWorkTagsTable (
        content_type TEXT NOT NULL,
        work_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        UNIQUE(content_type, work_id, tag_id),
        FOREIGN KEY (tag_id) REFERENCES $libraryTagsTable(tag_id) ON DELETE CASCADE
      )
    ''');

  await db.execute('''
      CREATE TABLE IF NOT EXISTS $libraryDisplaySettingsTable (
        module_key TEXT PRIMARY KEY,
        display_mode TEXT NOT NULL,
        grid_columns INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_library_episode_state_work_read ON $libraryEpisodeStateTable(content_type, work_id, is_read)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_library_episode_state_work_downloaded ON $libraryEpisodeStateTable(content_type, work_id, is_downloaded)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_library_work_tags_work ON $libraryWorkTagsTable(content_type, work_id)',
  );
}

/// Phase 7：针对统一书架/详情的高频筛选与排序路径补充索引。
/// 应用级共享书架分类：漫画和小说共用同一套用户分类。
Future<void> createSharedShelfCategoryTable(Database db) async {
  await db.execute('''
      CREATE TABLE IF NOT EXISTS $libraryShelfCategoriesTable (
        category_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
}

/// 写入两个固定类型视图：漫画、小说。
///
/// 共享表与两张模块分类表保持同编号镜像行；已有行不覆盖，便于升级重复执行。
Future<void> seedSystemShelfCategories(DatabaseExecutor db) async {
  final targets = <String>[
    libraryShelfCategoriesTable,
    if (await _tableExists(db, categoriesTable)) categoriesTable,
    if (await _tableExists(db, novelCategoriesTable)) novelCategoriesTable,
  ];
  for (final table in targets) {
    await db.insert(
      table,
      <String, Object?>{
        'category_id': comicDefaultCategoryId,
        'name': comicDefaultCategoryName,
        'sort_order': 0,
        'created_at': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      table,
      <String, Object?>{
        'category_id': novelDefaultCategoryId,
        'name': novelDefaultCategoryName,
        'sort_order': 1,
        'created_at': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}

Future<void> createLibraryPerformanceIndexes(Database db) async {
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_library_episode_state_work_bookmarked ON '
    '$libraryEpisodeStateTable(content_type, work_id, is_bookmarked)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_work_episodes_type_work_order ON '
    '$workEpisodesTable(content_type, work_id, order_index)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_episodes_comic_order ON '
    '$episodesTable(comic_id, order_index)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_shelf_items_comic ON '
    '$shelfItemsTable(comic_id)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_novel_shelf_items_novel ON '
    '$novelShelfItemsTable(novel_id)',
  );
}

Future<void> createLibraryCoverMigrationTable(Database db) async {
  await db.execute('''
      CREATE TABLE IF NOT EXISTS $libraryCoverMigrationsTable (
        asset_id TEXT NOT NULL,
        revision INTEGER NOT NULL,
        kind TEXT NOT NULL,
        completed_at INTEGER NOT NULL,
        PRIMARY KEY (asset_id, revision)
      )
    ''');
}

Future<void> createLibraryCoverRevisionTriggers(Database db) async {
  final comicColumns = await columnNames(db, comicsTable);
  if (comicColumns.containsAll(const <String>{
    'comic_id',
    'cover_image_url',
    'cover_local_path',
    'cover_revision',
  })) {
    await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_comics_cover_revision_update
        AFTER UPDATE OF cover_image_url ON $comicsTable
        WHEN OLD.cover_image_url IS NOT NEW.cover_image_url
        BEGIN
          UPDATE $comicsTable
          SET cover_revision = CASE
            WHEN NEW.cover_image_url IS NULL AND NEW.cover_local_path IS NULL THEN 0
            ELSE OLD.cover_revision + 1
          END
          WHERE comic_id = NEW.comic_id;
        END
      ''');
    await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_comics_cover_revision_insert
        AFTER INSERT ON $comicsTable
        WHEN NEW.cover_revision = 0
          AND (NEW.cover_image_url IS NOT NULL OR NEW.cover_local_path IS NOT NULL)
        BEGIN
          UPDATE $comicsTable SET cover_revision = 1
          WHERE comic_id = NEW.comic_id;
        END
      ''');
  }

  final workColumns = await columnNames(db, worksTable);
  if (workColumns.containsAll(const <String>{
    'work_id',
    'cover_image_url',
    'cover_local_path',
    'cover_revision',
  })) {
    await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_works_cover_revision_update
        AFTER UPDATE OF cover_image_url ON $worksTable
        WHEN OLD.cover_image_url IS NOT NEW.cover_image_url
        BEGIN
          UPDATE $worksTable
          SET cover_revision = CASE
            WHEN NEW.cover_image_url IS NULL AND NEW.cover_local_path IS NULL THEN 0
            ELSE OLD.cover_revision + 1
          END
          WHERE work_id = NEW.work_id;
        END
      ''');
    await db.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_works_cover_revision_insert
        AFTER INSERT ON $worksTable
        WHEN NEW.cover_revision = 0
          AND (NEW.cover_image_url IS NOT NULL OR NEW.cover_local_path IS NOT NULL)
        BEGIN
          UPDATE $worksTable SET cover_revision = 1
          WHERE work_id = NEW.work_id;
        END
      ''');
  }
}

Future<void> upgradeLibraryFrom38To40(Database db) async {
  await addColumnIfMissing(
    db,
    table: comicsTable,
    column: 'cover_revision',
    definition: 'INTEGER NOT NULL DEFAULT 0',
  );
  await addColumnIfMissing(
    db,
    table: comicsTable,
    column: 'custom_cover_revision',
    definition: 'INTEGER NOT NULL DEFAULT 0',
  );
  await addColumnIfMissing(
    db,
    table: worksTable,
    column: 'cover_revision',
    definition: 'INTEGER NOT NULL DEFAULT 0',
  );
  await addColumnIfMissing(
    db,
    table: worksTable,
    column: 'custom_cover_revision',
    definition: 'INTEGER NOT NULL DEFAULT 0',
  );
  await backfillCoverRevision(
    db,
    table: comicsTable,
    revisionColumn: 'cover_revision',
    sourceColumns: const <String>['cover_image_url', 'cover_local_path'],
  );
  await backfillCoverRevision(
    db,
    table: comicsTable,
    revisionColumn: 'custom_cover_revision',
    sourceColumns: const <String>[
      'custom_cover_image_url',
      'custom_cover_local_path',
    ],
  );
  await backfillCoverRevision(
    db,
    table: worksTable,
    revisionColumn: 'cover_revision',
    sourceColumns: const <String>['cover_image_url', 'cover_local_path'],
  );
  await backfillCoverRevision(
    db,
    table: worksTable,
    revisionColumn: 'custom_cover_revision',
    sourceColumns: const <String>['custom_cover_local_path'],
  );
  await createLibraryCoverMigrationTable(db);
  await createLibraryCoverRevisionTriggers(db);
}

/// v44 -> v45：把漫画、小说各自的用户分类迁移成共享分类。
///
/// 每条旧分类分配新的共享编号，同时写入两张模块分类表作为镜像；再把该
/// 模块的 shelf item 改到新编号并删除旧分类行。这样现有外键、按分类查询和
/// 移动分类逻辑不需要改成第二套映射。
Future<void> upgradeLibraryFrom44To45(Database db) async {
  await createSharedShelfCategoryTable(db);
  // v45 的中间态仍以共享 default 承接两个模块的默认分类；45→46 再按类型拆分。
  await db.insert(libraryShelfCategoriesTable, <String, Object?>{
    'category_id': legacyDefaultCategoryId,
    'name': '默认',
    'sort_order': 0,
    'created_at': 0,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  final hasComicCategories = await _tableExists(db, categoriesTable);
  final hasNovelCategories = await _tableExists(db, novelCategoriesTable);
  if (!hasComicCategories && !hasNovelCategories) {
    return;
  }
  if (hasComicCategories) {
    await _ensureModuleDefaultCategory(db, table: categoriesTable);
  }
  if (hasNovelCategories) {
    await _ensureModuleDefaultCategory(db, table: novelCategoriesTable);
  }

  final legacy = <_LegacyShelfCategory>[];
  for (final (module, table, available) in <(String, String, bool)>[
    ('comic', categoriesTable, hasComicCategories),
    ('novel', novelCategoriesTable, hasNovelCategories),
  ]) {
    if (!available) {
      continue;
    }
    final rows = await db.query(
      table,
      where: 'category_id != ?',
      whereArgs: const <Object>['default'],
    );
    for (final row in rows) {
      legacy.add(
        _LegacyShelfCategory(
          module: module,
          categoryId: row['category_id'] as String,
          name: row['name'] as String,
          createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
        ),
      );
    }
  }
  legacy.sort((a, b) {
    final created = a.createdAt.compareTo(b.createdAt);
    if (created != 0) return created;
    final module = a.module.compareTo(b.module);
    if (module != 0) return module;
    return a.categoryId.compareTo(b.categoryId);
  });

  var sortOrder = 1;
  final usedIds = <String>{'default'};
  for (final entry in legacy) {
    final newId = _newSharedCategoryId(usedIds);
    final values = <String, Object?>{
      'category_id': newId,
      'name': entry.name,
      'sort_order': sortOrder,
      'created_at': entry.createdAt,
    };
    if (hasComicCategories) {
      await db.insert(categoriesTable, values);
    }
    if (hasNovelCategories) {
      await db.insert(novelCategoriesTable, values);
    }
    final shelfTable = entry.module == 'comic'
        ? shelfItemsTable
        : novelShelfItemsTable;
    await db.update(
      shelfTable,
      <String, Object?>{'category_id': newId},
      where: 'category_id = ?',
      whereArgs: <Object>[entry.categoryId],
    );
    final sourceTable = entry.module == 'comic'
        ? categoriesTable
        : novelCategoriesTable;
    await db.delete(
      sourceTable,
      where: 'category_id = ?',
      whereArgs: <Object>[entry.categoryId],
    );
    await db.insert(libraryShelfCategoriesTable, values);
    usedIds.add(newId);
    sortOrder += 1;
  }
}

/// v45 -> v46：把共享 default 拆成漫画／小说两个固定类型视图。
///
/// 作品只保留一条书架行：旧 default 中的作品按类型写入系统编号；同一作品
/// 已归入自定义收藏夹时删除重复的 default 行，保留用户选择。完成后三张分类
/// 表都不再有 default，避免留下不可删除的隐藏分类。
Future<void> upgradeLibraryFrom45To46(Database db) async {
  await seedSystemShelfCategories(db);
  if (await _tableExists(db, shelfItemsTable)) {
    await _repointLegacyDefault(
      db,
      shelfTable: shelfItemsTable,
      workColumn: 'comic_id',
      targetCategoryId: comicDefaultCategoryId,
    );
  }
  if (await _tableExists(db, novelShelfItemsTable)) {
    await _repointLegacyDefault(
      db,
      shelfTable: novelShelfItemsTable,
      workColumn: 'novel_id',
      targetCategoryId: novelDefaultCategoryId,
    );
  }

  // 自定义收藏夹重新从 2 开始编号，两个系统视图固定排在最前。
  final customRows = await db.query(
    libraryShelfCategoriesTable,
    columns: const <String>['category_id'],
    where: 'category_id NOT IN (?, ?, ?)',
    whereArgs: const <Object>[
      comicDefaultCategoryId,
      novelDefaultCategoryId,
      legacyDefaultCategoryId,
    ],
    orderBy: 'sort_order ASC, created_at ASC',
  );
  var sortOrder = 2;
  for (final row in customRows) {
    final categoryId = row['category_id'] as String;
    for (final table in <String>[
      libraryShelfCategoriesTable,
      if (await _tableExists(db, categoriesTable)) categoriesTable,
      if (await _tableExists(db, novelCategoriesTable)) novelCategoriesTable,
    ]) {
      await db.update(
        table,
        <String, Object?>{'sort_order': sortOrder},
        where: 'category_id = ?',
        whereArgs: <Object>[categoryId],
      );
    }
    sortOrder += 1;
  }

  for (final table in <String>[
    libraryShelfCategoriesTable,
    if (await _tableExists(db, categoriesTable)) categoriesTable,
    if (await _tableExists(db, novelCategoriesTable)) novelCategoriesTable,
  ]) {
    await db.delete(
      table,
      where: 'category_id = ?',
      whereArgs: const <Object>[legacyDefaultCategoryId],
    );
  }
}

Future<void> _repointLegacyDefault(
  DatabaseExecutor db, {
  required String shelfTable,
  required String workColumn,
  required String targetCategoryId,
}) async {
  // 已归入自定义收藏夹的作品不保留旧默认行；删除后不会触发 UNIQUE 冲突。
  await db.rawDelete(
    '''
    DELETE FROM $shelfTable
    WHERE category_id = ?
      AND $workColumn IN (
        SELECT $workColumn FROM $shelfTable WHERE category_id != ?
      )
    ''',
    <Object>[legacyDefaultCategoryId, legacyDefaultCategoryId],
  );
  await db.update(
    shelfTable,
    <String, Object?>{'category_id': targetCategoryId},
    where: 'category_id = ?',
    whereArgs: const <Object>[legacyDefaultCategoryId],
  );
}

Future<bool> _tableExists(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    <Object>[table],
  );
  return rows.isNotEmpty;
}

String _newSharedCategoryId(Set<String> usedIds) {
  final now = DateTime.now().microsecondsSinceEpoch;
  for (var attempt = 0; attempt < 1000; attempt++) {
    final candidate = 's${now}_${Random().nextInt(1 << 20)}';
    if (usedIds.add(candidate)) {
      return candidate;
    }
  }
  throw StateError('无法生成共享分类编号');
}

Future<void> _ensureModuleDefaultCategory(
  Database db, {
  required String table,
}) async {
  await db.insert(table, <String, Object?>{
    'category_id': 'default',
    'name': '默认',
    'sort_order': 0,
    'created_at': 0,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

class _LegacyShelfCategory {
  const _LegacyShelfCategory({
    required this.module,
    required this.categoryId,
    required this.name,
    required this.createdAt,
  });

  final String module;
  final String categoryId;
  final String name;
  final int createdAt;
}

Future<void> upgradeLibraryFrom42To43(Database db) async {
  await createLibraryStateTables(db);
  await addColumnIfMissing(
    db,
    table: libraryEpisodeStateTable,
    column: 'read_state_version',
    definition: 'INTEGER NOT NULL DEFAULT 0',
  );
}
