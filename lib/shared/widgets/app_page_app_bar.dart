import 'package:flutter/material.dart';
import 'package:y300/app/theme/app_system_ui.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

/// 根页统一顶栏：沿用页面表面色，标题取更大字号，动作与压入页同一胶囊体系。
///
/// FlClash 同类根页以大标题区分页面层级；滚动内容和底部导航仍由原外壳负责。
class AppRootPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppRootPageAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.toolbarHeight = 64,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = theme.scaffoldBackgroundColor;
    return AppBar(
      toolbarHeight: toolbarHeight,
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: titleWidget == null ? 16 : 8,
      leading: leading,
      automaticallyImplyLeading: false,
      systemOverlayStyle: AppSystemUi.onSurfaces(
        top: surface,
        bottom: theme.navigationBarTheme.backgroundColor ?? surface,
      ),
      title:
          titleWidget ??
          Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: scheme.onSurface,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
      actions: actions.isEmpty ? null : [AppToolbarActions(children: actions)],
      bottom: bottom,
    );
  }
}

/// 压入页统一顶栏：使用页面自身表面色，标题左对齐，动作沿用组合胶囊。
///
/// 不绘制整条强调色底；状态栏图标按实际顶部表面解析。返回键保持圆形触区，
/// 只有可返回时才出现，避免首页或测试宿主出现空操作按钮。
///
/// 搜索态与选择态等自绘标题的顶栏通过 [titleWidget]、[leading] 复用同一外壳，
/// 不再复制第二套背景、状态栏和动作胶囊逻辑。
class AppPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppPageAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.titleSpacing,
    this.actions = const [],
    this.bottom,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final double? titleSpacing;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final surface = theme.scaffoldBackgroundColor;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return AppBar(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: titleSpacing ?? 2,
      automaticallyImplyLeading: false,
      leading: leading ?? (canPop ? const AppToolbarBackButton() : null),
      systemOverlayStyle: AppSystemUi.onSurfaces(
        top: surface,
        bottom: theme.navigationBarTheme.backgroundColor ?? surface,
      ),
      title:
          titleWidget ??
          Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
      actions: actions.isEmpty ? null : [AppToolbarActions(children: actions)],
      bottom: bottom,
    );
  }
}
