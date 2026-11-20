import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/shared/widgets/app_glass_environment.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  const backKey = Key('shared-reader-top-back-button');
  const moreKey = Key('shared-reader-top-action-more');
  const bookmarkKey = Key('shared-reader-top-action-bookmark');
  const openThreadKey = Key('shared-reader-top-action-open-thread');

  ReaderTopBarConfig barConfig({
    VoidCallback? onBookmark,
    VoidCallback? onOpenThread,
    List<ReaderToolbarMenuEntry> moreEntries = const [],
  }) {
    return ReaderTopBarConfig(
      title: '作品标题',
      subtitle: '章节标题',
      onBack: () {},
      actions: [
        ReaderToolbarAction(
          id: 'bookmark',
          icon: Icons.bookmark,
          label: '书签',
          onPressed: onBookmark ?? () {},
        ),
        ReaderToolbarAction(
          id: 'open-thread',
          icon: Icons.open_in_new,
          label: '原帖',
          onPressed: onOpenThread ?? () {},
        ),
        ReaderToolbarMenuAction(
          id: 'more',
          icon: Icons.more_vert,
          label: '更多',
          entries: moreEntries,
        ),
      ],
    );
  }

  Widget bar(
    ReaderTopBarConfig config, {
    AppGlassLevel? glassLevel,
    Size viewSize = const Size(800, 600),
    double textScale = 1,
  }) {
    return LocalizedTestApp(
      theme: AppTheme.light(),
      builder: (context, child) {
        final content = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: viewSize, textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
        return glassLevel == null
            ? content
            : AppGlassEnvironment(glassLevel: glassLevel, child: content);
      },
      home: Scaffold(body: ReaderTopOverlayBar(config: config)),
    );
  }

  Finder surfaceOf(Finder button) => find
      .descendant(
        of: find.ancestor(of: button, matching: find.byType(Stack)).first,
        matching: find.byType(AppGlassSurface),
      )
      .first;

  testWidgets(
    'top bar keeps back standalone and groups related actions before more',
    (tester) async {
      await tester.pumpWidget(
        bar(barConfig(), glassLevel: AppGlassLevel.standard),
      );

      final barRect = tester.getRect(
        find.byKey(const Key('shared-reader-top-overlay-bar')),
      );
      final back = tester.getRect(find.byKey(backKey));
      final title = tester.getRect(
        find.byKey(const Key('shared-reader-title-button')),
      );
      final bookmarkSurface = tester.getRect(
        surfaceOf(find.byKey(bookmarkKey)),
      );
      final moreSurface = tester.getRect(surfaceOf(find.byKey(moreKey)));
      final openThreadSurface = tester.getRect(
        surfaceOf(find.byKey(openThreadKey)),
      );

      // 返回独立；标题与动作、动作组之间各留 8，尾部留 12。
      expect(title.left - back.right, 8);
      expect(bookmarkSurface.left - title.right, 8);
      expect(moreSurface.left - bookmarkSurface.right, 8);
      expect(barRect.right - moreSurface.right, 12);

      // 相关动作共用一块胶囊玻璃，更多是独立圆键。
      expect(openThreadSurface, bookmarkSurface);
      expect(moreSurface.width, 48);
      expect(bookmarkSurface.width, 96);

      // 48 逻辑像素命中区不随玻璃视觉尺寸缩小。
      for (final finder in [
        find.byKey(backKey),
        find.byKey(bookmarkKey),
        find.byKey(openThreadKey),
        find.byKey(moreKey),
      ]) {
        expect(tester.getSize(finder).shortestSide, greaterThanOrEqualTo(48));
      }

      final titleText = tester.widget<Text>(
        find.byKey(const Key('shared-reader-top-title')),
      );
      expect(titleText.maxLines, 1);
      expect(titleText.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow screen and large text keep back and more', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(200, 600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      bar(
        barConfig(),
        glassLevel: AppGlassLevel.standard,
        viewSize: const Size(200, 600),
        textScale: 2,
      ),
    );

    expect(find.byKey(backKey), findsOneWidget);
    expect(find.byKey(moreKey), findsOneWidget);
    // 放不下的次要动作先收起，返回与更多始终保留。
    expect(find.byKey(bookmarkKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('more opens the anchored menu in order and picks once', (
    tester,
  ) async {
    final picked = <String>[];
    await tester.pumpWidget(
      bar(
        barConfig(
          moreEntries: [
            ReaderToolbarMenuEntry(
              id: 'refresh-episode',
              icon: Icons.refresh,
              label: '重新获取',
              onSelected: () => picked.add('refresh'),
            ),
            ReaderToolbarMenuEntry(
              id: 'mark-read-toggle',
              icon: Icons.check_circle_outline,
              label: '标记未读',
              enabled: false,
              onSelected: () => picked.add('mark-read'),
            ),
            ReaderToolbarMenuEntry(
              id: 'set-cover',
              icon: Icons.image_outlined,
              label: '设为封面',
              checked: true,
              danger: true,
              onSelected: () => picked.add('set-cover'),
            ),
          ],
        ),
        glassLevel: AppGlassLevel.standard,
      ),
    );

    await tester.tap(find.byKey(moreKey));
    await tester.pumpAndSettle();

    final refresh = find.byKey(
      const Key('shared-reader-action-refresh-episode'),
    );
    final markRead = find.byKey(
      const Key('shared-reader-action-mark-read-toggle'),
    );
    final setCover = find.byKey(const Key('shared-reader-action-set-cover'));
    expect(refresh, findsOneWidget);
    expect(markRead, findsOneWidget);
    expect(setCover, findsOneWidget);
    expect(
      tester.getTopLeft(refresh).dy,
      lessThan(tester.getTopLeft(markRead).dy),
    );
    expect(
      tester.getTopLeft(markRead).dy,
      lessThan(tester.getTopLeft(setCover).dy),
    );

    // 禁用项保留在菜单里，点击不执行也不关闭。
    await tester.tap(markRead);
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
    expect(refresh, findsOneWidget);

    await tester.tap(refresh);
    await tester.pump();
    expect(picked, ['refresh']);
    await tester.pumpAndSettle();
    // 选中项只执行一次，菜单已关闭。
    expect(picked, ['refresh']);
    expect(refresh, findsNothing);
  });

  testWidgets('more menu cancel closes without running an action', (
    tester,
  ) async {
    final picked = <String>[];
    await tester.pumpWidget(
      bar(
        barConfig(
          moreEntries: [
            ReaderToolbarMenuEntry(
              id: 'refresh-episode',
              label: '重新获取',
              onSelected: () => picked.add('refresh'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byKey(moreKey));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('shared-reader-action-refresh-episode')),
      findsOneWidget,
    );

    // 点外关闭。
    await tester.tapAt(
      tester.getBottomRight(find.byType(Scaffold)) - const Offset(8, 8),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('shared-reader-action-refresh-episode')),
      findsNothing,
    );
    expect(picked, isEmpty);

    // 返回键关闭。
    await tester.tap(find.byKey(moreKey));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('shared-reader-action-refresh-episode')),
      findsNothing,
    );
    expect(picked, isEmpty);
  });
}
