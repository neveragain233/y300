import 'package:flutter/material.dart';
import 'package:prism_ui/segmented_control.dart' as prism;
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 阅读设置分组行内的分段单选控件，使用 [prism.SegmentedControl]。
class ReaderOptionRow<T> extends StatelessWidget {
  const ReaderOptionRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.stacked = false,
  });

  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w500,
    );
    final control = AppPrismTheme(
      child: prism.SegmentedControl<T>(
        segments: options,
        value: value,
        onChanged: onChanged,
      ),
    );

    Widget body = LayoutBuilder(
      builder: (context, constraints) {
        if (stacked || constraints.maxWidth < 320) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
                const SizedBox(height: 6),
                control,
              ],
            ),
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: control),
              ],
            ),
          ),
        );
      },
    );

    if (!enabled) {
      body = IgnorePointer(child: Opacity(opacity: 0.45, child: body));
    }
    return body;
  }
}
