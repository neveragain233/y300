import 'package:y300/core/persistence/library_shelf_category_constants.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';

/// 模块标识：用于区分漫画与小说的默认行为差异。
enum LibraryModuleKey { comic, novel, favorite, bookshelf }

/// 混合书架中的作品身份：来源类型 + 原始作品编号。
///
/// 单模块页面继续直接使用原始 workId；只有混合书架用编码后的身份键
/// 区分同编号的漫画与小说，避免选择、页面键和差异比较互相覆盖。
class LibraryWorkId {
  const LibraryWorkId({required this.source, required this.workId});

  final LibraryModuleKey source;
  final String workId;

  String get encoded => '${source.name}:$workId';

  /// 按第一个冒号拆分；原始作品编号本身可以继续包含冒号。
  static LibraryWorkId? tryParse(String value) {
    final index = value.indexOf(':');
    if (index <= 0 || index == value.length - 1) {
      return null;
    }
    final sourceName = value.substring(0, index);
    LibraryModuleKey? source;
    for (final key in LibraryModuleKey.values) {
      if (key.name == sourceName) {
        source = key;
        break;
      }
    }
    if (source == null) {
      return null;
    }
    return LibraryWorkId(source: source, workId: value.substring(index + 1));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryWorkId &&
          other.source == source &&
          other.workId == workId;

  @override
  int get hashCode => Object.hash(source, workId);
}

/// 作品展示方式：网格或列表。
enum LibraryDisplayMode { grid, list }

/// 标签模型。
class LibraryTag {
  const LibraryTag({
    required this.tagId,
    required this.name,
    required this.createdAt,
  });

  final String tagId;
  final String name;
  final DateTime createdAt;
}

/// 通用分类模型。
class LibraryCategory {
  const LibraryCategory({
    required this.categoryId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    this.visibleMatchCount = 0,
    this.source,
    this.isSynthetic = false,
  });

  /// 页面与状态使用的分类键。混合书架中使用带来源的身份键。
  final String categoryId;
  final String name;
  final int sortOrder;
  final DateTime createdAt;

  /// 搜索模式下该分类命中数。
  final int visibleMatchCount;

  /// 混合书架分类的来源模块；单模块分类为 null。
  final LibraryModuleKey? source;

  /// 合成展示分类（当前只有“全部”），不是仓储分类。
  final bool isSynthetic;

  /// 固定编号的系统类型视图；不可改名或删除。
  bool get isSystemCategory =>
      categoryId == comicDefaultCategoryId ||
      categoryId == novelDefaultCategoryId;

  LibraryCategory copyWith({
    String? categoryId,
    String? name,
    int? sortOrder,
    DateTime? createdAt,
    int? visibleMatchCount,
    LibraryModuleKey? source,
    bool? isSynthetic,
  }) {
    return LibraryCategory(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      visibleMatchCount: visibleMatchCount ?? this.visibleMatchCount,
      source: source ?? this.source,
      isSynthetic: isSynthetic ?? this.isSynthetic,
    );
  }
}

/// 统一书架的元数据快照。
///
/// Snapshot 是 Milestone B 的查询边界：适配器/仓储一次性返回 UI 首屏所需
/// 的分类、作品和搜索命中数，避免控制器再按分类或按作品触发多轮查询。
class LibraryShelfSnapshot {
  const LibraryShelfSnapshot({
    required this.categories,
    required this.itemsByCategory,
    required this.visibleMatchCountByCategory,
  });

