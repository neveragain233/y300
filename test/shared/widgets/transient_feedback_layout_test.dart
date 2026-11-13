import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/transient_feedback_layout.dart';

void main() {
  testWidgets(
    'existing queue moves with overlays without restarting its lifetime',
    (tester) async {
      final height = ValueNotifier(100.0);
      final keyboard = ValueNotifier(0.0);
      final active = ValueNotifier(true);
      addTearDown(height.dispose);
      addTearDown(keyboard.dispose);
      addTearDown(active.dispose);
      final messenger = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messenger,
          home: ListenableBuilder(
            listenable: Listenable.merge([height, keyboard, active]),
            builder: (context, _) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewInsets: EdgeInsets.only(bottom: keyboard.value)),
              child: TransientFeedbackLayout(
                bottomOverlap: height.value,
                child: Scaffold(
                  body: TickerMode(
                    enabled: active.value,
                    child: const TransientFeedbackObstacle(
                      bottom: 160,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var undo = 0;
      final notice = messenger.currentState!.showSnackBar(
        SnackBar(
          content: const Text('notice'),
          duration: const Duration(seconds: 4),
          persist: false,
          action: SnackBarAction(label: 'undo', onPressed: () => undo++),
        ),
      );
      await tester.pumpAndSettle();
      final original = tester.getRect(find.text('notice'));
      active.value = false;
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('notice')).top - original.top,
        closeTo(60, 1),
      );
      height.value = 0;
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('notice')).top - original.top,
        closeTo(160, 1),
      );
      keyboard.value = 200;
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('notice')).bottom, lessThan(400));
      await tester.tap(find.text('undo'));
      await tester.pumpAndSettle();
      expect(undo, 1);
      expect(await notice.closed, SnackBarClosedReason.action);
      keyboard.value = 0;
      final timed = messenger.currentState!.showSnackBar(
        const SnackBar(content: Text('timed'), duration: Duration(seconds: 2)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));
      height.value = 80;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();
      expect(await timed.closed, SnackBarClosedReason.timeout);
      expect(tester.takeException(), isNull);
    },
  );
}
