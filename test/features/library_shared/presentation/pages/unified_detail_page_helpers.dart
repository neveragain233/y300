part of 'unified_detail_page_test.dart';

class _FakeDetailAdapter
    implements
        DetailModuleAdapter,
        DetailChapterReadStateAdapter,
        DetailWorkReadingResetAdapter,
        DetailChapterDownloadAdapter {
  _FakeDetailAdapter({
    this.module = LibraryModuleKey.novel,
    this.coverLocalPath,
    this.progressInfo,
    this.isBookmarked = false,
    this.isDownloaded = false,
    this.isRead = false,
    this.failMarkRead = false,
    this.includeSecondChapter = false,
    this.secondIsBookmarked = false,
    this.secondIsDownloaded = false,
    this.secondIsRead = false,
  });

  int markReadCallCount = 0;
  int loadHeaderCallCount = 0;
  int loadChaptersCallCount = 0;
  int refreshWorkCallCount = 0;
  int resetWorkCallCount = 0;
  String? lastBookmarkEpisodeId;
  String? lastResetEpisodeId;
  String? lastDownloadedEpisodeId;
  String? lastDeletedDownloadEpisodeId;
  LibraryFilterSet lastFilters = LibraryFilterSet.defaults;
  LibraryChapterSortOption lastSortOption = LibraryChapterSortOption.defaults;
  DetailRefreshResult refreshResult = DetailRefreshResult.immediate;
  bool failLoadHeaderOnce = false;
  bool failLoadChaptersOnce = false;
  bool failMarkDownload = false;
  bool failDeleteDownload = false;
  final bool failMarkRead;
  final String? coverLocalPath;
  final LibraryModuleKey module;
  final LibraryChapterProgressInfo? progressInfo;
  bool isBookmarked;
  bool isDownloaded;
  bool isRead;
  final bool includeSecondChapter;
  final bool secondIsBookmarked;
  final bool secondIsDownloaded;
  final bool secondIsRead;

  @override
  Future<void> resetChapterReadingState({
    required String workId,
    required String episodeId,
  }) async {
    lastResetEpisodeId = episodeId;
    isRead = false;
  }

  @override
  Future<void> resetWorkReadingState({required String workId}) async {
    resetWorkCallCount++;
    isRead = false;
  }

  @override
  Future<void> deleteChapterDownload({
    required String workId,
    required String episodeId,
  }) async {
    if (failDeleteDownload) {
      throw StateError('delete failed');
    }
    lastDeletedDownloadEpisodeId = episodeId;
    isDownloaded = false;
  }

  @override
  Future<void> downloadAll({required String workId}) async {}

  @override
  Future<void> downloadUnread({required String workId}) async {}

  @override
  Future<ReaderRouteTarget?> getReaderRouteTarget({
    required String workId,
    required bool preferContinue,
  }) async {
    return ReaderRouteTarget(workId: workId, episodeId: 'e1');
  }

  @override
  Future<ThreadRouteTarget?> getThreadRouteTarget({
    required String workId,
  }) async {
    return const ThreadRouteTarget(tid: '100');
  }

  @override
  Future<List<LibraryChapterItem>> loadChapters({
    required String workId,
    required LibraryFilterSet filters,
    required LibraryChapterSortOption sortOption,
  }) async {
    if (failLoadChaptersOnce) {
      failLoadChaptersOnce = false;
      throw StateError('chapters failed');
    }
    loadChaptersCallCount++;
    lastFilters = filters;
    lastSortOption = sortOption;
    final chapters = [
      LibraryChapterItem(
        episodeId: 'e1',
        workId: 'work-1',
        title: '第1章',
        orderIndex: 1,
        sourceTid: '100',
        sourcePid: '5001',
        isBookmarked: isBookmarked,
        isDownloaded: isDownloaded,
        isRead: isRead,
        progressInfo: progressInfo,
      ),
      if (includeSecondChapter ||
          secondIsBookmarked ||
          secondIsDownloaded ||
          secondIsRead)
        LibraryChapterItem(
          episodeId: 'e2',
          workId: 'work-1',
          title: '第2章',
          orderIndex: 2,
          sourceTid: '101',
          sourcePid: '5002',
          isBookmarked: secondIsBookmarked,
          isDownloaded: secondIsDownloaded,
          isRead: secondIsRead,
        ),
    ];
    final filtered = chapters.where((chapter) {
      return _match(filters.downloaded, chapter.isDownloaded) &&
          _match(filters.unread, !chapter.isRead) &&
          _match(filters.bookmarked, chapter.isBookmarked);
    }).toList();
    filtered.sort((a, b) {
      final compared = (a.sourceTid ?? '').compareTo(b.sourceTid ?? '');
      return sortOption.direction == LibrarySortDirection.asc
          ? compared
          : -compared;
    });
    return filtered;
  }

  bool _match(TriStateFilterValue filter, bool actual) {
    return switch (filter) {
      TriStateFilterValue.ignore => true,
      TriStateFilterValue.include => actual,
      TriStateFilterValue.exclude => !actual,
    };
  }

  @override
  Future<LibraryDetailHeader> loadHeader({required String workId}) async {
    loadHeaderCallCount++;
    if (failLoadHeaderOnce) {
      failLoadHeaderOnce = false;
      throw StateError('header failed');
    }
    return LibraryDetailHeader(
      workId: 'work-1',
      title: '测试作品',
      author: '作者A',
      sourceAuthorId: '10001',
      coverLocalPath: coverLocalPath,
      inShelf: true,
      intro: '这是一段简介',
      sourceTypeId: '398',
      sourceTagName: '韩国漫画',
    );
  }

  @override
  Future<void> markChapterBookmarked({
    required String workId,
    required String episodeId,
    required bool isBookmarked,
  }) async {
    lastBookmarkEpisodeId = episodeId;
    this.isBookmarked = isBookmarked;
  }

  @override
  Future<void> markChapterDownloaded({
    required String workId,
    required String episodeId,
    required bool isDownloaded,
  }) async {
    if (failMarkDownload) {
      throw StateError('download failed');
    }
    lastDownloadedEpisodeId = episodeId;
    this.isDownloaded = isDownloaded;
  }

  @override
  Future<void> markChapterRead({
    required String workId,
    required String episodeId,
    required bool isRead,
  }) async {
    markReadCallCount++;
    if (failMarkRead) {
      throw StateError('mark read failed');
    }
    this.isRead = isRead;
  }

  @override
  LibraryModuleKey get moduleKey => module;

  @override
  Future<DetailRefreshResult> refreshWork({required String workId}) async {
    refreshWorkCallCount++;
    return refreshResult;
  }

  @override
  Future<void> updateIntro({
    required String workId,
    required String intro,
  }) async {}

  @override
  Future<void> moveWorkToCategory({
    required String workId,
    required String toCategoryId,
  }) async {}

  @override
  Future<String?> currentCategoryId({required String workId}) async => null;

  @override
  Future<List<LibraryCategory>> loadCategories() async {
    return const [];
  }
}

