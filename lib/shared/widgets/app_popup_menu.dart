import 'dart:async';

import 'package:flutter/material.dart';
import 'package:prism_ui/common_button.dart' as prism_button;
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/press_region.dart' as prism_press;
import 'package:prism_ui/theme_data.dart' as prism_theme;
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 应用统一菜单入口：外观、开合运动与来源按钮接续由 prism_ui 锚定菜单提供。
///
/// 调用方沿用同一组参数与 [AppPopupMenuItem]／[PopupMenuDivider] 内容：
/// - 菜单宽度由内容测量，图标与勾选按需出现，不预留空列；
/// - 长菜单在可用高度内滚动，首末项与圆角之间保留内嵌间距；
/// - 开合沿用固定版本的液滴运动，展开期间菜单内容随外壳短暂模糊，
///   静止后文字、图标和状态标记清晰；
/// - 选中项动作只在关闭后执行一次，点外或返回关闭时调用一次 [onCanceled]。
///
/// 菜单路由位于 Navigator 之上的覆盖层，读不到页面里挂的应用界面库主题，
/// 所以这里把当前应用主题映射成 prism 主题随路由一起挂载，外壳与内容同源；
/// 来源控件自身没有表面（顶栏按钮、文字加箭头），液滴从透明接续其快照，
/// 打开首帧不会先画出另一套底色。系统要求减少动态效果时直接开关，
/// 不做液滴、快照接续和内容模糊。
class AppPopupMenuButton<T> extends StatelessWidget {
  const AppPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.icon,
    this.child,
    this.enabled = true,
  }) : assert(child == null || icon == null, '自定义触发控件已经提供内容，不再同时接受 icon');

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final String? tooltip;
  final Widget? icon;

  /// 自定义触发控件，用于文字加箭头这类不是图标的入口；给出时不用 [icon]。
  final Widget? child;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // 与 Material 弹出菜单一致，菜单内容在按钮重建时一并刷新。
    final entries = itemBuilder(context);
    final theme = prism_theme.ThemeData(
      colorScheme: prismColorSchemeOf(Theme.of(context).colorScheme),
    );
    final label = tooltip ?? MaterialLocalizations.of(context).showMenuTooltip;
    final trigger = child;
    return prism.PopupAnchor(
      // 菜单内容随外壳做上游液滴模糊；选中动作随关闭立即执行，不等收回动画。
      runsPickedAfterReturn: false,
      // 顶栏按钮和文字触发控件都没有自己的表面，液滴从透明淡入而不是先铺底色。
      bare: true,
      // 系统减少动态效果时直接开关：不做液滴展开与收回，来源按钮一直可见。
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      theme: theme,
      targetBuilder: (open) => trigger == null
          ? prism_button.IconButton(
              onPressed: enabled ? open : null,
              icon: icon ?? Icon(Icons.adaptive.more),
              tooltip: label,
            )
          : Tooltip(
              message: label,
              child: prism_press.PressRegion(
                onTap: enabled ? open : null,
                overlay: prism_press.PressRegion.pressOverlay,
                shape: const StadiumBorder(),
                child: trigger,
              ),
            ),
      popupBuilder: (context) => _AppPopupMenu<T>(
        entries: entries,
        onSelected: onSelected,
        onCanceled: onCanceled,
      ),
    );
  }
}

/// 应用菜单的一项，参数与原 Material 弹出菜单项一致。
///
/// [icon] 传入图标控件时菜单按行前景色着色显示；[checked] 表达菜单自身状态；
/// [danger] 用于不可逆或限制性操作。三者在旧调用点都可不传。
class AppPopupMenuItem<T> extends PopupMenuItem<T> {
  const AppPopupMenuItem({
    super.key,
    required String label,
    super.value,
    super.onTap,
    super.enabled = true,
    this.icon,
    this.checked,
    this.danger = false,
  }) : label = label,
       super(child: const SizedBox.shrink());

  final String label;

  /// 菜单行前导图标；只在这里描述外观，点击动作仍归 [value]／[onTap]。
  final Widget? icon;

  /// 菜单项自身的选中状态，例如当前排序方式。
  final bool? checked;

  /// 危险动作用危险前景色表达，同时保留禁用态。
  final bool danger;
}

class _AppPopupMenu<T> extends StatefulWidget {
  const _AppPopupMenu({
    required this.entries,
    this.onSelected,
    this.onCanceled,
  });

  final List<PopupMenuEntry<T>> entries;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;

  @override
  State<_AppPopupMenu<T>> createState() => _AppPopupMenuState<T>();
}

class _AppPopupMenuState<T> extends State<_AppPopupMenu<T>> {
  /// 本次弹出是否已经选中某一项；用于区分点选与点外／返回关闭。
  bool _picked = false;

  @override
  void dispose() {
    if (!_picked) {
      final onCanceled = widget.onCanceled;
      if (onCanceled != null) {
        // 关闭发生在浮层卸载期间，回调推迟到当前构建帧之后，
        // 让调用方可以安全更新自己的状态。
        scheduleMicrotask(onCanceled);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 界面库主题随菜单路由挂载（见 [AppPopupMenuButton]），内容直接继承。
    return prism.PopupMenu(items: _items(), onWillSelect: () => _picked = true);
  }

  List<prism.PopupMenuItem> _items() {
    final items = <prism.PopupMenuItem>[];
    var startsSection = false;
    for (final entry in widget.entries) {
      if (entry is PopupMenuDivider) {
        // 分组分隔挂到下一项：菜单库在项前画分隔线，末尾多余分隔直接省略。
        startsSection = items.isNotEmpty;
        continue;
      }
      if (entry is! AppPopupMenuItem<T>) {
        assert(
          false,
          'AppPopupMenuButton 只渲染 AppPopupMenuItem 与 PopupMenuDivider，'
          '收到 ${entry.runtimeType}',
        );
        continue;
      }
      items.add(_item(entry, startsSection: startsSection));
      startsSection = false;
    }
    return items;
  }

  prism.PopupMenuItem _item(
    AppPopupMenuItem<T> item, {
    required bool startsSection,
  }) {
    return prism.PopupMenuItem(
      key: item.key,
      label: item.label,
      leading: item.icon,
      danger: item.danger,
      checked: item.checked,
      section: startsSection ? const prism.PopupMenuSection() : null,
      onPressed: item.enabled ? () => _runPicked(item) : null,
    );
  }

  void _runPicked(AppPopupMenuItem<T> item) {
    item.onTap?.call();
    final value = item.value;
    if (value == null) {
      // 与 Material 弹出菜单一致：无值项关闭菜单按取消处理。
      widget.onCanceled?.call();
      return;
    }
    widget.onSelected?.call(value);
  }
}
