import 'package:flutter/material.dart';
import 'package:prism_ui/switch.dart' as prism;
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/features/profile/presentation/blog/blog_editor_state.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';
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
        KeyedSubtree(
          key: const Key('blog-editor-visibility'),
          child: DropdownButtonFormField<UserBlogVisibility>(
            key: ValueKey((
              draft.visibility,
              Object.hashAll(options.availableVisibilities),
            )),
            initialValue: draft.visibility,
            decoration:
                _settingDecoration(
                  context,
                  label: l10n.profileBlogAccessScope,
                ).copyWith(
                  prefixIcon: Icon(_visibilityIcon(draft.visibility), size: 20),
                  errorText:
                      state.issue == BlogEditorIssue.visibilityUnavailable
                      ? l10n.profileBlogVisibilityUnavailable
                      : null,
                  errorMaxLines: 3,
                ),
            style: theme.textTheme.bodyMedium?.copyWith(color: native.body),
            dropdownColor: native.card,
            isExpanded: true,
            itemHeight: null,
            items: [
              for (final visibility in {
                ...options.availableVisibilities,
                draft.visibility,
              })
                DropdownMenuItem(
                  value: visibility,
                  enabled: options.availableVisibilities.contains(visibility),
                  child: Text(
                    blogVisibilityLabel(l10n, visibility),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged:
                enabled && !readOnly && options.availableVisibilities.isNotEmpty
                ? (visibility) {
                    if (visibility != null) {
                      onChanged(
                        (draft) => draft.copyWith(visibility: visibility),
                      );
                    }
                  }
                : null,
          ),
        ),
        if (draft.visibility == UserBlogVisibility.passwordProtected) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('blog-editor-password'),
            controller: password,
            enabled: enabled,
            readOnly: readOnly || !canEditAccess,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            keyboardType: TextInputType.visiblePassword,
            decoration:
                _settingDecoration(
                  context,
                  label: l10n.profileBlogPassword,
                ).copyWith(
                  helperText: options.hasPassword
                      ? l10n.profileBlogKeepPassword
                      : null,
                  helperMaxLines: 3,
                  errorText: state.issue == BlogEditorIssue.passwordRequired
                      ? l10n.profileBlogPasswordRequired
                      : null,
                  errorMaxLines: 3,
                ),
            onChanged: (value) =>
                onChanged((draft) => draft.copyWith(password: value)),
          ),
        ],
        if (draft.visibility == UserBlogVisibility.selectedFriends) ...[
          const SizedBox(height: 12),
          TextField(
            key: const Key('blog-editor-target-names'),
            controller: targetNames,
            enabled: enabled,
            readOnly: readOnly || !canEditAccess,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration:
                _settingDecoration(
                  context,
                  label: l10n.profileBlogTargetNames,
                ).copyWith(
                  helperText: l10n.profileBlogTargetNamesHint,
                  helperMaxLines: 3,
                  errorText: state.issue == BlogEditorIssue.targetNamesRequired
                      ? l10n.profileBlogTargetNamesRequired
                      : null,
                  errorMaxLines: 3,
                ),
            onChanged: (value) =>
                onChanged((draft) => draft.copyWith(targetNames: value)),
          ),
        ],
        const SizedBox(height: 4),
        BlogEditorSwitchRow(
          controlKey: const Key('blog-editor-comments-enabled'),
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

/// 日志编辑表单里的开关行。
///
/// 表单是紧密排布的输入项，没有分组列表表面，套用 `AppSwitchRow` 会多出
/// 缩进和最小行高；这里只取同一 prism 开关外观。整行与开关都可切换，
/// 禁用态由空回调表达，原 `contentPadding: zero`／`dense` 的排布保持不变。
class BlogEditorSwitchRow extends StatelessWidget {
  const BlogEditorSwitchRow({
    super.key,
    required this.controlKey,
    required this.title,
    required this.value,
    required this.onChanged,
    this.titleStyle,
  });

  final Key controlKey;
  final String title;
  final TextStyle? titleStyle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    void toggle() {
      if (enabled) {
        onChanged!(!value);
      }
    }

    final disabledColor = theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return Semantics(
      container: true,
      label: title,
      toggled: value,
      enabled: enabled,
      onTap: enabled ? toggle : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? toggle : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: (titleStyle ?? theme.textTheme.bodyLarge)?.copyWith(
                      color: enabled
                          ? (titleStyle?.color ?? theme.colorScheme.onSurface)
                          : disabledColor,
                    ),
                  ),
                ),
                AppPrismTheme(
                  child: prism.Switch(
                    key: controlKey,
                    value: value,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _settingDecoration(
  BuildContext context, {
  required String label,
}) {
  final native = Theme.of(context).y300NativeContent;
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: native.supportingText),
    floatingLabelStyle: TextStyle(color: native.author),
    isDense: true,
    filled: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
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
