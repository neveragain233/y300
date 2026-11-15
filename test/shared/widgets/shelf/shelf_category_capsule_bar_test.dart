import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/shared/widgets/shelf/shelf_category_capsule_bar.dart';
import 'package:y300/shared/widgets/shelf/shelf_theme_palette.dart';

void main() {
  testWidgets('selected capsule uses the shelf selection palette', (
    tester,
  ) async {
    var tapped = -1;
    final palette = const ShelfThemePaletteResolver().resolve(
      ThemeData(useMaterial3: true, colorSchemeSeed: Colors.brown),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.brown),
        home: Scaffold(
          body: ShelfCategoryCapsuleBar(
            tabs: const <ShelfCategoryCapsuleTab>[
              ShelfCategoryCapsuleTab(id: 'a', label: '全部'),
              ShelfCategoryCapsuleTab(id: 'b', label: '漫画·追更'),
            ],
            selectedIndex: 0,
            onTap: (index) => tapped = index,
            indicatorKey: const Key('indicator'),
            tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('indicator')), findsOneWidget);
    final selected = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('tab-a')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final shape = selected.decoration! as ShapeDecoration;
    expect(shape.color, palette.categorySelectedBackground);

    await tester.tap(find.byKey(const ValueKey<String>('tab-b')));
    expect(tapped, 1);
  });

  testWidgets('overflowing capsules scroll the selected tab into view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ShelfCategoryCapsuleBar(
              tabs: const <ShelfCategoryCapsuleTab>[
                ShelfCategoryCapsuleTab(id: 'a', label: '全部'),
                ShelfCategoryCapsuleTab(id: 'b', label: '漫画·默认'),
                ShelfCategoryCapsuleTab(id: 'c', label: '漫画·追更'),
                ShelfCategoryCapsuleTab(id: 'd', label: '小说·默认'),
                ShelfCategoryCapsuleTab(id: 'e', label: '小说·追更'),
                ShelfCategoryCapsuleTab(id: 'f', label: '小说·已完结'),
              ],
              selectedIndex: 5,
              onTap: (_) {},
              indicatorKey: const Key('indicator'),
              tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey<String>('tab-f')));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
  });

  testWidgets('capsule bar grows with large text without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ShelfCategoryCapsuleBar(
              tabs: const <ShelfCategoryCapsuleTab>[
                ShelfCategoryCapsuleTab(id: 'a', label: '全部'),
                ShelfCategoryCapsuleTab(id: 'b', label: '漫画·一个很长的分类名称'),
              ],
              selectedIndex: 1,
              onTap: (_) {},
              indicatorKey: const Key('indicator'),
              tabKeyBuilder: (id) => ValueKey<String>('tab-$id'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('indicator')), findsOneWidget);
  });
}
