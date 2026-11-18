part of 'local_comic_repository_test.dart';

void _schemaMigrationCases() {
  test(
    'database v27 upgrades through latest schema without rebuilding',
    () async {
      final legacyDb = await dbFuture;
      await legacyDb.insert(AppDatabase.comicsTable, <String, Object?>{
        'comic_id': 'yamibo:legacy',
        'source_tid': 'legacy',
        'source_fid': '30',
        'title': '迁移前漫画',
        'catalog_url': 'https://bbs.yamibo.com/misc.php?mod=tag&id=1',
        'created_at': 1783900800000,
        'updated_at': 1783900800000,
      });
      await legacyDb.execute(
        'DROP TABLE ${AppDatabase.novelEpisodeSyncStagingTable}',
      );
      await legacyDb.execute('DROP TABLE ${AppDatabase.novelSourceStateTable}');
      await legacyDb.execute(
        'ALTER TABLE ${AppDatabase.comicsTable} '
        'DROP COLUMN custom_catalog_url',
      );
      await legacyDb.setVersion(27);
      await legacyDb.close();

      final upgradedDb = await AppDatabase.open();
      addTearDown(upgradedDb.close);
      final columns = await upgradedDb.rawQuery(
        'PRAGMA table_info(${AppDatabase.comicsTable})',
      );
      final rows = await upgradedDb.query(AppDatabase.comicsTable);

      expect(
        columns.map((column) => column['name']),
        contains('custom_catalog_url'),
      );
      expect(rows.single['comic_id'], 'yamibo:legacy');
      expect(
        rows.single['catalog_url'],
        'https://bbs.yamibo.com/misc.php?mod=tag&id=1',
      );
      expect(rows.single['custom_catalog_url'], isNull);
      final tableNames = (await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      )).map((row) => row['name']).toSet();
      expect(tableNames, contains(AppDatabase.novelSourceStateTable));
      expect(tableNames, contains(AppDatabase.novelEpisodeSyncStagingTable));
    },
  );

  test(
    'database v31 keeps legacy progress when enabling per-episode rows',
    () async {
      final legacyDb = await dbFuture;
      await legacyDb.insert(AppDatabase.comicsTable, <String, Object?>{
        'comic_id': 'yamibo:legacy-progress',
        'source_tid': '300',
        'source_fid': '30',
        'title': '旧进度漫画',
        'created_at': 1783900800000,
        'updated_at': 1783900800000,
      });
      await legacyDb.insert(AppDatabase.episodesTable, <String, Object?>{
        'episode_id': 'yamibo:legacy-progress:301',
        'comic_id': 'yamibo:legacy-progress',
        'episode_title': '第一话',
        'source_tid': '301',
        'source_url': 'thread-301-1-1.html',
        'order_index': 0,
      });
      await legacyDb.execute('DROP TABLE ${AppDatabase.readingProgressTable}');
      await legacyDb.execute('''
      CREATE TABLE ${AppDatabase.readingProgressTable} (
        comic_id TEXT PRIMARY KEY,
        episode_id TEXT NOT NULL,
        image_index INTEGER NOT NULL,
        scroll_offset REAL NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (comic_id) REFERENCES ${AppDatabase.comicsTable}(comic_id) ON DELETE CASCADE
      )
    ''');
      await legacyDb.insert(AppDatabase.readingProgressTable, <String, Object?>{
        'comic_id': 'yamibo:legacy-progress',
        'episode_id': 'yamibo:legacy-progress:301',
        'image_index': 3,
        'scroll_offset': 88.0,
        'updated_at': 1783900800000,
      });
      await legacyDb.setVersion(31);
      await legacyDb.close();

      final upgradedDb = await AppDatabase.open();
      addTearDown(upgradedDb.close);
      final columns = await upgradedDb.rawQuery(
        'PRAGMA table_info(${AppDatabase.readingProgressTable})',
      );
      final primaryKeyColumns =
          columns
              .where((column) => (column['pk'] as int? ?? 0) > 0)
              .toList(growable: false)
            ..sort((a, b) => (a['pk'] as int).compareTo(b['pk'] as int));
      final rows = await upgradedDb.query(AppDatabase.readingProgressTable);

      expect(primaryKeyColumns.map((column) => column['name']), <Object?>[
        'comic_id',
        'episode_id',
      ]);
      expect(rows.single['episode_id'], 'yamibo:legacy-progress:301');
      expect(rows.single['image_index'], 3);
    },
  );

  test(
    'database v32 backfills favorite detail state without data loss',
    () async {
      final legacyDb = await dbFuture;
      await legacyDb.insert(AppDatabase.favoriteThreadsTable, <String, Object?>{
        'tid': 'resolved',
        'title': '已补全收藏',
        'detail_loaded_at': 1783900800000,
        'first_seen_at': 1783900800000,
        'last_seen_at': 1783900800000,
      });
      await legacyDb.insert(AppDatabase.favoriteThreadsTable, <String, Object?>{
        'tid': 'pending',
        'title': '待补全收藏',
        'first_seen_at': 1783900800000,
        'last_seen_at': 1783900800000,
      });
      await legacyDb.execute(
        'DROP INDEX idx_favorite_threads_active_detail_state_order',
      );
      await legacyDb.execute(
        'ALTER TABLE ${AppDatabase.favoriteThreadsTable} '
        'DROP COLUMN detail_state',
      );
      await legacyDb.setVersion(32);
      await legacyDb.close();

      final upgradedDb = await AppDatabase.open();
      addTearDown(upgradedDb.close);
      final columns = await upgradedDb.rawQuery(
        'PRAGMA table_info(${AppDatabase.favoriteThreadsTable})',
      );
      final rows = await upgradedDb.query(
        AppDatabase.favoriteThreadsTable,
        orderBy: 'tid ASC',
      );
      final indexNames = (await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index'",
      )).map((row) => row['name']);

      expect(columns.map((column) => column['name']), contains('detail_state'));
      expect(rows.map((row) => row['tid']), <Object?>['pending', 'resolved']);
      expect(rows[0]['detail_state'], 'pending');
      expect(rows[1]['detail_state'], 'resolved');
      expect(
        indexNames,
        contains('idx_favorite_threads_active_detail_state_order'),
      );
    },
  );
}