class _ReadThroughDetailAdapter extends _FakeDetailAdapter
    implements DetailChapterReadThroughAdapter {
  _ReadThroughDetailAdapter() : super(module: LibraryModuleKey.comic);

  final Set<String> readEpisodeIds = <String>{};
  final List<String> markedThroughTargets = <String>[];
  final List<String> restoredEpisodeIds = <String>[];
  bool removeTargetAtCommit = false;

  @override
  Future<List<LibraryChapterItem>> loadChapters({
    required String workId,
    required LibraryFilterSet filters,
    required LibraryChapterSortOption sortOption,
  }) async {
    loadChaptersCallCount++;
    return <LibraryChapterItem>[
      for (final (index, episodeId) in <(int, String)>[
        (0, 'e1'),
        (1, 'e2'),
        (2, 'e3'),
      ])
        LibraryChapterItem(
          episodeId: episodeId,
          workId: 'work-1',
          title: '第${index + 1}章',
          orderIndex: index,
          sourceTid: '${100 + index}',
          sourcePid: '${5001 + index}',
          isRead: readEpisodeIds.contains(episodeId),
        ),
    ];
  }

  @override
  Future<void> markChapterRead({
    required String workId,
    required String episodeId,
    required bool isRead,
  }) async {
    markReadCallCount++;
    if (isRead) {
      readEpisodeIds.add(episodeId);
    } else {
      readEpisodeIds.remove(episodeId);
    }
  }

  @override
  Future<void> resetChapterReadingState({
    required String workId,
    required String episodeId,
  }) async {
    lastResetEpisodeId = episodeId;
    readEpisodeIds.remove(episodeId);
  }

  @override
  Future<ChapterReadThroughOutcome?> markChaptersReadThrough({
    required String workId,
    required String targetEpisodeId,
  }) async {
    markedThroughTargets.add(targetEpisodeId);
    if (removeTargetAtCommit) {
      return null;
    }
    final ordered = <String>['e1', 'e2', 'e3'];
    final targetIndex = ordered.indexOf(targetEpisodeId);
    if (targetIndex < 0) {
      return null;
    }
    final prefix = ordered.take(targetIndex + 1).toList(growable: false);
    final changed = <String>[
      for (final episodeId in prefix)
        if (!readEpisodeIds.contains(episodeId)) episodeId,
    ];
    readEpisodeIds.addAll(prefix);
    return ChapterReadThroughOutcome(
      changedEpisodeIds: changed,
      readAt: DateTime(2026, 7, 1),
    );
  }

  @override
  Future<void> restoreChaptersRead({
    required String workId,
    required List<String> episodeIds,
    required DateTime readAt,
  }) async {
    restoredEpisodeIds.addAll(episodeIds);
    readEpisodeIds.removeAll(episodeIds);
  }
}

