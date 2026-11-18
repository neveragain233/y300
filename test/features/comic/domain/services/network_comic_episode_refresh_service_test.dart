import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/comic/domain/models/comic_models.dart';
import 'package:y300/features/comic/domain/repositories/comic_catalog_directory_reader.dart';
import 'package:y300/features/comic/domain/services/comic_consecutive_op_post_parser.dart';
import 'package:y300/features/comic/domain/services/comic_episode_discovery_service.dart';
import 'package:y300/features/comic/domain/services/comic_episode_link_merger.dart';
import 'package:y300/features/comic/domain/services/comic_post_parsing_engine.dart';
import 'package:y300/features/comic/domain/services/comic_recursive_thread_request_governor.dart';
import 'package:y300/features/comic/domain/services/comic_reader_feature_flags.dart';
import 'package:y300/features/comic/domain/services/comic_refresh_keyword_resolver.dart';
import 'package:y300/features/comic/domain/services/comic_search_candidate_ranker.dart';
import 'package:y300/features/comic/domain/services/comic_episode_refresh_service.dart';
import 'package:y300/features/comic/data/services/network_comic_episode_refresh_service.dart';
import 'package:y300/features/comic/domain/services/comic_subject_parser.dart';
import 'package:y300/features/comic/domain/services/comic_thread_discovery_cache.dart';
import 'package:y300/features/favorites/domain/services/favorite_sync_request_governor.dart';
import 'package:y300/features/search/data/services/forum_search_coordinator.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';

import '../../../../support/search/search_response_fixtures.dart';
import 'deathpair_discovery_fixture.dart';

part 'network_comic_episode_refresh_service_candidate_cases.dart';
part 'network_comic_episode_refresh_service_filtering_cases.dart';
part 'network_comic_episode_refresh_service_episode_merge_cases.dart';
part 'network_comic_episode_refresh_service_keyword_cases.dart';
part 'network_comic_episode_refresh_service_catalog_cases.dart';
part 'network_comic_episode_refresh_service_test_fakes.dart';

void main() {
  group('NetworkComicEpisodeRefreshService', () {
    _candidateCases();
    _filteringCases();
    _episodeMergeCases();
    _keywordCases();
    _catalogCases();
  });
}
