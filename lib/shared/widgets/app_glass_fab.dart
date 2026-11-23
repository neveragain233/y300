import 'package:flutter/material.dart';
import 'package:prism_ui/navigation_dock.dart' show ElasticPress;
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

/// 应用共享的 Prism 液态玻璃 / E-ink 实色悬浮操作按钮。
///
/// 当 [label] 为 null 时呈现 56x56 圆形按钮；非空时呈现带文字标签的胶囊按钮。
/// 非墨水屏且未开启减少动态效果时，外层接入 [ElasticPress] 提供按压膨胀、
/// 拖拽跟随与松手回弹；墨水屏与减少动态效果模式禁用动画、水波纹与投影，
/// 并使用高对比实色描边。
class AppGlassFloatingActionButton extends StatelessWidget {
  const AppGlassFloatingActionButton({
    super.key,
    this.buttonKey,
    required this.onPressed,
    required this.icon,
    this.label,
    this.tooltip,
    this.heroTag,
  });

  final Key? buttonKey;
  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final String? tooltip;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eInk = EInkModeScope.of(context);
    final reduceMotion = AppMotion.reduceMotion(context);
    final enabled = onPressed != null;
    final glassActive =
        AppGlassSurface.levelOf(context).enabled &&
        !eInk &&
        !MediaQuery.highContrastOf(context);
    final foreground = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.38);

    final Widget fab;
    final labelText = label;
    if (labelText == null) {
      fab = glassActive
          ? FloatingActionButton(
              key: buttonKey,
              heroTag: heroTag,
              onPressed: onPressed,
              tooltip: tooltip,
              backgroundColor: Colors.transparent,
              foregroundColor: foreground,
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              disabledElevation: 0,
              shape: const CircleBorder(),
              child: AppGlassSurface(
                borderRadius: 28,
                child: SizedBox.square(
                  dimension: 56,
                  child: Center(child: Icon(icon, color: foreground)),
                ),
              ),
            )
          : FloatingActionButton(
              key: buttonKey,
              heroTag: heroTag,
              onPressed: onPressed,
              tooltip: tooltip,
              backgroundColor: eInk
                  ? scheme.surface
                  : scheme.surfaceContainerHigh,
              foregroundColor: foreground,
              elevation: eInk ? 0 : null,
              highlightElevation: eInk ? 0 : null,
              focusElevation: eInk ? 0 : null,
              hoverElevation: eInk ? 0 : null,
              disabledElevation: eInk ? 0 : null,
              shape: eInk
                  ? CircleBorder(
                      side: BorderSide(
                        color: AppTheme.eInkBorderColor(scheme.brightness),
                      ),
                    )
                  : const CircleBorder(),
              child: Icon(icon),
            );
    } else {
      fab = glassActive
          ? FloatingActionButton.extended(
              key: buttonKey,
              heroTag: heroTag,
              onPressed: onPressed,
              tooltip: tooltip,
              backgroundColor: Colors.transparent,
              foregroundColor: foreground,
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              disabledElevation: 0,
              shape: const StadiumBorder(),
              extendedPadding: EdgeInsets.zero,
              extendedIconLabelSpacing: 0,
              label: AppGlassSurface(
                borderRadius: 28,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 20, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: foreground),
                        const SizedBox(width: 8),
                        Text(
                          labelText,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : FloatingActionButton.extended(
              key: buttonKey,
              heroTag: heroTag,
              onPressed: onPressed,
              tooltip: tooltip,
              backgroundColor: eInk
                  ? scheme.surface
                  : scheme.surfaceContainerHigh,
              foregroundColor: foreground,
              elevation: eInk ? 0 : null,
              highlightElevation: eInk ? 0 : null,
              focusElevation: eInk ? 0 : null,
              hoverElevation: eInk ? 0 : null,
              disabledElevation: eInk ? 0 : null,
              shape: eInk
                  ? StadiumBorder(
                      side: BorderSide(
                        color: AppTheme.eInkBorderColor(scheme.brightness),
                      ),
                    )
                  : const StadiumBorder(),
              icon: Icon(icon),
              label: Text(labelText),
            );
    }

    if (reduceMotion) {
      return fab;
    }
    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      child: ElasticPress(enabled: enabled, child: fab),
    );
  }
}
