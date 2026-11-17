import 'package:flutter/material.dart';
import 'package:prism_ui/common_button.dart' as prism_button;
import 'package:prism_ui/dialog.dart' as prism;
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 应用确认框：外观、圆角、按钮排布与开合运动由 prism_ui 浮层对话框提供。
///
/// 返回 true 只在按下确认按钮时成立；取消、返回键与点外关闭都返回 false，
/// 与原 `showDialog<bool>` 调用方对 null 的处理保持一致。浮层脱离页面树，
/// 因此在路由内部重新挂一次 [AppPrismTheme]。
///
/// [confirmKey]、[cancelKey] 供页面和测试定位按钮；文案由调用方经
/// `AppLocalizations` 提供。`destructive` 把最后一项（确认）标为危险色，
/// 与 prism 对话框自身规则一致：确认是默认动作，取消在前。
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  Key? confirmKey,
  Key? cancelKey,
  bool dismissible = true,
}) async {
  final result = await prism.showFloatingDialog<bool>(
    context: context,
    dismissible: dismissible,
    child: _AppConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      confirmKey: confirmKey,
      cancelKey: cancelKey,
    ),
  );
  return result ?? false;
}

class _AppConfirmDialog extends StatefulWidget {
  const _AppConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    required this.confirmKey,
    required this.cancelKey,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final Key? confirmKey;
  final Key? cancelKey;

  @override
  State<_AppConfirmDialog> createState() => _AppConfirmDialogState();
}

class _AppConfirmDialogState extends State<_AppConfirmDialog> {
  /// 收回动画期间按钮仍在树上，只接受第一次回答，避免重复 pop 掉下层页面。
  bool _answered = false;

  void _answer(bool value) {
    if (_answered) {
      return;
    }
    _answered = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AppPrismTheme(
      child: prism.AlertDialog(
        title: widget.title,
        destructive: widget.destructive,
        actions: [
          prism_button.TextButton(
            key: widget.cancelKey,
            onPressed: () => _answer(false),
            child: Text(widget.cancelLabel),
          ),
          prism_button.TextButton(
            key: widget.confirmKey,
            onPressed: () => _answer(true),
            child: Text(widget.confirmLabel),
          ),
        ],
        child: widget.message == null ? null : Text(widget.message!),
      ),
    );
  }
}
