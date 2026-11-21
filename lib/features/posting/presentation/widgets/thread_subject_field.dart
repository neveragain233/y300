import 'package:flutter/material.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_text_input.dart';

/// 发帖标题输入框。
///
/// 单独抽出 widget 是为了让 `PostingComposerPage` 的 build 树更扁平，
/// 同时把 widget key（外部测试入口）封装在一处。
///
/// `maxLength` `<=0` 时按"无限制"处理：不渲染计数；否则在右下角展示
/// "当前 / 上限"，超限时染上错误色，与 controller 的 preflight 校验保持一致。
class ThreadSubjectField extends StatelessWidget {
  const ThreadSubjectField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.fieldKey,
    this.hintText,
    this.maxLength = 0,
    this.counterTextKey,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final Key? fieldKey;
  final String? hintText;

  /// `<=0` 表示版块没声明上限，UI 不显示计数。
  final int maxLength;
  final Key? counterTextKey;

  @override
  Widget build(BuildContext context) {
    final hasLimit = maxLength > 0;
    final input = AppTextInput(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      maxLines: 1,
      textInputAction: TextInputAction.next,
      hintText: hintText ?? AppLocalizations.of(context).postingSubjectHint,
      variant: AppTextInputVariant.underline,
    );
    if (!hasLimit) {
      return input;
    }
    // 仅自主绘制计数而不向输入控件传 maxLength，避免超限字符被平台截断；
    // preflight 与 state.canSubmit 已经在网络/按钮层兜住超限。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        input,
        const SizedBox(height: 4),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final currentLength = value.text.length;
            final colorScheme = Theme.of(context).colorScheme;
            final exceeded = currentLength > maxLength;
            return Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                '$currentLength / $maxLength',
                key: counterTextKey,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: exceeded
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
