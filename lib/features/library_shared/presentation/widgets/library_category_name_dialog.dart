import 'package:flutter/material.dart';
import 'package:prism_ui/dialog.dart' as prism;
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_confirm_dialog.dart';
import 'package:y300/shared/widgets/app_text_input.dart';

/// 分类命名对话框：书架管理与选择态共用同一套字段、动作与返回语义。
///
/// 输入框沿用共享 [AppTextInput]，外壳与动作沿用 prism 表单对话框；确认时
/// 返回原始文本，调用方自行 trim 与空值判断，取消、返回键和点外关闭返回
/// null。创建与重命名只在标题、初始值和键上不同，不各留一套 Material 实现。
Future<String?> showLibraryCategoryNameDialog(
  BuildContext context, {
  required String title,
  required String hintText,
  String initialValue = '',
  Key? dialogKey,
  Key? fieldKey,
  Key? confirmKey,
}) {
  return prism.showFloatingDialog<String>(
    context: context,
    child: _LibraryCategoryNameDialog(
      title: title,
      hintText: hintText,
      initialValue: initialValue,
      dialogKey: dialogKey,
      fieldKey: fieldKey,
      confirmKey: confirmKey,
    ),
  );
}

class _LibraryCategoryNameDialog extends StatefulWidget {
  const _LibraryCategoryNameDialog({
    required this.title,
    required this.hintText,
    required this.initialValue,
    required this.dialogKey,
    required this.fieldKey,
    required this.confirmKey,
  });

  final String title;
  final String hintText;
  final String initialValue;
  final Key? dialogKey;
  final Key? fieldKey;
  final Key? confirmKey;

  @override
  State<_LibraryCategoryNameDialog> createState() =>
      _LibraryCategoryNameDialogState();
}

class _LibraryCategoryNameDialogState
    extends State<_LibraryCategoryNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFormDialog(
      key: widget.dialogKey,
      title: widget.title,
      hasFields: true,
      content: AppTextInput(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        hintText: widget.hintText,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        AppDialogAction(
          label: l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialogAction(
          key: widget.confirmKey,
          label: l10n.commonConfirm,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }
}
