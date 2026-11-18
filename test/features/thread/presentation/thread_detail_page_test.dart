import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/material.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:flutter/rendering.dart'
    show RenderAspectRatio, RenderParagraph, ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' as riverpod_misc;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/app/localization/app_server_content_conversion_provider.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/features/auth/application/auth_session_controller.dart';
import 'package:y300/features/profile/data/providers/profile_read_providers.dart';
import 'package:y300/features/profile/presentation/user_profile_page.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/blacklist/application/blacklist_display_preferences_controller.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';

import '../../profile/test_support/profile_repository_fixture.dart';

import 'package:y300/core/data_source/api_result_data_read_adapter.dart';
import 'package:y300/core/media/device_memory_profile.dart';
import 'package:y300/core/network/api_result.dart';
import 'package:y300/core/network/cookie_store.dart';
import 'package:y300/core/network/webview_cookie_sync_service.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/forum_image_load_spec.dart';
import 'package:y300/features/cache/domain/models/forum_image_dimensions.dart';
import 'package:y300/features/cache/domain/services/forum_image_dimension_index.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart'
    hide ThreadPostRatingsRepository;
import 'package:yamibo_forum_client/yamibo_forum_client.dart' as forum_client;
import 'package:y300/core/network/yamibo_forum_client_provider.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/features/cache/domain/services/forum_image_precache_service.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/cache/domain/services/native_page_cache_invalidation_service.dart';
import 'package:y300/features/favorites/data/providers/favorite_directory_providers.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_driver.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_page.dart';
import 'package:y300/features/history/data/providers/history_providers.dart';
import 'package:y300/features/history/domain/models/history_models.dart';
import 'package:y300/features/history/domain/services/history_diagnostic_recorder.dart';
import 'package:y300/features/history/domain/services/history_visit_recorder.dart';
import 'package:y300/features/composer_shared/domain/repositories/composer_draft_repository.dart';
import 'package:y300/features/composer_shared/data/services/composer_image_picker.dart';
import 'package:y300/features/composer_shared/data/providers/composer_providers.dart';
import 'package:y300/features/composer_shared/domain/models/composer_attachment_models.dart';
import 'package:y300/features/composer_shared/domain/models/composer_draft_models.dart';
import 'package:y300/features/composer_shared/domain/services/composer_image_upload_coordinator.dart';

import '../../../support/favorite_command_test_support.dart';

import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/data/providers/novel_providers.dart';
import 'package:y300/features/novel/data/repositories/novel_repository.dart';
import 'package:y300/features/novel/domain/models/novel_reader_marks.dart';
import 'package:y300/features/reader_shared/domain/continuous_image/continuous_image.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_converter.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_converter_factory.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_conversion_mode.dart';
import 'package:y300/features/reply/data/providers/reply_providers.dart';
import 'package:y300/features/tags/data/repositories/forum_tag_repository.dart';
import 'package:y300/features/tags/data/providers/tag_providers.dart';
import 'package:y300/features/tags/domain/forum_tag_lookup.dart';
import 'package:y300/features/tags/domain/forum_tag_models.dart';
import 'package:y300/features/thread/data/providers/thread_favorite_providers.dart';
import 'package:y300/features/thread/data/providers/thread_interaction_providers.dart';
import 'package:y300/features/thread/data/services/thread_post_locator.dart';
import 'package:y300/features/thread/data/repositories/thread_post_ratings_repository.dart';
import 'package:y300/features/thread/data/providers/thread_repository_providers.dart';
import 'package:y300/features/thread/domain/models/thread_favorite_models.dart';
import 'package:y300/features/thread/domain/models/thread_image_open_models.dart';
import 'package:y300/features/thread/domain/models/thread_image_reader_exit_result.dart';
import 'package:y300/features/thread/domain/models/thread_post_target.dart';
import 'package:y300/features/thread/domain/services/thread_favorite_action_service.dart';
import 'package:y300/features/thread/presentation/thread_detail_controller.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';
import 'package:y300/features/thread/presentation/html_rendering/thread_post_html_first_body.dart';
import 'package:y300/features/thread/presentation/thread_image_reader_page.dart';
import 'package:y300/features/thread/presentation/thread_detail_page.dart';
import 'package:y300/features/thread/presentation/thread_detail_state.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_theme.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_widgets.dart';
import 'package:y300/features/forum/presentation/widgets/forum_display_theme.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/forum_cached_avatar.dart';
import 'package:y300/shared/widgets/forum_default_avatar.dart';
import 'package:y300/shared/widgets/forum_content_spacing.dart';
import 'package:y300/shared/widgets/forum_pull_to_refresh.dart';
import 'package:y300/shared/widgets/app_status_views.dart';
import 'package:y300/features/thread/domain/contracts/thread_body_reading_observer.dart';

part 'thread_detail_page_helpers.dart';
part 'thread_detail_page_fakes.dart';
part 'thread_detail_page_entry_navigation_cases.dart';
part 'thread_detail_page_paging_cases.dart';
part 'thread_detail_page_history_cases.dart';
part 'thread_detail_page_html_rendering_cases.dart';
part 'thread_detail_page_image_and_layout_cases.dart';
part 'thread_detail_page_page_chrome_cases.dart';
part 'thread_detail_page_body_landing_cases.dart';
part 'thread_detail_page_post_actions_cases.dart';
part 'thread_detail_page_forum_variants_cases.dart';
part 'thread_detail_page_profile_and_social_cases.dart';
part 'thread_detail_page_blacklist_cases.dart';
part 'thread_detail_page_page_keys_cases.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('ThreadDetailPage', () {
    _entryNavigationCases();
    _pagingCases();
    _historyCases();
    _htmlRenderingCases();
    _imageAndLayoutCases();
    _pageChromeCases();
    _bodyLandingCases();
    _postActionsCases();
    _forumVariantsCases();
    _profileAndSocialCases();
    _blacklistCases();
    _pageKeysCases();
  });
}
