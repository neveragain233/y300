import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/shared/widgets/image_lightbox/image_lightbox_page.dart';

import '../../../test_support/localized_test_app.dart';

void main() {
  Widget buildHost({
    int itemCount = 3,
    int initialIndex = 0,
    bool eInk = false,
    Size resolvedSize = const Size(400, 3200),
    Future<String?> Function(int currentIndex, bool hasNavigated)? onBeforeExit,
    ValueChanged<String?>? onResult,
  }) {
    return LocalizedTestApp(
      home: EInkModeScope(
        enabled: eInk,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-lightbox'),
                onPressed: () async {
                  final result = await Navigator.of(context).push<String>(
                    buildImageLightboxRoute<String>(
                      builder: (_) => ImageLightboxPage<String>(
                        itemCount: itemCount,
                        initialIndex: initialIndex,
                        initialAspectRatioFor: (_) =>
                            resolvedSize.width / resolvedSize.height,
                        onBeforeExit: onBeforeExit,
                        actionsFor: (_, index) => [
                          ImageLightboxAction(
                            key: const Key('test-lightbox-action'),
                            icon: Icons.link_rounded,
                            tooltip: 'copy-$index',
                            onPressed: () {},
                          ),
                        ],
                        itemBuilder: (context, index, onSizeResolved) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            onSizeResolved(resolvedSize);
                          });
                          return SizedBox(
                            key: ValueKey<String>('lightbox-item-$index'),
                            width: 100,
                            height: 800,
                            child: const ColoredBox(color: Colors.blueGrey),
                          );
                        },
                      ),
                    ),
                  );
                  onResult?.call(result);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'single tap toggles HUD visibility and long image double-tap fits width',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildHost());
      await tester.tap(find.byKey(const Key('open-lightbox')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('image-lightbox-close-button')),
        findsOneWidget,
      );
      expect(find.text('1 / 3'), findsOneWidget);
      expect(
        find.byKey(const Key('image-lightbox-fit-toggle-button')),
        findsOneWidget,
      );

      // 单击隐藏工具栏
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final closeOpacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byKey(const Key('image-lightbox-close-button')),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(closeOpacity.opacity, 0.0);

      // 再次单击恢复工具栏
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final restoredOpacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.byKey(const Key('image-lightbox-close-button')),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      expect(restoredOpacity.opacity, 1.0);

      // 双击长图放大至满宽（4x）
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();

      final zoomedTransform = tester.widget<Transform>(
        find.byKey(const Key('image-lightbox-transform')),
      );
      expect(zoomedTransform.transform.getMaxScaleOnAxis(), closeTo(4.0, 0.05));

      // 放大后竖向拖拽不应关闭灯箱
      await tester.drag(
        find.byKey(const Key('image-lightbox-page-view')),
        const Offset(0, 220),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageLightboxPage<String>), findsOneWidget);

      // 再次双击复位至 1x
      await tester.tapAt(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tapAt(const Offset(200, 400));
      await tester.pumpAndSettle();

      final resetTransform = tester.widget<Transform>(
        find.byKey(const Key('image-lightbox-transform')),
      );
      expect(resetTransform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    },
  );

  testWidgets(
    'pull down dismisses past threshold and springs back when short',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? receivedResult;
      await tester.pumpWidget(
        buildHost(
          onBeforeExit: (index, navigated) async => 'exit:$index:$navigated',
          onResult: (value) => receivedResult = value,
        ),
      );
      await tester.tap(find.byKey(const Key('open-lightbox')));
      await tester.pumpAndSettle();

      // 短距离下拉松手后回弹，不退出
      await tester.drag(
        find.byKey(const Key('image-lightbox-page-view')),
        const Offset(0, 40),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageLightboxPage<String>), findsOneWidget);

      // 超过阈值下拉退出并等待 onBeforeExit
      await tester.drag(
        find.byKey(const Key('image-lightbox-page-view')),
        const Offset(0, 180),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ImageLightboxPage<String>), findsNothing);
      expect(receivedResult, 'exit:0:false');
    },
  );

  testWidgets(
    'keyboard ArrowRight pages LTR and Escape exits with navigation result',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? receivedResult;
      await tester.pumpWidget(
        buildHost(
          eInk: true,
          onBeforeExit: (index, navigated) async => 'exit:$index:$navigated',
          onResult: (value) => receivedResult = value,
        ),
      );
      await tester.tap(find.byKey(const Key('open-lightbox')));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ImageLightboxPage<String>), findsNothing);
      expect(receivedResult, 'exit:1:true');
    },
  );
}
