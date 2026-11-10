import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/shared/widgets/y300_page_scaffold.dart';

import '../../test_support/localized_test_app.dart';

void main() {
  testWidgets('hidden chrome releases and excludes keyboard focus', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    final focus = FocusNode();
    var actions = 0;
    addTearDown(visible.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, shown, _) => Y300PageScaffold(
            toolbarVisible: shown,
            appBar: AppBar(
              actions: [
                IconButton(
                  focusNode: focus,
                  onPressed: () => actions++,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    visible.value = false;
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(focus.canRequestFocus, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(actions, 0);
    visible.value = true;
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('bottom input stays above keyboard with safe area applied once', (
    tester,
  ) async {
    final keyboard = ValueNotifier(0.0);
    addTearDown(keyboard.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: ValueListenableBuilder<double>(
          valueListenable: keyboard,
          builder: (context, height, _) => MediaQuery(
            data: MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: height),
              padding: EdgeInsets.only(bottom: height == 0 ? 24 : 0),
              viewPadding: const EdgeInsets.only(bottom: 24),
            ),
            child: const Y300PageScaffold(
              body: SizedBox.expand(key: Key('reading-body')),
              bottomBar: SizedBox(
                height: 56,
                child: TextField(key: Key('reply-input')),
              ),
            ),
          ),
        ),
      ),
    );
    final before = tester.getRect(find.byKey(const Key('reading-body')));
    keyboard.value = 250;
    await tester.pumpAndSettle();
    final input = tester.getRect(find.byKey(const Key('reply-input')));
    final body = tester.getRect(find.byKey(const Key('reading-body')));
    expect(input.bottom, 600 - 250);
    expect(body.bottom, input.top);
    expect(before.bottom - body.bottom, 250 - 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'chrome visibility preserves content, scroll and safe area budget',
    (tester) async {
      final visible = ValueNotifier(true);
      final scroll = ScrollController();
      addTearDown(visible.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        LocalizedTestApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(top: 24, bottom: 24),
              viewPadding: EdgeInsets.only(top: 24, bottom: 24),
              disableAnimations: true,
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, shown, _) => Y300PageScaffold(
                appBar: AppBar(title: const Text('toolbar')),
                toolbarVisible: shown,
                bottomBarVisible: shown,
                bottomBar: const SizedBox(height: 56),
                body: ListView.builder(
                  key: const Key('content'),
                  controller: scroll,
                  itemCount: 100,
                  itemBuilder: (_, index) =>
                      SizedBox(height: 64, child: Text('$index')),
                ),
              ),
            ),
          ),
        ),
      );
      scroll.jumpTo(300);
      await tester.pump();
      final rect = tester.getRect(find.byKey(const Key('content')));
      visible.value = false;
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('content'))), rect);
      expect(scroll.offset, 300);
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide).first).duration,
        Duration.zero,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
