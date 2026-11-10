import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/clipboard/forum_clipboard_runtime.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';

import '../test_support/localized_test_app.dart';

void main() {
  testWidgets(
    'folding preserves one detail instance, list position and detail stack',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      final source = fixture.source.currentState!;
      source.scroll.jumpTo(240);
      source.show('one', key: fixture.detail);
      await tester.pumpAndSettle();
      final detail = fixture.detail.currentState!;
      detail.scroll.jumpTo(350);
      expect(find.text('source'), findsOneWidget);
      expect(fixture.controller.hasDetail, isTrue);
      await tester.tap(find.byKey(const Key('adaptive-detail-expand')));
      await tester.pumpAndSettle();
      expect(fixture.controller.expanded, isTrue);
      expect(find.text('source'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.controller.expanded, isFalse);
      expect(fixture.detail.currentState, same(detail));

      tester.view.physicalSize = const Size(400, 900);
      await tester.pumpAndSettle();
      expect(fixture.detail.currentState, same(detail));
      expect(detail.scroll.offset, 350);
      expect(fixture.source.currentState, same(source));
      expect(source.scroll.offset, 240);
      expect(find.text('source'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.controller.hasDetail, isFalse);
      expect(find.text('source'), findsOneWidget);
      expect(source.scroll.offset, 240);
    },
  );

  testWidgets('toolbar back restores panes before popping the detail stack', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    fixture.source.currentState!.scroll.jumpTo(240);
    fixture.source.currentState!.show('one', key: fixture.detail);
    await tester.pumpAndSettle();
    final first = fixture.detail.currentState!;
    first.scroll.jumpTo(350);
    final secondKey = GlobalKey<_DetailState>();
    unawaited(
      openAdaptiveDetail(
        fixture.detail.currentContext!,
        MaterialPageRoute<void>(
          builder: (_) => _Detail(id: 'two', key: secondKey),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final second = secondKey.currentState!;
    second.scroll.jumpTo(450);
    await tester.tap(find.byKey(const Key('adaptive-detail-expand')));
    await tester.pumpAndSettle();
    expect(fixture.controller.expanded, isTrue);
    await tester.tap(find.byKey(const Key('adaptive-detail-back')));
    await tester.pumpAndSettle();
    expect(fixture.controller.expanded, isFalse);
    expect(secondKey.currentState, same(second));
    expect(second.scroll.offset, 450);
    expect(fixture.source.currentState!.scroll.offset, 240);
    await tester.tap(find.byKey(const Key('adaptive-detail-back')));
    await tester.pumpAndSettle();
    expect(secondKey.currentState, isNull);
    expect(fixture.detail.currentState, same(first));
    expect(first.scroll.offset, 350);
    await tester.tap(find.byKey(const Key('adaptive-detail-back')));
    await tester.pumpAndSettle();
    expect(fixture.controller.hasDetail, isFalse);
    expect(find.text('source'), findsOneWidget);
  });

  testWidgets(
    'new source selection replaces detail, root reading route retires hidden dispatch',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      fixture.source.currentState!.show('one');
      await tester.pumpAndSettle();
      fixture.source.currentState!.show('two');
      await tester.pumpAndSettle();
      expect(find.text('one'), findsNothing);
      expect(find.text('two'), findsOneWidget);
      unawaited(
        fixture.navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('reader')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(isAdaptiveSourceCurrent(fixture.source.currentContext!), isFalse);
      fixture.source.currentState!.show('late');
      fixture.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('two'), findsOneWidget);
      expect(find.text('late'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(fixture.controller.hasDetail, isFalse);
      expect(find.text('source'), findsOneWidget);
    },
  );

  testWidgets(
    'nested popup blocks clipboard and source dispatch only while active',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);
      await fixture.pump(tester);
      fixture.source.currentState!.show('one', key: fixture.detail);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        fixture.source.currentContext!,
      );
      final routes = container.read(forumClipboardRouteObserverProvider);
      expect(routes.isBlocked, isFalse);
      unawaited(
        showModalBottomSheet<void>(
          context: fixture.detail.currentContext!,
          builder: (_) => const SizedBox(height: 100, child: Text('panel')),
        ),
      );
      await tester.pumpAndSettle();
      expect(routes.isBlocked, isTrue);
      expect(isAdaptiveSourceCurrent(fixture.source.currentContext!), isFalse);
      fixture.active.value = false;
      await tester.pumpAndSettle();
      expect(routes.isBlocked, isFalse);
      fixture.active.value = true;
      await tester.pumpAndSettle();
      expect(routes.isBlocked, isTrue);
      Navigator.of(fixture.detail.currentContext!).pop();
      await tester.pumpAndSettle();
      expect(routes.isBlocked, isFalse);
      expect(isAdaptiveSourceCurrent(fixture.source.currentContext!), isTrue);
    },
  );

  testWidgets('repeated system back consumes only the detail route', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    unawaited(
      Navigator.of(fixture.source.currentContext!).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('section'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      openAdaptiveDetail(
        tester.element(find.text('section')),
        MaterialPageRoute<void>(builder: (_) => const _Detail(id: 'thread')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('thread'), findsOneWidget);

    // 系统返回手势可能在同一帧重复派发；第二次不能继续弹掉来源分区页。
    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('thread'), findsNothing);
    expect(find.text('section'), findsOneWidget);
    expect(fixture.controller.hasDetail, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resetToRoot clears detail and source stacks', (tester) async {
    final fixture = _Fixture();
    addTearDown(fixture.dispose);
    await fixture.pump(tester);
    unawaited(
      Navigator.of(fixture.source.currentContext!).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('section'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      openAdaptiveDetail(
        tester.element(find.text('section')),
        MaterialPageRoute<void>(builder: (_) => const _Detail(id: 'thread')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('thread'), findsOneWidget);

    await fixture.controller.resetToRoot();
    await tester.pumpAndSettle();

    expect(find.text('thread'), findsNothing);
    expect(find.text('section'), findsNothing);
    expect(find.text('source'), findsOneWidget);
    expect(fixture.controller.hasDetail, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  final source = GlobalKey<_SourceState>();
  final detail = GlobalKey<_DetailState>();
  final navigator = GlobalKey<NavigatorState>();
  final controller = AdaptiveDetailController();
  final active = ValueNotifier(true);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: LocalizedTestApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: active,
              builder: (_, isActive, _) => AdaptiveDetailHost(
                controller: controller,
                isActive: isActive,
                child: _Source(key: source),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() {
    controller.dispose();
    active.dispose();
  }
}

class _Source extends StatefulWidget {
  const _Source({super.key});
  @override
  State<_Source> createState() => _SourceState();
}

class _SourceState extends State<_Source> {
  final scroll = ScrollController();
  void show(String id, {GlobalKey<_DetailState>? key}) {
    unawaited(
      openAdaptiveDetail(
        context,
        MaterialPageRoute<void>(
          builder: (_) => _Detail(id: id, key: key),
        ),
      ),
    );
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('source')),
    body: ListView.builder(
      controller: scroll,
      itemCount: 100,
      itemBuilder: (_, index) => SizedBox(height: 60, child: Text('$index')),
    ),
  );
}

class _Detail extends StatefulWidget {
  const _Detail({super.key, required this.id});
  final String id;
  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: adaptiveDetailBackButton(context),
      title: Text(widget.id),
      actions: const [AdaptiveDetailExpandAction()],
    ),
    body: ListView.builder(
      controller: scroll,
      itemCount: 100,
      itemBuilder: (_, index) =>
          SizedBox(height: 60, child: Text('body-$index')),
    ),
  );
}
