import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/navigation/main_navigation_settings_controller.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/core/network/api_result.dart';
import 'package:y300/core/network/cookie_store.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/core/network/webview_cookie_sync_service.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';

import '../../../support/forum_auth_test_support.dart';

import 'package:y300/features/auth/application/auth_session_controller.dart';
import 'package:y300/features/auth/presentation/login_webview_page.dart';
import 'package:y300/features/composer_shared/presentation/controllers/composer_unused_image_management_controller.dart';
import 'package:y300/features/composer_shared/presentation/widgets/composer_unused_image_management_page.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_driver.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_route_factory.dart';
import 'package:y300/features/messages/data/message_repository_provider.dart';
import 'package:y300/features/messages/presentation/message_center_page.dart';
import 'package:y300/features/messages/presentation/message_feed_providers.dart';
import 'package:y300/features/messages/presentation/widgets/message_attention_icon.dart';
import 'package:y300/features/more/presentation/about_page.dart';
import 'package:y300/features/more/presentation/settings_page.dart';
import 'package:y300/features/more/presentation/more_page.dart';
import 'package:y300/features/profile/data/providers/daily_sign_in_providers.dart';
import 'package:y300/features/profile/data/providers/friend_read_providers.dart';
import 'package:y300/features/profile/data/providers/profile_read_providers.dart';
import 'package:y300/features/profile/data/providers/thread_read_providers.dart';
import 'package:y300/features/profile/presentation/threads/my_thread_page.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/features/profile/presentation/current_account_summary_controller.dart';
import 'package:y300/features/profile/presentation/friends/my_friends_page.dart';
import 'package:y300/features/profile/presentation/profile_blog_page.dart';
import 'package:y300/features/profile/presentation/user_profile_page.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/features/thread/presentation/html_rendering/forum_html_renderer_prototype_page.dart';

import '../../profile/test_support/blog_directory_fixture.dart';
import '../../profile/test_support/friend_read_fixture.dart';
import '../../messages/support/message_test_repository.dart';

part 'more_page_navigation_cases.dart';
part 'more_page_entries_cases.dart';
part 'more_page_auth_cases.dart';
part 'more_page_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  _navigationCases();
  _entriesCases();
  _authCases();
}
