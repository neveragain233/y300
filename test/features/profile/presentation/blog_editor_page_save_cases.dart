part of 'blog_editor_page_test.dart';

void _saveCases() {
  testWidgets('new blog saves on return and restores raw HTML and settings', (
    tester,
  ) async {
    final service = BlogOperationFixture(autoPrepare: true);
    final repo = MemoryBlogDraftRepository();
    final host = await _open(tester, service, create: true, drafts: repo);
    expect(find.byType(AppPageAppBar), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('blog-editor-subject')),
      '未发布标题',
    );
    await _replaceBody(tester, '保留正文');
    await _openSettings(tester);
    await tester.enterText(
      find.byKey(const Key('blog-editor-tags')),
      'tag1 tag2',
    );
    await _closeSettings(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BlogEditorPage), findsNothing);
    expect(repo.values['101']!.subject, '未发布标题');
    expect(repo.values['101']!.tags, 'tag1 tag2');
    final savedHtml = repo.values['101']!.bodyHtml;
    await tester.tap(find.byKey(const Key('open-editor')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('blog-editor-subject')))
          .controller!
          .text,
      '未发布标题',
    );
    expect(_body(tester).controller.document.toPlainText(), '保留正文\n');
    expect(find.text(_l10n(tester).composerRestoredDraft), findsOneWidget);
    await _save(tester);
    expect(service.editorSubmissions.single.input.bodyHtml, savedHtml);
    expect(repo.values['101']!.pendingSubmission, isTrue);
    service.saved();
    await tester.pumpAndSettle();
    expect(repo.values, isEmpty);
    expect((await host.result)?.receipt.blogId, '12');
  });

  testWidgets('save failure prevents returning and retry keeps latest input', (
    tester,
  ) async {
    final repo = MemoryBlogDraftRepository();
    await _open(
      tester,
      BlogOperationFixture(autoPrepare: true),
      create: true,
      drafts: repo,
    );
    await tester.enterText(
      find.byKey(const Key('blog-editor-subject')),
      'latest',
    );
    repo.failSave = true;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BlogEditorPage), findsOneWidget);
    expect(find.text(_l10n(tester).profileBlogDraftSaveFailed), findsWidgets);
    repo.failSave = false;
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BlogEditorPage), findsNothing);
    expect(repo.values['101']!.subject, 'latest');
  });

  testWidgets(
    'background immediately persists and account expiry keeps old draft',
    (tester) async {
      final host = await _open(
        tester,
        BlogOperationFixture(autoPrepare: true),
        create: true,
      );
      await tester.enterText(
        find.byKey(const Key('blog-editor-subject')),
        'old actor',
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(host.drafts.values['101']!.subject, 'old actor');
      host.changeActor('202');
      await tester.pumpAndSettle();
      expect(find.byType(QuillEditor), findsNothing);
      expect(host.drafts.values['101']!.subject, 'old actor');
      expect(host.drafts.values.containsKey('202'), isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  testWidgets('load failure retains stored content until explicit reset', (
    tester,
  ) async {
    final repo = MemoryBlogDraftRepository()..failLoad = true;
    repo.values['101'] = _savedDraft(subject: 'protected');
    await _open(
      tester,
      BlogOperationFixture(autoPrepare: true),
      create: true,
      drafts: repo,
    );
    expect(find.byType(QuillEditor), findsNothing);
    expect(repo.values['101']!.subject, 'protected');
    await tester.tap(find.byKey(const Key('blog-draft-reset-load-error')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('blog-draft-reset-confirm')));
    await tester.pumpAndSettle();
    expect(repo.values, isEmpty);
    expect(find.byType(QuillEditor), findsOneWidget);
  });

  testWidgets(
    'pending draft is read only until explicit durable acknowledgment',
    (tester) async {
      final repo = MemoryBlogDraftRepository();
      repo.values['101'] = _savedDraft(pending: true);
      final service = BlogOperationFixture(autoPrepare: true);
      await _open(tester, service, create: true, drafts: repo);
      expect(_submitButton(tester).onPressed, isNull);
      expect(_body(tester).controller.readOnly, isTrue);
      await tester.tap(find.byKey(const Key('blog-draft-resume')));
      await tester.pumpAndSettle();
      repo.failSave = true;
      await tester.tap(find.byKey(const Key('blog-draft-resume-confirm')));
      await tester.pumpAndSettle();
      expect(_submitButton(tester).onPressed, isNull);
      expect(repo.values['101']!.pendingSubmission, isTrue);
      repo.failSave = false;
      await tester.tap(find.byKey(const Key('blog-draft-resume')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blog-draft-resume-confirm')));
      await tester.pumpAndSettle();
      expect(repo.values['101']!.pendingSubmission, isFalse);
      expect(_submitButton(tester).onPressed, isNotNull);
      expect(service.editorSubmissions, isEmpty);
    },
  );

  testWidgets(
    'unknown publication restores pending input without an automatic resend',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      final host = await _open(tester, service, create: true);
      await tester.enterText(
        find.byKey(const Key('blog-editor-subject')),
        'uncertain',
      );
      await _replaceBody(tester, 'body');
      await _save(tester);
      service.editorSubmissions.single.result.complete(
        const DataCommandOutcomeUnknown(blogActionWriteFailure),
      );
      await tester.pumpAndSettle();
      expect(host.drafts.values['101']!.pendingSubmission, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-editor')));
      await tester.pumpAndSettle();
      expect(service.editorSubmissions, hasLength(1));
      expect(_submitButton(tester).onPressed, isNull);
      expect(find.byKey(const Key('blog-draft-check')), findsOneWidget);
      expect(_body(tester).controller.document.toPlainText(), 'body\n');
    },
  );

  testWidgets('failed persistence prevents any publication request', (
    tester,
  ) async {
    final service = BlogOperationFixture(autoPrepare: true);
    final host = await _open(tester, service, create: true);
    await tester.enterText(
      find.byKey(const Key('blog-editor-subject')),
      'kept',
    );
    await _replaceBody(tester, 'body');
    host.drafts.failSave = true;
    await _save(tester);
    await tester.pumpAndSettle();
    expect(service.editorSubmissions, isEmpty);
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.byKey(const Key('blog-draft-save-retry')), findsOneWidget);
  });

  testWidgets(
    'reset is immediate after confirmation and old debounce cannot revive content',
    (tester) async {
      final host = await _open(
        tester,
        BlogOperationFixture(autoPrepare: true),
        create: true,
      );
      await tester.enterText(
        find.byKey(const Key('blog-editor-subject')),
        'discard',
      );
      await _replaceBody(tester, 'old body');
      await _openSettings(tester);
      final reset = find.byKey(const Key('blog-draft-reset'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('blog-draft-reset-confirm')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(host.drafts.values, isEmpty);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('blog-editor-subject')))
            .controller!
            .text,
        isEmpty,
      );
      expect(_body(tester).controller.document.toPlainText(), '\n');
    },
  );

  testWidgets('restoration keeps password visibility and vanished category', (
    tester,
  ) async {
    final repo = MemoryBlogDraftRepository();
    repo.values['101'] = BlogDraftSnapshot(
      accountId: '101',
      updatedAt: DateTime(2020),
      subject: 'private draft',
      bodyHtml: '<table><tr><td><b>原文</b></td></tr></table>',
      personalCategoryId: '999',
      visibility: UserBlogVisibility.passwordProtected,
    );
    final service = BlogOperationFixture(autoPrepare: true);
    await _open(tester, service, create: true, drafts: repo);
    expect(
      find.text(_l10n(tester).profileBlogDraftPasswordRestored),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('blog-draft-settings-changed')),
      findsOneWidget,
    );
    await _openSettings(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('blog-editor-password')))
          .controller!
          .text,
      isEmpty,
    );
    await _closeSettings(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      repo.values['101']!.visibility,
      UserBlogVisibility.passwordProtected,
    );
    expect(repo.values['101']!.personalCategoryId, '999');
    expect(
      repo.values['101']!.bodyHtml,
      '<table><tr><td><b>原文</b></td></tr></table>',
    );
  });
}
