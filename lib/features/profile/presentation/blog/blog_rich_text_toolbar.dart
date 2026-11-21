import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/features/composer_shared/presentation/quill/composer_quill_size_mapping.dart';
import 'package:y300/features/composer_shared/presentation/widgets/composer_sticker_image.dart';
import 'package:y300/features/profile/presentation/blog/blog_rich_text_controller.dart';
import 'package:y300/features/profile/presentation/blog/blog_rich_text_embeds.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/adaptive_panel.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';

class BlogRichTextToolbar extends StatelessWidget {
  const BlogRichTextToolbar({
    super.key,
    required this.controller,
    required this.enabled,
    required this.smilies,
    this.onImagePressed,
  });
  final BlogRichTextController controller;
  final bool enabled;
  final List<UserBlogSmiley> smilies;
  final VoidCallback? onImagePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final native = Theme.of(context).y300NativeContent;
    return Material(
      color: native.card,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: native.subtleStateLayer)),
          ),
          child: SingleChildScrollView(
            key: const Key('blog-editor-toolbar'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: AnimatedBuilder(
              animation: controller.quill,
              builder: (context, _) {
                final attributes = controller.quill
                    .getSelectionStyle()
                    .attributes;
                return Row(
                  children: [
                    for (final (attribute, icon, label) in [
                      (Attribute.bold, Icons.format_bold, l10n.composerBold),
                      (
                        Attribute.italic,
                        Icons.format_italic,
                        l10n.composerItalic,
                      ),
                      (
                        Attribute.underline,
                        Icons.format_underlined,
                        l10n.composerUnderline,
                      ),
                    ])
                      Builder(
                        builder: (context) {
                          final selected =
                              attributes[attribute.key]?.value == true;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AppToolbarIconButton(
                              buttonKey: Key('blog-format-${attribute.key}'),
                              size: AppToolbarButtonSize.compact,
                              tooltip: label,
                              glassLevel: selected ? AppGlassLevel.off : null,
                              baseColor: selected
                                  ? native.selectionBackground
                                  : Colors.transparent,
                              foregroundColor: selected
                                  ? native.author
                                  : native.body,
                              onPressed: enabled
                                  ? () {
                                      controller.quill.formatSelection(
                                        Attribute.clone(
                                          attribute,
                                          selected ? null : true,
                                        ),
                                      );
                                      controller.focusNode.requestFocus();
                                    }
                                  : null,
                              icon: Icon(icon),
                            ),
                          );
                        },
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AppToolbarIconButton(
                        buttonKey: const Key('blog-format-size'),
                        size: AppToolbarButtonSize.compact,
                        tooltip: l10n.composerFontSize,
                        baseColor: Colors.transparent,
                        foregroundColor: native.body,
                        onPressed: enabled ? () => _chooseSize(context) : null,
                        icon: const Icon(Icons.format_size),
                      ),
                    ),
                    if (onImagePressed != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AppToolbarIconButton(
                          buttonKey: const Key('blog-insert-image'),
                          size: AppToolbarButtonSize.compact,
                          tooltip: l10n.composerImage,
                          baseColor: Colors.transparent,
                          foregroundColor: native.body,
                          onPressed: enabled ? onImagePressed : null,
                          icon: const Icon(Icons.image_outlined),
                        ),
                      ),
                    if (smilies.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AppToolbarIconButton(
                          buttonKey: const Key('blog-insert-smiley'),
                          size: AppToolbarButtonSize.compact,
                          tooltip: l10n.composerSticker,
                          baseColor: Colors.transparent,
                          foregroundColor: native.body,
                          onPressed: enabled
                              ? () => _chooseSmiley(context)
                              : null,
                          icon: const Icon(Icons.emoji_emotions_outlined),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseSize(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final generation = controller.generation;
    final selected = composerDiscuzSizeForQuillSize(
      controller.quill
          .getSelectionStyle()
          .attributes[Attribute.size.key]
          ?.value,
    );
    final size = await showAdaptivePanel<int>(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.composerFontSize,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var value = 1; value <= 7; value++) ...[
                      ChoiceChip(
                        key: Key('blog-font-size-$value'),
                        label: Text('$value'),
                        selected: selected == '$value',
                        onSelected: (_) => Navigator.pop(context, value),
                      ),
                      if (value != 7) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 0),
                child: Text(l10n.composerClearFontSize),
              ),
            ],
          ),
        ),
      ),
    );
    if (size == null ||
        generation != controller.generation ||
        controller.quill.readOnly) {
      return;
    }
    controller.quill.formatSelection(
      Attribute.clone(Attribute.size, composerQuillSizeForDiscuzSize(size)),
    );
    controller.focusNode.requestFocus();
  }

  Future<void> _chooseSmiley(BuildContext context) async {
    final generation = controller.generation;
    final l10n = AppLocalizations.of(context);
    final smiley = await showAdaptivePanel<UserBlogSmiley>(
      context: context,
      builder: (context) => GridView.extent(
        key: const Key('blog-smiley-picker'),
        maxCrossAxisExtent: 64,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        children: [
          for (final item in smilies)
            IconButton(
              key: Key('blog-smiley-${item.index}'),
              tooltip: '${l10n.composerSticker} ${item.index}',
              onPressed: () => Navigator.pop(context, item),
              icon: ComposerStickerImage(
                sticker: blogEditorSticker(item.imageUri.toString()),
                width: 32,
                height: 32,
                placeholder: const SizedBox(width: 32, height: 32),
                errorPlaceholder: const Icon(Icons.broken_image_outlined),
              ),
            ),
        ],
      ),
    );
    if (smiley == null ||
        generation != controller.generation ||
        controller.quill.readOnly) {
      return;
    }
    controller.insertImage(smiley.imageUri.toString(), inline: true);
    controller.focusNode.requestFocus();
  }
}
