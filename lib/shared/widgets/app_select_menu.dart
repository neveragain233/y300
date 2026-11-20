import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';

/// 展开选项的一项：提交给页面的值与显示文案。
class AppSelectOption<T> {
  const AppSelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// 当前值加箭头的展开选项菜单。
///
/// 与三点菜单共用 [AppPopupMenuButton] 的锚定弹层：从触发控件旁展开、
/// 开合运动与来源快照一致，当前值带勾选，选中提交一次，点外或返回取消。
/// 禁用时只作展示，触发控件不响应；这是页面控制器给出 `enabled` 的唯一入口，
/// 组件自身不读取保存状态。
class AppSelectMenu<T> extends StatelessWidget {
  const AppSelectMenu({
    super.key,
    required this.value,
    required this.options,
    required this.onSelected,
    this.enabled = true,
  });

  final T value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T> onSelected;
  final bool enabled;

  /// 选项行在弹层里的稳定键，供页面测试定位；菜单关闭后随路由释放。
  static Key itemKeyOf(Object? value) => ValueKey<Object?>(value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: .38);
    final option = options.firstWhere((option) => option.value == value);
    return AppPopupMenuButton<T>(
      enabled: enabled,
      itemBuilder: (context) => [
        for (final option in options)
          AppPopupMenuItem<T>(
            key: itemKeyOf(option.value),
            value: option.value,
            label: option.label,
            checked: option.value == value,
          ),
      ],
      onSelected: onSelected,
      // 来源只有文字与箭头，弹层从透明快照接续，与三点菜单同一套开合。
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.label,
              style: theme.textTheme.bodyLarge?.copyWith(color: color),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}
