import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' as riverpod_misc;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/app/localization/app_server_content_conversion_provider.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/data_source/api_result_data_read_adapter.dart';
import 'package:y300/core/network/api_result.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/forum_image_dimensions.dart';
import 'package:y300/features/cache/domain/models/forum_image_load_spec.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/forum_image_dimension_index.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/blacklist/application/blacklist_display_preferences_controller.dart';
import 'package:y300/features/favorites/data/providers/favorite_directory_providers.dart';
import 'package:y300/features/forum/data/providers/forum_display_repository_providers.dart';
import 'package:y300/features/forum/presentation/forum_display_page.dart';
import 'package:y300/features/forum/presentation/widgets/forum_display_theme.dart';
import 'package:y300/features/forum/presentation/widgets/forum_home_widgets.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/plain_text_batch_conversion_service.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_conversion_mode.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_converter.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_converter_factory.dart';
import 'package:y300/features/search/presentation/forum_search_page.dart';
import 'package:y300/features/tags/data/providers/tag_providers.dart';
import 'package:y300/features/tags/domain/forum_tag_lookup.dart';
import 'package:y300/features/tags/domain/forum_tag_models.dart';
import 'package:y300/features/thread/data/providers/thread_repository_providers.dart';
import 'package:y300/features/thread/presentation/thread_detail_page.dart';
import 'package:y300/shared/widgets/forum_cached_avatar.dart';
import 'package:y300/shared/widgets/forum_default_avatar.dart';
import 'package:y300/shared/widgets/forum_native_surface.dart';

import '../../../support/favorite_command_test_support.dart';

part 'forum_display_page_loading_cases.dart';
part 'forum_display_page_tag_menu_cases.dart';
part 'forum_display_page_rendering_cases.dart';
part 'forum_display_page_pagination_cases.dart';
part 'forum_display_page_chrome_cases.dart';
part 'forum_display_page_navigation_cases.dart';
part 'forum_display_page_filter_cases.dart';
part 'forum_display_page_test_fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ForumDisplayPage', () {
    _loadingCases();
    _tagMenuCases();
    _renderingCases();
    _paginationCases();
    _chromeCases();
    _navigationCases();
    _filterCases();
  });
}
