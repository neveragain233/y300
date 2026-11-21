import 'package:flutter/material.dart';
import 'package:prism_ui/checkbox.dart' as prism;
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 应用统一复选行：勾选框由 prism_ui 绘制，经 [AppPrismTheme] 跟随主题，
/// 保持 48 逻辑像素有效触区、选中底色与合并复选语义。
class AppCheckboxRow extends StatelessWidget {
  const AppCheckboxRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.onChanged,
    this.checkboxKey,
    this.isCircle = false,
    this.compact = false,
    this.selected = false,
    this.selectedBackgroundColor,
    this.borderRadius,
    this.contentPadding,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Key? checkboxKey;
  final bool isCircle;
  final bool compact;
  final bool selected;
  final Color? selectedBackgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? contentPadding;

  bool get _enabled => onChanged != null;

  void _toggle() {
    final handler = onChanged;
    if (handler == null) {
      return;
    }
    handler(!value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = _enabled;
    final radius = borderRadius ?? BorderRadius.circular(12);
    final backgroundColor = selected
        ? (selectedBackgroundColor ?? scheme.primary.withValues(alpha: 0.08))
        : Colors.transparent;
    final titleColor = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);
    final subtitleColor = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurfaceVariant.withValues(alpha: 0.38);
    final padding =
        contentPadding ??
        (compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 4));

    return Semantics(
      container: true,
      label: subtitle == null ? title : '$title\n$subtitle',
      checked: value,
      selected: selected,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      child: ExcludeSemantics(
        child: Material(
          color: backgroundColor,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? _toggle : null,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 48 : 56),
              child: Padding(
                padding: padding,
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: titleColor,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppPrismTheme(
                      child: prism.Checkbox(
                        key: checkboxKey,
                        value: value,
                        isCircle: isCircle,
                        onChanged: enabled
                            ? (next) => onChanged?.call(next ?? !value)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
