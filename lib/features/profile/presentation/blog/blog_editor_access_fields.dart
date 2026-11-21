import 'package:flutter/material.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/features/profile/presentation/blog/blog_editor_state.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_select_menu.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';

class BlogEditorAccessFields extends StatelessWidget {
  const BlogEditorAccessFields({
    super.key,
    required this.state,
    required this.password,
    required this.targetNames,
    required this.onChanged,
    this.locked = false,
  });
  final BlogEditorState state;
  final bool locked;
  final TextEditingController password;
  final TextEditingController targetNames;
  final ValueChanged<BlogEditorDraft Function(BlogEditorDraft)> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final native = theme.y300NativeContent;
    final draft = state.draft;
    final options = state.options!;
    final enabled = !state.busy;
    final readOnly =
        locked ||
        {
          BlogEditorPhase.unknown,
          BlogEditorPhase.applied,
          BlogEditorPhase.expired,
        }.contains(state.phase);
    final canEditAccess = options.availableVisibilities.contains(
      draft.visibility,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSelectField<UserBlogVisibility>(
          key: const Key('blog-editor-visibility'),
          value: draft.visibility,
          label: l10n.profileBlogAccessScope,
          prefixIcon: Icon(_visibilityIcon(draft.visibility), size: 20),
          textStyle: theme.textTheme.bodyMedium?.copyWith(color: native.body),
          errorText: state.issue == BlogEditorIssue.visibilityUnavailable
              ? l10n.profileBlogVisibilityUnavailable
              : null,
          enabled:
              enabled && !readOnly && options.availableVisibilities.isNotEmpty,
          options: [
            for (final visibility in {
              ...options.availableVisibilities,
              draft.visibility,
            })
              AppSelectOption(
                value: visibility,
                label: blogVisibilityLabel(l10n, visibility),
                enabled: options.availableVisibilities.contains(visibility),
              ),
          ],
          onSelected: (visibility) =>
              onChanged((draft) => draft.copyWith(visibility: visibility)),
        ),
        if (draft.visibility == UserBlogVisibility.passwordProtected) ...[
          const SizedBox(height: 12),
          AppTextInput(
            key: const Key('blog-editor-password'),
            controller: password,
            enabled: enabled,
            readOnly: readOnly || !canEditAccess,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            keyboardType: TextInputType.visiblePassword,
            label: l10n.profileBlogPassword,
            helperText: options.hasPassword
                ? l10n.profileBlogKeepPassword
                : null,
            helperMaxLines: 3,
            errorText: state.issue == BlogEditorIssue.passwordRequired
                ? l10n.profileBlogPasswordRequired
                : null,
            onChanged: (value) =>
                onChanged((draft) => draft.copyWith(password: value)),
          ),
        ],
        if (draft.visibility == UserBlogVisibility.selectedFriends) ...[
          const SizedBox(height: 12),
          AppTextInput(
            key: const Key('blog-editor-target-names'),
            controller: targetNames,
            enabled: enabled,
            readOnly: readOnly || !canEditAccess,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            label: l10n.profileBlogTargetNames,
            helperText: l10n.profileBlogTargetNamesHint,
            helperMaxLines: 3,
            errorText: state.issue == BlogEditorIssue.targetNamesRequired
                ? l10n.profileBlogTargetNamesRequired
                : null,
            onChanged: (value) =>
                onChanged((draft) => draft.copyWith(targetNames: value)),
          ),
        ],
        const SizedBox(height: 4),
        AppSwitchRow.compact(
          switchKey: const Key('blog-editor-comments-enabled'),
          title: l10n.profileBlogCommentsAllowed,
          titleStyle: theme.textTheme.bodyMedium?.copyWith(color: native.body),
          value: draft.commentsEnabled,
          onChanged: enabled && !readOnly && options.canEditComments
              ? (value) =>
                    onChanged((draft) => draft.copyWith(commentsEnabled: value))
              : null,
        ),
      ],
    );
  }
}

String blogVisibilityLabel(AppLocalizations l10n, UserBlogVisibility value) =>
    switch (value) {
      UserBlogVisibility.public => l10n.profileBlogVisibilityPublic,
      UserBlogVisibility.friends => l10n.profileBlogVisibilityFriends,
      UserBlogVisibility.selectedFriends => l10n.profileBlogVisibilitySelected,
      UserBlogVisibility.private => l10n.profileBlogVisibilityPrivate,
      UserBlogVisibility.passwordProtected =>
        l10n.profileBlogVisibilityPassword,
    };

IconData _visibilityIcon(UserBlogVisibility value) => switch (value) {
  UserBlogVisibility.public => Icons.public,
  UserBlogVisibility.friends ||
  UserBlogVisibility.selectedFriends => Icons.people_outline,
  UserBlogVisibility.private ||
  UserBlogVisibility.passwordProtected => Icons.lock_outline,
};
