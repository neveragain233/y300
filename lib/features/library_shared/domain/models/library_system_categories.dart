import 'package:y300/core/persistence/library_shelf_category_constants.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';

/// 系统类型视图与模块默认归属的固定编号规则。
///
/// 编号是唯一的稳定身份；界面名称按当前语言解析，数据库名称不参与判断。
abstract final class LibrarySystemCategories {
  const LibrarySystemCategories._();

  static const String comicId = comicDefaultCategoryId;
  static const String novelId = novelDefaultCategoryId;
  static const Set<String> ids = <String>{comicId, novelId};

  static bool isSystem(String categoryId) => ids.contains(categoryId);

  static LibraryModuleKey? ownerOf(String categoryId) {
    return switch (categoryId) {
      comicId => LibraryModuleKey.comic,
      novelId => LibraryModuleKey.novel,
      _ => null,
    };
  }

  /// 模块未归入自定义收藏夹时的默认存储编号。
  static String? defaultIdFor(LibraryModuleKey module) {
    return switch (module) {
      LibraryModuleKey.comic => comicId,
      LibraryModuleKey.novel => novelId,
      LibraryModuleKey.favorite || LibraryModuleKey.bookshelf => null,
    };
  }

  /// 分类列表按模块投影：保留本模块系统视图与全部自定义收藏夹。
  static List<LibraryCategory> projectForModule(
    Iterable<LibraryCategory> categories, {
    required LibraryModuleKey module,
  }) {
    final ownedSystemId = defaultIdFor(module);
    return <LibraryCategory>[
      for (final category in categories)
        if (!category.isSystemCategory ||
            category.categoryId == ownedSystemId)
          category,
    ];
  }
}
