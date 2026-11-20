import 'package:flutter/material.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_chrome_palette.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_models.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

/// 阅读器顶栏：正文与控件色板沿用阅读专项解析，顶栏按钮使用同一玻璃组件。
///
/// 布局按同层规则分配：返回独立，标题与动作之间留 8；相关动作合成公共
/// 动作胶囊，末项（“更多”）保持独立圆键，组合之间 8，尾部留 12。窄屏或
/// 大字号下标题先省略，仍放不下时从最左侧收起次要动作，保留返回与末项。
///
/// 玻璃档位由应用根 `AppGlassEnvironment` 提供；关闭或高对比时胶囊与圆键
/// 退回该工具栏自身的 [ReaderChromePalette.chromeBackground]，前景保持控件色板。
class ReaderTopOverlayBar extends StatelessWidget {
  const ReaderTopOverlayBar({super.key, required this.config});

  final ReaderTopBarConfig config;

  /// 公共按钮层的 48 逻辑像素触区、组内与组间间距、尾部留白。
  ///
  /// 这里只用于判断窄屏下还能放下几个动作；按钮本身尺寸由公共层决定，
  /// 不因玻璃或本布局缩小。
  static const double _actionExtent = 48;
  static const double _actionGap = 8;
  static const double _endPadding = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = const ReaderChromePaletteResolver().resolve(theme);
    // 公共胶囊按主题取底面；把阅读控件色板投影回主题，顶栏动作与原来的
    // 实色按钮保持同一色板语义。
    final actionTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        surfaceContainerHigh: palette.chromeBackground,
        onSurface: palette.chromeForeground,
      ),
    );
    return Material(
      key: const Key('shared-reader-top-overlay-bar'),
      color: palette.chromeBackground,
      child: SafeArea(
        bottom: false,
        // 使用实际文字高度，兼容系统回退字体和大字号的行度量。
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = _visibleActions(constraints.maxWidth);
              return Row(
                children: [
                  AppToolbarIconButton(
                    buttonKey: const Key('shared-reader-top-back-button'),
                    tooltip: AppLocalizations.of(context).readerBack,
                    onPressed: config.onBack,
                    foregroundColor: palette.chromeForeground,
                    baseColor: palette.chromeBackground,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: _actionGap),
                  Expanded(child: _buildTitle(context, palette)),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: _actionGap),
                    Theme(
                      data: actionTheme,
                      child: AppToolbarActions(
                        // 玻璃由 AppToolbarActions 提供；公共按钮在组内自动
                        // 不再自画圆底，菜单触发键也归同一组内 scope。
                        children: [
                          for (final action in actions)
                            _buildAction(action, palette),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context, ReaderChromePalette palette) {
    return InkWell(
      key: const Key('shared-reader-title-button'),
      onTap: config.onTitleTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              config.title,
              key: const Key('shared-reader-top-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: palette.chromeForeground),
            ),
            const SizedBox(height: 2),
            Text(
              config.subtitle,
              key: const Key('shared-reader-top-subtitle'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.chromeForeground),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(ReaderToolbarAction action, ReaderChromePalette palette) {
    final menu = action is ReaderToolbarMenuAction ? action : null;
    if (menu != null) {
      return AppToolbarMenuButton<String>(
        buttonKey: Key('shared-reader-top-action-${action.id}'),
        tooltip: action.label,
        icon: Icon(action.icon),
        enabled: action.enabled,
        itemBuilder: (context) => [
          for (final entry in menu.entries)
            AppPopupMenuItem<String>(
              key: Key('shared-reader-action-${entry.id}'),
              value: entry.id,
              label: entry.label,
              icon: entry.icon == null ? null : Icon(entry.icon),
              enabled: entry.enabled,
              checked: entry.checked,
              danger: entry.danger,
            ),
        ],
        onSelected: (id) =>
            menu.entries.firstWhere((entry) => entry.id == id).onSelected(),
      );
    }
    return AppToolbarIconButton(
      buttonKey: Key('shared-reader-top-action-${action.id}'),
      tooltip: action.label,
      onPressed: action.enabled ? action.onPressed : null,
      foregroundColor: palette.chromeForeground,
      baseColor: palette.chromeBackground,
      icon: Icon(action.icon),
    );
  }

  /// 从末项（更多）向前保留动作，直到 48 触区与组间距放不下为止。
  ///
  /// 标题占剩余空间并在栏内单行省略，所以窄屏与大字号下先牺牲标题，
  /// 再牺牲左侧次要动作；返回与末项（更多）始终保留。
  List<ReaderToolbarAction> _visibleActions(double maxWidth) {
    final actions = config.actions;
    if (actions.isEmpty) {
      return const [];
    }
    final budget = maxWidth - _actionExtent - _actionGap * 2 - _endPadding;
    final visible = <ReaderToolbarAction>[];
    for (final action in actions.reversed) {
      final count = visible.length + 1;
      final needed = count * _actionExtent + (count > 1 ? _actionGap : 0);
      if (visible.isNotEmpty && needed > budget) {
        break;
      }
      visible.insert(0, action);
    }
    return visible;
  }
}
