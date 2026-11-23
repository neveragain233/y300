import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/cache/presentation/widgets/library_cached_image.dart';
import 'package:y300/features/library_shared/data/providers/library_cover_providers.dart';
import 'package:y300/features/library_shared/data/services/library_cover_decode_scheduler.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_module_adapter.dart';
import 'package:y300/features/library_shared/domain/contracts/library_view_preferences_repository.dart';
import 'package:y300/features/library_shared/domain/models/library_view_preferences.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_selection_action_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/services/library_shelf_refresh_bus.dart';
import 'package:y300/features/library_shared/domain/services/recent_reading.dart';
import 'package:y300/features/library_shared/domain/services/shelf_feature_flags.dart';
import 'package:y300/features/library_shared/presentation/images/library_cover_image_provider.dart';
import 'package:y300/features/library_shared/presentation/pages/unified_shelf_page.dart';
import 'package:y300/features/library_shared/presentation/selection/shelf_selection_host_controller.dart';
import 'package:y300/features/library_shared/presentation/services/recent_reading_action.dart';
import 'package:y300/l10n/app_localizations_zh.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/inline_search_app_bar.dart';
import 'package:y300/shared/widgets/library_cover_placeholder.dart';
import 'package:y300/shared/widgets/shelf/shelf_category_capsule_bar.dart';
import 'package:y300/shared/widgets/shelf/shelf_cover_card.dart';
import 'package:y300/shared/widgets/shelf/shelf_cover_image.dart';
import 'package:y300/shared/widgets/shelf/shelf_theme_palette.dart';

import '../../../../test_support/localized_test_app.dart';
import '../../../../test_support/unavailable_library_cover_store.dart';

part 'unified_shelf_page_search_filter_cases.dart';
part 'unified_shelf_page_layout_sort_cases.dart';
part 'unified_shelf_page_cover_status_cases.dart';
part 'unified_shelf_page_theme_cases.dart';
part 'unified_shelf_page_selection_cases.dart';
part 'unified_shelf_page_mixed_recent_cases.dart';
part 'unified_shelf_page_category_cases.dart';
part 'unified_shelf_page_test_fakes.dart';

void main() {
  _searchFilterCases();
  _layoutSortCases();
  _coverStatusCases();
  _themeCases();
  _selectionCases();
  _mixedRecentCases();
  _categoryCases();
}
