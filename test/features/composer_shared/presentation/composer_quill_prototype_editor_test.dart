import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../../test_support/localized_test_app.dart';

import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/composer_shared/data/providers/composer_providers.dart';
import 'package:y300/features/composer_shared/domain/models/composer_attachment_models.dart';
import 'package:y300/features/composer_shared/domain/models/composer_insertion_models.dart';
import 'package:y300/features/composer_shared/domain/models/sticker_models.dart';
import 'package:y300/features/composer_shared/domain/services/composer_message_insertion_service.dart';
import 'package:y300/features/composer_shared/presentation/quill/composer_quill_bbcode_codec.dart';
import 'package:y300/features/composer_shared/presentation/quill/composer_quill_embeds.dart';
import 'package:y300/features/composer_shared/presentation/quill/composer_quill_selection_adapter.dart';
import 'package:y300/features/composer_shared/domain/services/composer_sticker_image_cache_loader.dart';
import 'package:y300/features/composer_shared/presentation/bbcode/forum_bbcode_renderer.dart';
import 'package:y300/features/composer_shared/presentation/widgets/composer_attachment_preview.dart';
import 'package:y300/features/composer_shared/presentation/widgets/composer_bbcode_source_editor.dart';
import 'package:y300/features/composer_shared/presentation/widgets/composer_sticker_image.dart';
import 'package:y300/features/composer_shared/presentation/widgets/composer_quill_prototype_editor.dart';
import 'package:y300/features/composer_shared/presentation/widgets/composer_toolbar_action.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:forum_content_renderer/forum_content_renderer.dart';
import 'package:y300/shared/widgets/forum_content_spacing.dart';

part 'composer_quill_prototype_editor_helpers.dart';
part 'composer_quill_prototype_editor_init_collapse_cases.dart';
part 'composer_quill_prototype_editor_collapse_editing_cases.dart';
part 'composer_quill_prototype_editor_collapse_lifecycle_cases.dart';
part 'composer_quill_prototype_editor_formatting_tools_cases.dart';
part 'composer_quill_prototype_editor_links_attachments_cases.dart';
part 'composer_quill_prototype_editor_attach_sticker_cases.dart';

void main() {
  _initCollapseCases();
  _collapseEditingCases();
  _collapseLifecycleCases();
  _formattingToolsCases();
  _linksAttachmentsCases();
  _attachStickerCases();
}
