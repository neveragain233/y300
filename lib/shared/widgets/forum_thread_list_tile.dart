import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/forum_native_surface.dart';

/// 帖子卡片的共享布局，业务入口与原文由调用方提供。
class ForumThreadListTile extends StatelessWidget {
  const ForumThreadListTile({
    super.key,
    required this.title,
    required this.metadata,
    required this.onTap,
    required this.surfaceColor,
    required this.shadowColor,
    this.titleColor,
    this.titleKey,
    this.badges,
    this.excerpt = '',
    this.footer,
    this.trailing,
  });

  final String title;
  final Key? titleKey;
  final Widget metadata;
  final VoidCallback onTap;
  final Color surfaceColor;
  final Color shadowColor;
  final Color? titleColor;
  final Widget? badges;
  final String excerpt;
  final Widget? footer;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(12);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: ForumNativeSurfaceShadows.card(shadowColor),
      ),
      child: Material(
        color: surfaceColor,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        key: titleKey,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: titleColor ?? theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          height: 1.28,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
                if (badges != null) ...[const SizedBox(height: 6), badges!],
                const SizedBox(height: 8),
                metadata,
                if (excerpt.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    excerpt.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (footer != null) ...[const SizedBox(height: 9), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
