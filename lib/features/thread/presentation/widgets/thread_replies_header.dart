import 'package:flutter/material.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/forum_content_spacing.dart';

import 'thread_detail_theme.dart';

/// 回复区的计数、作者筛选与顺序切换栏。
///
/// 顺序区保留“正序／倒序”两个文字标签和原选中外观，但整块只有一个点击与
/// 读屏操作，避免把两个视觉标签暴露成两个可激活控件。
class ThreadRepliesHeader extends StatelessWidget {
  const ThreadRepliesHeader({
    super.key,
    required this.replyCount,
    required this.isOnlyAuthor,
    required this.isReverseOrder,
    required this.palette,
    this.enabled = true,
    this.onToggleAuthorFilter,
    this.onToggleOrder,
    this.authorFilterKey,
    this.orderToggleKey,
  });

  final int replyCount;
  final bool isOnlyAuthor;
  final bool isReverseOrder;
  final ThreadDetailNativePalette palette;
  final bool enabled;
  final VoidCallback? onToggleAuthorFilter;
  final VoidCallback? onToggleOrder;

  /// 吸顶栏只为测量和显示而复制视觉，不复制列表里那份可测试/可命中的控件键。
  final Key? authorFilterKey;
  final Key? orderToggleKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ForumContentSpacing.postBodyHorizontal,
        8,
        ForumContentSpacing.postBodyHorizontal,
        4,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  alignment: AlignmentDirectional.centerStart,
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.threadDetailReplyCount(replyCount),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: palette.title,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (onToggleAuthorFilter != null)
                _filterButton(
                  context,
                  key: authorFilterKey,
                  label: l10n.threadDetailOnlyAuthor,
                  selected: isOnlyAuthor,
                  onPressed: onToggleAuthorFilter!,
                ),
            ],
          ),
          if (onToggleOrder != null) _orderToggle(context),
        ],
      ),
    );
  }

  Widget _orderToggle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final toggle = onToggleOrder;
    Widget label(String text, bool selected) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? palette.accent : palette.muted,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      key: orderToggleKey,
      button: true,
      enabled: enabled,
      label: l10n.threadDetailReplyOrder,
      value: isReverseOrder
          ? l10n.threadDetailDescendingOrder
          : l10n.threadDetailAscendingOrder,
      onTap: enabled ? toggle : null,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? toggle : null,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              label(l10n.threadDetailAscendingOrder, !isReverseOrder),
              const SizedBox(width: 8),
              label(l10n.threadDetailDescendingOrder, isReverseOrder),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterButton(
    BuildContext context, {
    required Key? key,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      key: key,
      style: TextButton.styleFrom(
        foregroundColor: selected ? palette.accent : palette.muted,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: enabled ? onPressed : null,
      child: Semantics(selected: selected, child: Text(label)),
    );
  }
}
