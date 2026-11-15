import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

void main() {
  group('LibraryCategory', () {
    test('isSystemCategory follows fixed category ids, not names', () {
      final category = LibraryCategory(
        categoryId: 'comic-default',
        name: '任意名称',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(category.isSystemCategory, isTrue);
      expect(
        LibraryCategory(
          categoryId: 'c1',
          name: '漫画',
          sortOrder: 2,
          createdAt: _epoch,
        ).isSystemCategory,
        isFalse,
      );
    });

    test('copyWith should override visibleMatchCount', () {
      final category = LibraryCategory(
        categoryId: 'c1',
        name: '分类',
        sortOrder: 1,
        createdAt: DateTime(2026, 1, 1),
      );
      final updated = category.copyWith(visibleMatchCount: 6);
      expect(updated.visibleMatchCount, 6);
      expect(updated.categoryId, category.categoryId);
    });
  });

  group('LibraryWorkId', () {
    test('round trips work ids that already contain colons', () {
      const id = LibraryWorkId(
        source: LibraryModuleKey.novel,
        workId: 'novel:49:200',
      );
      expect(id.encoded, 'novel:novel:49:200');
      expect(LibraryWorkId.tryParse(id.encoded), id);
    });

    test('rejects unknown sources and blank ids', () {
      expect(LibraryWorkId.tryParse('unknown:work'), isNull);
      expect(LibraryWorkId.tryParse(':work'), isNull);
      expect(LibraryWorkId.tryParse('comic:'), isNull);
    });

    test('mixed work identity keeps same raw ids apart', () {
      final comic = LibraryWorkItem(
        workId: 'yamibo:1',
        categoryId: 'default',
        title: 'A',
        unreadCount: 0,
        totalChapterCount: 1,
        readChapterCount: 0,
        addedAt: DateTime(2026, 1, 1),
        source: LibraryModuleKey.comic,
      );
      final novel = comic.copyWith(source: LibraryModuleKey.novel);
      expect(comic.identityKey, 'comic:yamibo:1');
      expect(novel.identityKey, 'novel:yamibo:1');
      expect(comic.identityKey, isNot(novel.identityKey));
    });
  });

  test('legacy default id is no longer a system category', () {
    final category = LibraryCategory(
      categoryId: 'default',
      source: LibraryModuleKey.comic,
      name: '默认',
      sortOrder: 0,
      createdAt: DateTime(2026, 1, 1),
    );
    expect(category.isSystemCategory, isFalse);
  });
}
