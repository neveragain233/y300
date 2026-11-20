import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism_ui/input.dart' as prism_input;
import 'package:prism_ui/text_field.dart' as prism;
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 输入框表面：分组表单默认填充，标题行保留下划线，源码编辑器保留无边框。
enum AppTextInputVariant { filled, underline, plain }

/// 应用文本输入的唯一适配入口。
///
/// 页面只描述字段语义（标签、提示、说明、错误、前缀图标与行为），
/// 具体外观交给 prism_ui：填充表面、聚焦描边、错误文案与文本选区都由
/// [prism.TextField] 绘制；标题行和无边框源码编辑器分别通过
/// [AppTextInputVariant.underline] 与 [AppTextInputVariant.plain] 保留原有
/// 布局形态。标签与多行说明由这里统一排版，避免 Material 浮动标签在分组
/// 表面里与 prism 输入的两套基线互相打架。
///
/// 控制器、焦点、校验和保存语义仍归调用方；这里不读任何 App 或业务状态。
class AppTextInput extends StatelessWidget {
  const AppTextInput({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.helperText,
    this.helperMaxLines = 2,
    this.errorText,
    this.errorMaxLines = 3,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.fillColor,
    this.style,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enableIMEPersonalizedLearning = true,
    this.enableInteractiveSelection = true,
    this.minLines,
    this.maxLines = 1,
    this.expands = false,
    this.maxLength,
    this.contentPadding,
    this.variant = AppTextInputVariant.filled,
    this.contextMenuBuilder,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// 字段上方的标签；为 null 时不占位。
  final String? label;

  final String? hintText;

  /// 字段下方的说明；出现 [errorText] 时由错误文案取代。
  final String? helperText;

  final int helperMaxLines;

  final String? errorText;
  final int errorMaxLines;

  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? suffixText;

  /// 填充表面的底色；默认取主题的上一层表面。
  final Color? fillColor;

  final TextStyle? style;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool enableIMEPersonalizedLearning;
  final bool enableInteractiveSelection;
  final int? minLines;
  final int? maxLines;
  final bool expands;
  final int? maxLength;
  final EdgeInsetsGeometry? contentPadding;
  final AppTextInputVariant variant;
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    final field = prism.TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
      enableInteractiveSelection: enableInteractiveSelection,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      minLines: minLines,
      maxLines: maxLines,
      expands: expands,
      maxLength: maxLength,
      style: style,
      contextMenuBuilder: contextMenuBuilder,
      textAlignVertical: variant == AppTextInputVariant.underline
          ? TextAlignVertical.center
          : null,
      decoration: _decoration(),
    );
    final input = switch (variant) {
      AppTextInputVariant.filled => prism_input.FilledInputTheme(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        fillColor: fillColor,
        child: field,
      ),
      AppTextInputVariant.underline => _UnderlineInputFrame(child: field),
      AppTextInputVariant.plain => field,
    };
    final label = this.label;
    final helper = errorText == null && helperText != null
        ? Text(
            helperText!,
            maxLines: helperMaxLines,
            overflow: TextOverflow.ellipsis,
            style: _captionStyle(context),
          )
        : null;
    if (label == null && helper == null) {
      return AppPrismTheme(child: input);
    }
    return AppPrismTheme(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Text(label, style: _captionStyle(context)),
            const SizedBox(height: 6),
          ],
          input,
          if (helper != null) ...[const SizedBox(height: 6), helper],
        ],
      ),
    );
  }

  prism.InputDecoration _decoration() {
    final collapsed = variant == AppTextInputVariant.plain;
    final border = collapsed || variant == AppTextInputVariant.underline
        ? const prism.NoInputBorder()
        : null;
    final decoration = prism.InputDecoration(
      hintText: hintText,
      errorText: errorText,
      errorMaxLines: errorMaxLines,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      filled: variant == AppTextInputVariant.filled,
      fillColor: fillColor,
      isCollapsed: collapsed,
      isDense: !collapsed && variant == AppTextInputVariant.underline,
      contentPadding: contentPadding,
      border: border,
      enabledBorder: border,
      disabledBorder: border,
      focusedBorder: border,
      errorBorder: border,
      focusedErrorBorder: border,
    );
    return decoration;
  }

  TextStyle? _captionStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
}

/// 下划线表面：聚焦时底线换成强调色，形态和行高保持不变。
class _UnderlineInputFrame extends StatefulWidget {
  const _UnderlineInputFrame({required this.child});

  final Widget child;

  @override
  State<_UnderlineInputFrame> createState() => _UnderlineInputFrameState();
}

class _UnderlineInputFrameState extends State<_UnderlineInputFrame> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused != _focused) {
          setState(() => _focused = focused);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.child,
          SizedBox(
            height: 2,
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedContainer(
                // 下划线过渡沿用全局动效策略；系统要求减少动态效果时直接
                // 呈现终态，墨水屏再由 AppMotion 统一归零。
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppMotion.duration(
                        context,
                        const Duration(milliseconds: 167),
                      ),
                height: _focused ? 2 : 1,
                color: _focused ? scheme.primary : scheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
