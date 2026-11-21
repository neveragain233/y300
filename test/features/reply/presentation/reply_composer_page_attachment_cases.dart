part of 'reply_composer_page_test.dart';

void _attachmentCases() {
  testWidgets(
    'ReplyComposerPage shows uploaded image embed and submits raw attach code',
    (tester) async {
      const path = 'E:/test/reply/uploaded.png';
      final replyRepository = _FakeThreadReplyAdapter();
      await tester.pumpWidget(
        _buildPage(
          replyRepository: replyRepository,
          imagePicker: _FakeReplyImagePicker(
            images: [
              const ComposerPickedImage(
                path: path,
                fileName: 'uploaded.png',
                mimeType: 'image/png',
                originalIndex: 0,
              ),
            ],
          ),
          imageUploadCoordinator: _FakeReplyImageUploadCoordinator(
            events: [
              ComposerImageUploadEvent.uploaded(
                localId: '',
                current: 1,
                total: 1,
                uploadedImage: ComposerUploadedImage(
                  localId: '',
                  aid: '123456',
                  uploadedAt: DateTime.now(),
                ),
              ),
              const ComposerImageUploadEvent.completed(total: 1),
            ],
          ),
        ),
      );
      await tester.pump();
      await _enterReplySourceText(tester, '正文');
      await tester.pump();
      await tester.tap(find.byKey(const Key('reply-composer-source-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reply-composer-image-button')));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('composer-quill-attach-123456')),
      );
      await tester.pump();

      expect(find.byKey(const Key('reply-composer-image-queue')), findsNothing);
      expect(find.text('uploaded.png 已上传'), findsOneWidget);
      expect(
        find.byKey(const Key('composer-quill-attach-123456')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('composer-quill-attach-image-123456')),
        findsOneWidget,
      );
      final previewImage = tester.widget<_TestAttachPreviewImage>(
        find.byKey(const Key('composer-quill-attach-image-123456')),
      );
      expect(previewImage.file.path, path);
      expect(
        find.textContaining('[attach]123456[/attach]', findRichText: true),
        findsNothing,
      );

      await _openReplySourceEditor(tester);
      final sourceField = tester.widget<AppTextInput>(
        find.byKey(const Key('reply-composer-message-input')),
      );
      expect(
        sourceField.controller?.text,
        anyOf('正文\n[attach]123456[/attach]', '正文\n[attach]123456[/attach]\n'),
      );
      await tester.tap(find.byKey(const Key('reply-composer-send-button')));
      await tester.pumpAndSettle();

      expect(
        replyRepository.sentDrafts.single.message,
        anyOf('正文\n[attach]123456[/attach]', '正文\n[attach]123456[/attach]\n'),
      );
    },
  );

  testWidgets(
    'ReplyComposerPage shows upload failure without changing message',
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
          imageUploadCoordinator: _FakeReplyImageUploadCoordinator(
            events: [
              const ComposerImageUploadEvent.failed(
                localId: '',
                current: 1,
                total: 1,
                failure: ComposerImageUploadFailure(
                  code: ComposerImageUploadFailureCode.server,
                  detail: '图片上传失败',
                ),
              ),
              const ComposerImageUploadEvent.completed(total: 1),
            ],
          ),
        ),
      );
      await tester.pump();
      await _enterReplySourceText(tester, '正文');
      await tester.pump();
      await tester.tap(find.byKey(const Key('reply-composer-source-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reply-composer-image-button')));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('上传失败'), findsWidgets);
      expect(find.byKey(const Key('reply-composer-image-error')), findsNothing);
      await _openReplySourceEditor(tester);
      final sourceField = tester.widget<AppTextInput>(
        find.byKey(const Key('reply-composer-message-input')),
      );
      expect(sourceField.controller?.text, '正文');
      expect(find.textContaining('[attach]'), findsNothing);
    },
  );

  testWidgets('ReplyComposerPage submits post reply with prepared token', (
    tester,
  ) async {
    final replyRepository = _FakeThreadReplyAdapter();
    await tester.pumpWidget(
      _buildPage(args: _postArgs(), replyRepository: replyRepository),
    );
    await tester.pump();
    await tester.pump();
    await _enterReplySourceText(tester, '楼层回复');
    await tester.pump();
    await tester.tap(find.byKey(const Key('reply-composer-send-button')));
    await tester.pumpAndSettle();

    final draft = replyRepository.sentDrafts.single;
    expect(draft.target.pid, '41554317');
    expect(draft.preparation?.token, isA<_TestThreadReplyToken>());
    expect(draft.preparation?.quotePreview, '引用正文');
  });
}
