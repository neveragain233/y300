import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../test_support/localized_test_app.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/features/library_shared/domain/contracts/detail_module_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/services/library_shelf_refresh_bus.dart';
import 'package:y300/features/library_shared/presentation/pages/unified_detail_page.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/shelf/typographic_library_cover.dart';
import 'package:y300/features/library_shared/presentation/services/library_detail_text_resolver.dart';
import 'package:y300/features/library_shared/presentation/widgets/cover_focal_point_picker.dart';
import 'package:y300/l10n/app_localizations_zh.dart';

part 'unified_detail_page_helpers.dart';
part 'unified_detail_page_header_metadata_cases.dart';
part 'unified_detail_page_cover_appearance_cases.dart';
part 'unified_detail_page_chapter_filters_cases.dart';
part 'unified_detail_page_chapter_gestures_cases.dart';
part 'unified_detail_page_refresh_download_cases.dart';

void main() {
  _headerMetadataCases();
  _coverAppearanceCases();
  _chapterFiltersCases();
  _chapterGesturesCases();
  _refreshDownloadCases();
}
