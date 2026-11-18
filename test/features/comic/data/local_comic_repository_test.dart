import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:y300/core/persistence/app_database.dart';
import 'package:y300/features/comic/data/repositories/local_comic_repository.dart';
import 'package:y300/features/comic/data/services/comic_favorite_ingest_service.dart';
import 'package:y300/features/comic/domain/models/comic_models.dart';
import 'package:y300/features/comic/domain/services/comic_post_aggregation_service.dart';
import 'package:y300/features/comic/domain/services/comic_post_parsing_engine.dart';
import 'package:y300/features/comic/domain/services/comic_subject_parser.dart';
import 'package:y300/features/comic/domain/services/html_comic_parser_service.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/library_shared/data/repositories/local_library_state_repository.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';

import '../../../test_support/unavailable_library_cover_store.dart';

import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';

import '../domain/services/deathpair_discovery_fixture.dart';
import '../domain/services/magical_girl_discovery_fixture.dart';

part 'local_comic_repository_schema_migration_cases.dart';
part 'local_comic_repository_shelf_ingest_cases.dart';
part 'local_comic_repository_category_metadata_cases.dart';
part 'local_comic_repository_episode_detail_cases.dart';
part 'local_comic_repository_shelf_snapshot_progress_cases.dart';
part 'local_comic_repository_episode_image_cases.dart';
part 'local_comic_repository_image_cache_cases.dart';
part 'local_comic_repository_duplicate_group_cases.dart';

late LocalComicRepository repository;
late Future<Database> dbFuture;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('LocalComicRepository', () {
    setUp(() async {
      await deleteDatabase(AppDatabase.dbName);
      dbFuture = AppDatabase.open();
      repository = LocalComicRepository(
        dbFuture,
        libraryCoverStore: const UnavailableLibraryCoverStore(),
      );
    });

    _schemaMigrationCases();
    _shelfIngestCases();
    _categoryMetadataCases();
    _episodeDetailCases();
    _shelfSnapshotProgressCases();
    _episodeImageCases();
    _imageCacheCases();
    _duplicateGroupCases();
  });
}