final class _QueuedDownloadDetailAdapter extends _FakeDetailAdapter
    implements DetailChapterDownloadActivityAdapter {
  _QueuedDownloadDetailAdapter() : super(module: LibraryModuleKey.comic);

  final ValueNotifier<Set<String>> _activeEpisodeIds =
      ValueNotifier<Set<String>>(<String>{});

  @override
  Listenable get chapterDownloadActivityListenable => _activeEpisodeIds;

  @override
  bool isChapterDownloadActive({
    required String workId,
    required String episodeId,
  }) {
    return _activeEpisodeIds.value.contains(episodeId);
  }

  @override
  Future<void> markChapterDownloaded({
    required String workId,
    required String episodeId,
    required bool isDownloaded,
  }) async {
    lastDownloadedEpisodeId = episodeId;
    _activeEpisodeIds.value = <String>{episodeId};
  }

  void complete(String episodeId) {
    isDownloaded = true;
    _activeEpisodeIds.value = <String>{};
  }

  void dispose() {
    _activeEpisodeIds.dispose();
  }
}

class _EditableDetailAdapter extends _FakeDetailAdapter
    implements DetailMetadataEditor {
  _EditableDetailAdapter({
    this.fields = const <LibraryMetadataField>{
      LibraryMetadataField.title,
      LibraryMetadataField.author,
      LibraryMetadataField.translationGroup,
      LibraryMetadataField.searchTitle,
    },
  });

  final Set<LibraryMetadataField> fields;
  String title = '测试作品';
  String? author = '作者A';
  String? translationGroup = '汉化组A';
  String? originalWork;
  String? lastCustomTitle;
  String? lastCustomAuthor;
  String? lastCustomTranslationGroup;
  String? lastCustomOriginalWork;
  String? lastCustomSearchTitle;
  String intro = '这是一段简介';
  int updateCalls = 0;
  int updateIntroCalls = 0;

  @override
  LibraryModuleKey get moduleKey => LibraryModuleKey.comic;

  @override
  DetailMetadataEditorConfig get metadataEditorConfig =>
      DetailMetadataEditorConfig(fields: fields);

  @override
  Future<LibraryDetailHeader> loadHeader({required String workId}) async {
    return LibraryDetailHeader(
      workId: 'work-1',
      title: title,
      sourceTitle: '来源标题',
      customTitle: lastCustomTitle,
      author: author,
      sourceAuthor: '来源作者',
      customAuthor: lastCustomAuthor,
      translationGroup: translationGroup,
      sourceTranslationGroup: '来源汉化组',
      customTranslationGroup: lastCustomTranslationGroup,
      originalWork: originalWork,
      customOriginalWork: lastCustomOriginalWork,
      customSearchTitle: lastCustomSearchTitle,
      inShelf: true,
      intro: intro,
    );
  }

  @override
  Future<void> updateIntro({
    required String workId,
    required String intro,
  }) async {
    updateIntroCalls += 1;
    this.intro = intro;
  }

  @override
  Future<void> updateCustomMetadata({
    required String workId,
    String? customTitle,
    String? customAuthor,
    String? customTranslationGroup,
    String? customOriginalWork,
    String? customSearchTitle,
  }) async {
    updateCalls += 1;
    lastCustomTitle = customTitle;
    lastCustomAuthor = customAuthor;
    lastCustomTranslationGroup = customTranslationGroup;
    lastCustomOriginalWork = customOriginalWork;
    lastCustomSearchTitle = customSearchTitle;
    title = customTitle ?? '来源标题';
    author = customAuthor ?? '来源作者';
    translationGroup = customTranslationGroup ?? '来源汉化组';
    originalWork = customOriginalWork;
  }
}

