import 'package:flutter/material.dart';

import '../../test_support/localized_test_app.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/popup.dart' as prism;
import 'package:y300/shared/widgets/native_page_dropdown_button.dart';

void main() {
  testWidgets('opens near the current page and lazily builds page rows', (
    tester,
  ) async {
    int? selectedPage;
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: Center(
            child: NativePageDropdownButton(
              buttonKey: const Key('test-page-button'),
              menuKeyPrefix: 'test',
              currentPage: 75,
              lastPage: 100,
              hasMore: true,
              enabled: true,
              label: '第 75 页',
              style: TextButton.styleFrom(),
              onSelected: (page) => selectedPage = page,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('test-page-button')));
    await tester.pumpAndSettle();

    expect(find.byType(prism.PopupMenu), findsOneWidget);
    expect(find.byKey(const Key('test-page-list')), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    expect(
      tester.getCenter(find.byKey(const Key('test-page-menu'))).dx,
      closeTo(
        tester.getCenter(find.byKey(const Key('test-page-button'))).dx,
        1,
      ),
    );
    expect(find.byKey(const Key('test-page-option-75')), findsOneWidget);
    expect(find.byKey(const Key('test-page-option-1')), findsNothing);

    await tester.tap(find.byKey(const Key('test-page-option-78')));
    await tester.pumpAndSettle();

    expect(selectedPage, 78);
    expect(find.byKey(const Key('test-page-list')), findsNothing);
  });

  testWidgets('unknown total only exposes the next known reachable page', (
    tester,
  ) async {
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: Center(
            child: NativePageDropdownButton(
              buttonKey: const Key('unknown-total-page-button'),
              menuKeyPrefix: 'unknown-total',
              currentPage: 4,
              lastPage: null,
              hasMore: true,
              enabled: true,
              label: '第 4 页',
              style: TextButton.styleFrom(),
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('unknown-total-page-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('unknown-total-page-option-5')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('unknown-total-page-option-6')), findsNothing);
  });

  testWidgets('large page counts build lazily and push onto root navigator', (
    tester,
  ) async {
    final root = GlobalKey<NavigatorState>();
    final nested = GlobalKey<NavigatorState>();
    int? selectedPage;
    await tester.pumpWidget(
      LocalizedTestApp(
        navigatorKey: root,
        home: Scaffold(
          body: Navigator(
            key: nested,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: NativePageDropdownButton(
                      buttonKey: const Key('large-page-button'),
                      menuKeyPrefix: 'large',
                      currentPage: 1000,
                      lastPage: 2000,
                      hasMore: true,
                      enabled: true,
                      label: '第 1000 页',
                      style: TextButton.styleFrom(),
                      onSelected: (page) => selectedPage = page,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('large-page-button')));
    await tester.pumpAndSettle();

    final menuFinder = find.byKey(const Key('large-page-menu'));
    expect(menuFinder, findsOneWidget);
    expect(Navigator.of(tester.element(menuFinder)), same(root.currentState));
    expect(
      Navigator.of(tester.element(menuFinder)),
      isNot(same(nested.currentState)),
    );
    expect(find.byKey(const Key('large-page-option-1000')), findsOneWidget);
    expect(find.byKey(const Key('large-page-option-1')), findsNothing);
    expect(find.byKey(const Key('large-page-option-2000')), findsNothing);

    await tester.tap(find.byKey(const Key('large-page-option-1001')));
    await tester.pumpAndSettle();
    expect(selectedPage, 1001);
  });
}
