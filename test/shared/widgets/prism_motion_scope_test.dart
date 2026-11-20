import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/animated_visibility.dart';
import 'package:prism_ui/dialog.dart' as prism_dialog;
import 'package:prism_ui/motion.dart';
import 'package:prism_ui/navigation_dock.dart';
import 'package:prism_ui/press_region.dart';
import 'package:prism_ui/segmented_control.dart';
import 'package:y300/app/localization/app_prism_ui_localizations.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';
import 'package:y300/shared/widgets/reader_content_region.dart';

void main() {
  testWidgets('scope reduces prism durations without touching MediaQuery', (
    tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: PrismMotionScope(
          reduceMotion: true,
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(PrismMotion.reduce(captured), isTrue);
    expect(
      PrismMotion.duration(captured, const Duration(milliseconds: 280)),
      Duration.zero,
    );
    expect(MediaQuery.disableAnimationsOf(captured), isFalse);
  });

  testWidgets('scope falls back to the system reduce-motion flag', (
    tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(PrismMotion.reduce(captured), isTrue);
  });

  testWidgets('animated visibility finishes immediately when reduced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: PrismMotionScope(
          reduceMotion: true,
          child: Scaffold(
            body: AnimatedVisibility.sidebar(
              key: Key('reduced-visibility'),
              visible: true,
              child: Text('content'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('app motion and layout tokens follow the e-ink scope', (
    tester,
  ) async {
    late BuildContext fullContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            fullContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(AppMotion.reduceMotion(fullContext), isFalse);
    expect(
      AppMotion.duration(fullContext, const Duration(milliseconds: 120)),
      const Duration(milliseconds: 120),
    );
    expect(
      AppLayoutTokens.motionDuration(fullContext),
      AppLayoutTokens.feedbackDuration,
    );

    late BuildContext eInkContext;
    await tester.pumpWidget(
      MaterialApp(
        home: EInkModeScope(
          enabled: true,
          child: Builder(
            builder: (context) {
              eInkContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(AppMotion.reduceMotion(eInkContext), isTrue);
    expect(
      AppMotion.duration(eInkContext, const Duration(milliseconds: 120)),
      Duration.zero,
    );
    expect(AppLayoutTokens.motionDuration(eInkContext), Duration.zero);
  });

  testWidgets(
    'reader content region preserves root disableAnimations in eink',
    (tester) async {
      late BuildContext insideReader;
      await tester.pumpWidget(
        MaterialApp(
          home: EInkModeScope(
            enabled: true,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(600, 800),
                disableAnimations: true,
              ),
              child: ReaderContentRegion(
                backgroundColor: Colors.white,
                child: Builder(
                  builder: (context) {
                    insideReader = context;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(MediaQuery.disableAnimationsOf(insideReader), isTrue);
      expect(AppMotion.reduceMotion(insideReader), isTrue);
    },
  );

  testWidgets(
    'floating dialog uses zero transition duration under reduced motion',
    (tester) async {
      ModalRoute<dynamic>? pushed;
      final observer = _RecordingRouteObserver(
        onPush: (route) => pushed = route,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            AppPrismUiLocalizations.delegate,
          ],
          navigatorObservers: [observer],
          home: PrismMotionScope(
            reduceMotion: true,
            child: AppPrismTheme(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    prism_dialog.showFloatingDialog<void>(
                      context: context,
                      child: const Text('dialog-body'),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();

      expect(find.text('dialog-body'), findsOneWidget);
      expect(
        (pushed! as PopupRoute<dynamic>).transitionDuration,
        Duration.zero,
      );
    },
  );

  testWidgets(
    'segmented control, press region, and elastic press stay static',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PrismMotionScope(
            reduceMotion: true,
            child: AppPrismTheme(
              child: Column(
                children: [
                  SegmentedControl<int>(
                    segments: const [(0, 'A'), (1, 'B')],
                    value: 0,
                    onChanged: (_) {},
                  ),
                  PressRegion(
                    overlay: PressRegion.pressOverlay,
                    onTap: () {},
                    child: const SizedBox(width: 48, height: 48),
                  ),
                  const ElasticPress(
                    child: SizedBox(
                      key: Key('elastic-target'),
                      width: 48,
                      height: 48,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.duration, Duration.zero);
      final textStyle = tester.widget<AnimatedDefaultTextStyle>(
        find.byType(AnimatedDefaultTextStyle).first,
      );
      expect(textStyle.duration, Duration.zero);
      final overlayTween = tester.widget<TweenAnimationBuilder<Color?>>(
        find.byType(TweenAnimationBuilder<Color?>),
      );
      expect(overlayTween.duration, Duration.zero);

      final targetFinder = find.byKey(const Key('elastic-target'));
      final gesture = await tester.startGesture(tester.getCenter(targetFinder));
      await tester.pump(const Duration(milliseconds: 100));
      final box = tester.renderObject<RenderBox>(targetFinder);
      expect(ElasticPress.liftOf(box), 0);
      await gesture.up();
      await tester.pump();
    },
  );
}

class _RecordingRouteObserver extends NavigatorObserver {
  _RecordingRouteObserver({required this.onPush});

  final ValueChanged<ModalRoute<dynamic>> onPush;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is ModalRoute<dynamic>) {
      onPush(route);
    }
  }
}
