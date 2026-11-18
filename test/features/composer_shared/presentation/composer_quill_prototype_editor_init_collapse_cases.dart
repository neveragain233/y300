part of 'composer_quill_prototype_editor_test.dart';

void _initCollapseCases() {
  testWidgets('composer surfaces align with native forum body spacing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const LocalizedTestApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 240,
            child: ComposerQuillEditorSurface(
              key: Key('spacing-quill-surface'),
              keyPrefix: 'spacing-quill',
              minHeight: 120,
            ),
          ),
        ),
      ),
    );

    final quillSurface = tester.widget<ComposerQuillEditorSurface>(
      find.byKey(const Key('spacing-quill-surface')),
    );
    final quillPadding = quillSurface.contentPadding.resolve(TextDirection.ltr);
    expect(
      quillPadding.left + ForumContentSpacing.quillInnerHorizontal,
      ForumContentSpacing.readableBodyHorizontal,
    );

    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: ComposerBbCodeSourceEditor(
                viewKey: const Key('spacing-source-editor'),
                inputKey: const Key('spacing-source-input'),
                controller: TextEditingController(),
                enabled: true,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final sourcePadding = tester.widget<Padding>(
      find.byKey(const Key('spacing-source-editor')),
    );
    final resolvedSourcePadding = sourcePadding.padding.resolve(
      TextDirection.ltr,
    );
    expect(
      resolvedSourcePadding.left + ForumContentSpacing.composerPageHorizontal,
      ForumContentSpacing.readableBodyHorizontal,
    );
  });

  testWidgets('collapse header toggles while only trailing icon edits', (
    tester,
  ) async {
    const source =
        '[collapse=0,外层]\n'
        '外层正文\n'
        '[collapse=0,内层]\n内层正文[/collapse]\n'
        '外层结尾[/collapse]';
    await tester.pumpWidget(_buildEditor(initialBbCode: source));

    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('composer-quill-collapse-collapse-1-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('test-quill-collapse-editor-page')),
      findsNothing,
    );
    await tester.tap(find.text('外层'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('composer-quill-collapse-collapse-1-content')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-collapse-1-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ForumCollapseChrome), findsNWidgets(2));
    await tester.tap(
      find.byKey(const Key('composer-quill-collapse-edit-collapse-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('test-quill-collapse-editor-page')),
      findsOneWidget,
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('composer-quill-collapse-collapse-1-content')),
      findsOneWidget,
    );
  });

  testWidgets('adjacent collapse cards get one scalable visual line gap', (
    tester,
  ) async {
    const source =
        '[collapse=0,第一]\n内容一[/collapse]\n'
        '[collapse=0,第二]\n内容二[/collapse]\n'
        '[collapse=0,第三]\n内容三[/collapse]';
    const firstGap = Key('composer-quill-collapse-gap-after-collapse-0');
    const secondGap = Key('composer-quill-collapse-gap-after-collapse-1');
    const trailingGap = Key('composer-quill-collapse-gap-after-collapse-2');

    await tester.pumpWidget(_buildEditor(initialBbCode: source, textScale: 1));

    expect(find.byKey(firstGap), findsOneWidget);
    expect(find.byKey(secondGap), findsOneWidget);
    expect(find.byKey(trailingGap), findsNothing);
    final normalHeight = tester.getSize(find.byKey(firstGap)).height;
    expect(normalHeight, greaterThan(0));
    expect(tester.getSize(find.byKey(secondGap)).height, normalHeight);

    await tester.pumpWidget(
      _buildEditor(initialBbCode: source, textScale: 1.5),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(firstGap)).height,
      greaterThan(normalHeight),
    );
  });

  testWidgets('existing blank or text suppresses synthetic collapse gap', (
    tester,
  ) async {
    const gap = Key('composer-quill-collapse-gap-after-collapse-0');
    await tester.pumpWidget(
      _buildEditor(
        initialBbCode:
            '[collapse=0,第一]\n内容一[/collapse]\n\n'
            '[collapse=0,第二]\n内容二[/collapse]',
      ),
    );
    expect(find.byKey(gap), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      _buildEditor(
        initialBbCode:
            '[collapse=0,第一]\n内容一[/collapse]\n'
            '间隔正文\n'
            '[collapse=0,第二]\n内容二[/collapse]',
      ),
    );
    expect(find.byKey(gap), findsNothing);
  });
}
