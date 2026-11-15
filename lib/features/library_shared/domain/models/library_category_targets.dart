/// 分类目标里的“移出收藏夹”占位编号。
///
/// 它不是仓储分类，模块适配器按作品类型映射到 comic-default／novel-default；
/// 类型视图本身不作为写入目标。
abstract final class LibraryCategoryTargets {
  const LibraryCategoryTargets._();

  static const String home = '__shelf_home__';

  static bool isHome(String? categoryId) => categoryId == home;
}
