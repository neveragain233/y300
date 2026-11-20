part of 'blog_editor_page_test.dart';

void _accessCases() {
  testWidgets(
    'existing password is not filled and leaving it blank preserves it',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      service.editorForm = (target) => blogEditorPreparation(
        target,
        visibility: UserBlogVisibility.passwordProtected,
        availableVisibilities: UserBlogVisibility.values,
        hasPassword: true,
      );
      await _open(tester, service);
      await _openSettings(tester);
      final field = find.byKey(const Key('blog-editor-password'));
      await tester.ensureVisible(field);
      final password = tester.widget<AppTextInput>(field);
      expect(password.obscureText, isTrue);
      expect(password.controller!.text, isEmpty);
      await _save(tester);
      final input = service.editorSubmissions.single.input;
      expect(input.visibility, UserBlogVisibility.passwordProtected);
      expect(input.password, isNull);
      service.saved();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('account switch clears a password entered in the open sheet', (
    tester,
  ) async {
    final service = BlogOperationFixture(autoPrepare: true);
    service.editorForm = (target) => blogEditorPreparation(
      target,
      availableVisibilities: UserBlogVisibility.values,
      hasPassword: false,
    );
    final host = await _open(tester, service);
    await _choose(
      tester,
      'blog-editor-visibility',
      _l10n(tester).profileBlogVisibilityPassword,
    );
    final field = find.byKey(const Key('blog-editor-password'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'old-account-private-secret');
    final input = tester.widget<AppTextInput>(field).controller!;
    host.changeActor('202');
    await tester.pumpAndSettle();
    expect(input.text, isEmpty);
    expect(find.byType(TextField, skipOffstage: false), findsNothing);
    expect(service.editorSubmissions, isEmpty);
    host.changeActor('101');
    await tester.pumpAndSettle();
    expect(find.byType(TextField, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unknown submission keeps access settings readable but immutable',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      service.editorForm = (target) => blogEditorPreparation(
        target,
        visibility: UserBlogVisibility.passwordProtected,
        availableVisibilities: UserBlogVisibility.values,
        canEditComments: true,
        hasPassword: true,
      );
      await _open(tester, service);
      await _save(tester);
      service.editorSubmissions.single.result.complete(
        const DataCommandOutcomeUnknown(blogActionWriteFailure),
      );
      await tester.pumpAndSettle();
      await _openSettings(tester);
      final visibility = find.byKey(const Key('blog-editor-visibility'));
      final dropdown = find.descendant(
        of: visibility,
        matching: find.byType(DropdownButton<UserBlogVisibility>),
      );
      expect(
        tester.widget<DropdownButton<UserBlogVisibility>>(dropdown).onChanged,
        isNull,
      );
      expect(
        tester
            .widget<prism.Switch>(
              find.byKey(const Key('blog-editor-comments-enabled')),
            )
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<AppTextInput>(find.byKey(const Key('blog-editor-password')))
            .readOnly,
        isTrue,
      );
      expect(find.byKey(const Key('blog-editor-open-web')), findsNothing);
      await _closeSettings(tester);
      expect(_submitButton(tester).onPressed, isNull);
      expect(service.editorSubmissions, hasLength(1));
    },
  );

  for (final useServer in [false, true]) {
    testWidgets(
      'known failure retains input and server review useServer=$useServer',
      (tester) async {
        final service = BlogOperationFixture(autoPrepare: true);
        await _open(tester, service);
        await _replaceBody(tester, 'My version');
        await _save(tester);
        service.editorSubmissions.last.result.complete(
          const DataCommandRejected(blogActionWriteFailure),
        );
        await tester.pumpAndSettle();
        expect(_body(tester).controller.document.toPlainText(), 'My version\n');
        service.editorForm = (target) =>
            blogEditorPreparation(target, bodyHtml: '<p>Server version</p>');
        await _reveal(tester, find.byKey(const Key('blog-editor-retry')));
        await tester.tap(find.byKey(const Key('blog-editor-retry')));
        await tester.pumpAndSettle();
        expect(_submitButton(tester).onPressed, isNull);
        await _reveal(
          tester,
          find.byKey(const Key('blog-editor-show-server')),
          delta: -200,
        );
        await tester.tap(find.byKey(const Key('blog-editor-show-server')));
        await tester.pumpAndSettle();
        expect(find.byType(ForumHtmlContentView), findsOneWidget);
        final choice = find.byKey(
          Key(useServer ? 'blog-editor-use-server' : 'blog-editor-keep-local'),
        );
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(
          _body(tester).controller.document.toPlainText(),
          useServer ? 'Server version\n' : 'My version\n',
        );
        await _save(tester);
        expect(
          _plainText(service.editorSubmissions.last.input.bodyHtml),
          useServer ? 'Server version' : 'My version',
        );
        service.saved();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'unknown outcome retains copyable input without retry or browser resend',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      final host = await _open(tester, service);
      await _replaceBody(tester, 'Uncertain input');
      await _save(tester);
      service.editorSubmissions.last.result.complete(
        const DataCommandOutcomeUnknown(blogActionWriteFailure),
      );
      await tester.pumpAndSettle();
      expect(_body(tester).controller.readOnly, isTrue);
      expect(
        _body(tester).controller.document.toPlainText(),
        'Uncertain input\n',
      );
      expect(find.byKey(const Key('blog-editor-retry')), findsNothing);
      expect(find.byKey(const Key('blog-editor-open-web')), findsNothing);
      expect(_submitButton(tester).onPressed, isNull);
      await tapBack(tester, within: find.byType(BlogEditorPage));
      await tester.tap(find.byKey(const Key('blog-editor-leave')));
      await tester.pumpAndSettle();
      expect(await host.result, isNull);
      expect(host.container.read(blogMutationBusProvider).last, isNull);
    },
  );

  testWidgets(
    'browser fallback requires input warning and destroys the old editor',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      final host = await _open(tester, service);
      await tester.enterText(
        find.byKey(const Key('blog-editor-subject')),
        'My changes',
      );
      final web = find.byKey(const Key('blog-editor-open-web'));
      await _openSettings(tester);
      await _reveal(tester, web);
      await tester.tap(web);
      await tester.pumpAndSettle();
      expect(host.webLaunches, isEmpty);
      await tester.tap(find.text(_l10n(tester).commonCancel));
      await tester.pumpAndSettle();
      await _openSettings(tester);
      await _reveal(tester, web);
      await tester.tap(web);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blog-editor-confirm-web')));
      await tester.pumpAndSettle();
      expect(await host.result, isNull);
      expect(host.navigation.editorTarget!.action, UserBlogAction.edit);
      expect(host.webLaunches.single.expectedAccountId, '101');
      expect(find.byType(BlogEditorPage), findsNothing);
      await tapBack(
        tester,
        within: find.ancestor(
          of: find.text('browser fixture'),
          matching: find.byType(Scaffold),
        ),
      );
      expect(find.byType(BlogEditorPage), findsNothing);
      expect(service.editorSubmissions, isEmpty);
    },
  );

  testWidgets(
    'applied receipt waits for a leave dialog without popping the wrong route',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      final host = await _open(tester, service);
      await _save(tester);
      await tapBack(tester, within: find.byType(BlogEditorPage), settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      service.saved();
      await tester.pumpAndSettle();
      expect(
        find.text(_l10n(tester).profileBlogLeaveEditorTitle),
        findsOneWidget,
      );
      await tester.tap(find.text(_l10n(tester).commonCancel));
      await tester.pumpAndSettle();
      expect((await host.result)?.receipt.blogId, '11');
      expect(find.byKey(const Key('open-editor')), findsOneWidget);
    },
  );

  testWidgets('applied receipt waits until a covered preview route returns', (
    tester,
  ) async {
    final service = BlogOperationFixture(autoPrepare: true);
    final host = await _open(tester, service);
    await _save(tester);
    host.navigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: const Text('image preview fixture'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    service.saved();
    await tester.pumpAndSettle();
    expect(find.text('image preview fixture'), findsOneWidget);
    await tapBack(
      tester,
      within: find.ancestor(
        of: find.text('image preview fixture'),
        matching: find.byType(Scaffold),
      ),
    );
    expect((await host.result)?.receipt.blogId, '11');
    expect(find.byKey(const Key('open-editor')), findsOneWidget);
  });
}
