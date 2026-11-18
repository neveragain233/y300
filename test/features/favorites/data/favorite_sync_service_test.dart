import 'dart:io' as io;

import 'dart:async';

import 'package:content_title_core/content_title_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/data_source/api_result_data_read_adapter.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/core/network/api_result.dart';
import 'package:y300/features/comic/data/services/comic_favorite_auto_refresh_coordinator.dart';
import 'package:y300/features/comic/data/services/comic_favorite_ingest_service.dart';
import 'package:y300/features/comic/domain/repositories/comic_repository.dart';
import 'package:y300/features/comic/domain/models/comic_detail_models.dart';
import 'package:y300/features/comic/domain/models/comic_models.dart';
import 'package:y300/features/comic/domain/services/comic_catalog_miss_policy.dart';
import 'package:y300/features/comic/domain/services/comic_duplicate_merge_service.dart';
import 'package:y300/features/comic/domain/services/comic_first_episode_cover_service.dart';
import 'package:y300/features/comic/domain/services/comic_refresh_outcome_applier.dart';
import 'package:y300/features/comic/domain/services/comic_search_refresh_queue_models.dart';
import 'package:y300/features/comic/domain/services/comic_search_refresh_queue_service.dart';
import 'package:y300/features/comic/domain/services/comic_episode_refresh_service.dart';
import 'package:y300/features/comic/domain/services/comic_thread_discovery_cache.dart';
import 'package:y300/features/favorites/data/services/favorite_content_ingest_registry.dart';
import 'package:y300/features/favorites/data/services/favorite_detail_context_loader.dart';
import 'package:y300/features/favorites/domain/services/favorite_sync_request_governor.dart';
import 'package:y300/features/favorites/domain/services/favorite_parse_service.dart';
import 'package:y300/features/favorites/data/services/favorite_sync_service.dart';
import 'package:y300/features/favorites/data/services/library_post_ingest_task_runner.dart';
import 'package:y300/features/favorites/data/repositories/local_favorite_repository.dart';
import 'package:y300/features/favorites/domain/models/favorite_cache_models.dart';
import 'package:y300/features/favorites/domain/models/favorite_content_ingest.dart';
import 'package:y300/features/favorites/domain/services/library_post_ingest_task_runner.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/services/library_shelf_refresh_bus.dart';
import 'package:y300/features/novel/data/services/novel_favorite_ingest_service.dart';
import 'package:y300/features/storage/domain/download_storage_models.dart';
import 'package:y300/features/storage/domain/download_storage_service.dart';
import 'package:y300/features/tags/domain/forum_tag_lookup.dart';
import 'package:y300/features/tags/domain/forum_tag_models.dart';
import 'package:y300/features/thread/domain/thread_content_classifier.dart';

part 'favorite_sync_service_directory_sync_cases.dart';
part 'favorite_sync_service_detail_ingest_cases.dart';
part 'favorite_sync_service_completion_snapshot_cases.dart';
part 'favorite_sync_service_failure_recovery_cases.dart';
part 'favorite_sync_service_test_fakes.dart';

const _longRunningTagName = '長篇連載';

void main() {
  _directorySyncCases();
  _detailIngestCases();
  _snapshotCompletionCases();
  _failureRecoveryCases();
}
