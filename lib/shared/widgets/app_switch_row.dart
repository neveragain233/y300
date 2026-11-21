import 'package:flutter/material.dart';
import 'package:prism_ui/switch.dart' as prism;
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 应用统一开关控件：外观、按压与减动效收敛由 prism_ui 绘制，
/// 经 [AppPrismTheme] 跟随当前预设与明暗，并保证 48 逻辑像素最小命中区。
///
/// 供行点击另有跳转语义（例如导航管理）或内联占位场景直接使用；
/// 分组列表与表单开关行优先使用 [AppSwitchRow] 或 [AppSwitchRow.compact]。
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    this.switchKey,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.semanticLabel,
  });

  final Key? switchKey;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  final String? semanticLabel;

  bool get _enabled => !disabled && onChanged != null;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: AppPrismTheme(
          child: prism.Switch(
            key: switchKey,
            value: value,
            onChanged: _enabled ? onChanged : null,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}

/// 分组列表与表单中的统一开关行：开关本身由 [AppSwitch] 绘制。
///
/// 标准档沿用 [AppGroupedRow]（外置分组表面、56 最小高度）；
/// 紧凑档（[AppSwitchRow.compact]）用于面板和密集表单，去掉分组缩进同时
/// 保留整行点击、48 逻辑像素尾部开关触区与合并开关语义。
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({
    super.key,
    this.switchKey,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.leading,
    this.compact = false,
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
  });

  const AppSwitchRow.compact({
    super.key,
    this.switchKey,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.leading,
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
  }) : compact = true;

  final Key? switchKey;
  final String title;
  final String? subtitle;
  final bool value;

  /// 开关切换回调；为 null 时整行呈禁用态。
  final ValueChanged<bool>? onChanged;

  /// 额外禁用，例如保存中；与原值同时决定是否可交互。
  final bool disabled;

  final Widget? leading;

  /// 紧凑模式：去掉分组行水平边距，适用于已有内边距的表单与阅读面板。
  final bool compact;

  /// 仅在 [compact] 为 true 时生效的内边距；默认垂直 4 逻辑像素。
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  bool get _enabled => !disabled && onChanged != null;

  void _toggle() {
    final onChanged = this.onChanged;
    if (!_enabled || onChanged == null) {
      return;
    }
    onChanged(!value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final control = AppSwitch(
      switchKey: switchKey,
      value: value,
      onChanged: onChanged,
      disabled: disabled,
    );
    // 整行合成一个开关节点：标题与说明只读一次，开关状态由同一节点播报；
    // 行与尾部开关仍是各自独立的触区。
    return Semantics(
      container: true,
      // 说明并入同一标签，读屏只报一次行内容与开关状态。
      label: subtitle == null ? title : '$title\n$subtitle',
      toggled: value,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      child: ExcludeSemantics(
        child: compact
            ? _buildCompactRow(context, enabled, control)
            : AppGroupedRow(
                leading: leading,
                title: title,
                subtitle: subtitle,
                enabled: enabled,
                onTap: enabled ? _toggle : null,
                trailing: control,
              ),
      ),
    );
  }

  Widget _buildCompactRow(BuildContext context, bool enabled, Widget control) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final disabledColor = scheme.onSurface.withValues(alpha: 0.38);
    final resolvedTitleStyle = (titleStyle ?? theme.textTheme.bodyLarge)
        ?.copyWith(
          color: enabled
              ? (titleStyle?.color ?? scheme.onSurface)
              : disabledColor,
        );
    final resolvedSubtitleStyle = (subtitleStyle ?? theme.textTheme.bodySmall)
        ?.copyWith(
          color: enabled
              ? (subtitleStyle?.color ?? scheme.onSurfaceVariant)
              : scheme.onSurfaceVariant.withValues(alpha: 0.38),
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              if (leading != null) ...[
                SizedBox(
                  width: 24,
                  child: IconTheme(
                    data: IconThemeData(
                      size: 22,
                      color: enabled ? scheme.onSurface : disabledColor,
                    ),
                    child: Center(widthFactor: 1, child: leading!),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: resolvedTitleStyle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: resolvedSubtitleStyle),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              control,
            ],
          ),
        ),
      ),
    );
  }
}
