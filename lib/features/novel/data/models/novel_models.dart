import 'package:y300/core/persistence/library_shelf_category_constants.dart';

export 'package:y300/features/novel/domain/models/novel_reading_progress.dart';

export 'package:y300/features/novel/domain/models/novel_reader_preferences.dart';

class NovelItem {
  const NovelItem({
    required this.novelId,
    required this.sourceTid,
    required this.sourceFid,
    this.sourceTypeId,
    this.sourceTagName,
    required this.title,
    this.author,
    this.customTitle,
    this.customAuthor,
    this.customTranslationGroup,
    this.customOriginalWork,
    this.coverImageUrl,
    this.coverLocalPath,
    this.customCoverLocalPath,
    this.customCoverFocusX,
    this.customCoverFocusY,
    this.coverRevision = 0,
    this.customCoverRevision = 0,
    this.coverHidden = false,
    required this.updatedAt,
    required this.episodeCount,
    this.categoryId = novelDefaultCategoryId,
  });

  final String novelId;
  final String sourceTid;
  final String sourceFid;
  final String? sourceTypeId;
  final String? sourceTagName;
  final String title;

  /// 来源发布者（发帖人）名称，未自定义译者时默认作为译者展示。
  final String? author;
  final String? customTitle;
  final String? customAuthor;

  /// 自定义译者：null 表示默认跟随发帖人；空字符串 `""` 表示显式隐藏译者。
  final String? customTranslationGroup;
  final String? customOriginalWork;
  final String? coverImageUrl;
  final String? coverLocalPath;
  final String? customCoverLocalPath;
  final double? customCoverFocusX;
  final double? customCoverFocusY;
  final int coverRevision;
  final int customCoverRevision;
  final bool coverHidden;
  final DateTime updatedAt;
  final int episodeCount;
  final String categoryId;

  String get sourceTitle => title;

  String get displayTitle =>
      _preferredText(customTitle, sourceTitle) ?? sourceTitle;

  String? get publisherName => _preferredText(author, null);

  String? get displayAuthor => _preferredText(customAuthor, null);

  String? get displayOriginalWork => _preferredText(customOriginalWork, null);

  String? displayTranslator({String? sourcePublisher}) {
    final custom = customTranslationGroup;
    if (custom != null) {
      final trimmed = custom.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return _preferredText(sourcePublisher, publisherName);
  }
}

String? _preferredText(String? preferred, String? fallback) {
  final normalizedPreferred = preferred?.trim();
  if (normalizedPreferred != null && normalizedPreferred.isNotEmpty) {
    return normalizedPreferred;
  }
  final normalizedFallback = fallback?.trim();
  return normalizedFallback == null || normalizedFallback.isEmpty
      ? null
      : normalizedFallback;
}

class NovelEpisodeItem {
  const NovelEpisodeItem({
    required this.episodeId,
    required this.novelId,
    required this.sourceTid,
    this.sourcePid,
    this.sourcePage,
    required this.episodeTitle,
    required this.orderIndex,
    this.datelineText,
  });

  final String episodeId;
  final String novelId;
  final String sourceTid;
  final String? sourcePid;
  final int? sourcePage;
  final String episodeTitle;
  final int orderIndex;
  final String? datelineText;
}

class NovelChapterContent {
  const NovelChapterContent({
    required this.episodeId,
    required this.rawHtml,
    required this.plainText,
    required this.paragraphs,
  });

  final String episodeId;
  final String rawHtml;
  final String plainText;
  final List<String> paragraphs;
}

class NovelShelfCategory {
  const NovelShelfCategory({
    required this.categoryId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });

  final String categoryId;
  final String name;
  final int sortOrder;
  final DateTime createdAt;

  bool get isDefault => categoryId == novelDefaultCategoryId;
}
