import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../app_database_tables.dart';
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
  await db.insert(libraryShelfCategoriesTable, <String, Object?>{
    'category_id': 'default',
    'name': '默认',
    'sort_order': 0,
    'created_at': 0,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
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

Future<bool> _tableExists(Database db, String table) async {
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
