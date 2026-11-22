import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/app_capsule_tab_bar.dart';

void main() {
  testWidgets('null or out-of-range selectedIndex leaves all tabs unselected', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      var tapped = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCapsuleTabBar(
              tabs: const <AppCapsuleTabItem>[
                AppCapsuleTabItem(id: 'all', label: '全部'),
                AppCapsuleTabItem(id: 'latest', label: '最新'),
              ],
              selectedIndex: null,
              onTap: (index) => tapped = index,
              indicatorKey: const Key('indicator'),
              tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('indicator')), findsNothing);
      final allSemantics = tester.getSemantics(
        find.byKey(const ValueKey<String>('tab-all')),
      );
      expect(allSemantics.flagsCollection.isButton, isTrue);
      expect(allSemantics.flagsCollection.isSelected, Tristate.isFalse);

      await tester.tap(find.byKey(const ValueKey<String>('tab-latest')));
      expect(tapped, 1);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets(
    'preferredHeight matches custom padding and grows with text scale',
    (tester) async {
      const padding = EdgeInsets.fromLTRB(16, 4, 8, 4);
      late double normalHeight;
      late double largeHeight;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                normalHeight = AppCapsuleTabBar.preferredHeight(
                  context,
                  labels: const <String>['全部', '最新'],
                  padding: padding,
                );
                return AppCapsuleTabBar(
                  tabs: const <AppCapsuleTabItem>[
                    AppCapsuleTabItem(id: 'all', label: '全部'),
                    AppCapsuleTabItem(id: 'latest', label: '最新'),
                  ],
                  selectedIndex: 0,
                  padding: padding,
                  onTap: (_) {},
                  indicatorKey: const Key('indicator'),
                  tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(normalHeight, 56);
      expect(
        tester.getSize(find.byType(AppCapsuleTabBar)).height,
        closeTo(normalHeight, 1),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey<String>('tab-all'))).left,
        16,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  largeHeight = AppCapsuleTabBar.preferredHeight(
                    context,
                    labels: const <String>['全部', '一个很长的筛选标签'],
                    padding: padding,
                  );
                  return AppCapsuleTabBar(
                    tabs: const <AppCapsuleTabItem>[
                      AppCapsuleTabItem(id: 'all', label: '全部'),
                      AppCapsuleTabItem(id: 'long', label: '一个很长的筛选标签'),
                    ],
                    selectedIndex: 1,
                    padding: padding,
                    onTap: (_) {},
                    indicatorKey: const Key('indicator'),
                    tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(largeHeight, greaterThan(normalHeight));
      expect(
        tester.getSize(find.byType(AppCapsuleTabBar)).height,
        closeTo(largeHeight, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
