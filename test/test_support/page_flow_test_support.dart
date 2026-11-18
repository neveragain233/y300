import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds the single back button rendered inside [pageScope].
///
/// Page flow tests must resolve the current route instead of using a global
/// `find.byType(BackButton)`: the outgoing route stays in the tree while a
/// route transition runs, so a global finder can match two back buttons.
///
/// [pageScope] is the root of the page that owns the back button, for example
/// `find.byType(ProfileBlogDetailPage)` or a page-root key. When the scope does
/// not contain exactly one back button, the thrown [TestFailure] reports the
/// scope and the number of back buttons in the whole tree, so the failing
/// route is easy to locate.
Finder backButtonIn(Finder pageScope) {
  final backButton = find.descendant(
    of: pageScope,
    matching: find.byType(BackButton),
  );
  final count = backButton.evaluate().length;
  if (count == 1) {
    return backButton;
  }
  final globalCount = find.byType(BackButton).evaluate().length;
  throw TestFailure(
    'Expected exactly one BackButton inside $pageScope, found $count '
    '(find.byType(BackButton) matches $globalCount in the whole tree). '
    'Pass the root Finder of the route that owns the back button.',
  );
}

/// Taps the page-scoped back button and, by default, settles the route.
///
/// Pass `settle: false` when the test drives the transition with explicit
/// pumps, such as observing a pending command before it completes.
Future<void> tapBack(
  WidgetTester tester, {
  required Finder within,
  bool settle = true,
}) async {
  await tester.tap(backButtonIn(within));
  if (settle) {
    await tester.pumpAndSettle();
  }
}
