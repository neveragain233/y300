import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/navigation/main_destination_stack.dart';

void main() {
  testWidgets('switches animate through rebuilds and keep page state', (
    tester,
  ) async {
    late StateSetter update;
    var index = 0;
    var revision = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MainDestinationStack(
                index: index,
                children: [
                  TextField(
                    key: const Key('first'),
                    decoration: InputDecoration(labelText: '$revision'),
                  ),
                  const TextField(key: Key('second')),
                ],
              );
            },
          ),
        ),
      ),
    );
    final first = tester.element(find.byKey(const Key('first')));
    await tester.enterText(find.byKey(const Key('first')), '保留输入');
    FadeTransition transition() =>
        tester.widget(find.byKey(const Key('main-destination-transition')));
    update(() => index = 1);
    await tester.pump();
    expect(transition().opacity.value, 0);
    await tester.pump(const Duration(milliseconds: 30));
    final progress = transition().opacity.value;
    expect(progress, inExclusiveRange(0, 1));
    update(() => revision++);
    await tester.pump(const Duration(milliseconds: 30));
    expect(transition().opacity.value, greaterThan(progress));
    update(() => index = 0);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.element(find.byKey(const Key('first'))), same(first));
    expect(find.text('保留输入'), findsOneWidget);
    expect(transition().opacity.value, 1);
  });

  testWidgets('reduced motion switches immediately', (tester) async {
    late StateSetter update;
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return MainDestinationStack(
                index: index,
                children: const [Text('一'), Text('二')],
              );
            },
          ),
        ),
      ),
    );
    update(() => index = 1);
    await tester.pump();
    final transition = tester.widget<FadeTransition>(
      find.byKey(const Key('main-destination-transition')),
    );
    expect(transition.opacity.value, 1);
    expect(find.text('二'), findsOneWidget);
  });
}
