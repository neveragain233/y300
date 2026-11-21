part of 'reply_composer_page_test.dart';

void _caretCases() {
  testWidgets(
    'ReplyComposerPage source editor inserts the image at a mid message caret',
    (tester) async {
      await tester.pumpWidget(
        _buildPage(
          preferencesRepository: _FakeComposerPreferencesRepository(
            preferences: const ComposerPreferences(
              defaultSurface: ComposerSurfacePreference.source,
              newDraftUseSignature: true,
            ),
          ),
          imagePicker: _FakeReplyImagePicker(
            images: const [
              ComposerPickedImage(
                path: '/gallery/first.jpg',
                fileName: 'first.jpg',
                mimeType: 'image/jpeg',
                originalIndex: 0,
              ),
            ],
          ),
          imageUploadCoordinator: _uploadedAidCoordinator('123456'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reply-composer-message-input')),
        '第一行\n第二行',
      );
      await tester.pump();
      final field = tester.widget<AppTextInput>(
        find.byKey(const Key('reply-composer-message-input')),
      );
      field.controller!.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();

      await tester.tap(find.byKey(const Key('reply-composer-image-button')));
      await _pumpUntilMessageContains(tester, '[attach]123456[/attach]');
      await tester.pump();

      expect(field.controller!.text, '第一行\n[attach]123456[/attach]\n第二行');
      // 图片下一行的开头，也就是 `第二行` 的第一个字符前。
      expect(
        field.controller!.selection,
        const TextSelection.collapsed(offset: 28),
      );
    },
  );

  testWidgets(
    'ReplyComposerPage quill editor inserts the image at a mid message caret',
    (tester) async {
      await tester.pumpWidget(
        _buildPage(
          imagePicker: _FakeReplyImagePicker(
            images: const [
              ComposerPickedImage(
                path: '/gallery/first.jpg',
                fileName: 'first.jpg',
                mimeType: 'image/jpeg',
                originalIndex: 0,
              ),
            ],
          ),
          imageUploadCoordinator: _uploadedAidCoordinator('123456'),
        ),
      );
      await tester.pumpAndSettle();
      final quill = tester
          .widget<QuillEditor>(find.byType(QuillEditor))
          .controller;
      quill.document = Document()..insert(0, '第一行\n第二行');
      quill.updateSelection(
        const TextSelection.collapsed(offset: 3),
        ChangeSource.local,
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('reply-composer-image-button')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('composer-quill-attach-123456')),
      );
      await tester.pump();

      // 图片是长度 1 的 embed：`第一行`(0-2) `\n`(3) 图片(4) `\n`(5) `第二行`(6-8)。
      expect(quill.document.toPlainText(), '第一行\n￼\n第二行\n');
      expect(quill.selection, const TextSelection.collapsed(offset: 6));

      await _openReplySourceEditor(tester);
      final field = tester.widget<AppTextInput>(
        find.byKey(const Key('reply-composer-message-input')),
      );
      expect(field.controller!.text, '第一行\n[attach]123456[/attach]\n第二行');
    },
  );

  testWidgets(
    'ReplyComposerPage parks the upload when the captured caret is overwritten',
    (tester) async {
      final hold = Completer<void>();
      await tester.pumpWidget(
        _buildPage(
          preferencesRepository: _FakeComposerPreferencesRepository(
            preferences: const ComposerPreferences(
              defaultSurface: ComposerSurfacePreference.source,
              newDraftUseSignature: true,
            ),
          ),
          imagePicker: _FakeReplyImagePicker(
            images: const [
              ComposerPickedImage(
                path: '/gallery/first.jpg',
                fileName: 'first.jpg',
                mimeType: 'image/jpeg',
                originalIndex: 0,
              ),
            ],
          ),
          imageUploadCoordinator: _uploadedAidCoordinator(
            '123456',
            holdUntil: hold,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inputFinder = find.byKey(const Key('reply-composer-message-input'));
      await tester.enterText(inputFinder, '第一行\n第二行');
      await tester.pump();
      final field = tester.widget<AppTextInput>(inputFinder);
      field.controller!.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();

      await tester.tap(find.byKey(const Key('reply-composer-image-button')));
      await tester.pump();
      // 上传期间整段重写正文，捕获的光标已经不存在。
      await tester.enterText(inputFinder, '完全替换');
      await tester.pump();
      hold.complete();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('reply-composer-pending-attachment')),
        findsOneWidget,
      );
      expect(field.controller!.text, '完全替换');

      // 重新选好位置后再点图片按钮，才把已上传的附件插进来。
      field.controller!.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();
      await tester.tap(find.byKey(const Key('reply-composer-image-button')));
      await tester.pumpAndSettle();

      expect(field.controller!.text, '完全\n[attach]123456[/attach]\n替换');
      expect(
        find.byKey(const Key('reply-composer-pending-attachment')),
        findsNothing,
      );
    },
  );
}
