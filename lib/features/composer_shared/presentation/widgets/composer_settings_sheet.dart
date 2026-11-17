import 'package:flutter/material.dart';
import 'package:prism_ui/switch.dart' as prism;
import 'package:y300/shared/widgets/app_prism_theme.dart';

class ComposerSettingsSheet extends StatelessWidget {
  const ComposerSettingsSheet({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class ComposerSettingsSwitchTile extends StatelessWidget {
  const ComposerSettingsSwitchTile({
    super.key,
    required this.tileKey,
    required this.title,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final Key tileKey;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _CompactSwitchRow(
      controlKey: tileKey,
      title: title,
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// 紧凑设置面板里的开关行。
///
/// 面板自身已有内边距和分隔线，套用分组列表的 `AppSwitchRow` 会多出一层
/// 缩进，因此这里只复用同一 prism 开关外观；整行仍是可切换触区，禁用态由
/// 空回调表达，与原 `SwitchListTile` 的交互一致。
class _CompactSwitchRow extends StatelessWidget {
  const _CompactSwitchRow({
    required this.controlKey,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Key controlKey;
  final String title;
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
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.38),
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

class ComposerSettingsActionTile extends StatelessWidget {
  const ComposerSettingsActionTile({
    super.key,
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.onPressed,
    this.destructive = false,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive && onPressed != null
        ? Theme.of(context).colorScheme.error
        : null;
    return ListTile(
      key: tileKey,
      leading: Icon(icon, color: color),
      title: Text(title, style: color == null ? null : TextStyle(color: color)),
      contentPadding: EdgeInsets.zero,
      dense: true,
      enabled: onPressed != null,
      onTap: onPressed,
    );
  }
}
