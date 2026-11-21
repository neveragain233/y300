part of 'unified_shelf_page_test.dart';

void _categoryCases() {
  testWidgets(
    'restored non-first category aligns PageView content with selected capsule',
    (tester) async {
      final prefsRepo = _MemoryCategoryViewPreferencesRepository(
        savedCategoryId: 'other',
      );
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeCategoryShelfAdapter(),
            viewPreferencesRepository: prefsRepo,
            onOpenWork: (context, workId) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('unified-shelf-grid-item-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-grid-item-1')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'tapping across multiple tabs skips intermediate category saves',
    (tester) async {
      final prefsRepo = _MemoryCategoryViewPreferencesRepository();
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: _FakeCategoryShelfAdapter(),
            viewPreferencesRepository: prefsRepo,
            onOpenWork: (context, workId) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      prefsRepo.savedCategoryIds.clear();

      await tester.tap(
        find.byKey(const ValueKey<String>('unified-shelf-category-tab-third')),
      );
      await tester.pumpAndSettle();

      expect(prefsRepo.savedCategoryIds, <String>['third']);
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-grid-item-3')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'eInk mode jumps category pages directly and disables horizontal swipe',
    (tester) async {
      await tester.pumpWidget(
        EInkModeScope(
          enabled: true,
          child: LocalizedTestApp(
            home: UnifiedShelfPage(
              adapter: _FakeCategoryShelfAdapter(),
              onOpenWork: (context, workId) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('unified-shelf-grid-view')).first,
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-grid-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('unified-shelf-grid-item-2')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('unified-shelf-category-tab-third')),
      );
      // Single frame after tap in eInk jumps directly without animated sweep.
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('unified-shelf-grid-item-3')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'long-pressing custom category opens management menu while system category does not',
    (tester) async {
      final l10n = AppLocalizationsZh();
      final adapter = _FakeCategoryShelfAdapter();
      await tester.pumpWidget(
        LocalizedTestApp(
          home: UnifiedShelfPage(
            adapter: adapter,
            onOpenWork: (context, workId) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(
          const ValueKey<String>('unified-shelf-category-tab-comic-default'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryShelfRenameCategoryTitle), findsNothing);

      // Long-press a non-selected custom category and verify target ID matches.
      await tester.longPress(
        find.byKey(const ValueKey<String>('unified-shelf-category-tab-third')),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryShelfRenameCategoryTitle), findsOneWidget);
      expect(find.text(l10n.libraryShelfDeleteCategoryTitle), findsOneWidget);

      await tester.tap(find.text(l10n.libraryShelfDeleteCategoryTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonDelete));
      await tester.pumpAndSettle();

      expect(adapter.deletedCategoryIds, <String>['third']);
    },
  );
}

class _MemoryCategoryViewPreferencesRepository
    implements LibraryViewPreferencesRepository {
  _MemoryCategoryViewPreferencesRepository({this.savedCategoryId});

  final String? savedCategoryId;
  final List<String> savedCategoryIds = <String>[];

  @override
  Future<LibraryShelfViewPreferences> load({
    required LibraryShelfViewPreferences defaults,
  }) async {
    return defaults.copyWith(lastCategoryId: savedCategoryId);
  }

  @override
  Future<void> save(LibraryShelfViewPreferences preferences) async {
    final categoryId = preferences.lastCategoryId;
    if (categoryId != null) {
      savedCategoryIds.add(categoryId);
    }
  }
}

class _FakeCategoryShelfAdapter extends _FakeShelfAdapter {
  _FakeCategoryShelfAdapter()
    : super(
        initialDisplayMode: LibraryDisplayMode.grid,
        categories: <LibraryCategory>[
          LibraryCategory(
            categoryId: 'comic-default',
            name: '系统分类',
            sortOrder: 0,
            createdAt: DateTime(2026, 1, 1),
          ),
          LibraryCategory(
            categoryId: 'other',
            name: '自建二',
            sortOrder: 1,
            createdAt: DateTime(2026, 1, 2),
          ),
          LibraryCategory(
            categoryId: 'third',
            name: '自建三',
            sortOrder: 2,
            createdAt: DateTime(2026, 1, 3),
          ),
        ],
        itemsByCategory: <String, List<LibraryWorkItem>>{
          'comic-default': <LibraryWorkItem>[
            _item(workId: '1', title: 'Comic A'),
          ],
          'other': <LibraryWorkItem>[_item(workId: '2', title: 'Comic B')],
          'third': <LibraryWorkItem>[_item(workId: '3', title: 'Comic C')],
        },
      );

  final List<String> deletedCategoryIds = <String>[];

  @override
  Future<void> deleteCategory({required String categoryId}) async {
    deletedCategoryIds.add(categoryId);
    categories.removeWhere((item) => item.categoryId == categoryId);
  }
}
