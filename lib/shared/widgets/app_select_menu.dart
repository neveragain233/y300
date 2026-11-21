import 'package:flutter/material.dart';
import 'package:prism_ui/press_region.dart' as prism_press;
import 'package:prism_ui/surface.dart' as prism_surface;
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 展开选项的一项：提交给页面的值、显示文案及可选可用态。
class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
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
            enabled: option.enabled,
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

/// 表单中的锚定选择字段，替代原生 `DropdownButtonFormField`。
///
/// 触发区采用与 `AppTextInputVariant.filled` 一致的 16 圆角填充表面、标签与
/// 错误文案；展开层复用 [AppPopupMenuButton] 的锚定菜单与勾选状态，
/// 选中提交一次，点外或返回取消。
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.options,
    required this.onSelected,
    this.value,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.errorText,
    this.enabled = true,
    this.textStyle,
    this.fillColor,
  });

  final T? value;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T>? onSelected;
  final String? label;
  final String? hintText;
  final Widget? prefixIcon;
  final String? errorText;
  final bool enabled;
  final TextStyle? textStyle;
  final Color? fillColor;

  bool get _interactive => enabled && onSelected != null && options.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final interactive = _interactive;
    final selected = value == null
        ? null
        : options.where((option) => option.value == value).firstOrNull;
    final displayText = selected?.label ?? hintText ?? '';
    final disabledColor = scheme.onSurface.withValues(alpha: 0.38);
    final textColor = !interactive
        ? disabledColor
        : selected == null
        ? scheme.onSurfaceVariant
        : (textStyle?.color ?? scheme.onSurface);
    final iconColor = interactive ? scheme.onSurfaceVariant : disabledColor;
    final captionStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final field = AppPopupMenuButton<T>(
      enabled: interactive,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in options)
          AppPopupMenuItem<T>(
            key: AppSelectMenu.itemKeyOf(option.value),
            value: option.value,
            label: option.label,
            checked: selected != null && option.value == selected.value,
            enabled: option.enabled,
          ),
      ],
      targetBuilder: (context, open) => AppPrismTheme(
        child: Builder(
          builder: (prismContext) {
            final surfaceColor =
                fillColor ??
                prism_surface.SurfaceContext(prismContext).raisedSurfaceLevel
                    .colorOf(prismColorSchemeOf(scheme));
            return DecoratedBox(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: errorText != null
                    ? Border.all(color: scheme.error, width: 1.5)
                    : null,
              ),
              child: prism_press.PressRegion(
                onTap: interactive ? open : null,
                overlay: prism_press.PressRegion.pressOverlay,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        if (prefixIcon != null) ...[
                          IconTheme(
                            data: IconThemeData(size: 20, color: iconColor),
                            child: prefixIcon!,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            displayText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: (textStyle ?? theme.textTheme.bodyLarge)
                                ?.copyWith(color: textColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_drop_down, size: 20, color: iconColor),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (label == null && errorText == null) {
      return field;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(label!, style: captionStyle),
          const SizedBox(height: 6),
        ],
        field,
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}
