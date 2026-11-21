import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/domain/contracts/library_view_preferences_repository.dart';
import 'package:y300/features/library_shared/domain/contracts/shelf_module_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_filter_models.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/domain/models/library_view_preferences.dart';
import 'package:y300/features/library_shared/domain/services/library_shelf_refresh_bus.dart';
import 'package:y300/features/library_shared/presentation/pages/unified_shelf_page.dart';
import 'package:y300/l10n/app_localizations_zh.dart';

import '../../../../test_support/localized_test_app.dart';

/// 书架筛选面板试点：分段切换、定高不跳变、摘要预览、确认一次、取消回滚、大字号滚动与遮罩拦截。
void main() {
  Finder segmentFinder(String label) => find.descendant(
    of: find.byKey(const Key('unified-shelf-panel-tabs')),
    matching: find.text(label),
  );

  testWidgets(
    'segmented control switches filter, sort and display with constant height',
    (tester) async {
      final l10n = AppLocalizationsZh();
      await _pumpShelfPhone(tester);
      await _openPanel(tester);

      final panelRoot = find
          .ancestor(
            of: find.byKey(const Key('unified-shelf-panel-tabs')),
            matching: find.byType(SafeArea),
          )
          .first;
      final initialHeight = tester.getSize(panelRoot).height;
      expect(
        find.byKey(const Key('unified-shelf-panel-summary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-filter-unread')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-sort-chapterCount')),
        findsNothing,
      );

      await tester.tap(segmentFinder(l10n.libraryShelfSort));
      await tester.pumpAndSettle();
      expect(tester.getSize(panelRoot).height, initialHeight);
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-sort-chapterCount')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-filter-unread')),
        findsNothing,
      );

      await tester.tap(segmentFinder(l10n.libraryShelfDisplayMode));
      await tester.pumpAndSettle();
      expect(tester.getSize(panelRoot).height, initialHeight);
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-display-grid')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('unified-shelf-grid-columns-slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-sort-chapterCount')),
        findsNothing,
      );
    },
  );

  testWidgets('panel controls keep accessible touch targets', (tester) async {
    await _pumpShelfPhone(tester);
    await _openPanel(tester);

    expect(
      tester.getSize(find.byKey(const Key('unified-shelf-panel-tabs'))).height,
      greaterThanOrEqualTo(44),
    );
    for (final key in const [
      Key('unified-shelf-filter-cancel'),
      Key('unified-shelf-filter-apply'),
    ]) {
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('confirm commits the changed value once and closes the panel', (
    tester,
  ) async {
    final l10n = AppLocalizationsZh();
    final repository = _RecordingPreferencesRepository();
    final adapter = await _pumpShelfPhone(tester, repository: repository);
    final savesBefore = repository.saves.length;
    final queriesBefore = adapter.queryCount;

    await _openPanel(tester);
    await tester.tap(segmentFinder(l10n.libraryShelfDisplayMode));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('unified-shelf-display-list')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unified-shelf-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unified-shelf-list-view')), findsOneWidget);
    expect(find.byKey(const Key('unified-shelf-panel-tabs')), findsNothing);
    expect(repository.saves.length - savesBefore, 1);
    expect(repository.saves.last.displayMode, LibraryDisplayMode.list);
    // 只有显示方式变化，不额外触发作品查询。
    expect(adapter.queryCount, queriesBefore);
  });

  testWidgets('cancel discards the draft and keeps the saved values', (
    tester,
  ) async {
    final l10n = AppLocalizationsZh();
    final repository = _RecordingPreferencesRepository();
    await _pumpShelfPhone(tester, repository: repository);
    final savesBefore = repository.saves.length;

    await _openPanel(tester);
    await tester.tap(segmentFinder(l10n.libraryShelfDisplayMode));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('unified-shelf-display-list')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unified-shelf-filter-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unified-shelf-grid-view')), findsOneWidget);
    expect(repository.saves.length, savesBefore);

    // 重新打开时草稿回到已保存值：网格选中，列表未选中。
    await _openPanel(tester);
    await tester.tap(segmentFinder(l10n.libraryShelfDisplayMode));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('unified-shelf-display-grid')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('unified-shelf-display-list')),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
  });

  testWidgets('large text in a short window scrolls while actions stay put', (
    tester,
  ) async {
    final l10n = AppLocalizationsZh();
    await _pumpShelfPhone(tester, textScale: 2, viewSize: const Size(400, 360));
    await _openPanel(tester);
    await tester.tap(segmentFinder(l10n.libraryShelfDisplayMode));
    await tester.pumpAndSettle();

    expect(find.text(l10n.commonApply).hitTestable(), findsOneWidget);
    expect(find.text(l10n.commonCancel).hitTestable(), findsOneWidget);
    final applyBottom = tester
        .getBottomLeft(find.byKey(const Key('unified-shelf-filter-apply')))
        .dy;
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('unified-shelf-panel-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(
      find.byKey(const Key('unified-shelf-panel-scroll')),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unified-shelf-grid-columns-slider')).hitTestable(),
      findsOneWidget,
    );
    expect(
      tester
          .getBottomLeft(find.byKey(const Key('unified-shelf-filter-apply')))
          .dy,
      applyBottom,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('barrier consumes background taps instead of running them', (
    tester,
  ) async {
    await _pumpShelfPhone(tester);
    await _openPanel(tester);

    final searchButton = find.byKey(const Key('unified-shelf-search-button'));
    expect(searchButton, findsOneWidget);
    await tester.tapAt(tester.getCenter(searchButton));
    await tester.pumpAndSettle();

    // 点按由遮罩消费：既不进入搜索态，也关闭了面板。
    expect(find.byKey(const Key('unified-shelf-search-input')), findsNothing);
    expect(find.byKey(const Key('unified-shelf-panel-tabs')), findsNothing);
    expect(searchButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('display and sort rows expose their selected state to readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpShelfPhone(tester);
      await _openPanel(tester);
      final l10n = AppLocalizationsZh();

      await tester.tap(segmentFinder(l10n.libraryShelfDisplayMode));
      await tester.pumpAndSettle();

      // 显示方式：网格当前选中、列表未选中，读屏可分辨。
      expect(_isSelected(tester, l10n.libraryShelfGrid), isTrue);
      expect(_isSelected(tester, l10n.libraryShelfList), isFalse);
      // 网格列数的当前值随所属行朗读，不依赖独立的尾部文本。
      expect(
        tester
            .getSemantics(find.text(l10n.libraryShelfColumnsPerRow))
            .getSemanticsData()
            .value,
        '3',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('unified-shelf-display-list')),
      );
      await tester.pumpAndSettle();
      expect(_isSelected(tester, l10n.libraryShelfGrid), isFalse);
      expect(_isSelected(tester, l10n.libraryShelfList), isTrue);

      // 排序字段同为多选一，默认收藏日期选中。
      await tester.tap(segmentFinder(l10n.libraryShelfSort));
      await tester.pumpAndSettle();
      expect(_isSelected(tester, l10n.libraryShelfSortFavoriteAddedAt), isTrue);
      expect(_isSelected(tester, l10n.libraryShelfSortChapterCount), isFalse);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

bool? _isSelected(WidgetTester tester, String label) {
  final flags = tester
      .getSemantics(find.text(label))
      .getSemanticsData()
      .flagsCollection;
  return switch (flags.isSelected) {
    Tristate.isTrue => true,
    Tristate.isFalse => false,
    Tristate.none => null,
  };
}

Future<_FilterShelfAdapter> _pumpShelfPhone(
  WidgetTester tester, {
  LibraryViewPreferencesRepository? repository,
  double textScale = 1,
  Size viewSize = const Size(400, 800),
}) async {
  tester.view.physicalSize = viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final adapter = _FilterShelfAdapter();
  await tester.pumpWidget(
    LocalizedTestApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: UnifiedShelfPage(
        adapter: adapter,
        viewPreferencesRepository: repository,
        onOpenWork: (_, _) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return adapter;
}

Future<void> _openPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('unified-shelf-filter-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('unified-shelf-panel-tabs')), findsOneWidget);
}

class _RecordingPreferencesRepository
    implements LibraryViewPreferencesRepository {
  final List<LibraryShelfViewPreferences> saves =
      <LibraryShelfViewPreferences>[];

  @override
  Future<LibraryShelfViewPreferences> load({
    required LibraryShelfViewPreferences defaults,
  }) async {
    return defaults;
  }

  @override
  Future<void> save(LibraryShelfViewPreferences preferences) async {
    saves.add(preferences);
  }
}

class _FilterShelfAdapter
    implements
        ShelfModuleAdapter,
        ShelfModuleCapabilitiesAdapter,
        ShelfDownloadStatusAdapter {
  _FilterShelfAdapter();

  final List<LibraryCategory> _categories = <LibraryCategory>[
    LibraryCategory(
      categoryId: 'default',
      name: '默认',
      sortOrder: 0,
      createdAt: DateTime(2026, 1, 1),
    ),
  ];
  final Map<String, List<LibraryWorkItem>> _items =
      <String, List<LibraryWorkItem>>{
        'default': <LibraryWorkItem>[
          LibraryWorkItem(
            workId: '1',
            categoryId: 'default',
            title: 'Comic A',
            unreadCount: 1,
            totalChapterCount: 3,
            readChapterCount: 2,
            addedAt: DateTime(2026, 1, 1),
          ),
        ],
      };

  int queryCount = 0;

  @override
  ShelfModuleCapabilities get capabilities =>
      const ShelfModuleCapabilities.defaults();

  @override
  LibraryModuleKey get moduleKey => LibraryModuleKey.comic;

  @override
  LibraryDisplayMode get defaultDisplayMode => LibraryDisplayMode.grid;

  @override
  String? get initialCategoryId => null;

  @override
  Set<LibraryModuleKey> get refreshModuleKeys => <LibraryModuleKey>{moduleKey};

  @override
  ValueListenable<LibraryShelfRefreshSignal?>? get shelfRefreshSignals => null;

  @override
  ValueListenable<LibraryShelfTaskProgress?>? get taskProgress => null;

  @override
  Future<Object> buildDetailRouteArgument({required String workId}) async {
    return workId;
  }

  @override
  Future<String> createCategory({required String name}) async => 'created';

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<List<LibraryCategory>> loadCategories() async => _categories;

  @override
  Future<List<LibraryWorkItem>> loadCategoryItems({
    required String categoryId,
  }) async {
    return _items[categoryId] ?? const <LibraryWorkItem>[];
  }

  @override
  Future<void> moveWorkToCategory({
    required String workId,
    required String fromCategoryId,
    required String toCategoryId,
  }) async {}

  @override
  Future<String?> pickRandomWorkId({required String categoryId}) async => '1';

  @override
  Future<Map<String, List<LibraryWorkItem>>> queryItems({
    required List<LibraryCategory> categories,
    required LibraryFilterSet filters,
    required LibraryShelfSortOption sortOption,
    required String keyword,
  }) async {
    queryCount += 1;
    return _items;
  }

  @override
  Future<void> refreshShelf() async {}

  @override
  Future<void> renameCategory({
    required String categoryId,
    required String newName,
  }) async {}

  @override
  Future<Map<String, List<LibraryWorkItem>>> searchItemsByKeyword({
    required String keyword,
  }) async {
    return _items;
  }
}
