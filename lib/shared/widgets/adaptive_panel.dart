import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:y300/app/layout/app_window_layout.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

/// 辅助操作覆盖所属连续区域，不挤压底下的阅读或详情视口。
Future<T?> showAdaptivePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
}) {
  // 根页面操作覆盖主壳导航；阅读器与分栏详情默认仍归所属区域。
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
  final source = context.findRenderObject();
  final sourceCenter = source is RenderBox && source.hasSize
      ? source.localToGlobal(source.size.center(Offset.zero))
      : overlay.localToGlobal(overlay.size.center(Offset.zero));
  final anchor = overlay.globalToLocal(sourceCenter);
  final media = MediaQuery.of(navigator.context);
  final window = AppWindowLayout(
    size: overlay.size,
    displayFeatures: media.displayFeatures,
  );
  final region =
      window.regions.where((rect) => rect.contains(anchor)).firstOrNull ??
      window.readingRegion;
  if (region.width < 720 || region.height < 360) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      constraints: constraints,
      anchorPoint: anchor,
      sheetAnimationStyle: AppMotion.reduceMotion(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: builder,
    );
  }
  return showGeneralDialog<T>(
    context: context,
    anchorPoint: anchor,
    useRootNavigator: useRootNavigator,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: AppLayoutTokens.motionDuration(context),
    transitionBuilder: (_, animation, _, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(.05, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
    pageBuilder: (context, _, _) => LayoutBuilder(
      builder: (context, available) {
        final media = MediaQuery.of(context);
        final window = AppWindowLayout(
          size: available.biggest,
          displayFeatures: media.displayFeatures,
        );
        final region =
            window.regions.where((rect) => rect.contains(anchor)).firstOrNull ??
            window.readingRegion;
        final bottomInset = math.max(
          0.0,
          media.viewInsets.bottom - (available.maxHeight - region.bottom),
        );
        // 系统状态栏继续使用底下统一的顶栏表面，避免左右两侧需要相反图标明暗。
        final topInset = useSafeArea
            ? math.max(0.0, media.viewPadding.top - region.top)
            : 0.0;
        final panel = Rect.fromLTWH(
          region.right - math.min(480, region.width),
          region.top + topInset,
          math.min(480, region.width),
          math.max(0, region.height - topInset - bottomInset),
        );
        final localMedia = media
            .copyWith(size: available.biggest)
            .removeDisplayFeatures(panel)
            .copyWith(size: panel.size, viewInsets: EdgeInsets.zero);
        return Stack(
          children: [
            Positioned.fromRect(
              rect: panel,
              child: MediaQuery(
                data: localMedia,
                // 表面并入应用根玻璃宿主：关闭档与高对比回退主题实色，
                // 标准／增强档共用同一份背景捕获，不在这里新建宿主。
                child: AppGlassSurface(
                  key: const Key('adaptive-side-panel'),
                  borderRadius: AppLayoutTokens.panelRadius,
                  baseColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: SafeArea(
                    bottom: bottomInset == 0,
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            key: const Key('adaptive-panel-close'),
                            tooltip: AppLocalizations.of(context).commonClose,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                        Expanded(child: Builder(builder: builder)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
