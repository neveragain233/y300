part of 'reply_composer_page_test.dart';

void _chromeCases() {
  testWidgets('ReplyComposerPage builds dark theme chrome', (tester) async {
    await tester.pumpWidget(_buildPage(theme: AppTheme.dark()));
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppPageAppBar), findsOneWidget);
    expect(
      find.byKey(const Key('reply-composer-quill-editor')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reply-composer-send-button')), findsOneWidget);
  });

  testWidgets('ReplyComposerPage localizes chrome and preserves raw reply', (
    tester,
  ) async {
    const rawReply = '[quote]引用原文[/quote]\n简体與繁體';
    await tester.pumpWidget(_buildPage(locale: const Locale('zh', 'TW')));
    await tester.pumpAndSettle();

    expect(find.text('回覆帖子'), findsOneWidget);
    expect(find.byTooltip('送出'), findsOneWidget);
    await _enterReplySourceText(tester, rawReply);
    final field = tester.widget<AppTextInput>(
      find.byKey(const Key('reply-composer-message-input')),
    );
    expect(field.controller?.text, rawReply);
  });

  testWidgets('ReplyComposerPage shows minimal composer UI', (tester) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    expect(find.text('回复帖子'), findsOneWidget);
    expect(find.text('预览'), findsNothing);
    expect(
      find.byKey(const Key('reply-composer-source-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reply-composer-more-button')), findsOneWidget);
    expect(
      find.byKey(const Key('reply-composer-sticker-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reply-composer-format-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reply-composer-color-button')), findsNothing);
    expect(
      find.byKey(const Key('reply-composer-backcolor-button')),
      findsNothing,
    );
    expect(find.byKey(const Key('reply-composer-link-button')), findsOneWidget);
    expect(find.byKey(const Key('reply-composer-size-button')), findsNothing);
    expect(
      find.byKey(const Key('reply-composer-quote-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reply-composer-code-button')), findsNothing);
    expect(
      find.byKey(const Key('reply-composer-align-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reply-composer-message-input')), findsNothing);
    expect(
      find.byKey(const Key('reply-composer-bbcode-preview-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('reply-composer-use-signature-switch')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('reply-composer-image-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reply-composer-send-button')), findsOneWidget);
  });

  testWidgets('ReplyComposerPage restores and updates the default surface', (
    tester,
  ) async {
    final preferencesRepository = _FakeComposerPreferencesRepository(
      preferences: const ComposerPreferences(
        defaultSurface: ComposerSurfacePreference.source,
        newDraftUseSignature: true,
      ),
    );
    await tester.pumpWidget(
      _buildPage(preferencesRepository: preferencesRepository),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reply-composer-message-input')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reply-composer-quill-editor')), findsNothing);

    await tester.tap(find.byKey(const Key('reply-composer-source-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reply-composer-quill-editor')),
      findsOneWidget,
    );
    expect(
      preferencesRepository.preferences.defaultSurface,
      ComposerSurfacePreference.quill,
    );
  });

  testWidgets('ReplyComposerPage wraps selection with quote BBCode', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();
    await _enterReplySourceText(tester, '前引用后');
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 1,
      extentOffset: 3,
    );

    await tester.tap(find.byKey(const Key('reply-composer-quote-button')));
    await tester.pump();

    expect(editable.controller.text, '前[quote]引用[/quote]后');
  });

  testWidgets('ReplyComposerPage wraps selection from text context menu', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();
    await _enterReplySourceText(tester, '前选中后');
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection(
      baseOffset: 1,
      extentOffset: 3,
    );
    tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
    await tester.pumpAndSettle();

    expect(find.text('代码'), findsNothing);

    await tester.tap(find.text('引用'));
    await tester.pumpAndSettle();

    expect(editable.controller.text, '前[quote]选中[/quote]后');
  });

  testWidgets('ReplyComposerPage inserts picked backcolor BBCode', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();
    await _openReplySourceEditor(tester);

    await tester.tap(find.byKey(const Key('reply-composer-backcolor-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('reply-composer-backcolor-sheet')),
      findsOneWidget,
    );
    final picker = tester.widget<ColorPicker>(
      find.byKey(const Key('reply-composer-backcolor-picker')),
    );
    picker.onColorChanged(const Color(0xffff33aa));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('reply-composer-backcolor-use-button')),
    );
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '[backcolor=#ff33aa][/backcolor]');
    expect(editable.controller.selection.baseOffset, 19);
    expect(editable.controller.selection.extentOffset, 19);
  });

  testWidgets('ReplyComposerPage places more action before image and send', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    final moreCenter = tester.getCenter(
      find.byKey(const Key('reply-composer-more-button')),
    );
    final sendCenter = tester.getCenter(
      find.byKey(const Key('reply-composer-send-button')),
    );

    final sourceCenter = tester.getCenter(
      find.byKey(const Key('reply-composer-source-button')),
    );

    expect(sourceCenter.dx, lessThan(moreCenter.dx));
    expect(moreCenter.dx, lessThan(sendCenter.dx));
  });

  testWidgets('ReplyComposerPage keeps Quill toolbar pinned to bottom', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    final scaffoldBottom = tester.getBottomLeft(find.byType(Scaffold)).dy;
    final imageButtonBottom = tester
        .getBottomLeft(find.byKey(const Key('reply-composer-image-button')))
        .dy;

    expect(scaffoldBottom - imageButtonBottom, lessThan(64));
  });
}
