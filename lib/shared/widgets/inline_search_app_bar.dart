import 'package:flutter/material.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_text_input.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

/// A search-mode app bar whose text field is visually part of the toolbar.
///
/// Callers retain ownership of the text and focus controllers so search
/// lifecycle, debouncing, and route behavior stay at the feature boundary.
/// The bar reuses [AppPageAppBar] so the page surface, circular back button,
/// title baseline and action capsule stay identical to pushed pages.
class InlineSearchAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const InlineSearchAppBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.fieldKey,
    required this.hintText,
    required this.clearTooltip,
    required this.onBack,
    this.backButtonKey,
    this.clearButtonKey,
    this.onChanged,
    this.onSubmitted,
    this.onCleared,
    this.submitButtonKey,
    this.submitTooltip,
    this.onSubmit,
    this.submitEnabled = true,
    this.autofocus = true,
    this.bottom,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Key fieldKey;
  final String hintText;
  final String clearTooltip;
  final VoidCallback onBack;
  final Key? backButtonKey;
  final Key? clearButtonKey;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCleared;
  final Key? submitButtonKey;
  final String? submitTooltip;
  final VoidCallback? onSubmit;
  final bool submitEnabled;
  final bool autofocus;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;
    final foreground =
        appBarTheme.foregroundColor ??
        appBarTheme.titleTextStyle?.color ??
        theme.colorScheme.onSurface;
    final titleStyle =
        (appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)?.copyWith(
          color: foreground,
        );

    return AppPageAppBar(
      leading: AppToolbarBackButton(key: backButtonKey, onPressed: _handleBack),
      titleSpacing: 0,
      bottom: bottom,
      titleWidget: AppTextInput(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        maxLines: 1,
        textInputAction: TextInputAction.search,
        style: titleStyle,
        cursorColor: foreground,
        hintText: hintText,
        hintStyle: titleStyle?.copyWith(
          color: foreground.withValues(alpha: 0.68),
        ),
        variant: AppTextInputVariant.plain,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
      actions: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final hasQuery = value.text.trim().isNotEmpty;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.text.isNotEmpty)
                  IconButton(
                    key: clearButtonKey,
                    tooltip: clearTooltip,
                    onPressed: _handleClear,
                    icon: const Icon(Icons.close),
                  ),
                if (onSubmit != null)
                  IconButton(
                    key: submitButtonKey,
                    tooltip: submitTooltip,
                    onPressed: submitEnabled && hasQuery ? onSubmit : null,
                    icon: const Icon(Icons.search),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _handleBack() {
    focusNode.unfocus();
    onBack();
  }

  void _handleClear() {
    controller.clear();
    onChanged?.call('');
    onCleared?.call();
    focusNode.requestFocus();
  }
}
