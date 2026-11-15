import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';

void main() {
  group('LibraryCategory', () {
    test('isDefault should be true when categoryId is default', () {
      final category = LibraryCategory(
        categoryId: 'default',
        name: '默认',
        sortOrder: 0,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(category.isDefault, isTrue);
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

  test('source default category is still a default category', () {
    final category = LibraryCategory(
      categoryId: 'comic:default',
      sourceCategoryId: 'default',
      source: LibraryModuleKey.comic,
      name: '默认',
      sortOrder: 0,
      createdAt: DateTime(2026, 1, 1),
    );
    expect(category.isDefault, isTrue);
  });
}
