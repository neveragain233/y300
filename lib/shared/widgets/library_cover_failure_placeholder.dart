import 'package:flutter/material.dart';
import 'package:y300/l10n/app_localizations.dart';

/// 封面资源加载失败时的可重试占位。
///
/// 与加载态的中性块区分开：这里给出一个“重试”胶囊；列表等小尺寸槽位使用紧凑
/// 形式，但仍说明当前是封面加载失败。
class LibraryCoverFailurePlaceholder extends StatelessWidget {
  const LibraryCoverFailurePlaceholder({
    super.key,
    required this.color,
    required this.onRetry,
    this.compact = false,
  });

  /// 中性纸底颜色，与加载态保持同一表面。
  final Color color;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, size: compact ? 13 : 15),
          const SizedBox(width: 4),
          Text(
            l10n.libraryCoverRetry,
            style:
                (compact
                        ? theme.textTheme.labelSmall
                        : theme.textTheme.labelMedium)
                    ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
    return ColoredBox(
      color: color,
      child: Center(
        child: Semantics(
          button: true,
          label: l10n.libraryCoverLoadFailed,
          onTap: onRetry,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRetry,
            child: ConstrainedBox(
              // 保持 48 逻辑像素触区，同时让槽位其他位置继续响应外层点击。
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Center(widthFactor: 1, heightFactor: 1, child: pill),
            ),
          ),
        ),
      ),
    );
  }
}