class _SourceTagCatalogAdapter extends _FakeDetailAdapter
    implements DetailSourceTagsAdapter, DetailCatalogEditor {
  _SourceTagCatalogAdapter() : super(module: LibraryModuleKey.comic);

  String? lastCatalogUrl;

  @override
  Future<List<DetailSourceTag>> loadSourceTags({required String workId}) async {
    return const <DetailSourceTag>[DetailSourceTag(label: '漫画', tagId: '86')];
  }

  @override
  Future<DetailCatalogConfiguration> loadCatalogConfiguration({
    required String workId,
  }) async {
    return const DetailCatalogConfiguration(
      sourceCatalogUrl: null,
      customCatalogUrl: null,
    );
  }

  @override
  Future<DetailCatalogUpdateOutcome> updateCatalogOverride({
    required String workId,
    String? catalogUrl,
  }) async {
    lastCatalogUrl = catalogUrl;
    return const DetailCatalogUpdateOutcome(
      code: DetailCatalogUpdateOutcomeCode.saved,
    );
  }
}

class _CatalogEditableDetailAdapter extends _FakeDetailAdapter
    implements DetailCatalogEditor {
  String? lastCatalogUrl;

  @override
  LibraryModuleKey get moduleKey => LibraryModuleKey.comic;

  @override
  Future<DetailCatalogConfiguration> loadCatalogConfiguration({
    required String workId,
  }) async {
    return const DetailCatalogConfiguration(
      sourceCatalogUrl: 'https://bbs.yamibo.com/misc.php?mod=tag&id=1',
      customCatalogUrl: null,
    );
  }

  @override
  Future<DetailCatalogUpdateOutcome> updateCatalogOverride({
    required String workId,
    String? catalogUrl,
  }) async {
    lastCatalogUrl = catalogUrl;
    return const DetailCatalogUpdateOutcome(
      code: DetailCatalogUpdateOutcomeCode.saved,
    );
  }
}

