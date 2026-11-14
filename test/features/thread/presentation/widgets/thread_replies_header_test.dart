import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_theme.dart';
import 'package:y300/features/thread/presentation/widgets/thread_replies_header.dart';
import 'package:y300/l10n/app_localizations.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  testWidgets('exposes one order toggle with the current order as its value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var orderToggles = 0;
    var authorToggles = 0;

    await tester.pumpWidget(
      _app(
        onToggleAuthorFilter: () => authorToggles++,
        onToggleOrder: () => orderToggles++,
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadRepliesHeader)),
    );
    expect(find.text(l10n.threadDetailReplyCount(38)), findsOneWidget);
    final order = find.byKey(const Key('thread-replies-order-toggle'));
    final orderSemantics = tester.getSemantics(order);
    expect(orderSemantics.label, l10n.threadDetailReplyOrder);
    expect(orderSemantics.value, l10n.threadDetailAscendingOrder);
    expect(orderSemantics.flagsCollection.isButton, isTrue);
    expect(
      tester
          .getSemantics(find.byKey(const Key('thread-replies-author-filter')))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );

    // 两个视觉标签同属一个操作：点任一侧只切换一次。
    await tester.tap(find.text(l10n.threadDetailDescendingOrder));
    await tester.tap(find.text(l10n.threadDetailAscendingOrder));
    expect(orderToggles, 2);
    await tester.tap(find.byKey(const Key('thread-replies-author-filter')));
    expect(authorToggles, 1);

    await tester.pumpWidget(
      _app(
        isOnlyAuthor: true,
        isReverseOrder: true,
        onToggleAuthorFilter: () => authorToggles++,
        onToggleOrder: () => orderToggles++,
      ),
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('thread-replies-author-filter')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(tester.getSemantics(order).value, l10n.threadDetailDescendingOrder);
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
          onToggleOrder: () => changes++,
        ),
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('thread-replies-author-filter')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(const Key('thread-replies-order-toggle')),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
      await tester.tap(find.byKey(const Key('thread-replies-author-filter')));
      expect(changes, 0);

      await tester.pumpWidget(_app(replyCount: 0));
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ThreadRepliesHeader)),
      );
      expect(find.text(l10n.threadDetailReplyCount(0)), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(
        find.byKey(const Key('thread-replies-order-toggle')),
        findsNothing,
      );
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
              onToggleOrder: () {},
            ),
          );
          final l10n = AppLocalizations.of(
            tester.element(find.byType(ThreadRepliesHeader)),
          );
          expect(find.text(l10n.threadDetailOnlyAuthor), findsOneWidget);
          expect(find.text(l10n.threadDetailAscendingOrder), findsOneWidget);
          expect(find.text(l10n.threadDetailDescendingOrder), findsOneWidget);
          expect(tester.takeException(), isNull);
          for (final button in find.byType(TextButton).evaluate()) {
            final size = tester.getSize(find.byWidget(button.widget));
            expect(size.width, greaterThanOrEqualTo(48));
            expect(size.height, greaterThanOrEqualTo(48));
          }
          final toggle = tester.getSize(
            find.byKey(const Key('thread-replies-order-toggle')),
          );
          expect(toggle.height, greaterThanOrEqualTo(48));
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
  VoidCallback? onToggleOrder,
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
            onToggleOrder: onToggleOrder,
            authorFilterKey: const Key('thread-replies-author-filter'),
            orderToggleKey: const Key('thread-replies-order-toggle'),
          ),
        ),
      ),
    ),
  );
}
