import 'package:flutter/material.dart';

/// Shared delete affordance for composer image cards.
///
/// The interaction target is 48dp so it meets the minimum touch size, while
/// the visual chip keeps its 40dp container with the smaller 24dp circle so
/// dense image grids remain easy to scan. The extra hit area grows inward,
/// leaving the chip itself flush with the card corner as before.
class ComposerImageDeleteButton extends StatelessWidget {
  const ComposerImageDeleteButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.visualKey,
    this.isBusy = false,
  });

  /// Minimum touch target; the visual chip stays [visualChipSize].
  static const double hitTargetSize = 48;

  /// Visual container that kept the original 40dp footprint.
  static const double visualChipSize = 40;

  final String tooltip;
  final VoidCallback? onPressed;
  final Key? visualKey;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !isBusy;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: SizedBox.square(
          dimension: hitTargetSize,
          child: Material(
            color: Colors.transparent,
            // 命中区保持整块 48 方形；圆形只用于视觉与墨水反馈，
            // 避免 Material 圆形裁剪把四角排除在触区之外。
            child: InkWell(
              onTap: enabled ? onPressed : null,
              customBorder: const CircleBorder(),
              // 命中区向内扩展，视觉圆钮继续贴住卡片角落，不在图片上位移。
              child: Align(
                alignment: AlignmentDirectional.topEnd,
                child: SizedBox.square(
                  dimension: visualChipSize,
                  child: Center(
                    child: DecoratedBox(
                      key: visualKey,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: 24,
                        child: isBusy
                            ? const Padding(
                                padding: EdgeInsets.all(5),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.close, size: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
