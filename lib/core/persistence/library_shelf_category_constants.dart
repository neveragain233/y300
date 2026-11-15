/// 书架系统分类的固定编号与规范名称。
///
/// 编号是持久化身份，页面、仓储和迁移都按编号判断，不依赖名称；名称只作为
/// 数据库中的规范数据，界面显示仍由本地化结果覆盖。
const String comicDefaultCategoryId = 'comic-default';
const String novelDefaultCategoryId = 'novel-default';

/// v45 及更早版本共用的默认分类编号，只用于迁移读取与清理。
const String legacyDefaultCategoryId = 'default';

const String comicDefaultCategoryName = '漫画';
const String novelDefaultCategoryName = '小说';
