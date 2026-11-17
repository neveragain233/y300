import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
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
    expect(snackBar.duration, const Duration(seconds: 4));
    expect(snackBar.backgroundColor, scheme.surfaceContainerLowest);
    expect(snackBar.action?.textColor, scheme.primary);
    expect(snackBar.shape, isA<RoundedRectangleBorder>());

    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(undone, 1);
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
