import 'package:flutter/material.dart';
import 'package:prism_ui/switch.dart' as prism;
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 分组列表中的开关行：文案、前导槽与触区沿用 [AppGroupedRow]，
/// 开关本身由 prism_ui 绘制，经 [AppPrismTheme] 跟随当前预设与明暗。
///
/// 整行与尾部开关都可切换，尾部保持独立触区；点击后的接受、回滚和持久化
/// 仍由调用方的 [onChanged] 决定。拖动切换、按压与减少动态效果沿用 prism
/// 开关自身能力，这里不复制第二套自绘开关。
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.disabled = false,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// 开关切换回调；为 null 时整行呈禁用态。
  final ValueChanged<bool>? onChanged;

  /// 额外禁用，例如保存中；与原值同时决定是否可交互。
  final bool disabled;

  final Widget? leading;

  bool get _enabled => !disabled && onChanged != null;

  void _toggle() {
    final onChanged = this.onChanged;
    if (!_enabled || onChanged == null) {
      return;
    }
    onChanged(!value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    // 整行合成一个开关节点：标题与说明只读一次，开关状态由同一节点播报；
    // 行与尾部开关仍是各自独立的触区。
    return Semantics(
      container: true,
      // 说明并入同一标签，读屏只报一次行内容与开关状态。
      label: subtitle == null ? title : '$title\n$subtitle',
      toggled: value,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      child: ExcludeSemantics(
        child: AppGroupedRow(
          leading: leading,
          title: title,
          subtitle: subtitle,
          enabled: enabled,
          onTap: enabled ? _toggle : null,
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: AppPrismTheme(
                child: prism.Switch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
