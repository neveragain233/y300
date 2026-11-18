part of 'blog_editor_page_test.dart';

void _settingsCases() {
  testWidgets(
    'create prepares before input and saves exact plain content once',
    (tester) async {
      final service = BlogOperationFixture();
      final host = await _open(tester, service, create: true);
      expect(find.byType(TextField), findsNothing);
      expect(_submitButton(tester).onPressed, isNull);
      service.preparedEditor();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(QuillEditor), findsOneWidget);
      expect(find.byKey(const Key('blog-body-mode-menu')), findsNothing);
      expect(find.byKey(const Key('blog-editor-save')), findsNothing);
      expect(find.byKey(const Key('blog-editor-tags')), findsNothing);
      expect(
        find.byKey(const Key('blog-editor-settings-summary')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('blog-editor-subject')),
        'A new journal',
      );
      await _replaceBody(tester, '  第一行 <b>文字</b>\n\n第二行');
      await _save(tester);
      expect(service.editorSubmissions, hasLength(1));
      expect(
        _plainText(service.editorSubmissions.single.input.bodyHtml),
        '  第一行 <b>文字</b>\n\n第二行',
      );
      expect(_submitButton(tester).onPressed, isNull);
      service.saved();
      await tester.pumpAndSettle();
      expect((await host.result)?.receipt.blogId, '12');
      expect((await host.result)?.subject, 'A new journal');
      expect(host.container.read(blogMutationBusProvider).last?.blogId, '12');
    },
  );

  testWidgets(
    'preview does not rewrite HTML or submit and title-only edit preserves source',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      const html = '<p class="keep">繁體 <b>原文</b> &amp; literal</p>';
      service.editorForm = (target) => blogEditorPreparation(
        target,
        bodyHtml: html,
        visibility: UserBlogVisibility.passwordProtected,
        commentsEnabled: false,
      );
      final host = await _open(tester, service);
      await tester.enterText(
        find.byKey(const Key('blog-editor-subject')),
        'Title <not a tag>',
      );
      await tester.tap(find.byKey(const Key('blog-editor-preview-toggle')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ForumHtmlContentView>(find.byType(ForumHtmlContentView))
            .html,
        '<h2>Title &lt;not a tag&gt;</h2>$html',
      );
      expect(service.editorSubmissions, isEmpty);
      await tester.tap(find.byKey(const Key('blog-editor-preview-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(QuillEditor), findsOneWidget);
      await _save(tester);
      expect(service.editorSubmissions.single.input.bodyHtml, html);
      expect(
        service.editorSubmissions.single.input.preparation.visibility,
        UserBlogVisibility.passwordProtected,
      );
      expect(
        service.editorSubmissions.single.input.preparation.commentsEnabled,
        isFalse,
      );
      service.saved();
      await tester.pumpAndSettle();
      expect(await host.result, isNotNull);
    },
  );

  testWidgets(
    'category creation requires a name and passes metadata to the prepared form',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      await _open(tester, service);
      final l10n = _l10n(tester);
      await _choose(tester, 'blog-editor-site-category', 'Stories');
      await _choose(
        tester,
        'blog-editor-personal-category',
        l10n.profileBlogNewCategory,
      );
      await _save(tester);
      await tester.pumpAndSettle();
      expect(service.editorSubmissions, isEmpty);
      expect(
        find.byKey(const Key('blog-editor-settings-sheet')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('blog-editor-category-name')),
            )
            .decoration!
            .errorText,
        l10n.profileBlogNewCategoryNameRequired,
      );
      await tester.ensureVisible(
        find.byKey(const Key('blog-editor-category-name')),
      );
      await tester.enterText(
        find.byKey(const Key('blog-editor-category-name')),
        '新的分类',
      );
      await tester.ensureVisible(find.byKey(const Key('blog-editor-tags')));
      await tester.enterText(
        find.byKey(const Key('blog-editor-tags')),
        'one two',
      );
      await tester.ensureVisible(
        find.byKey(const Key('blog-editor-publish-feed')),
      );
      await tester.tap(find.byKey(const Key('blog-editor-publish-feed')));
      await tester.pump();
      await _save(tester);
      final input = service.editorSubmissions.single.input;
      expect(input.siteCategoryId, '8');
      expect(input.personalCategoryId, '0');
      expect(input.newPersonalCategory, '新的分类');
      expect(input.tags, 'one two');
      expect(input.publishFeed, isTrue);
      service.saved();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'settings update the draft immediately and survive closing and reopening',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      await _open(tester, service);
      await _openSettings(tester);
      await tester.ensureVisible(find.byKey(const Key('blog-editor-tags')));
      await tester.enterText(
        find.byKey(const Key('blog-editor-tags')),
        '新的标签, reading',
      );
      await _choose(tester, 'blog-editor-personal-category', 'Travel');
      await tester.ensureVisible(
        find.byKey(const Key('blog-editor-publish-feed')),
      );
      await tester.tap(find.byKey(const Key('blog-editor-publish-feed')));
      await _closeSettings(tester, tapBarrier: true);
      expect(service.editorSubmissions, isEmpty);
      await _openSettings(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('blog-editor-tags')))
            .controller!
            .text,
        '新的标签, reading',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('blog-editor-personal-category')),
          matching: find.text('Travel'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<prism.Switch>(
              find.byKey(const Key('blog-editor-publish-feed')),
            )
            .value,
        isTrue,
      );
      await _save(tester);
      final input = service.editorSubmissions.single.input;
      expect(input.tags, '新的标签, reading');
      expect(input.personalCategoryId, '9');
      expect(input.publishFeed, isTrue);
      service.saved();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('account change clears an open settings sheet and its input', (
    tester,
  ) async {
    final service = BlogOperationFixture(autoPrepare: true);
    final host = await _open(tester, service);
    final l10n = _l10n(tester);
    await _openSettings(tester);
    await tester.ensureVisible(find.byKey(const Key('blog-editor-tags')));
    await tester.enterText(
      find.byKey(const Key('blog-editor-tags')),
      'old account draft',
    );
    host.changeActor('202');
    await tester.pumpAndSettle();
    expect(find.byType(TextField, skipOffstage: false), findsNothing);
    expect(find.text('old account draft', skipOffstage: false), findsNothing);
    expect(find.text(l10n.forumWebViewAccountChanged), findsWidgets);
    expect(service.editorSubmissions, isEmpty);
    host.changeActor('101');
    await tester.pumpAndSettle();
    expect(find.byType(TextField, skipOffstage: false), findsNothing);
    expect(host.container.read(blogMutationBusProvider).last, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final visibility in UserBlogVisibility.values) {
    testWidgets(
      'native access settings submit $visibility and updated comment policy',
      (tester) async {
        final service = BlogOperationFixture(autoPrepare: true);
        service.editorForm = (target) => blogEditorPreparation(
          target,
          visibility: visibility == UserBlogVisibility.public
              ? UserBlogVisibility.friends
              : UserBlogVisibility.public,
          availableVisibilities: UserBlogVisibility.values,
          canEditComments: true,
          hasPassword: false,
        );
        await _open(tester, service);
        final l10n = _l10n(tester);
        await _choose(
          tester,
          'blog-editor-visibility',
          _visibilityLabel(l10n, visibility),
        );
        const names = 'Alice  Bob\n名字甲';
        const password = 'a new p@ssword';
        if (visibility == UserBlogVisibility.selectedFriends) {
          final field = find.byKey(const Key('blog-editor-target-names'));
          await tester.ensureVisible(field);
          await tester.enterText(field, names);
        }
        if (visibility == UserBlogVisibility.passwordProtected) {
          final field = find.byKey(const Key('blog-editor-password'));
          await tester.ensureVisible(field);
          expect(tester.widget<TextField>(field).obscureText, isTrue);
          await tester.enterText(field, password);
        }
        final comments = find.byKey(const Key('blog-editor-comments-enabled'));
        await tester.ensureVisible(comments);
        await tester.tap(comments);
        await tester.pump();
        await _closeSettings(tester);
        final summary = find.byKey(const Key('blog-editor-settings-summary'));
        expect(
          find.descendant(
            of: summary,
            matching: find.textContaining(_visibilityLabel(l10n, visibility)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: summary,
            matching: find.textContaining(l10n.profileBlogCommentsClosed),
          ),
          findsOneWidget,
        );
        await _save(tester);
        final input = service.editorSubmissions.single.input;
        expect(input.visibility, visibility);
        expect(input.commentsEnabled, isFalse);
        expect(
          input.password,
          visibility == UserBlogVisibility.passwordProtected ? password : null,
        );
        if (visibility == UserBlogVisibility.selectedFriends) {
          expect(input.targetNames, names);
        }
        service.saved();
        await tester.pumpAndSettle();
      },
    );
  }

  for (final visibility in [
    UserBlogVisibility.passwordProtected,
    UserBlogVisibility.selectedFriends,
  ]) {
    testWidgets(
      'empty private access input for $visibility reopens settings before submit',
      (tester) async {
        final service = BlogOperationFixture(autoPrepare: true);
        service.editorForm = (target) => blogEditorPreparation(
          target,
          availableVisibilities: UserBlogVisibility.values,
          hasPassword: false,
          targetNames: '',
        );
        await _open(tester, service);
        await _choose(
          tester,
          'blog-editor-visibility',
          _visibilityLabel(_l10n(tester), visibility),
        );
        final passwordMode = visibility == UserBlogVisibility.passwordProtected;
        final field = find.byKey(
          Key(
            passwordMode ? 'blog-editor-password' : 'blog-editor-target-names',
          ),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, passwordMode ? '   ' : ' \n ');
        await _save(tester);
        await tester.pumpAndSettle();
        expect(service.editorSubmissions, isEmpty);
        expect(
          find.byKey(const Key('blog-editor-settings-sheet')),
          findsOneWidget,
        );
        await tester.ensureVisible(field);
        await tester.enterText(
          field,
          passwordMode ? 'new password' : 'Alice Bob',
        );
        await _save(tester);
        expect(service.editorSubmissions, hasLength(1));
        service.saved();
        await tester.pumpAndSettle();
      },
    );
  }
}
