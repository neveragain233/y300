import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';

import 'package:flutter/material.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' as riverpod_misc;
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/localization/app_server_content_conversion_provider.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/navigation/forum_link_routes.dart';
import 'package:y300/core/clipboard/clipboard_providers.dart';
import 'package:y300/core/clipboard/clipboard_text_writer.dart';
import 'package:y300/core/network/api_result.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/core/network/yamibo_forum_source.dart';
import 'package:y300/core/network/yamibo/yamibo_session_snapshot.dart';
import 'package:y300/core/network/yamibo/yamibo_session_store.dart';

import '../../../support/forum_auth_test_support.dart';

import 'package:y300/features/auth/application/auth_session_controller.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/document_cache_models.dart';
import 'package:y300/features/cache/domain/models/forum_image_load_spec.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart'
    hide ForumHomeFavoriteForum, ForumHomeRepository;
import 'package:y300/features/cache/domain/services/forum_image_precache_service.dart';
import 'package:y300/features/cache/domain/services/native_page_cache_invalidation_service.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/favorites/data/providers/favorite_directory_providers.dart';
import 'package:y300/features/forum/data/repositories/forum_home_repository.dart';
import 'package:y300/features/forum/data/models/forum_home_chrome_models.dart';
import 'package:y300/features/forum/data/services/forum_home_request_profile_resolver.dart';
import 'package:y300/features/forum/presentation/forum_home_page.dart';
import 'package:y300/features/forum/presentation/forum_display_page.dart';
import 'package:y300/features/forum/presentation/forum_home_controller.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_external_launcher.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_route_factory.dart';
import 'package:y300/features/tags/presentation/yamibo_tag_thread_page.dart';
import 'package:y300/features/forum/presentation/widgets/forum_home_widgets.dart';

import '../../../support/favorite_command_test_support.dart';

import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/plain_text_batch_conversion_service.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_conversion_mode.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_converter.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_converter_factory.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../../support/forum_home_test_support.dart';

part 'forum_home_page_helpers.dart';
part 'forum_home_page_menu_loading_cases.dart';
part 'forum_home_page_carousel_cases.dart';
part 'forum_home_page_sections_cases.dart';
part 'forum_home_page_navigation_cases.dart';
part 'forum_home_page_refresh_auth_cases.dart';

void main() {
  group('ForumHomePage', () {
    _menuLoadingCases();
    _carouselCases();
    _sectionsCases();
    _navigationCases();
    _refreshAuthCases();
  });
}
