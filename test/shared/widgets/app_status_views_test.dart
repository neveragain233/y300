import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/shared/widgets/app_status_views.dart';

void main() {
  Widget host(
    Widget child, {
    TextScaler textScaler = const TextScaler.linear(1),
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: appChild!,
      ),
      home: Scaffold(body: child),
    );
  }

  testWidgets('loading delays its indicator and announces one label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(const AppLoadingState(label: '正在读取帖子')));

    expect(find.byKey(AppLoadingState.labelKey), findsOneWidget);
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
    expect(find.bySemanticsLabel('正在读取帖子'), findsNothing);

    await tester.pump(const Duration(milliseconds: 299));
    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(AppLoadingState.indicatorKey), findsOneWidget);
    expect(find.bySemanticsLabel('正在读取帖子'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('loading keeps a readable label when animations are reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const AppLoadingState(label: '正在读取帖子'), disableAnimations: true),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(AppLoadingState.indicatorKey), findsNothing);
    expect(find.text('正在读取帖子'), findsOneWidget);
  });

  testWidgets('empty state shows its hierarchy and survives large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(260, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      host(
        const AppEmptyState(title: '暂无论坛版块', message: '下拉可以重新读取'),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无论坛版块'), findsOneWidget);
    expect(find.text('下拉可以重新读取'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state retries through a large enough target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var retries = 0;
    var secondary = 0;
    await tester.pumpWidget(
      host(
        AppErrorState(
          message: '读取失败，请稍后重试',
          retryLabel: '重试',
          retryKey: const Key('status-retry'),
          onRetry: () => retries++,
          secondaryAction: TextButton(
            key: const Key('status-secondary'),
            onPressed: () => secondary++,
            child: const Text('回到首页'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('读取失败，请稍后重试'), findsOneWidget);
    expect(find.bySemanticsLabel('读取失败，请稍后重试'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('status-retry'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('status-secondary'))).height,
      greaterThanOrEqualTo(48),
    );

    await tester.tap(find.byKey(const Key('status-retry')));
    await tester.pump();
    expect(retries, 1);

    await tester.tap(find.byKey(const Key('status-secondary')));
    await tester.pump();
    expect(secondary, 1);
    semantics.dispose();
  });

  testWidgets('error state allows scrolling at large text sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(260, 280);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      host(
        AppErrorState(
          message: '读取失败，请检查网络后重试',
          retryLabel: '重试',
          retryKey: const Key('status-retry-large'),
          onRetry: () {},
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('status-retry-large')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
