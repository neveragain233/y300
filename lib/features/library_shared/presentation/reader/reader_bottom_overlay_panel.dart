import 'package:flutter/material.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_chrome_palette.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_models.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_progress_control.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

class ReaderBottomOverlayPanel extends StatelessWidget {
  const ReaderBottomOverlayPanel({super.key, required this.config});

  final ReaderBottomBarConfig config;

  /// 动作组在宽屏下的最大宽度；窄屏按可用宽度收缩。
  static const double _maxActionRowWidth = 480;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = const ReaderChromePaletteResolver().resolve(theme);
    final progress = config.progress;
    final thumbnailStrip = config.thumbnailStrip;
    // 公共按钮层按主题取圆底面与前景；把阅读控件色板投影回主题，
    // 关闭档与高对比时按钮退回控件背景色。
    final actionTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        surfaceContainerHigh: palette.chromeBackground,
        onSurface: palette.chromeForeground,
      ),
    );
    return Material(
      key: const Key('shared-reader-bottom-overlay-panel'),
      color: palette.chromeBackground,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: ReaderSystemUiInsets.bottom(context, minimum: 12),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (thumbnailStrip != null)
                  KeyedSubtree(
                    key: const Key('shared-reader-thumbnail-strip-slot'),
                    child: thumbnailStrip,
                  ),
                if (thumbnailStrip != null &&
                    (progress != null || config.actions.isNotEmpty))
                  const SizedBox(height: 6),
                if (progress != null) ReaderProgressControl(config: progress),
                if (config.actions.isNotEmpty) ...[
                  if (progress != null) const SizedBox(height: 6),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maxActionRowWidth,
                      ),
                      child: Theme(
                        data: actionTheme,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (final action in config.actions)
                              AppToolbarIconButton(
                                buttonKey: Key(
                                  'shared-reader-bottom-action-${action.id}',
                                ),
                                tooltip: action.label,
                                onPressed: action.enabled
                                    ? action.onPressed
                                    : null,
                                size: AppToolbarButtonSize.compact,
                                foregroundColor: palette.chromeForeground,
                                baseColor: palette.chromeBackground,
                                icon: Icon(action.icon),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
