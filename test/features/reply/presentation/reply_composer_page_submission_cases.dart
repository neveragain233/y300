part of 'reply_composer_page_test.dart';

void _submissionCases() {
  testWidgets('ReplyComposerPage keeps send disabled for empty input', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('reply-composer-send-button')),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('ReplyComposerPage switches source and Quill editor', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage());
    await tester.pump();

    expect(
      find.byKey(const Key('reply-composer-quill-editor')),
      findsOneWidget,
    );
    await _enterReplySourceText(tester, '[b]粗体内容[/b]');
    await tester.pump();

    expect(
      find.byKey(const Key('reply-composer-bbcode-preview-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('reply-composer-message-input')),
      findsOneWidget,
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '[b]粗体内容[/b]');
    final sourceField = tester.widget<TextField>(
      find.byKey(const Key('reply-composer-message-input')),
    );
    final decoration = sourceField.decoration;
    expect(decoration?.border, InputBorder.none);
    expect(decoration?.enabledBorder, InputBorder.none);
    expect(decoration?.focusedBorder, InputBorder.none);
    expect(decoration?.disabledBorder, InputBorder.none);
    expect(decoration?.filled, isFalse);
    expect(decoration?.fillColor, isNull);

    await tester.tap(find.byKey(const Key('reply-composer-source-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('reply-composer-quill-editor')),
      findsOneWidget,
    );
    expect(find.text('粗体内容', findRichText: true), findsOneWidget);
  });

  testWidgets('ReplyComposerPage pops sent result after successful submit', (
    tester,
  ) async {
    final replyRepository = _FakeThreadReplyAdapter(result: _replyApplied);
    ReplyComposerResult? poppedResult;

    await tester.pumpWidget(
      _buildLauncher(
        replyRepository: replyRepository,
        onResult: (result) {
          poppedResult = result;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('open-reply-composer-page')));
    await tester.pumpAndSettle();
    await _enterReplySourceText(tester, '提交内容');
    await tester.pump();
    await tester.tap(find.byKey(const Key('reply-composer-send-button')));
    await tester.pumpAndSettle();

    expect(replyRepository.sentDrafts.single.message, '提交内容');
    expect(poppedResult?.sent, isTrue);
    expect(poppedResult?.rawSuccessDetail, isNull);
  });

  testWidgets('ReplyComposerPage submits raw source message from source mode', (
    tester,
  ) async {
    final replyRepository = _FakeThreadReplyAdapter(result: _replyApplied);

    await tester.pumpWidget(_buildLauncher(replyRepository: replyRepository));

    await tester.tap(find.byKey(const Key('open-reply-composer-page')));
    await tester.pumpAndSettle();
    await _enterReplySourceText(tester, '[quote]原始源码[/quote]');
    await tester.pump();
    await tester.tap(find.byKey(const Key('reply-composer-send-button')));
    await tester.pumpAndSettle();

    expect(replyRepository.sentDrafts.single.message, '[quote]原始源码[/quote]');
  });

  testWidgets('ReplyComposerPage inserts sticker code at cursor position', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(stickerGroups: _stickerGroups));
    await tester.pump();
    await _enterReplySourceText(tester, '前后');
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection.collapsed(offset: 1);

    await tester.tap(find.byKey(const Key('reply-composer-sticker-button')));
    await tester.pumpAndSettle();
    expect(find.text('貓貓蟲'), findsOneWidget);
    expect(find.text('{:9_656:}'), findsNothing);
    await tester.tap(find.byKey(const Key('reply-sticker-item-{:9_656:}')));
    await tester.pumpAndSettle();

    expect(find.text('前{:9_656:}后'), findsOneWidget);
  });

  testWidgets('ReplyComposerPage shows inserted sticker as Quill embed', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(stickerGroups: _stickerGroups));
    await tester.pump();
    await _enterReplySourceText(tester, '{:9_656:}');
    await tester.pump();
    await tester.tap(find.byKey(const Key('reply-composer-source-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('composer-quill-sticker-{:9_656:}')),
      findsOneWidget,
    );
    expect(find.textContaining('{:9_656:}', findRichText: true), findsNothing);
  });

  testWidgets('ReplyComposerPage submits raw sticker code', (tester) async {
    final replyRepository = _FakeThreadReplyAdapter(result: _replyApplied);

    await tester.pumpWidget(
      _buildLauncher(
        replyRepository: replyRepository,
        stickerGroups: _stickerGroups,
      ),
    );

    await tester.tap(find.byKey(const Key('open-reply-composer-page')));
    await tester.pumpAndSettle();
    await _enterReplySourceText(tester, '表情{:9_656:}');
    await tester.pump();
    await tester.tap(find.byKey(const Key('reply-composer-send-button')));
    await tester.pumpAndSettle();

    expect(replyRepository.sentDrafts.single.message, '表情{:9_656:}');
  });

  testWidgets('ReplyComposerPage shows post reply preparation banner', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(args: _postArgs()));
    await tester.pump();
    await tester.pump();

    expect(find.text('回复楼层'), findsOneWidget);
    expect(
      find.byKey(const Key('reply-composer-reference-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('引用正文'), findsOneWidget);
  });

  testWidgets('ReplyComposerPage shows post preparation failure and retry', (
    tester,
  ) async {
    final replyRepository = _FakeThreadReplyAdapter(
      preparationResult:
          const DataReadFailure<
            ThreadReplyPreparation,
            ThreadReplyCapabilities
          >(
            kind: DataReadFailureKind.parse,
            diagnosticMessage: 'test_form_parse_failure',
          ),
    );

    await tester.pumpWidget(
      _buildPage(args: _postArgs(), replyRepository: replyRepository),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('reply-composer-preparation-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reply-composer-retry-prepare-button')),
      findsOneWidget,
    );
    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('reply-composer-send-button')),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('ReplyComposerPage disables image button while preparing post', (
    tester,
  ) async {
    final preparationCompleter =
        Completer<
          DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>
        >();
    await tester.pumpWidget(
      _buildPage(
        args: _postArgs(),
        replyRepository: _FakeThreadReplyAdapter(
          asyncPreparationResult: preparationCompleter.future,
        ),
      ),
    );
    await tester.pump();

    final imageButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const Key('reply-composer-image-button')),
        matching: find.byType(IconButton),
      ),
    );
    expect(imageButton.onPressed, isNull);
    preparationCompleter.complete(
      DataReadSuccess<ThreadReplyPreparation, ThreadReplyCapabilities>(
        data: const ThreadReplyPreparation(
          target: ThreadReplyTarget.post(
            fid: '33',
            tid: '572063',
            pid: '41554317',
          ),
          token: _TestThreadReplyToken(),
        ),
        capabilities: _threadReplyCapabilities,
        metadata: const DataReadMetadata.network(),
      ),
    );
  });

  testWidgets('ReplyComposerPage does not show fixed upload queue', (
    tester,
  ) async {
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
            const ComposerImageUploadEvent.started(
              localId: '',
              current: 1,
              total: 1,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('reply-composer-image-button')));
    await tester.pump();

    expect(find.byKey(const Key('reply-composer-image-queue')), findsNothing);
    expect(find.text('first.jpg'), findsNothing);
    expect(find.textContaining('上传中'), findsNothing);
  });

  testWidgets('ReplyComposerPage inserts image block at the captured cursor', (
    tester,
  ) async {
    final replyRepository = _FakeThreadReplyAdapter();
    await tester.pumpWidget(
      _buildPage(
        replyRepository: replyRepository,
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
    await _pumpUntilMessageContains(tester, '[attach]123456[/attach]');
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(
      editable.controller.text,
      anyOf('正文\n[attach]123456[/attach]', '正文\n[attach]123456[/attach]\n'),
    );
    expect(find.byKey(const Key('reply-composer-image-queue')), findsNothing);
    expect(find.text('first.jpg 已上传'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reply-composer-send-button')));
    await tester.pumpAndSettle();

    expect(
      replyRepository.sentDrafts.single.message,
      anyOf('正文\n[attach]123456[/attach]', '正文\n[attach]123456[/attach]\n'),
    );
  });
}
