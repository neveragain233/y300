part of 'reply_composer_page_test.dart';

void _draftCases() {
  testWidgets('ReplyComposerPage restores draft into input', (tester) async {
    final args = _threadArgs();
    final draftRepository = _MemoryReplyDraftRepository();
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '恢复的草稿',
        useSignature: false,
        updatedAt: DateTime.utc(2026, 6, 6),
      ),
    );

    await tester.pumpWidget(
      _buildPage(args: args, draftRepository: draftRepository),
    );
    await tester.pump();
    await tester.pump();

    await _openReplySourceEditor(tester);
    final restoredField = tester.widget<TextField>(
      find.byKey(const Key('reply-composer-message-input')),
    );
    expect(restoredField.controller?.text, '恢复的草稿');
    expect(find.text('已恢复未发送草稿'), findsOneWidget);
    expect(
      find.byKey(const Key('reply-composer-restored-draft-banner')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('reply-composer-use-signature-switch')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('reply-composer-more-button')));
    await tester.pumpAndSettle();
    final switchTile = tester.widget<prism.Switch>(
      find.byKey(const Key('reply-composer-use-signature-switch')),
    );
    expect(switchTile.value, isFalse);
    await tester.tap(
      find.byKey(const Key('reply-composer-use-signature-switch')),
    );
    await tester.pumpAndSettle();
    final toggledSwitchTile = tester.widget<prism.Switch>(
      find.byKey(const Key('reply-composer-use-signature-switch')),
    );
    expect(toggledSwitchTile.value, isTrue);
  });

  testWidgets('ReplyComposerPage restores uploaded image without upload UI', (
    tester,
  ) async {
    final args = _threadArgs();
    final draftRepository = _MemoryReplyDraftRepository();
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '正文\n[attach]123456[/attach]',
        useSignature: true,
        updatedAt: DateTime.utc(2026, 6, 8),
        imageAttachments: [
          _uploadedAttachment(
            localId: 'image-1',
            aid: '123456',
            uploadedAt: DateTime.utc(2026, 6, 8, 10),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _buildPage(args: args, draftRepository: draftRepository),
    );
    await tester.pump();

    expect(find.byKey(const Key('reply-composer-image-queue')), findsNothing);
    expect(find.textContaining('已上传'), findsNothing);
    expect(
      find.byKey(const Key('composer-quill-attach-123456')),
      findsOneWidget,
    );
  });

  testWidgets('ReplyComposerPage resets persisted content after confirmation', (
    tester,
  ) async {
    final args = _threadArgs();
    final draftRepository = _MemoryReplyDraftRepository();
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '正文\n[attach]123456[/attach]',
        useSignature: false,
        updatedAt: DateTime.now(),
        imageAttachments: [
          _uploadedAttachment(
            localId: 'image-1',
            aid: '123456',
            uploadedAt: DateTime.now(),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _buildPage(args: args, draftRepository: draftRepository),
    );
    await tester.pumpAndSettle();
    await _openReplySourceEditor(tester);

    await tester.tap(find.byKey(const Key('reply-composer-more-button')));
    await tester.pumpAndSettle();
    final resetTile = tester.widget<ListTile>(
      find.byKey(const Key('reply-composer-reset-draft-button')),
    );
    expect(resetTile.enabled, isTrue);

    await tester.tap(
      find.byKey(const Key('reply-composer-reset-draft-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('重置草稿？'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('reply-composer-reset-cancel-button')),
    );
    await tester.pumpAndSettle();
    var messageField = tester.widget<TextField>(
      find.byKey(const Key('reply-composer-message-input')),
    );
    expect(messageField.controller?.text, contains('正文'));

    await tester.tap(find.byKey(const Key('reply-composer-more-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('reply-composer-reset-draft-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('reply-composer-reset-confirm-button')),
    );
    await tester.pumpAndSettle();

    messageField = tester.widget<TextField>(
      find.byKey(const Key('reply-composer-message-input')),
    );
    expect(messageField.controller?.text, isEmpty);
    expect(find.byKey(const Key('reply-composer-image-queue')), findsNothing);
    expect(await draftRepository.loadDraft(args.identity), isNull);

    await tester.tap(find.byKey(const Key('reply-composer-more-button')));
    await tester.pumpAndSettle();
    final signatureSwitch = tester.widget<prism.Switch>(
      find.byKey(const Key('reply-composer-use-signature-switch')),
    );
    expect(signatureSwitch.value, isFalse);
    final disabledResetTile = tester.widget<ListTile>(
      find.byKey(const Key('reply-composer-reset-draft-button')),
    );
    expect(disabledResetTile.enabled, isFalse);
  });

  testWidgets('ReplyComposerPage restores uploaded attach embed', (
    tester,
  ) async {
    const path = 'E:/test/reply/restored.png';
    final args = _threadArgs();
    final draftRepository = _MemoryReplyDraftRepository();
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '正文\n[attach]123456[/attach]',
        useSignature: true,
        updatedAt: DateTime.utc(2026, 6, 8),
        imageAttachments: [
          _uploadedAttachment(
            localId: 'image-1',
            aid: '123456',
            uploadedAt: DateTime.utc(2026, 6, 8, 10),
            localPath: path,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _buildPage(args: args, draftRepository: draftRepository),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('composer-quill-attach-123456')),
      findsOneWidget,
    );
    expect(
      find.textContaining('[attach]123456[/attach]', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('ReplyComposerPage keeps remote-valid image after cache expiry', (
    tester,
  ) async {
    final args = _threadArgs();
    final draftRepository = _MemoryReplyDraftRepository(
      now: () => DateTime.utc(2026, 6, 8, 12),
    );
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '正文\n[attach]123456[/attach]',
        useSignature: true,
        updatedAt: DateTime.utc(2026, 6, 8),
        imageAttachments: [
          _uploadedAttachment(
            localId: 'expired',
            aid: '123456',
            uploadedAt: DateTime.utc(2026, 5, 24, 12),
            cachePath: '/cache/expired.jpg',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _buildPage(
        args: args,
        draftRepository: draftRepository,
        draftVerificationService: const _PassThroughDraftVerificationService(),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('composer-quill-attach-123456')),
      findsOneWidget,
    );
    await _openReplySourceEditor(tester);
    final sanitizedField = tester.widget<TextField>(
      find.byKey(const Key('reply-composer-message-input')),
    );
    expect(sanitizedField.controller?.text, '正文\n[attach]123456[/attach]');
  });

  testWidgets('ReplyComposerPage reports failed draft image verification', (
    tester,
  ) async {
    final args = _threadArgs();
    final draftRepository = _MemoryReplyDraftRepository();
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '正文\n[attach]123456[/attach]',
        useSignature: true,
        updatedAt: DateTime.utc(2026, 8, 3),
        imageAttachments: [
          _uploadedAttachment(
            localId: 'image-1',
            aid: '123456',
            uploadedAt: DateTime.utc(2026, 8, 3),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _buildPage(
        args: args,
        draftRepository: draftRepository,
        draftVerificationService:
            const _FailedDraftAttachmentVerificationService(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('reply-composer-draft-image-verification-error')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reply-composer-retry-draft-image-verification')),
      findsOneWidget,
    );
    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('reply-composer-send-button')),
    );
    expect(sendButton.onPressed, isNotNull);
  });

  testWidgets('ReplyComposerPage reports invalid images but keeps BBCode', (
    tester,
  ) async {
    final args = _threadArgs();
    final draftRepository = _MemoryReplyDraftRepository();
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '正文\n[attach]123456[/attach]',
        useSignature: true,
        updatedAt: DateTime.utc(2026, 8, 3),
        imageAttachments: [
          _uploadedAttachment(
            localId: 'image-1',
            aid: '123456',
            uploadedAt: DateTime.utc(2026, 8, 3),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _buildPage(
        args: args,
        draftRepository: draftRepository,
        draftVerificationService:
            const _InvalidDraftAttachmentVerificationService(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('reply-composer-invalid-draft-images-snackbar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('reply-composer-invalid-draft-images')),
      findsNothing,
    );

    // A normal page rebuild must not enqueue the same verification result again.
    await tester.tap(find.byKey(const Key('reply-composer-source-button')));
    await tester.pump();
    expect(
      find.byKey(const Key('reply-composer-invalid-draft-images-snackbar')),
      findsOneWidget,
    );

    await _openReplySourceEditor(tester);
    final source = tester.widget<TextField>(
      find.byKey(const Key('reply-composer-message-input')),
    );
    expect(source.controller?.text, '正文\n[attach]123456[/attach]');
  });
}
