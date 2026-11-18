part of 'composer_quill_prototype_editor_test.dart';

void _linksAttachmentsCases() {
  testWidgets('link sheet inserts label and exports url BBCode', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-link-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('test-quill-tool-panel')), findsNothing);
    final linkUrlEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('test-quill-link-url-input')),
        matching: find.byType(EditableText),
      ),
    );
    expect(linkUrlEditable.focusNode.hasFocus, isTrue);
    await tester.enterText(
      find.byKey(const Key('test-quill-link-url-input')),
      'https://example.com',
    );
    await tester.enterText(
      find.byKey(const Key('test-quill-link-label-input')),
      '示例',
    );
    await tester.tap(find.byKey(const Key('test-quill-link-use-button')));
    await tester.pumpAndSettle();

    expect(latest, '[url=https://example.com]示例[/url]');
  });

  testWidgets('cancelling link sheet returns focus without changing content', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    controller.replaceText(
      0,
      0,
      '正文',
      const TextSelection.collapsed(offset: 2),
    );

    await tester.pumpWidget(_buildEditor(controller: controller));
    await tester.tap(find.byKey(const Key('test-quill-link-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-quill-link-cancel-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-quill-link-sheet')), findsNothing);
    expect(_editorFocusNode(tester).hasFocus, isTrue);
    expect(controller.document.toPlainText(), '正文\n');
  });

  testWidgets(
    'collapsed link insertion does not inherit active inline styles',
    (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);
      String latest = '';

      await tester.pumpWidget(
        _buildEditor(
          controller: controller,
          onBbCodeChanged: (value) => latest = value,
        ),
      );

      await tester.tap(find.byKey(const Key('test-quill-format-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test-quill-format-bold-toggle')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('test-quill-format-size-4')),
      );
      await tester.tap(find.byKey(const Key('test-quill-format-size-4')));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('test-quill-format-color-swatch-d32f2f')),
      );
      await tester.tap(
        find.byKey(const Key('test-quill-format-color-swatch-d32f2f')),
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('test-quill-link-button')),
      );
      await tester.tap(find.byKey(const Key('test-quill-link-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('test-quill-link-url-input')),
        'https://example.com',
      );
      await tester.enterText(
        find.byKey(const Key('test-quill-link-label-input')),
        '示例',
      );
      await tester.tap(find.byKey(const Key('test-quill-link-use-button')));
      await tester.pumpAndSettle();

      expect(latest, '[url=https://example.com]示例[/url]');
    },
  );

  testWidgets('multi line quote exports as one continuous quote block', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
      ),
    );
    controller.replaceText(
      0,
      0,
      '第一行\n第二行',
      const TextSelection(baseOffset: 0, extentOffset: 7),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('test-quill-quote-button')));
    await tester.pump();

    expect(latest, '[quote]第一行\n第二行[/quote]');
  });

  testWidgets(
    'quote toggles on a normal blank line after exiting quote as a new block',
    (tester) async {
      final controller = QuillController.basic();
      addTearDown(controller.dispose);
      String latest = '';

      await tester.pumpWidget(
        _buildEditor(
          controller: controller,
          onBbCodeChanged: (value) => latest = value,
        ),
      );

      await tester.tap(find.byKey(const Key('test-quill-quote-button')));
      await tester.pump();
      controller.replaceText(
        0,
        0,
        '旧引用',
        const TextSelection.collapsed(offset: 3),
      );
      await tester.pump();
      controller.replaceText(
        3,
        0,
        '\n',
        const TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      controller.replaceText(
        4,
        0,
        '\n',
        const TextSelection.collapsed(offset: 5),
      );
      await tester.pump();

      expect(_currentLineIsQuoted(controller), isFalse);

      await tester.tap(find.byKey(const Key('test-quill-quote-button')));
      await tester.pump();

      expect(_currentLineIsQuoted(controller), isTrue);

      final offset = controller.selection.start;
      controller.replaceText(
        offset,
        0,
        '新引用',
        TextSelection.collapsed(offset: offset + 3),
      );
      await tester.pump();

      expect(latest, '[quote]旧引用[/quote]\n[quote]新引用[/quote]');
    },
  );

  testWidgets('sticker and image callbacks insert embeds and export BBCode', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
        onImagePressed: (anchor) async {
          _insertTestAttachment(controller, anchor);
        },
        imageAttachments: [_uploadedAttachment()],
        attachImageBuilder: _buildTestAttachPreviewImage,
        attachFileExists: _testAttachFileExists,
        stickerGroups: _stickerGroups(),
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-sticker-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('test-quill-sticker-item-{:9_656:}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('test-quill-image-button')));
    await tester.pumpAndSettle();

    expect(latest, '{:9_656:}\n[attach]123456[/attach]');
    final stickerImage = tester.widget<ComposerStickerImage>(
      find.byKey(const Key('composer-quill-sticker-{:9_656:}')),
    );
    expect(stickerImage.width, isNull);
    expect(stickerImage.height, isNull);
    final frame = tester.widget<ConstrainedBox>(
      find.byKey(const Key('composer-quill-sticker-frame-{:9_656:}')),
    );
    expect(frame.constraints.maxWidth, 96);
    expect(frame.constraints.maxHeight, 96);
    expect(
      find.byKey(const Key('composer-quill-attach-image-123456')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('composer-quill-attach-123456')),
      findsOneWidget,
    );
  });

  testWidgets(
    'attachment preview follows the Quill body width without stretching small images',
    (tester) async {
      const narrowSurfaceWidth = 420.0;
      const wideSurfaceWidth = 620.0;
      final controller = QuillController.basic();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildEditor(
          controller: controller,
          surfaceWidth: narrowSurfaceWidth,
          imageAttachments: [_uploadedAttachment()],
          attachImageBuilder: _buildTestAttachPreviewImage,
          attachFileExists: _testAttachFileExists,
        ),
      );
      controller.replaceText(
        0,
        0,
        '[attach]123456[/attach]',
        const TextSelection.collapsed(offset: 23),
      );
      await tester.pumpAndSettle();

      var preview = tester.widget<ComposerAttachmentPreviewImage>(
        find.byKey(const Key('composer-quill-attach-preview-123456')),
      );
      expect(
        preview.maxWidth,
        closeTo(_expectedAttachmentMaxWidth(narrowSurfaceWidth), 0.001),
      );
      expect(preview.maxWidth, isNot(320));
      expect(
        tester.getSize(
          find.byKey(const Key('composer-quill-attach-image-123456')),
        ),
        const Size(32, 32),
      );

      await tester.pumpWidget(
        _buildEditor(
          controller: controller,
          surfaceWidth: wideSurfaceWidth,
          imageAttachments: [_uploadedAttachment()],
          attachImageBuilder: _buildTestAttachPreviewImage,
          attachFileExists: _testAttachFileExists,
        ),
      );
      await tester.pumpAndSettle();

      preview = tester.widget<ComposerAttachmentPreviewImage>(
        find.byKey(const Key('composer-quill-attach-preview-123456')),
      );
      expect(
        preview.maxWidth,
        closeTo(_expectedAttachmentMaxWidth(wideSurfaceWidth), 0.001),
      );
      expect(
        tester.getSize(
          find.byKey(const Key('composer-quill-attach-image-123456')),
        ),
        const Size(32, 32),
      );
    },
  );

  testWidgets('oversized attachment is constrained to the Quill body width', (
    tester,
  ) async {
    const surfaceWidth = 420.0;
    final controller = QuillController.basic();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        surfaceWidth: surfaceWidth,
        imageAttachments: [_uploadedAttachment()],
        attachImageBuilder: _buildWideTestAttachPreviewImage,
        attachFileExists: _testAttachFileExists,
      ),
    );
    controller.replaceText(
      0,
      0,
      '[attach]123456[/attach]',
      const TextSelection.collapsed(offset: 23),
    );
    await tester.pumpAndSettle();

    final imageSize = tester.getSize(
      find.byKey(const Key('composer-quill-attach-image-123456')),
    );
    expect(
      imageSize.width,
      closeTo(_expectedAttachmentMaxWidth(surfaceWidth), 0.001),
    );
    expect(imageSize.height, closeTo(imageSize.width / 2, 0.001));
  });

  testWidgets('a hand written legal attach code renders its image', (
    tester,
  ) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
        imageAttachments: [_uploadedAttachment()],
        attachImageBuilder: _buildTestAttachPreviewImage,
        attachFileExists: _testAttachFileExists,
      ),
    );

    controller.replaceText(
      0,
      0,
      '[attach]123456[/attach]',
      const TextSelection.collapsed(offset: 23),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('composer-quill-attach-image-123456')),
      findsOneWidget,
    );
    expect(latest, '[attach]123456[/attach]');
    // 归一后光标落到图片之后，逻辑宽度收缩为 1。
    expect(controller.selection.baseOffset, 1);
  });
}
