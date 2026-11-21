import 'dart:async';

import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart'
    hide ForumHomeRepository, ForumHomeFavoriteForum;
import 'package:y300/features/forum/data/repositories/forum_home_repository.dart';
import 'package:y300/features/cache/domain/models/document_cache_models.dart';

import '../../../support/forum_home_test_support.dart';

import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';
import 'package:y300/shared/widgets/transient_feedback_layout.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:prism_ui/dialog.dart' as prism;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/app/navigation/main_navigation_grouping.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/settings/app_navigation_lens_motion.dart';
import 'package:y300/app/navigation/main_navigation_widgets.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/app/navigation/history_entry_router.dart';
import 'package:y300/app/navigation/main_destination_page.dart';
import 'package:y300/app/navigation/main_navigation_settings_controller.dart';
import 'package:y300/app/navigation/main_navigation_settings_repository.dart';
import 'package:y300/features/messages/data/message_repository_provider.dart';
import 'package:y300/features/messages/presentation/message_center_page.dart';
import 'package:y300/features/messages/presentation/message_feed_providers.dart';
import 'package:y300/features/messages/application/message_attention_controller.dart';
import 'package:y300/features/messages/application/message_attention_providers.dart';
import 'package:y300/features/messages/presentation/widgets/message_attention_icon.dart';

import '../../messages/support/message_test_repository.dart';

import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/network/api_result.dart';
import 'package:y300/core/network/cookie_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';

import '../../../support/forum_auth_test_support.dart';

import 'package:y300/features/comic/data/providers/comic_providers.dart';
import 'package:y300/features/comic/domain/repositories/comic_repository.dart';
import 'package:y300/features/comic/data/providers/comic_refresh_workflow_providers.dart';
import 'package:y300/features/comic/domain/models/comic_detail_models.dart';
import 'package:y300/features/comic/domain/models/comic_models.dart';
import 'package:y300/features/comic/domain/models/comic_shelf_models.dart';
import 'package:y300/features/comic/domain/services/comic_search_refresh_queue_models.dart';
import 'package:y300/features/favorites/data/providers/favorite_providers.dart';
import 'package:y300/features/favorites/data/services/favorite_sync_service.dart';
import 'package:y300/features/favorites/data/repositories/local_favorite_repository.dart';
import 'package:y300/features/favorites/domain/models/favorite_cache_models.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_driver.dart';
import 'package:y300/features/history/data/providers/history_providers.dart';
import 'package:y300/features/history/domain/models/history_models.dart';
import 'package:y300/features/history/domain/repositories/history_repository.dart';
import 'package:y300/features/library_shared/data/providers/library_state_providers.dart';
import 'package:y300/features/library_shared/domain/repositories/library_state_repository.dart';
import 'package:y300/features/library_shared/data/providers/library_task_notification_providers.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_selection_action_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/models/library_state_models.dart';
import 'package:y300/features/library_shared/domain/services/library_task_notification_service.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_controller.dart';
import 'package:y300/features/library_shared/presentation/pages/unified_shelf_page.dart';
import 'package:y300/features/more/presentation/more_page.dart';
import 'package:y300/features/more/presentation/navigation_management_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_providers.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/data/providers/novel_providers.dart';
import 'package:y300/features/novel/data/repositories/novel_repository.dart';
import 'package:y300/features/novel/domain/models/novel_reader_marks.dart';
import 'package:y300/features/startup/presentation/main_shell_page.dart';
import 'package:y300/app/startup/main_shell_startup_providers.dart';
import 'package:y300/features/thread/domain/thread_content_classifier.dart';
import 'package:y300/l10n/app_localizations_zh.dart';
import 'package:y300/features/profile/data/providers/profile_read_providers.dart';
import 'package:y300/features/profile/presentation/profile_blog_page.dart';

import '../../profile/test_support/blog_directory_fixture.dart';

part 'main_shell_page_launch_cases.dart';
part 'main_shell_page_navigation_cases.dart';
part 'main_shell_page_destination_cases.dart';
part 'main_shell_page_routing_cases.dart';
part 'main_shell_page_session_cases.dart';
part 'main_shell_page_selection_cases.dart';
part 'main_shell_page_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(400, 800);
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  _launchCases();
  _navigationCases();
  _destinationCases();
  _routingCases();
  _sessionCases();
  _selectionCases();
}
