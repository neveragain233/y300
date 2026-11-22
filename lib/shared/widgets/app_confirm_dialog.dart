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
  bool useRootNavigator = true,
}) async {
  final result = await prism.showFloatingDialog<bool>(
    context: context,
    dismissible: dismissible,
    useRootNavigator: useRootNavigator,
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

/// 表单对话框中的一个动作；最后一项是默认动作（prism 对话框的排布规则）。
class AppDialogAction {
  const AppDialogAction({
    required this.label,
    required this.onPressed,
    this.key,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? key;
  final bool enabled;
}

/// 应用表单对话框外壳：标题、输入内容与动作排布由 prism 对话框绘制。
///
/// 与 [showAppConfirmDialog] 共用同一套浮层路由、遮罩与开合运动；需要输入框、
/// 多动作或提交中状态的对话框直接构建本组件，由宿主用
/// [showAppFormDialog] 打开。动作与字段内容仍由调用方持有。
class AppFormDialog extends StatelessWidget {
  const AppFormDialog({
    super.key,
    required this.title,
    required this.actions,
    this.content,
    this.destructive = false,
    this.hasFields = false,
  });

  final String title;
  final Widget? content;
  final List<AppDialogAction> actions;
  final bool destructive;

  /// 输入型对话框把标题居中、字段铺满动作宽度；提示型保持正文层级。
  final bool hasFields;

  @override
  Widget build(BuildContext context) {
    return AppPrismTheme(
      child: prism.AlertDialog(
        title: title,
        destructive: destructive,
        hasFields: hasFields,
        actions: [
          for (final action in actions)
            prism_button.TextButton(
              key: action.key,
              onPressed: action.enabled ? action.onPressed : null,
              child: Text(action.label),
            ),
        ],
        child: content,
      ),
    );
  }
}

/// 打开表单对话框；返回由动作通过 `Navigator.pop` 给出的结果。
Future<T?> showAppFormDialog<T>({
  required BuildContext context,
  required String title,
  required List<AppDialogAction> actions,
  Widget? content,
  bool destructive = false,
  bool hasFields = false,
  bool dismissible = true,
  bool useRootNavigator = true,
  Key? dialogKey,
}) {
  return prism.showFloatingDialog<T>(
    context: context,
    dismissible: dismissible,
    useRootNavigator: useRootNavigator,
    child: AppFormDialog(
      key: dialogKey,
      title: title,
      actions: actions,
      content: content,
      destructive: destructive,
      hasFields: hasFields,
    ),
  );
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
