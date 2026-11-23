import 'package:flutter/widgets.dart';

import 'reader_page_turn_models.dart';
import 'reader_paper_turn.dart';
import 'reader_sheet_motion.dart';

/// 整页级翻页容器：在非平移模式下抵消 `PageView` 轨道位移并封底防透底。
class ReaderSheetPageTransition extends StatelessWidget {
  const ReaderSheetPageTransition({
    super.key,
    required this.controller,
    required this.index,
    required this.effect,
    required this.reverse,
    required this.surfaceColor,
    this.paperClock,
    required this.child,
  });

  final PageController controller;
  final int index;
  final ReaderPageEffect effect;
  final bool reverse;
  final Color surfaceColor;
  final ReaderPaperClock? paperClock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (effect == ReaderPageEffect.slide) {
      return child;
    }
    final physicalReverse =
        reverse != (Directionality.of(context) == TextDirection.rtl);
    final sheetBody = ReaderPaperTurn(
      clock: paperClock,
      controller: controller,
      index: index,
      reverse: physicalReverse,
      enabled: effect == ReaderPageEffect.paper,
      paperColor: surfaceColor,
      child: ReaderSheetMotion(
        controller: controller,
        index: index,
        effect: effect,
        reverse: physicalReverse,
        // 覆盖、渐隐与卷曲期间下层页面仍在同位置绘制，需用不透明底色封底，
        // 避免透过图片留白或页间距看到下一话/下一张图。
        child: ColoredBox(
          color: surfaceColor,
          child: RepaintBoundary(child: child),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: controller,
          child: sheetBody,
          builder: (context, body) {
            final page =
                controller.hasClients &&
                    controller.position.hasContentDimensions
                ? controller.page ?? controller.initialPage.toDouble()
                : controller.initialPage.toDouble();
            final offset = index - page;
            return Transform.translate(
              offset: Offset(
                -offset * constraints.maxWidth * (physicalReverse ? -1 : 1),
                0,
              ),
              child: IgnorePointer(ignoring: offset.abs() > 0.001, child: body),
            );
          },
        );
      },
    );
  }
}
