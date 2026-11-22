import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/app_capsule_tab_bar.dart';
import 'package:y300/shared/widgets/shelf/shelf_theme_palette.dart';

class ShelfCategoryCapsuleTab {
  const ShelfCategoryCapsuleTab({required this.id, required this.label});

  final String id;
  final String label;
}

/// 书架分类的胶囊过滤器。
///
/// 视觉渲染与溢出羽化由公共 [AppCapsuleTabBar] 提供，这里只注入书架色板并
/// 保持既有的参数与长按分类管理契约。
class ShelfCategoryCapsuleBar extends StatelessWidget {
  const ShelfCategoryCapsuleBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
    required this.indicatorKey,
    required this.tabKeyBuilder,
    this.enabled = true,
    this.longPressMenuBuilder,
    this.onLongPressMenuSelected,
  });

  final List<ShelfCategoryCapsuleTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final Key indicatorKey;
  final Key Function(String id) tabKeyBuilder;
  final bool enabled;
  final List<PopupMenuEntry<String>> Function(
    BuildContext context,
    ShelfCategoryCapsuleTab tab,
  )?
  longPressMenuBuilder;
  final void Function(int index, String value)? onLongPressMenuSelected;

  @override
  Widget build(BuildContext context) {
    final palette = const ShelfThemePaletteResolver().resolve(
      Theme.of(context),
    );
    final tabMap = <String, ShelfCategoryCapsuleTab>{
      for (final tab in tabs) tab.id: tab,
    };
    return AppCapsuleTabBar(
      tabs: [
        for (final tab in tabs) AppCapsuleTabItem(id: tab.id, label: tab.label),
      ],
      selectedIndex: selectedIndex,
      onTap: onTap,
      indicatorKey: indicatorKey,
      tabKeyBuilder: tabKeyBuilder,
      enabled: enabled,
      selectedBackgroundColor: palette.categorySelectedBackground,
      selectedForegroundColor: palette.categorySelectedForeground,
      longPressMenuBuilder: longPressMenuBuilder == null
          ? null
          : (context, item) {
              final tab = tabMap[item.id];
              if (tab == null) {
                return const <PopupMenuEntry<String>>[];
              }
              return longPressMenuBuilder!(context, tab);
            },
      onLongPressMenuSelected: onLongPressMenuSelected,
    );
  }
}
