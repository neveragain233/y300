import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/animated_visibility.dart';
import 'package:prism_ui/motion.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';

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
}
