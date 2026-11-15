import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:y300/core/persistence/app_database.dart';
import 'package:y300/features/comic/data/local/comic_reading_progress_store.dart';
import 'package:y300/features/novel/data/repositories/sqflite_novel_reading_state_repository.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ComicReadingProgressStore comicProgress;
  late SqfliteNovelReadingStateRepository novelProgress;

  setUp(() async {
    db = await AppDatabase.open(databaseName: inMemoryDatabasePath);
    comicProgress = ComicReadingProgressStore(Future<Database>.value(db));
    novelProgress = SqfliteNovelReadingStateRepository(
      Future<Database>.value(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'comic query returns the newest visible chapter of an existing work',
    () async {
      for (final comicId in <String>['comic:1', 'comic:2']) {
        await db.insert(AppDatabase.comicsTable, <String, Object?>{
          'comic_id': comicId,
          'source_tid': comicId,
          'source_fid': '30',
          'title': comicId,
          'created_at': 1,
          'updated_at': 1,
        });
        await db.insert(AppDatabase.episodesTable, <String, Object?>{
          'episode_id': '$comicId:e1',
          'comic_id': comicId,
          'episode_title': 'e1',
          'source_tid': '1',
          'source_url': 'thread-1-1-1.html',
          'order_index': 0,
        });
      }
      await db.insert(AppDatabase.readingProgressTable, <String, Object?>{
        'comic_id': 'comic:1',
        'episode_id': 'comic:1:e1',
        'image_index': 2,
        'scroll_offset': 12.0,
        'updated_at': DateTime(2026, 5, 1).millisecondsSinceEpoch,
      });
      await db.insert(AppDatabase.readingProgressTable, <String, Object?>{
        'comic_id': 'comic:2',
        'episode_id': 'comic:2:e1',
        'image_index': 0,
        'scroll_offset': 0.0,
        'updated_at': DateTime(2026, 6, 1).millisecondsSinceEpoch,
      });
      await db.insert(AppDatabase.comicsTable, <String, Object?>{
        'comic_id': 'comic:hidden',
        'source_tid': 'comic:hidden',
        'source_fid': '30',
        'title': 'comic:hidden',
        'created_at': 1,
        'updated_at': 1,
      });
      await db.insert(AppDatabase.episodesTable, <String, Object?>{
        'episode_id': 'comic:hidden:e1',
        'comic_id': 'comic:hidden',
        'episode_title': 'e1',
        'source_tid': '2',
        'source_url': 'thread-2-1-1.html',
        'order_index': 0,
        'is_hidden': 1,
      });
      await db.insert(AppDatabase.readingProgressTable, <String, Object?>{
        'comic_id': 'comic:hidden',
        'episode_id': 'comic:hidden:e1',
        'image_index': 0,
        'scroll_offset': 0.0,
        'updated_at': DateTime(2026, 7, 1).millisecondsSinceEpoch,
      });

      final outcome = await comicProgress.getMostRecentReadingProgress();

      expect(outcome?.comicId, 'comic:2');
      expect(outcome?.episodeId, 'comic:2:e1');
    },
  );

  test('novel query skips orphaned progress rows', () async {
    await db.insert(AppDatabase.worksTable, <String, Object?>{
      'work_id': 'novel:1',
      'content_type': 'novel',
      'source_tid': '1',
      'source_fid': '49',
      'title': 'novel',
      'updated_at': 1,
    });
    await db.insert(AppDatabase.workEpisodesTable, <String, Object?>{
      'episode_id': 'novel:1:e1',
      'work_id': 'novel:1',
      'content_type': 'novel',
      'source_tid': '1',
      'order_index': 0,
    });
    await db.insert(AppDatabase.novelReadingProgressTable, <String, Object?>{
      'novel_id': 'novel:1',
      'episode_id': 'novel:1:e1',
      'scroll_offset': 10.0,
      'flow_mode': 'vertical',
      'page_index': 0,
      'progress_percent': 0.2,
      'anchor_format_version': 1,
      'anchor_text_identity': 'x',
      'updated_at': DateTime(2026, 5, 1).millisecondsSinceEpoch,
    });
    await db.insert(AppDatabase.novelReadingProgressTable, <String, Object?>{
      'novel_id': 'novel:removed',
      'episode_id': 'novel:removed:e1',
      'scroll_offset': 0.0,
      'flow_mode': 'vertical',
      'page_index': 0,
      'progress_percent': 0.1,
      'anchor_format_version': 1,
      'anchor_text_identity': 'x',
      'updated_at': DateTime(2026, 7, 1).millisecondsSinceEpoch,
    });

    final outcome = await novelProgress.getMostRecentReading();

    expect(outcome?.novelId, 'novel:1');
    expect(outcome?.episodeId, 'novel:1:e1');
  });
}
