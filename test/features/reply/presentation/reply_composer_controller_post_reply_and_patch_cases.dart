part of 'reply_composer_controller_test.dart';

void _postReplyAndPatchCases() {
  test('submit sends BBCode source message unchanged', () async {
    final replyRepository = _FakeThreadReplyAdapter();
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(replyRepository: replyRepository);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);
    final controller = container.read(
      replyComposerControllerProvider(args).notifier,
    );

    controller.updateMessage('[quote]源码内容[/quote]');
    final result = await controller.submit();

    expect(result.sent, isTrue);
    expect(replyRepository.sentDrafts.single.message, '[quote]源码内容[/quote]');
  });

  test('post reply restores post draft and prepares reference', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final replyRepository = _FakeThreadReplyAdapter();
    final args = _postArgs();
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '楼层草稿',
        useSignature: false,
        updatedAt: DateTime.utc(2026, 6, 6),
      ),
    );
    final container = _buildContainer(
      draftRepository: draftRepository,
      replyRepository: replyRepository,
    );
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);

    final initialState = await container.read(
      replyComposerControllerProvider(args).future,
    );
    expect(initialState.message, '楼层草稿');
    expect(initialState.useSignature, isFalse);

    await _drainMicrotasks();
    final preparedState = container
        .read(replyComposerControllerProvider(args))
        .value;
    expect(replyRepository.prepareCallCount, 1);
    expect(preparedState?.preparation?.quotePreview, '[quote]引用[/quote]');
  });

  test('post reply submit preserves prepared opaque token', () async {
    final replyRepository = _FakeThreadReplyAdapter();
    final args = _postArgs();
    final container = _buildContainer(replyRepository: replyRepository);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);
    await _drainMicrotasks();
    final controller = container.read(
      replyComposerControllerProvider(args).notifier,
    );

    controller.updateMessage('回复楼层');
    final result = await controller.submit();

    expect(result.sent, isTrue);
    final draft = replyRepository.sentDrafts.single;
    expect(draft.target.kind, ThreadReplyTargetKind.post);
    expect(draft.target.pid, '41554317');
    expect(draft.preparation?.token, isA<_TestThreadReplyToken>());
    expect(draft.preparation?.quotePreview, '[quote]引用[/quote]');
  });

  test(
    'post reply preparation failure disables submit and keeps draft',
    () async {
      final draftRepository = _MemoryReplyDraftRepository();
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
      final args = _postArgs();
      final container = _buildContainer(
        draftRepository: draftRepository,
        replyRepository: replyRepository,
      );
      addTearDown(container.dispose);
      final subscription = _keepComposerAlive(container, args);
      addTearDown(subscription.close);
      await container.read(replyComposerControllerProvider(args).future);
      await _drainMicrotasks();
      final controller = container.read(
        replyComposerControllerProvider(args).notifier,
      );
      controller.updateMessage('失败也保留');

      final result = await controller.submit();

      expect(result.sent, isFalse);
      expect(replyRepository.sentDrafts, isEmpty);
      await controller.flushDraft();
      expect(
        (await draftRepository.loadDraft(args.identity))?.message,
        '失败也保留',
      );
    },
  );

  // 漏转发任何一个字段都会让基类的通用流程静默失效。
  test('applyPatch forwards every ComposerStatePatch field', () async {
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer();
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);

    final initial = await container.read(
      replyComposerControllerProvider(args).future,
    );
    final controller = container.read(
      replyComposerControllerProvider(args).notifier,
    );

    const mutation = ComposerTextMutation(
      previousSource: '旧',
      nextSource: '新',
      replacedSelection: ComposerSelection(start: 0, end: 1),
      resultSelection: ComposerSelection(start: 1, end: 1),
      revision: 9,
    );
    final applied = controller.applyPatch(
      initial,
      ComposerStatePatch(
        message: '新正文',
        useSignature: false,
        isSubmitting: true,
        restoredDraft: true,
        imageAttachments: [
          _attachmentWithStatus(
            localId: 'local-1',
            status: ComposerImageAttachmentStatus.local,
            aid: '',
          ),
        ],
        isUploadingImages: true,
        imageUploadCurrent: 2,
        imageUploadTotal: 3,
        messageRevision: 7,
        lastMessageMutation: mutation,
        pendingAttachmentAids: const ['888'],
        pendingAttachmentNotice: const ComposerPendingAttachmentNotice(
          code: ComposerPendingAttachmentNoticeCode.readyToReinsert,
          count: 1,
        ),
        failure: const ComposerSubmissionFailure(
          code: ComposerSubmissionFailureCode.unknown,
          kind: ComposerKind.reply,
          detail: '错误',
        ),
        imageUploadFailure: const ComposerImageUploadFailure(
          code: ComposerImageUploadFailureCode.unknown,
          detail: '上传错误',
        ),
      ),
    );

    expect(applied.message, '新正文');
    expect(applied.useSignature, isFalse);
    expect(applied.isSubmitting, isTrue);
    expect(applied.restoredDraft, isTrue);
    expect(applied.imageAttachments.single.localId, 'local-1');
    expect(applied.isUploadingImages, isTrue);
    expect(applied.imageUploadCurrent, 2);
    expect(applied.imageUploadTotal, 3);
    expect(applied.messageRevision, 7);
    expect(applied.lastMessageMutation, same(mutation));
    expect(applied.pendingAttachmentAids, ['888']);
    expect(
      applied.pendingAttachmentNotice?.code,
      ComposerPendingAttachmentNoticeCode.readyToReinsert,
    );
    expect(applied.failure?.detail, '错误');
    expect(applied.imageUploadFailure?.detail, '上传错误');

    final cleared = controller.applyPatch(
      applied,
      const ComposerStatePatch(
        clearFailure: true,
        clearImageUploadFailure: true,
        clearLastMessageMutation: true,
        clearPendingAttachmentNotice: true,
      ),
    );

    expect(cleared.failure, isNull);
    expect(cleared.imageUploadFailure, isNull);
    expect(cleared.lastMessageMutation, isNull);
    expect(cleared.pendingAttachmentNotice, isNull);
  });
}
