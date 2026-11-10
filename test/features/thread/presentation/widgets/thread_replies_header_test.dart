import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_theme.dart';
import 'package:y300/features/thread/presentation/widgets/thread_replies_header.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets('shows selected filters and invokes only an order change', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var authorToggles = 0;
    final orders = <bool>[];

    await tester.pumpWidget(
      _app(
        onToggleAuthorFilter: () => authorToggles++,
        onOrderChanged: orders.add,
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadRepliesHeader)),
    );
    expect(find.text(l10n.threadDetailReplyCount(38)), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const Key('thread-replies-normal-order')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('thread-replies-author-filter')))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );

    await tester.tap(find.byKey(const Key('thread-replies-normal-order')));
    expect(orders, isEmpty);
    await tester.tap(find.byKey(const Key('thread-replies-reverse-order')));
    await tester.tap(find.byKey(const Key('thread-replies-author-filter')));
    expect(orders, [true]);
    expect(authorToggles, 1);

    await tester.pumpWidget(
      _app(
        isOnlyAuthor: true,
        isReverseOrder: true,
        onToggleAuthorFilter: () => authorToggles++,
        onOrderChanged: orders.add,
      ),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('thread-replies-author-filter')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('thread-replies-reverse-order')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    await tester.tap(find.byKey(const Key('thread-replies-reverse-order')));
    expect(orders, [true]);
    await tester.tap(find.byKey(const Key('thread-replies-normal-order')));
    expect(orders, [true, false]);
    semantics.dispose();
  });

  testWidgets(
    'disables filters during loading and supports a read-only count',
    (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        _app(
          enabled: false,
          onToggleAuthorFilter: () => changes++,
          onOrderChanged: (_) => changes++,
        ),
      );
      for (final button in tester.widgetList<TextButton>(
        find.byType(TextButton),
      )) {
        expect(button.onPressed, isNull);
      }
      await tester.tap(find.byKey(const Key('thread-replies-author-filter')));
      expect(changes, 0);

      await tester.pumpWidget(_app(replyCount: 0));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThreadRepliesHeader)),
      );
      expect(find.text(l10n.threadDetailReplyCount(0)), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    },
  );

  for (final locale in [const Locale('zh'), const Locale('zh', 'TW')]) {
    for (final brightness in Brightness.values) {
      testWidgets('fits narrow screens and large text in $locale $brightness', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final scale in [1.0, 1.3, 2.0]) {
          await tester.pumpWidget(
            _app(
              locale: locale,
              brightness: brightness,
              scale: scale,
              onToggleAuthorFilter: () {},
              onOrderChanged: (_) {},
            ),
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(ThreadRepliesHeader)),
          );
          expect(
            find.text(l10n.threadDetailOnlyOriginalPoster),
            findsOneWidget,
          );
          expect(find.text(l10n.threadDetailAscendingOrder), findsOneWidget);
          expect(find.text(l10n.threadDetailDescendingOrder), findsOneWidget);
          expect(tester.takeException(), isNull);
          for (final button in find.byType(TextButton).evaluate()) {
            final size = tester.getSize(find.byWidget(button.widget));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
        }
      });
    }
  }
}

Widget _app({
  int replyCount = 38,
  bool isOnlyAuthor = false,
  bool isReverseOrder = false,
  bool enabled = true,
  double scale = 1,
  Locale locale = const Locale('zh'),
  Brightness brightness = Brightness.light,
  VoidCallback? onToggleAuthorFilter,
  ValueChanged<bool>? onOrderChanged,
}) {
  final theme = ThemeData(brightness: brightness);
  return LocalizedTestApp(
    locale: locale,
    theme: theme,
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: ThreadRepliesHeader(
            replyCount: replyCount,
            isOnlyAuthor: isOnlyAuthor,
            isReverseOrder: isReverseOrder,
            enabled: enabled,
            palette: ThreadDetailNativePalette.resolve(theme, continuous: true),
            onToggleAuthorFilter: onToggleAuthorFilter,
            onOrderChanged: onOrderChanged,
          ),
        ),
      ),
    ),
  );
}
