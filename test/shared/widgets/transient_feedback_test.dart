import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

void main() {
  testWidgets('transient snackbar keeps its queue slot and undo action', (
    tester,
  ) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    var undone = 0;
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    showTransientSnackBar(
      pageContext,
      '已取消收藏本版',
      snackBarKey: const Key('transient-feedback'),
      action: SnackBarAction(label: '撤销', onPressed: () => undone++),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transient-feedback')), findsOneWidget);
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final scheme = AppTheme.light().colorScheme;
    expect(snackBar.duration, kTransientSnackBarActionDuration);
    expect(snackBar.persist, isFalse);
    expect(snackBar.dismissDirection, DismissDirection.down);
    expect(snackBar.backgroundColor, scheme.surfaceContainerLowest);
    expect(snackBar.action?.textColor, scheme.primary);
    expect(snackBar.shape, isA<RoundedRectangleBorder>());

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(undone, 1);
  });

  testWidgets('plain toast uses 3s persist=false and e-ink flat border', (
    tester,
  ) async {
    var eInkEnabled = true;
    late StateSetter setHostState;
    late BuildContext pageContext;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return MaterialApp(
            theme: AppTheme.light(),
            home: EInkModeScope(
              enabled: eInkEnabled,
              child: Builder(
                builder: (context) {
                  pageContext = context;
                  return const Scaffold(body: SizedBox.expand());
                },
              ),
            ),
          );
        },
      ),
    );

    showTransientSnackBar(
      pageContext,
      '墨水屏提示',
      snackBarKey: const Key('eink-toast'),
    );
    await tester.pumpAndSettle();

    final eInkSnackBar = tester.widget<SnackBar>(
      find.byKey(const Key('eink-toast')),
    );
    final scheme = AppTheme.light().colorScheme;
    expect(eInkSnackBar.duration, kTransientSnackBarDuration);
    expect(eInkSnackBar.persist, isFalse);
    expect(eInkSnackBar.elevation, 0);
    expect(eInkSnackBar.backgroundColor, scheme.surface);
    expect(
      eInkSnackBar.shape,
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.eInkBorderColor(scheme.brightness)),
      ),
    );

    // Switching off e-ink must restore non-zero entrance/exit duration instead
    // of leaving ScaffoldMessenger's animation controller stuck at zero.
    setHostState(() => eInkEnabled = false);
    await tester.pump();
    showTransientSnackBar(
      pageContext,
      '正常提示',
      snackBarKey: const Key('normal-toast'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final midOpacity = tester
        .getTopLeft(find.byKey(const Key('normal-toast')))
        .dy;
    await tester.pumpAndSettle();
    final finalTop = tester
        .getTopLeft(find.byKey(const Key('normal-toast')))
        .dy;
    expect(midOpacity, greaterThan(finalTop));

    // Confirm auto-dismiss after the 3s timeout plus reverse animation.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('normal-toast')), findsNothing);
  });

  testWidgets('showTransientSnackBarWithMessenger uses captured style', (
    tester,
  ) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    late TransientFeedbackStyle style;
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            style = TransientFeedbackStyle.capture(context);
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    showTransientSnackBarWithMessenger(
      messengerKey.currentState,
      style,
      '标题',
      detail: '补充细节',
      snackBarKey: const Key('captured-toast'),
    );
    await tester.pumpAndSettle();

    expect(find.text('标题'), findsOneWidget);
    expect(find.text('补充细节'), findsOneWidget);
  });

  testWidgets('transient snackbar ignores blank messages', (tester) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );

    showTransientSnackBar(pageContext, '   ');
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}
