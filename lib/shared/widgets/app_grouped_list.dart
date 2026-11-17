import 'package:flutter/material.dart';

/// FlClash 风格分组列表：外置组标题、圆角分组表面与内缩分隔线。
///
/// 页面只传内容与动作，组表面、行槽位、分隔线和触区在公共组件内统一，
/// 避免各设置页重复组装 Material 表面。
class AppGroupedSection extends StatelessWidget {
  const AppGroupedSection({
    super.key,
    this.title,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cardColor = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainer
        : scheme.surfaceContainerLowest;
    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.6);
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                title!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Material(
              color: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        thickness: 0.6,
                        indent: 54,
                        color: dividerColor,
                      ),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分组内的一行：前导图标槽、标题／说明、可选当前值与箭头。
///
/// 需要开关、拖动手柄或下拉时从 [trailing] 传入原控件，交互仍归调用方。
/// 多选一或“当前值”行用 [selected]／[semanticsValue] 把状态并入行语义，
/// 读屏与视觉勾选保持一致；不传时保持原有无障碍输出。
class AppGroupedRow extends StatelessWidget {
  const AppGroupedRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.showChevron = false,
    this.minHeight = 56,
    this.selected,
    this.semanticsValue,
  }) : assert(
         selected == null || semanticsValue == null,
         '多选一状态行与当前值行分开表达，避免读屏同时朗读选中和取值',
       );

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;
  final double minHeight;

  /// 多选一行是否处于选中状态；null 表示该行不声明选中语义。
  final bool? selected;

  /// 当前值行的语义取值（例如每行列数）；与 [selected] 互斥。
  ///
  /// 传入时尾部控件只作视觉展示，取值由行节点统一朗读。
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final titleColor = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final subtitleColor = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurfaceVariant.withValues(alpha: 0.38);
    final hasTrailing = trailing != null || showChevron;
    // 尾部控件（开关、拖动手柄、下拉）留在行的点击区之外，
    // 避免操作开关时误触进入下级页面。
    Widget content = Row(
      children: [
        if (leading != null) ...[
          SizedBox(
            width: 24,
            child: IconTheme(
              data: IconThemeData(
                size: 22,
                color: enabled ? scheme.onSurface : titleColor,
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
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    if (selected != null || semanticsValue != null) {
      content = Semantics(
        selected: selected,
        value: semanticsValue,
        child: content,
      );
    }
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: 16,
                  top: 10,
                  bottom: 10,
                  end: hasTrailing ? 8 : 16,
                ),
                child: content,
              ),
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              // 取值已由行语义朗读，尾部展示不再重复进入语义树。
              child: semanticsValue == null
                  ? trailing!
                  : ExcludeSemantics(child: trailing!),
            ),
          if (showChevron)
            Padding(
              padding: EdgeInsetsDirectional.only(
                end: 12,
                start: trailing == null ? 8 : 0,
              ),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: enabled
                    ? scheme.onSurfaceVariant
                    : scheme.onSurfaceVariant.withValues(alpha: 0.38),
              ),
            ),
        ],
      ),
    );
    return row;
  }
}

/// 分组标题之间的留白与说明，保持外置标题和内容同一基线。
class AppGroupedCaption extends StatelessWidget {
  const AppGroupedCaption({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
