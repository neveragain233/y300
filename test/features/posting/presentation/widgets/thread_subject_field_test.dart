import 'package:flutter/material.dart';

import '../../../../test_support/localized_test_app.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/posting/presentation/widgets/thread_subject_field.dart';
import 'package:y300/shared/widgets/app_text_input.dart';

void main() {
  Widget wrap(Widget child) => LocalizedTestApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );

  testWidgets('uses underline-only decoration', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(ThreadSubjectField(controller: controller, onChanged: (_) {})),
    );

    final field = tester.widget<AppTextInput>(find.byType(AppTextInput));
    expect(field.variant, AppTextInputVariant.underline);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(AnimatedContainer), findsOneWidget);
  });
}
