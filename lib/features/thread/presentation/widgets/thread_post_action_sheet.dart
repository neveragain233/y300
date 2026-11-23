import 'package:flutter/material.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';

enum ThreadPostAction {
  copyPollOption,
  edit,
  reply,
  rate,
  comment,
  selectCopy,
  copyAll,
  copyFloorLink,
  onlyAuthor,
  blockUser,
}

class ThreadPostActionSheet {
  const ThreadPostActionSheet({
    required this.post,
    required this.editUri,
    required this.capabilities,
    this.canCopyPollOption = false,
    this.canViewOnlyAuthor = false,
    this.canBlockUser = false,
  });

  final ThreadPost post;
  final Uri? editUri;
  final ThreadDetailReadCapabilities? capabilities;
  final bool canCopyPollOption;
  final bool canViewOnlyAuthor;
  final bool canBlockUser;

  bool _supports(ThreadDetailCapability capability) {
    return capabilities?.supports(capability) ?? false;
  }

  List<AppPopupMenuItem<ThreadPostAction>> entries(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      if (canBlockUser)
        AppPopupMenuItem(
          key: const Key('thread-post-block-user-action'),
          value: ThreadPostAction.blockUser,
          icon: const Icon(Icons.person_off_outlined),
          label: l10n.blacklistBlockUser,
        ),
      if (canViewOnlyAuthor)
        AppPopupMenuItem(
          key: const Key('thread-post-only-author-action'),
          value: ThreadPostAction.onlyAuthor,
          icon: const Icon(Icons.person_outline),
          label: l10n.threadDetailOnlyAuthor,
        ),
      if (canCopyPollOption)
        AppPopupMenuItem(
          key: const Key('thread-post-copy-poll-option-action'),
          value: ThreadPostAction.copyPollOption,
          icon: const Icon(Icons.copy_outlined),
          label: l10n.threadPollCopyOptionText,
        ),
      if (editUri != null)
        AppPopupMenuItem(
          key: const Key('thread-post-edit-action'),
          value: ThreadPostAction.edit,
          icon: const Icon(Icons.edit_outlined),
          label: l10n.threadDetailEdit,
        ),
      if (_supports(ThreadDetailCapability.replyAction))
        AppPopupMenuItem(
          key: const Key('thread-post-reply-action'),
          value: ThreadPostAction.reply,
          icon: const Icon(Icons.reply_outlined),
          label: l10n.threadDetailReply,
        ),
      if (_supports(ThreadDetailCapability.ratingAction) &&
          post.rateUrl?.trim().isNotEmpty == true)
        AppPopupMenuItem(
          key: const Key('thread-post-rate-action'),
          value: ThreadPostAction.rate,
          icon: const Icon(Icons.favorite_border),
          label: l10n.threadRatingTitle,
        ),
      if (_supports(ThreadDetailCapability.commentAction) &&
          post.commentUrl?.trim().isNotEmpty == true)
        AppPopupMenuItem(
          key: const Key('thread-post-comment-action'),
          value: ThreadPostAction.comment,
          icon: const Icon(Icons.chat_bubble_outline),
          label: l10n.threadCommentTitle,
        ),
      AppPopupMenuItem(
        key: const Key('thread-post-select-copy-action'),
        value: ThreadPostAction.selectCopy,
        icon: const Icon(Icons.text_fields),
        label: l10n.threadDetailSelectCopy,
      ),
      AppPopupMenuItem(
        key: const Key('thread-post-copy-all-action'),
        value: ThreadPostAction.copyAll,
        icon: const Icon(Icons.copy_all_outlined),
        label: l10n.threadDetailCopyAll,
      ),
      AppPopupMenuItem(
        key: const Key('thread-post-copy-floor-link-action'),
        value: ThreadPostAction.copyFloorLink,
        icon: const Icon(Icons.link_outlined),
        label: l10n.threadDetailCopyFloorLink,
      ),
    ];
  }
}