  final List<LibraryCategory> categories;
  final Map<String, List<LibraryWorkItem>> itemsByCategory;
  final Map<String, int> visibleMatchCountByCategory;
}

/// 统一书架“作品卡片”最小视图模型。
///
/// - [secondaryName]：漫画可放汉化组，小说可放作者。
/// - [unreadCount]：用于网格左上角/列表右侧角标。
class LibraryWorkItem {
  const LibraryWorkItem({
    required this.workId,
    required this.categoryId,
    required this.title,
    this.secondaryName,
    this.coverImageUrl,
    this.customCoverImageUrl,
    this.coverLocalPath,
    this.customCoverLocalPath,
    this.customCoverFocusX,
    this.customCoverFocusY,
    this.coverAsset,
    required this.unreadCount,
    required this.totalChapterCount,
    required this.readChapterCount,
    required this.addedAt,
    this.lastReadAt,
    this.workUpdatedAt,
    this.lastCheckedAt,
    this.lastFetchedAt,
    this.hasTags = false,
    this.hasBookmarks = false,
    this.isDownloaded = false,
    this.source,
  });

  final String workId;
  final String categoryId;

  /// 混合书架作品的来源模块；单模块作品为 null。
  final LibraryModuleKey? source;

  /// 混合书架中区分同编号作品的唯一身份键。
  String get identityKey => source == null
      ? workId
      : LibraryWorkId(source: source!, workId: workId).encoded;
  final String title;
  final String? secondaryName;
  final String? coverImageUrl;
  final String? customCoverImageUrl;
  final String? coverLocalPath;
  final String? customCoverLocalPath;
  final LibraryCoverAssetRef? coverAsset;

  /// 自定义封面焦点（归一化 [-1,1]，映射为 [Alignment]）。
  ///
  /// 仅作用于自定义封面：宽幅图的中部未必是合适区域，焦点选区让用户
  /// 在不裁剪原图的前提下指定 `BoxFit.cover` 的对齐点。为空表示居中。
  final double? customCoverFocusX;
  final double? customCoverFocusY;
  final int unreadCount;
  final int totalChapterCount;
  final int readChapterCount;
  final DateTime addedAt;
  final DateTime? lastReadAt;
  final DateTime? workUpdatedAt;
  final DateTime? lastCheckedAt;
  final DateTime? lastFetchedAt;
  final bool hasTags;
  final bool hasBookmarks;
  final bool isDownloaded;

  bool get hasCoverSource =>
      coverAsset != null ||
      coverLocalPath?.trim().isNotEmpty == true ||
      customCoverLocalPath?.trim().isNotEmpty == true ||
      coverImageUrl?.trim().isNotEmpty == true ||
      customCoverImageUrl?.trim().isNotEmpty == true;

  LibraryWorkItem copyWith({
    String? categoryId,
    String? title,
    String? secondaryName,
    String? coverImageUrl,
    String? customCoverImageUrl,
    String? coverLocalPath,
    String? customCoverLocalPath,
    double? customCoverFocusX,
    double? customCoverFocusY,
    LibraryCoverAssetRef? coverAsset,
    int? unreadCount,
    int? totalChapterCount,
    int? readChapterCount,
    DateTime? addedAt,
    DateTime? lastReadAt,
    DateTime? workUpdatedAt,
    DateTime? lastCheckedAt,
    DateTime? lastFetchedAt,
    bool? hasTags,
    bool? hasBookmarks,
    bool? isDownloaded,
    LibraryModuleKey? source,
    bool clearCoverLocalPath = false,
    bool clearCustomCoverLocalPath = false,
    bool clearCustomCoverFocus = false,
  }) {
    return LibraryWorkItem(
      workId: workId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      secondaryName: secondaryName ?? this.secondaryName,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      customCoverImageUrl: customCoverImageUrl ?? this.customCoverImageUrl,
      coverLocalPath: clearCoverLocalPath
          ? null
          : (coverLocalPath ?? this.coverLocalPath),
      customCoverLocalPath: clearCustomCoverLocalPath
          ? null
          : (customCoverLocalPath ?? this.customCoverLocalPath),
      customCoverFocusX: clearCustomCoverFocus
          ? null
          : (customCoverFocusX ?? this.customCoverFocusX),
      customCoverFocusY: clearCustomCoverFocus
          ? null
          : (customCoverFocusY ?? this.customCoverFocusY),
      coverAsset: coverAsset ?? this.coverAsset,
      unreadCount: unreadCount ?? this.unreadCount,
      totalChapterCount: totalChapterCount ?? this.totalChapterCount,
      readChapterCount: readChapterCount ?? this.readChapterCount,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      workUpdatedAt: workUpdatedAt ?? this.workUpdatedAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      hasTags: hasTags ?? this.hasTags,
      hasBookmarks: hasBookmarks ?? this.hasBookmarks,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      source: source ?? this.source,
    );
  }
}

/// 统一详情页头部信息模型。
class LibraryDetailHeader {
  const LibraryDetailHeader({
    required this.workId,
    required this.title,
    this.coverImageUrl,
    this.customCoverImageUrl,
    this.coverLocalPath,
    this.customCoverLocalPath,
    this.customCoverFocusX,
    this.customCoverFocusY,
    this.coverAsset,
    this.author,
    this.sourceAuthor,
    this.sourceAuthorId,
    this.publisherName,
    this.publisherId,
    this.customAuthor,
    this.translationGroup,
    this.sourceTitle,
    this.customTitle,
    this.sourceTranslationGroup,
    this.customTranslationGroup,
    this.originalWork,
    this.customOriginalWork,
    this.customSearchTitle,
    this.intro,
    this.sourceTid,
    this.sourceTypeId,
    this.sourceTagName,
    required this.inShelf,
  });

