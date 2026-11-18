part of 'composer_quill_prototype_editor_test.dart';

void _collapseLifecycleCases() {
  testWidgets(
    'editing deletes title and body text but preserves nested BBCode',
    (tester) async {
      const initial =
          '[collapse=0,外层]\n'
          '嵌套1\n'
          '[collapse=0,内层]\n内层正文[/collapse][/collapse]';
      var latest = initial;
      await tester.pumpWidget(
        _buildEditor(
          initialBbCode: initial,
          onBbCodeChanged: (value) => latest = value,
        ),
      );

      await tester.tap(
        find.byKey(const Key('composer-quill-collapse-edit-collapse-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const Key('test-quill-collapse-editor-body-collapse-button'),
        ),
        findsOneWidget,
      );
      expect(find.byType(QuillEditor), findsOneWidget);
      final titleField = tester.widget<TextField>(
        find.byKey(const Key('test-quill-collapse-editor-title-field')),
      );
      expect(titleField.enableInteractiveSelection, isTrue);
      await tester.enterText(
        find.byKey(const Key('test-quill-collapse-editor-title-field')),
        '',
      );
      final bodyEditor = tester.widget<QuillEditor>(
        find.byKey(const Key('test-quill-collapse-editor-body-editor')),
      );
      expect(bodyEditor.config.enableInteractiveSelection, isTrue);
      bodyEditor.controller.replaceText(
        2,
        1,
        '',
        const TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('test-quill-collapse-editor-save-button')),
      );
      await tester.pumpAndSettle();

      expect(
        latest,
        '[collapse=0,]\n'
        '嵌套\n'
        '[collapse=0,内层]\n内层正文[/collapse][/collapse]',
      );
    },
  );

  testWidgets('second-level collapse save stays local until outer save', (
    tester,
  ) async {
    const initial = '[collapse=0,外层]\n外层正文[/collapse]';
    var latest = initial;
    await tester.pumpWidget(
      _buildEditor(
        initialBbCode: initial,
        onBbCodeChanged: (value) => latest = value,
      ),
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-0')),
    );
    await tester.pumpAndSettle();

    await _createSecondLevelCollapse(tester);

    expect(latest, initial);
    expect(
      find.byKey(const Key('test-quill-collapse-editor-page')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('test-quill-collapse-editor-save-button')),
    );
    await tester.pumpAndSettle();

    expect(
      latest,
      '[collapse=0,外层]\n'
      '外层正文\n'
      '[collapse=0,内层]\n内层正文[/collapse][/collapse]',
    );
  });

  testWidgets('discarding outer editor drops saved nested draft', (
    tester,
  ) async {
    const initial = '[collapse=0,外层]\n外层正文[/collapse]';
    var latest = initial;
    await tester.pumpWidget(
      _buildEditor(
        initialBbCode: initial,
        onBbCodeChanged: (value) => latest = value,
      ),
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-0')),
    );
    await tester.pumpAndSettle();

    await _createSecondLevelCollapse(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const Key('test-quill-collapse-editor-discard-confirm-button'),
      ),
    );
    await tester.pumpAndSettle();

    expect(latest, initial);
    expect(
      find.byKey(const Key('test-quill-collapse-editor-page')),
      findsNothing,
    );
  });

  testWidgets('second-level editor keeps deeper history preview-only', (
    tester,
  ) async {
    const initial =
        '[collapse=0,第一层]\n'
        '第一层正文\n'
        '[collapse=0,第二层]\n'
        '第二层正文\n'
        '[collapse=0,第三层]\n第三层正文[/collapse]\n'
        '[/collapse]\n'
        '[/collapse]';
    await tester.pumpWidget(_buildEditor(initialBbCode: initial));
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-2')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('test-quill-collapse-editor-body-collapse-button')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key(
          'test-quill-collapse-editor-body-collapse-editor-body-collapse-button',
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-0')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('composer-quill-collapse-collapse-0-toggle')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-collapse-0-toggle')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('composer-quill-collapse-collapse-0-content')),
      findsOneWidget,
    );
    expect(find.textContaining('第三层正文', findRichText: true), findsOneWidget);
  });

  testWidgets('collapse title and body can both be deleted to empty', (
    tester,
  ) async {
    var latest = '[collapse=0,标题]\n正文[/collapse]';
    await tester.pumpWidget(
      _buildEditor(
        initialBbCode: latest,
        onBbCodeChanged: (value) => latest = value,
      ),
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-0')),
    );
    await tester.pumpAndSettle();

    final titleFinder = find.byKey(
      const Key('test-quill-collapse-editor-title-field'),
    );
    final titleController = tester.widget<TextField>(titleFinder).controller!;
    await tester.enterText(titleFinder, '');
    await tester.pump();
    expect(
      tester.widget<TextField>(titleFinder).controller,
      same(titleController),
    );
    final bodyFinder = find.byKey(
      const Key('test-quill-collapse-editor-body-editor'),
    );
    final bodyController = tester.widget<QuillEditor>(bodyFinder).controller;
    bodyController.replaceText(
      0,
      2,
      '',
      const TextSelection.collapsed(offset: 0),
    );
    await tester.pump();
    expect(
      tester.widget<QuillEditor>(bodyFinder).controller,
      same(bodyController),
    );
    expect(bodyController.document.toPlainText(), '\n');

    await tester.tap(
      find.byKey(const Key('test-quill-collapse-editor-save-button')),
    );
    await tester.pumpAndSettle();
    expect(latest, '[collapse=0,]\n[/collapse]');
  });

  testWidgets('delete confirmation removes one atomic collapse', (
    tester,
  ) async {
    var latest = '[collapse=0,标题]\n正文[/collapse]';
    await tester.pumpWidget(
      _buildEditor(
        initialBbCode: latest,
        onBbCodeChanged: (value) => latest = value,
      ),
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('test-quill-collapse-editor-delete-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('test-quill-collapse-editor-delete-confirm-button')),
    );
    await tester.pumpAndSettle();

    expect(latest, isEmpty);
    expect(
      find.byKey(const Key('test-quill-collapse-editor-page')),
      findsNothing,
    );
  });

  testWidgets('upload bridge blocks collapse save delete and route exit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildEditor(
        initialBbCode: '[collapse=0,标题]\n正文[/collapse]',
        isUploadingImages: true,
        imageUploadCurrent: 1,
        imageUploadTotal: 2,
      ),
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-0')),
    );
    await tester.pumpAndSettle();

    final saveButton = tester.widget<IconButton>(
      find.byKey(const Key('test-quill-collapse-editor-save-button')),
    );
    final deleteButton = tester.widget<IconButton>(
      find.byKey(const Key('test-quill-collapse-editor-delete-button')),
    );
    expect(saveButton.onPressed, isNull);
    expect(deleteButton.onPressed, isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    expect(
      find.byKey(const Key('test-quill-collapse-editor-page')),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('collapse image insertion stays local until save', (
    tester,
  ) async {
    const initial = '[collapse=0,标题]\n正文[/collapse]';
    const codec = ComposerQuillBbCodeCodec();
    final document = codec.decodeDocument(initial);
    final rootController = QuillController(
      document: document,
      selection: TextSelection.collapsed(offset: document.length - 1),
    );
    addTearDown(rootController.dispose);
    var latest = initial;
    await tester.pumpWidget(
      _buildEditor(
        controller: rootController,
        onBbCodeChanged: (value) => latest = value,
        onImagePressed: (anchor) async {
          _insertTestAttachment(rootController, anchor);
        },
        imageAttachments: [_uploadedAttachment()],
        attachImageBuilder: _buildTestAttachPreviewImage,
        attachFileExists: _testAttachFileExists,
      ),
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-0')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('test-quill-collapse-editor-body-image-button')),
    );
    await tester.pumpAndSettle();

    expect(latest, initial);
    final bodyEditor = tester.widget<QuillEditor>(
      find.byKey(const Key('test-quill-collapse-editor-body-editor')),
    );
    expect(
      codec.encodeDocument(bodyEditor.controller.document),
      '正文\n[attach]123456[/attach]',
    );

    await tester.tap(
      find.byKey(const Key('test-quill-collapse-editor-save-button')),
    );
    await tester.pumpAndSettle();

    expect(latest, '[collapse=0,标题]\n正文\n[attach]123456[/attach]\n[/collapse]');
  });

  testWidgets('external parent replacement keeps conflicting editor open', (
    tester,
  ) async {
    final key = GlobalKey<_ControlledCollapseHarnessState>();
    await tester.pumpWidget(
      _buildControlledCollapseEditor(
        key: key,
        initialBbCode: '[collapse=0,标题]\n正文[/collapse]',
      ),
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-0')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('conflict-quill-collapse-editor-title-field')),
      '本地标题',
    );

    key.currentState!.replaceExternally('外部替换');
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('conflict-quill-collapse-editor-save-button')),
    );
    await tester.pumpAndSettle();

    expect(key.currentState!.source, '外部替换');
    expect(
      find.byKey(const Key('conflict-quill-collapse-editor-page')),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
