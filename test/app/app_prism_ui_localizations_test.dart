import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/l10n.dart';
import 'package:y300/app/localization/app_prism_ui_localizations.dart';

import '../test_support/localized_test_app.dart';

void main() {
  test('prism component chrome follows the app locales', () async {
    final simplified = await AppPrismUiLocalizations.delegate.load(
      const Locale('zh'),
    );
    expect(simplified.close, '关闭');
    expect(simplified.copy, '复制');
    expect(simplified.select, '选择');
    expect(simplified.showMore, '展开更多');

    final traditional = await AppPrismUiLocalizations.delegate.load(
      const Locale('zh', 'TW'),
    );
    expect(traditional.select, '選取');
    expect(traditional.showMore, '展開更多');
  });

  test('prism delegate only supports the app locales', () {
    const delegate = AppPrismUiLocalizations.delegate;
    expect(delegate.isSupported(const Locale('zh')), isTrue);
    expect(delegate.isSupported(const Locale('zh', 'TW')), isTrue);
    expect(delegate.isSupported(const Locale('en')), isFalse);
  });

  testWidgets('prism localizations are available on the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Builder(
          builder: (context) => Text(UiLocalizations.of(context).select),
        ),
      ),
    );
    expect(find.text('选择'), findsOneWidget);
  });
}
