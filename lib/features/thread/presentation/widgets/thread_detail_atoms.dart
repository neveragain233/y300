part of 'thread_detail_widgets.dart';

// Shared UI atoms and helpers for thread detail: avatar, pills and card/segment
// decorations. Split from thread_detail_widgets.dart during Phase 5b.

class ThreadAuthorAvatar extends StatelessWidget {
  const ThreadAuthorAvatar({
    super.key,
    required this.author,
    required this.authorId,
    required this.avatarUrl,
    this.imageReferer,
    this.avatarFallbackPolicy = ForumAvatarFallbackPolicy.neutralSurface,
    this.onTap,
  });

  final String author;
  final String authorId;
  final String? avatarUrl;
  final String? imageReferer;
  final ForumAvatarFallbackPolicy avatarFallbackPolicy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = ForumCachedAvatar(
      key: Key('thread-author-avatar-${_avatarOwnerId()}'),
      imageUrl: avatarUrl?.trim(),
      ownerId: _avatarOwnerId(),
      ownerType: ImageCacheOwnerType.thread,
      size: 34,
      imageReferer: imageReferer,
      fallbackPolicy: avatarFallbackPolicy,
    );
    if (onTap == null) {
      return avatar;
    }
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: avatar,
    );
  }

  String _avatarOwnerId() {
    final id = authorId.trim();
    if (id.isNotEmpty) {
      return id;
    }
    final name = author.trim();
    return name.isEmpty ? 'unknown' : name;
  }
}

class ThreadMetricPill extends StatelessWidget {
  const ThreadMetricPill({
    super.key,
    required this.icon,
    required this.label,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final ThreadDetailNativePalette palette;

  @override
  Widget build(BuildContext context) {
    return ForumMetricPill(
      icon: icon,
      label: label,
      backgroundColor: palette.chipBackground,
      iconColor: palette.softText,
      textColor: palette.muted,
    );
  }
}

class ThreadPill extends StatelessWidget {
  const ThreadPill({
    super.key,
    required this.label,
    required this.palette,
    this.emphasized = false,
  });

  final String label;
  final ThreadDetailNativePalette palette;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? palette.accent.withValues(alpha: 0.10)
            : palette.chipBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: emphasized ? palette.accent : palette.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(ThreadDetailNativePalette palette) {
  return BoxDecoration(
    color: palette.card,
    borderRadius: BorderRadius.circular(12),
    boxShadow: ForumNativeSurfaceShadows.card(palette.stateLayer),
  );
}

BoxDecoration _highlightedCardDecoration(ThreadDetailNativePalette palette) {
  return BoxDecoration(
    color: palette.accent.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(12),
    boxShadow: ForumNativeSurfaceShadows.card(palette.stateLayer),
  );
}

enum _ThreadPostCardSegmentPosition { header, middle, footer }

BoxDecoration _cardSegmentDecoration({
  required ThreadDetailNativePalette palette,
  required bool highlighted,
  required _ThreadPostCardSegmentPosition position,
}) {
  return BoxDecoration(
    color: highlighted ? palette.accent.withValues(alpha: 0.10) : palette.card,
  );
}

/// 连续楼层间适度加厚的分隔槽：比 0.5 像素细线更易识别楼界，同时保持克制。
class _ThreadFloorSeparatorBand extends StatelessWidget {
  const _ThreadFloorSeparatorBand({
    required this.palette,
    this.isFirstPost = false,
  });

  final ThreadDetailNativePalette palette;
  final bool isFirstPost;

  @override
  Widget build(BuildContext context) {
    final eInk = EInkModeScope.of(context);
    final edgeColor = eInk ? palette.outlineSoft : palette.border;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.floorDividerBand,
        border: isFirstPost || eInk
            ? Border(
                top: BorderSide(color: edgeColor, width: eInk ? 0.8 : 0.5),
                bottom: BorderSide(color: edgeColor, width: eInk ? 0.8 : 0.5),
              )
            : null,
      ),
      child: SizedBox(height: isFirstPost ? 4.5 : 3.5, width: double.infinity),
    );
  }
}
