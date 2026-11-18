part of 'composer_quill_prototype_editor_test.dart';

void _attachStickerCases() {
  testWidgets('an illegal attach code stays editable text', (tester) async {
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
      '[attach]abc[/attach]',
      const TextSelection.collapsed(offset: 20),
    );
    await tester.pumpAndSettle();

    expect(find.byType(_TestAttachPreviewImage), findsNothing);
    expect(latest, '[attach]abc[/attach]');
    expect(
      controller.document.toPlainText().trimRight(),
      '[attach]abc[/attach]',
    );
  });

  testWidgets('a deleted image renders again once its code is retyped', (
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
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-image-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('composer-quill-attach-image-123456')),
      findsOneWidget,
    );
    final withImage = latest;

    // 手动删掉图片节点。
    controller.replaceText(0, 1, '', const TextSelection.collapsed(offset: 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('composer-quill-attach-image-123456')),
      findsNothing,
    );

    // 再把同一段 attach 代码原样写回去：编码结果与删除前完全相同，
    // 这条用例专门覆盖 `next == _bbCodeText` 的提前返回路径。
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
    expect(latest, withImage);
  });

  testWidgets('sticker drawer pages by sticker group', (tester) async {
    final controller = QuillController.basic();
    addTearDown(controller.dispose);
    String latest = '';

    await tester.pumpWidget(
      _buildEditor(
        controller: controller,
        onBbCodeChanged: (value) => latest = value,
        stickerGroups: _stickerGroups(),
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-sticker-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-quill-sticker-tabs')), findsOneWidget);
    expect(
      find.byKey(const Key('test-quill-sticker-group-tab-bugcat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('test-quill-sticker-group-tab-azukisan')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('test-quill-sticker-item-{:9_656:}')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('test-quill-sticker-item-{:6_1:}')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('test-quill-sticker-group-tab-azukisan')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('test-quill-sticker-item-{:6_1:}')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('test-quill-sticker-item-{:6_1:}')));
    await tester.pump();

    expect(latest, '{:6_1:}');
    expect(find.byKey(const Key('test-quill-sticker-sheet')), findsOneWidget);
  });

  testWidgets('sticker drawer restores and reports the shared group id', (
    tester,
  ) async {
    String? selectedGroupId;
    await tester.pumpWidget(
      _buildEditor(
        stickerGroups: _stickerGroups(),
        initialStickerGroupId: 'azukisan',
        onStickerGroupChanged: (groupId) => selectedGroupId = groupId,
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-sticker-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('test-quill-sticker-item-{:6_1:}')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('test-quill-sticker-group-tab-bugcat')),
    );
    await tester.pumpAndSettle();

    expect(selectedGroupId, 'bugcat');
  });

  testWidgets('unknown sticker group falls back to the first group', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildEditor(
        stickerGroups: _stickerGroups(),
        initialStickerGroupId: 'removed-group',
      ),
    );

    await tester.tap(find.byKey(const Key('test-quill-sticker-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('test-quill-sticker-item-{:9_656:}')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('test-quill-sticker-item-{:6_1:}')),
      findsNothing,
    );
  });

  testWidgets('inserted embeds can be deleted before continuing text', (
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

    controller.replaceText(0, 1, '', const TextSelection.collapsed(offset: 0));
    controller.replaceText(
      1,
      0,
      '后续',
      const TextSelection.collapsed(offset: 3),
    );
    await tester.pump();

    expect(latest, '\n后续[attach]123456[/attach]');
  });
}