  final String workId;
  final String title;
  final String? coverImageUrl;
  final String? customCoverImageUrl;
  final String? coverLocalPath;
  final String? customCoverLocalPath;
  final LibraryCoverAssetRef? coverAsset;

  /// 自定义封面焦点（归一化 [-1,1]，映射为 [Alignment]）。详见 [LibraryWorkItem]。
  final double? customCoverFocusX;
  final double? customCoverFocusY;
  final String? author;
  final String? sourceAuthor;
  final String? sourceAuthorId;
  final String? publisherName;
  final String? publisherId;
  final String? customAuthor;
  final String? translationGroup;
  final String? sourceTitle;
  final String? customTitle;
  final String? sourceTranslationGroup;
  final String? customTranslationGroup;
  final String? originalWork;
  final String? customOriginalWork;
  final String? customSearchTitle;
  final String? intro;
  final String? sourceTid;
  final String? sourceTypeId;
  final String? sourceTagName;
  final bool inShelf;
}

/// 通用章节阅读进度展示模型。
enum LibraryChapterProgressKind { currentPage, lastRead, percentage }

class LibraryChapterProgressInfo {
  const LibraryChapterProgressInfo({
    required this.kind,
    required this.isCurrent,
    this.currentPage,
    this.totalPages,
    this.fraction,
  });

  final LibraryChapterProgressKind kind;
  final bool isCurrent;
  final int? currentPage;
  final int? totalPages;
  final double? fraction;
}

/// 通用章节行模型。
class LibraryChapterItem {
  const LibraryChapterItem({
    required this.episodeId,
    required this.workId,
    required this.title,
    this.sourceTitle,
    required this.orderIndex,
    this.sourceTid,
    this.sourcePid,
    this.publishTimeText,
    this.threadPostDateText,
    this.threadTidText,
    this.isRead = false,
    this.isDownloaded = false,
    this.isBookmarked = false,
    this.progressInfo,
    this.showSourceIdentifier = true,
  });

  final String episodeId;
  final String workId;
  final String title;

  /// 重命名后仍可按来源章节名检索，显示继续使用 title。
  final String? sourceTitle;
  final int orderIndex;
  final String? sourceTid;
  final String? sourcePid;
  final String? publishTimeText;
  final String? threadPostDateText;
  final String? threadTidText;
  final bool isRead;
  final bool isDownloaded;
  final bool isBookmarked;
  final LibraryChapterProgressInfo? progressInfo;

  /// Source identity remains available for routing even when metadata omits it.
  final bool showSourceIdentifier;
}
