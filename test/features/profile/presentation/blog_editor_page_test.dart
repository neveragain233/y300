import 'package:y300/features/profile/data/providers/blog_draft_providers.dart';
import 'package:y300/features/profile/domain/models/blog_draft_snapshot.dart';

import '../test_support/blog_draft_fixture.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:prism_ui/switch.dart' as prism;
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/composer_shared/data/providers/composer_providers.dart';
import 'package:y300/features/composer_shared/data/services/composer_image_picker.dart';
import 'package:y300/features/composer_shared/domain/models/composer_attachment_models.dart';
import 'package:y300/features/composer_shared/domain/services/composer_sticker_image_cache_loader.dart';
import 'package:y300/features/forum/domain/models/forum_webview_launch_models.dart';
import 'package:y300/features/forum/presentation/webview/forum_webview_route_factory.dart';
import 'package:y300/features/profile/data/providers/profile_read_providers.dart';
import 'package:y300/features/profile/presentation/blog/blog_quill_html_codec.dart';
import 'package:y300/features/profile/presentation/blog/blog_editor_page.dart';
import 'package:y300/features/profile/presentation/blog/blog_read_providers.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';

import '../../../test_support/localized_test_app.dart';
import '../../../test_support/page_flow_test_support.dart';
import '../test_support/blog_navigation_fixture.dart';
import '../test_support/blog_operation_fixture.dart';

part 'blog_editor_page_save_cases.dart';
part 'blog_editor_page_input_cases.dart';
part 'blog_editor_page_settings_cases.dart';
part 'blog_editor_page_access_cases.dart';
part 'blog_editor_page_layout_cases.dart';
part 'blog_editor_page_test_helpers.dart';

void main() {
  _saveCases();
  _inputCases();
  _settingsCases();
  _accessCases();
  _layoutCases();
}
