part of 'composer_quill_prototype_editor_test.dart';

void _collapseEditingCases() {
  testWidgets('surface strips formatting applied to an atomic collapse', (
    tester,
  ) async {
    const codec = ComposerQuillBbCodeCodec();
    const source = '[collapse=0,标题]\n[b]内部[/b][/collapse]';
    final document = codec.decodeDocument(source);
    const selection = TextSelection(baseOffset: 0, extentOffset: 1);
    final controller = QuillController(
      document: document,
      selection: selection,
    );
    addTearDown(controller.dispose);
    String? latest;
    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );

    controller.formatText(0, 1, Attribute.bold);
    controller.formatText(1, 1, Attribute.blockQuote);
    await tester.pump();

    final operations = controller.document.toDelta().toList();
    final collapseIndex = operations.indexWhere(
      (operation) => composerQuillCollapseEmbedPayload(operation.data) != null,
    );
    expect(operations[collapseIndex].attributes, isNull);
    expect(operations[collapseIndex + 1].data, '\n');
    expect(operations[collapseIndex + 1].attributes, isNull);
    expect(controller.selection, selection);
    expect(codec.encodeDocument(controller.document), source);
    expect(latest, isNull);
  });

  testWidgets('collapse title and save action match composer chrome', (
    tester,
  ) async {
    const initial = '[collapse=0,标题]\n正文[/collapse]';
    final theme = AppTheme.light();
    await tester.pumpWidget(_buildEditor(initialBbCode: initial));
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-0')),
    );
    await tester.pumpAndSettle();

    final titleFinder = find.byKey(
      const Key('test-quill-collapse-editor-title-field'),
    );
    final titleField = tester.widget<AppTextInput>(titleFinder);
    final localizations = AppLocalizations.of(tester.element(titleFinder));
    expect(titleField.hintText, localizations.composerCollapseTitleHint);
    expect(titleField.label, isNull);
    expect(titleField.variant, AppTextInputVariant.underline);
    final contentColumn = tester.widget<Column>(
      find.byKey(const Key('test-quill-collapse-editor-content-column')),
    );
    expect(contentColumn.children.whereType<Divider>(), isEmpty);

    final titlePadding = tester.widget<Padding>(
      find.byKey(const Key('test-quill-collapse-editor-title-padding')),
    );
    final resolvedPadding = titlePadding.padding.resolve(TextDirection.ltr);
    expect(
      resolvedPadding,
      const EdgeInsets.fromLTRB(
        ForumContentSpacing.composerPageHorizontal,
        ForumContentSpacing.composerPageVertical,
        ForumContentSpacing.composerPageHorizontal,
        12,
      ),
    );

    final saveFinder = find.byKey(
      const Key('test-quill-collapse-editor-save-button'),
    );
    var saveButton = tester.widget<IconButton>(saveFinder);
    final appBarForeground = theme.appBarTheme.foregroundColor!;
    expect(saveButton.tooltip, localizations.commonSave);
    expect(saveButton.onPressed, isNull);
    expect(
      saveButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      appBarForeground,
    );
    expect(
      saveButton.style?.foregroundColor?.resolve(<WidgetState>{
        WidgetState.disabled,
      }),
      appBarForeground.withValues(alpha: 0.38),
    );
    expect(
      find.descendant(
        of: saveFinder,
        matching: find.byIcon(Icons.save_outlined),
      ),
      findsOneWidget,
    );

    await tester.enterText(titleFinder, '新]题\n\uFFFC');
    await tester.pump();
    expect(tester.widget<AppTextInput>(titleFinder).controller!.text, '新题');
    saveButton = tester.widget<IconButton>(saveFinder);
    expect(saveButton.onPressed, isNotNull);

    await tester.enterText(titleFinder, '标题');
    await tester.pump();
    saveButton = tester.widget<IconButton>(saveFinder);
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('creating then discarding a collapse leaves parent unchanged', (
    tester,
  ) async {
    String? latest;
    await tester.pumpWidget(
      _buildEditor(
        initialBbCode: '父正文',
        onBbCodeChanged: (value) => latest = value,
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-collapse-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('test-quill-collapse-editor-page')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('test-quill-collapse-editor-save-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.enterText(
      find.byKey(const Key('test-quill-collapse-editor-title-field')),
      '未保存标题',
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const Key('test-quill-collapse-editor-discard-confirm-button'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const Key('test-quill-collapse-editor-discard-confirm-button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('test-quill-collapse-editor-page')),
      findsNothing,
    );
    expect(latest, isNull);
  });

  testWidgets('safe text selection is prefilled and saved as one collapse', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    controller.replaceText(
      0,
      0,
      '选中的正文',
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    String? latest;
    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-collapse-button')));
    await tester.pumpAndSettle();
    final bodyEditor = tester.widget<QuillEditor>(
      find.byKey(const Key('test-quill-collapse-editor-body-editor')),
    );
    expect(
      const ComposerQuillBbCodeCodec().encodeDocument(
        bodyEditor.controller.document,
      ),
      '选中的正文',
    );
    await tester.enterText(
      find.byKey(const Key('test-quill-collapse-editor-title-field')),
      '标题',
    );
    await tester.tap(
      find.byKey(const Key('test-quill-collapse-editor-save-button')),
    );
    await tester.pumpAndSettle();

    expect(latest, '[collapse=0,标题]\n选中的正文[/collapse]');
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.byType(AppTextInput), findsNothing);
  });

  testWidgets('selection containing an embed is preserved when creating', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    controller.replaceText(0, 0, 'A', const TextSelection.collapsed(offset: 1));
    controller.replaceText(
      1,
      0,
      composerQuillStickerEmbed('{:9_656:}'),
      const TextSelection.collapsed(offset: 2),
    );
    controller.replaceText(
      2,
      0,
      'B',
      const TextSelection(baseOffset: 0, extentOffset: 3),
    );
    String? latest;
    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-collapse-button')));
    await tester.pumpAndSettle();
    final bodyEditor = tester.widget<QuillEditor>(
      find.byKey(const Key('test-quill-collapse-editor-body-editor')),
    );
    expect(
      const ComposerQuillBbCodeCodec().encodeDocument(
        bodyEditor.controller.document,
      ),
      isEmpty,
    );
    await tester.enterText(
      find.byKey(const Key('test-quill-collapse-editor-title-field')),
      '空正文',
    );
    await tester.tap(
      find.byKey(const Key('test-quill-collapse-editor-save-button')),
    );
    await tester.pumpAndSettle();

    expect(latest, '[collapse=0,空正文]\n[/collapse]\nA{:9_656:}B');
  });
}
