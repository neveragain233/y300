import 'package:flutter/material.dart';

import '../../../../test_support/localized_test_app.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:y300/features/cache/data/providers/image_cache_providers.dart';
import 'package:y300/features/cache/domain/models/forum_image_cache_requests.dart';
import 'package:y300/features/cache/domain/models/forum_image_load_spec.dart';
import 'package:y300/features/cache/domain/models/image_cache_keys.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/cache/domain/services/image_cache_service.dart';
import 'package:y300/features/cache/domain/services/forum_image_request_resolver.dart';
import 'package:y300/features/cache/presentation/widgets/cached_library_image.dart';
import 'package:y300/features/image_loading/data/app_image_providers.dart';
import 'package:y300/features/reader_shared/domain/rich_text/typography/rich_text_typography.dart';
import 'package:y300/features/content_rendering_shared/content_rendering.dart';

import 'forum_html_test_theme.dart';

part 'forum_html_widget_post_renderer_text_theme_cases.dart';
part 'forum_html_widget_post_renderer_image_pipeline_cases.dart';
part 'forum_html_widget_post_renderer_image_layout_cases.dart';

void main() {
  _textThemeCases();
  _imagePipelineCases();
  _imageLayoutCases();
}

const _darkTestTheme = ForumHtmlThemeContext(
  brightness: ForumHtmlBrightness.dark,
  surface: Color(0xFF141414),
  foreground: Color(0xFFE9E9E9),
  link: Color(0xFF8DB7FF),
  quoteSurface: Color(0xFF242424),
  quoteForeground: Color(0xFFAAA39A),
  codeSurface: Color(0xFF202020),
  codeForeground: Color(0xFFE9E9E9),
);

String _cssHex(Color color) {
  final rgb = color.toARGB32() & 0x00FFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

html_dom.Element _elementFrom(String html) {
  return html_parser
      .parseFragment(html)
      .nodes
      .whereType<html_dom.Element>()
      .first;
}

TextSpan? _findTextSpanContaining(WidgetTester tester, String text) {
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    final span = _findTextSpanContainingIn(richText.text, text);
    if (span != null) {
      return span;
    }
  }
  return null;
}

TextSpan? _findTextSpanContainingIn(InlineSpan span, String text) {
  if (span is! TextSpan) {
    return null;
  }
  final value = span.text;
  if (value != null && value.contains(text)) {
    return span;
  }
  final children = span.children;
  if (children == null) {
    return null;
  }
  for (final child in children) {
    final found = _findTextSpanContainingIn(child, text);
    if (found != null) {
      return found;
    }
  }
  return null;
}

class _RecordingForumImageRequestResolver implements ForumImageRequestResolver {
  final specs = <ForumImageLoadSpec>[];
  final _delegate = const DefaultForumImageRequestResolver();

  @override
  ImageCacheRequest? resolveCacheRequest(ForumImageLoadSpec spec) {
    specs.add(spec);
    return _delegate.resolveCacheRequest(spec);
  }

  @override
  ForumImageRenderPolicy resolveRenderPolicy(ForumImageLoadSpec spec) {
    return _delegate.resolveRenderPolicy(spec);
  }
}

class _RecordingImageCacheService implements ImageCacheService {
  final requests = <ImageCacheRequest>[];
  final cachedResults = <String, CachedImageResult>{};

  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    requests.add(request);
    return CachedImageResult(success: true, cacheKey: request.cacheKey);
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) async =>
      cachedResults[cacheKey];

  @override
  Future<CachedImageResult> copyProtectedLocalFile(
    ImageCacheLocalCopyRequest request,
  ) async {
    return CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      localPath: request.sourcePath,
    );
  }

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async {
    return 0;
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

  @override
  Future<void> pruneToLimit({required int maxBytes}) async {}

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }

  @override
  Future<void> clearUnprotected() async {}
}