/// 隐藏状态由 adapter 自己维护，[loadChapters] 只返回可见章节——与真实
/// 存储层「隐藏在读取边界过滤」的语义一致。
class _ManageableDetailAdapter extends _FakeDetailAdapter
    implements DetailChapterManagementAdapter {
  _ManageableDetailAdapter()
    : super(module: LibraryModuleKey.comic, includeSecondChapter: true);

  final Map<String, bool> _hidden = <String, bool>{'e1': false, 'e2': false};

  @override
  Future<List<LibraryChapterItem>> loadChapters({
    required String workId,
    required LibraryFilterSet filters,
    required LibraryChapterSortOption sortOption,
  }) async {
    final chapters = await super.loadChapters(
      workId: workId,
      filters: filters,
      sortOption: sortOption,
    );
    return chapters
        .where((chapter) => _hidden[chapter.episodeId] != true)
        .toList(growable: false);
  }

  @override
  Future<List<DetailManagedChapter>> loadManagedChapters({
    required String workId,
  }) async {
    return _hidden.entries
        .map(
          (entry) => DetailManagedChapter(
            episodeId: entry.key,
            title: '第1章',
            sourceTid: '100',
            isManual: false,
            isHidden: entry.value,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<DetailManualChapterAddOutcome> addManualChapter({
    required String workId,
    required String input,
  }) async {
    _hidden[input] = false;
    return const DetailManualChapterAddOutcome(
      code: DetailManualChapterAddOutcomeCode.added,
    );
  }

  @override
  Future<DetailChapterRemovalResult> removeManualChapter({
    required String workId,
    required String episodeId,
  }) async => const DetailChapterRemovalResult(removed: false);

  @override
  Future<void> renameChapter({
    required String workId,
    required String episodeId,
    required String? customTitle,
  }) async {}

  @override
  Future<DetailChapterVisibilityUpdateResult> setChapterHidden({
    required String workId,
    required String episodeId,
    required bool isHidden,
  }) async {
    if (!_hidden.containsKey(episodeId)) {
      return const DetailChapterVisibilityUpdateResult(
        code: DetailChapterVisibilityUpdateCode.notFound,
      );
    }
    if (isHidden &&
        _hidden[episodeId] != true &&
        _hidden.values.where((hidden) => !hidden).length <= 1) {
      return const DetailChapterVisibilityUpdateResult(
        code: DetailChapterVisibilityUpdateCode.rejectedLastVisible,
      );
    }
    _hidden[episodeId] = isHidden;
    return const DetailChapterVisibilityUpdateResult(
      code: DetailChapterVisibilityUpdateCode.updated,
    );
  }
}

class _CoverEditableDetailAdapter extends _FakeDetailAdapter
    implements DetailCoverEditor {
  _CoverEditableDetailAdapter({
    this.hasCustomCover = false,
    this.hasSourceCover = false,
  });

  bool hasCustomCover;
  final bool hasSourceCover;
  bool coverHidden = false;
  bool coverRemoved = false;
  String? lastSourcePath;
  double? lastFocusX;
  double? lastFocusY;

  @override
  LibraryModuleKey get moduleKey => LibraryModuleKey.comic;

  @override
  Future<LibraryDetailHeader> loadHeader({required String workId}) async {
    return LibraryDetailHeader(
      workId: 'work-1',
      title: '测试作品',
      sourceTitle: '来源标题',
      coverLocalPath: hasSourceCover && !coverHidden
          ? 'missing-y300-source-cover.png'
          : null,
      customCoverLocalPath: hasCustomCover && !coverHidden
          ? 'missing-y300-custom-cover.png'
          : null,
      inShelf: true,
      intro: '简介',
    );
  }

  @override
  bool canRemoveCover(LibraryDetailHeader header) {
    return header.customCoverLocalPath != null || header.coverLocalPath != null;
  }

  @override
  Future<void> setCustomCoverFromLocalFile({
    required String workId,
    required String sourceLocalPath,
    double? focusX,
    double? focusY,
  }) async {
    lastSourcePath = sourceLocalPath;
    lastFocusX = focusX;
    lastFocusY = focusY;
  }

  @override
  Future<void> updateCustomCoverFocus({
    required String workId,
    required double? focusX,
    required double? focusY,
  }) async {
    lastFocusX = focusX;
    lastFocusY = focusY;
  }

  @override
  Future<void> removeCustomCover({required String workId}) async {
    coverRemoved = true;
    hasCustomCover = false;
    coverHidden = true;
  }
}

class _CoverCandidateDetailAdapter extends _CoverEditableDetailAdapter
    implements DetailCoverCandidateSource {
  @override
  Future<List<DetailCoverCandidate>> loadCoverCandidates({
    required String workId,
  }) async {
    return const <DetailCoverCandidate>[
      DetailCoverCandidate(imageUrl: 'https://img.test/candidate-1.jpg'),
      DetailCoverCandidate(imageUrl: 'https://img.test/candidate-2.jpg'),
    ];
  }
}

LinearGradient _headerGradient(WidgetTester tester) {
  final gradientBox = tester.widget<DecoratedBox>(
    find.byKey(const Key('unified-detail-header-gradient')),
  );
  final decoration = gradientBox.decoration as BoxDecoration;
  return decoration.gradient! as LinearGradient;
}

Widget _scopedApp({
  Key? key,
  Widget? home,
  TransitionBuilder? builder,
  ThemeData? theme,
}) {
  return ProviderScope(
    child: LocalizedTestApp(
      key: key,
      home: home,
      builder: builder,
      theme: theme,
    ),
  );
}
