part of 'blog_editor_page_test.dart';

void _layoutCases() {
  for (final submitting in [false, true]) {
    testWidgets(
      'account change during ${submitting ? 'save' : 'prepare'} drops all input and receipts',
      (tester) async {
        final service = BlogOperationFixture(autoPrepare: submitting);
        final host = await _open(tester, service);
        if (submitting) await _save(tester);
        host.changeActor('202');
        await tester.pump();
        host.changeActor('101');
        await tester.pump();
        if (submitting) {
          service.saved();
        } else {
          service.preparedEditor();
        }
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(
          find.text(_l10n(tester).forumWebViewAccountChanged),
          findsOneWidget,
        );
        expect(host.container.read(blogMutationBusProvider).last, isNull);
      },
    );

    testWidgets(
      'return during ${submitting ? 'save' : 'prepare'} cancels and ignores late completion',
      (tester) async {
        final service = BlogOperationFixture(autoPrepare: submitting);
        final host = await _open(tester, service);
        if (submitting) await _save(tester);
        await tapBack(
          tester,
          within: find.byType(BlogEditorPage),
          settle: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        if (submitting) {
          await tester.tap(find.byKey(const Key('blog-editor-leave')));
        }
        await tester.pumpAndSettle();
        final token = submitting
            ? service.editorSubmissions.last.input.cancellation
            : service.editorPreparations.last.cancellation;
        expect(token!.isCancelled, isTrue);
        if (submitting) {
          service.saved();
        } else {
          service.preparedEditor();
        }
        await tester.pumpAndSettle();
        expect(await host.result, isNull);
        expect(host.container.read(blogMutationBusProvider).last, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'keyboard transitions move blog actions and viewport together while retaining editing state',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final keyboardInsets = ValueNotifier<double>(0);
      addTearDown(keyboardInsets.dispose);
      final service = BlogOperationFixture(autoPrepare: true);
      await _open(tester, service, keyboardInsets: keyboardInsets);
      const text = '键盘开合时保留正文与选择范围';
      await _replaceBody(tester, text);
      final editor = _body(tester);
      final controller = editor.controller;
      const selection = TextSelection(baseOffset: 1, extentOffset: 4);
      controller.updateSelection(selection, ChangeSource.local);
      await tester.pumpAndSettle();
      final toolbar = find.byKey(const Key('blog-editor-toolbar'));
      final viewport = find.byKey(const Key('blog-editor-scroll'));
      final body = find.byKey(const Key('blog-editor-body'));
      final closedBottom = tester.getRect(toolbar).bottom;
      final bodyHeight = tester.getSize(body).height;

      void expectEditingRetained() {
        final current = _body(tester);
        expect(current.controller, same(controller));
        expect(current.focusNode, same(editor.focusNode));
        expect(current.scrollController, same(editor.scrollController));
        expect(controller.document.toPlainText(), '$text\n');
        expect(controller.selection, selection);
        expect(tester.getSize(body).height, closeTo(bodyHeight, 0.01));
        expect(
          tester.getRect(viewport).bottom,
          closeTo(tester.getRect(toolbar).top, 0.01),
        );
        expect(tester.takeException(), isNull);
      }

      keyboardInsets.value = 280;
      await tester.pump();
      expect(tester.getRect(toolbar).bottom, closeTo(closedBottom, 0.01));
      await tester.pump(const Duration(milliseconds: 45));
      final openingBottom = tester.getRect(toolbar).bottom;
      expect(openingBottom, inExclusiveRange(closedBottom - 280, closedBottom));
      expectEditingRetained();
      await tester.pump(const Duration(milliseconds: 45));
      expect(tester.getRect(toolbar).bottom, lessThan(openingBottom));
      expectEditingRetained();
      await tester.pumpAndSettle();
      final openBottom = tester.getRect(toolbar).bottom;
      expect(openBottom, closeTo(closedBottom - 280, 0.01));
      expectEditingRetained();

      keyboardInsets.value = 0;
      await tester.pump();
      expect(tester.getRect(toolbar).bottom, closeTo(openBottom, 0.01));
      await tester.pump(const Duration(milliseconds: 45));
      final closingBottom = tester.getRect(toolbar).bottom;
      expect(closingBottom, inExclusiveRange(openBottom, closedBottom));
      expectEditingRetained();
      await tester.pump(const Duration(milliseconds: 45));
      expect(tester.getRect(toolbar).bottom, greaterThan(closingBottom));
      expectEditingRetained();
      await tester.pumpAndSettle();
      expect(tester.getRect(toolbar).bottom, closeTo(closedBottom, 0.01));
      expectEditingRetained();
      await _save(tester);
      expect(_plainText(service.editorSubmissions.single.input.bodyHtml), text);
      service.saved();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('reversing keyboard transitions keeps blog actions continuous', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final keyboardInsets = ValueNotifier<double>(0);
    addTearDown(keyboardInsets.dispose);
    final service = BlogOperationFixture(autoPrepare: true);
    await _open(tester, service, keyboardInsets: keyboardInsets);
    await _replaceBody(tester, '快速收起再展开时保留正文');
    final toolbar = find.byKey(const Key('blog-editor-toolbar'));
    final closedBottom = tester.getRect(toolbar).bottom;

    keyboardInsets.value = 280;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final openingBottom = tester.getRect(toolbar).bottom;
    expect(openingBottom, inExclusiveRange(closedBottom - 280, closedBottom));

    keyboardInsets.value = 0;
    await tester.pump();
    expect(tester.getRect(toolbar).bottom, closeTo(openingBottom, 0.01));
    await tester.pump(const Duration(milliseconds: 30));
    final reversingBottom = tester.getRect(toolbar).bottom;
    expect(reversingBottom, inExclusiveRange(openingBottom, closedBottom));

    keyboardInsets.value = 280;
    await tester.pump();
    expect(tester.getRect(toolbar).bottom, closeTo(reversingBottom, 0.01));
    await tester.pump(const Duration(milliseconds: 45));
    expect(tester.getRect(toolbar).bottom, lessThan(reversingBottom));
    await tester.pumpAndSettle();
    expect(tester.getRect(toolbar).bottom, closeTo(closedBottom - 280, 0.01));
    expect(
      tester.getRect(find.byKey(const Key('blog-editor-scroll'))).bottom,
      closeTo(tester.getRect(toolbar).top, 0.01),
    );
    expect(_body(tester).controller.document.toPlainText(), '快速收起再展开时保留正文\n');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview keeps avoiding the keyboard without an editing toolbar',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final keyboardInsets = ValueNotifier<double>(0);
      addTearDown(keyboardInsets.dispose);
      final service = BlogOperationFixture(autoPrepare: true);
      await _open(tester, service, keyboardInsets: keyboardInsets);
      await _replaceBody(tester, '切换预览时保留正文');
      final controller = _body(tester).controller;
      keyboardInsets.value = 280;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blog-editor-preview-toggle')));
      await tester.pumpAndSettle();
      final viewport = find.byKey(const Key('blog-editor-scroll'));
      expect(find.byKey(const Key('blog-editor-toolbar')), findsNothing);
      expect(find.byType(ForumHtmlContentView), findsOneWidget);
      final openBottom = tester.getRect(viewport).bottom;
      expect(openBottom, closeTo(700 - 280, 0.01));

      keyboardInsets.value = 0;
      await tester.pump();
      expect(tester.getRect(viewport).bottom, closeTo(openBottom, 0.01));
      await tester.pump(const Duration(milliseconds: 45));
      expect(
        tester.getRect(viewport).bottom,
        inExclusiveRange(openBottom, 700),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport).bottom, closeTo(700, 0.01));
      expect(find.byKey(const Key('blog-editor-toolbar')), findsNothing);
      await tester.tap(find.byKey(const Key('blog-editor-preview-toggle')));
      await tester.pumpAndSettle();
      expect(_body(tester).controller, same(controller));
      expect(controller.document.toPlainText(), '切换预览时保留正文\n');
      expect(service.editorSubmissions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final family in AppThemeFamily.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'editor settings and preview fit $family $brightness with large text and keyboard',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 740));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final service = BlogOperationFixture(autoPrepare: true);
          await _open(
            tester,
            service,
            create: true,
            largeKeyboard: true,
            theme: AppTheme.build(family: family, brightness: brightness),
          );
          await tester.enterText(
            find.byKey(const Key('blog-editor-subject')),
            '长标题 ' * 12,
          );
          await tester.ensureVisible(find.byKey(const Key('blog-editor-body')));
          await _replaceBody(tester, '正文\n空行与换行\n\n' * 6);
          await _openSettings(tester);
          await _reveal(tester, find.byKey(const Key('blog-editor-open-web')));
          expect(
            find.byKey(const Key('blog-editor-open-web')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await _closeSettings(tester);
          await tester.tap(find.byKey(const Key('blog-editor-preview-toggle')));
          await tester.pumpAndSettle();
          expect(find.byType(ForumHtmlContentView), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _save(tester);
          service.saved();
          await tester.pumpAndSettle();
          expect(find.byType(BlogEditorPage), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
