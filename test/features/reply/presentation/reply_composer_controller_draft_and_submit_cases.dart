part of 'reply_composer_controller_test.dart';

void _draftAndSubmitCases() {
  test('restores thread draft on build', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final args = _threadArgs(tid: '572063');
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '恢复的草稿',
        useSignature: false,
        updatedAt: DateTime.utc(2026, 6, 6),
      ),
    );
    final container = _buildContainer(draftRepository: draftRepository);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);

    final state = await container.read(
      replyComposerControllerProvider(args).future,
    );

    expect(state.message, '恢复的草稿');
    expect(state.useSignature, isFalse);
  });

  test('restores draft image attachment queue on build', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final args = _threadArgs(tid: '572063');
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
    final container = _buildContainer(draftRepository: draftRepository);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);

    final state = await container.read(
      replyComposerControllerProvider(args).future,
    );

    expect(state.message, '正文\n[attach]123456[/attach]');
    expect(state.imageAttachments, hasLength(1));
    expect(state.imageAttachments.single.localId, 'image-1');
    expect(
      state.imageAttachments.single.status,
      ComposerImageAttachmentStatus.uploaded,
    );
  });

  test('different thread does not reuse draft', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: const ComposerDraftIdentity.thread(fid: '33', tid: '572063'),
        message: '旧帖子草稿',
        useSignature: true,
        updatedAt: DateTime.utc(2026, 6, 6),
      ),
    );
    final container = _buildContainer(draftRepository: draftRepository);
    addTearDown(container.dispose);
    final args = _threadArgs(tid: '572064');
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);

    final state = await container.read(
      replyComposerControllerProvider(args).future,
    );

    expect(state.message, isEmpty);
  });

  test('new draft uses the device signature default', () async {
    final preferencesRepository = _MemoryComposerPreferencesRepository(
      preferences: const ComposerPreferences(
        defaultSurface: ComposerSurfacePreference.quill,
        newDraftUseSignature: false,
      ),
    );
    final args = _threadArgs(tid: '572064');
    final container = _buildContainer(
      preferencesRepository: preferencesRepository,
    );
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);

    final state = await container.read(
      replyComposerControllerProvider(args).future,
    );

    expect(state.restoredDraft, isFalse);
    expect(state.useSignature, isFalse);
  });

  test('flushDraft saves latest message and signature state', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(draftRepository: draftRepository);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);
    final controller = container.read(
      replyComposerControllerProvider(args).notifier,
    );

    controller.updateMessage('新的草稿');
    controller.toggleUseSignature(false);
    await controller.flushDraft();

    final saved = await draftRepository.loadDraft(args.identity);
    expect(saved?.message, '新的草稿');
    expect(saved?.useSignature, isFalse);
  });

  test('flushDraft saves uploaded attachment metadata', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final imagePicker = _FakeReplyImagePicker(
      images: const [
        ComposerPickedImage(
          path: '/gallery/first.jpg',
          fileName: 'first.jpg',
          mimeType: 'image/jpeg',
          originalIndex: 0,
        ),
      ],
    );
    final uploadCoordinator = _FakeReplyImageUploadCoordinator(
      events: [
        ComposerImageUploadEvent.uploaded(
          localId: '',
          current: 1,
          total: 1,
          uploadedImage: ComposerUploadedImage(
            localId: '',
            aid: '123456',
            uploadedAt: DateTime.utc(2026, 6, 8, 10),
          ),
        ),
        const ComposerImageUploadEvent.completed(total: 1),
      ],
    );
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(
      draftRepository: draftRepository,
      imagePicker: imagePicker,
      imageUploadCoordinator: uploadCoordinator,
    );
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);
    final controller = container.read(
      replyComposerControllerProvider(args).notifier,
    );

    await controller.pickImages(
      insertionAnchor: const ComposerInsertionAnchor(
        baseRevision: 0,
        selection: ComposerSelection(start: 0, end: 0),
        mode: ComposerEditorMode.source,
      ),
    );
    await _drainMicrotasks();
    await controller.flushDraft();

    final saved = await draftRepository.loadDraft(args.identity);
    expect(saved?.message, '[attach]123456[/attach]\n');
    expect(saved?.imageAttachments, hasLength(1));
    expect(saved?.imageAttachments.single.aid, '123456');
    expect(
      saved?.imageAttachments.single.uploadedAt,
      DateTime.utc(2026, 6, 8, 10),
    );
  });

  test('empty input does not submit', () async {
    final replyRepository = _FakeThreadReplyAdapter();
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(replyRepository: replyRepository);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);

    final result = await container
        .read(replyComposerControllerProvider(args).notifier)
        .submit();

    expect(result.sent, isFalse);
    expect(replyRepository.sentDrafts, isEmpty);
    expect(
      container.read(replyComposerControllerProvider(args)).value?.failure,
      isA<ComposerValidationFailure>().having(
        (failure) => failure.code,
        'code',
        ComposerValidationFailureCode.contentRequired,
      ),
    );
  });

  test('successful submit sends draft and deletes saved draft', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final replyRepository = _FakeThreadReplyAdapter(
      result: const DataCommandApplied<ThreadReplyReceipt>(
        ThreadReplyReceipt(
          tid: '572063',
          pid: '41554318',
          publicationState: ThreadPublicationState.published,
        ),
      ),
    );
    final args = _threadArgs(tid: '572063');
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '旧草稿',
        useSignature: true,
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
    await container.read(replyComposerControllerProvider(args).future);
    final controller = container.read(
      replyComposerControllerProvider(args).notifier,
    );
    controller.updateMessage('提交内容');
    controller.toggleUseSignature(false);

    final result = await controller.submit();

    expect(result.sent, isTrue);
    expect(replyRepository.sentDrafts, hasLength(1));
    expect(replyRepository.sentDrafts.single.target.fid, '33');
    expect(replyRepository.sentDrafts.single.target.tid, '572063');
    expect(replyRepository.sentDrafts.single.message, '提交内容');
    expect(replyRepository.sentDrafts.single.useSignature, isFalse);
    expect(await draftRepository.loadDraft(args.identity), isNull);
  });

  test(
    'submit keeps a remote-valid aid after local retention elapses',
    () async {
      final draftRepository = _MemoryReplyDraftRepository();
      final replyRepository = _FakeThreadReplyAdapter();
      final args = _threadArgs(tid: '572063');
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
              uploadedAt: DateTime.now().subtract(const Duration(days: 15)),
              cachePath: '/cache/expired.jpg',
            ),
          ],
        ),
      );
      final container = _buildContainer(
        draftRepository: draftRepository,
        replyRepository: replyRepository,
        draftVerificationService: const _PassThroughDraftVerificationService(),
      );
      addTearDown(container.dispose);
      final subscription = _keepComposerAlive(container, args);
      addTearDown(subscription.close);
      await container.read(replyComposerControllerProvider(args).future);

      final result = await container
          .read(replyComposerControllerProvider(args).notifier)
          .submit();

      expect(result.sent, isTrue);
      expect(
        replyRepository.sentDrafts.single.message,
        '正文\n[attach]123456[/attach]',
      );
      expect(replyRepository.sentDrafts.single.attachmentIds, <String>[
        '123456',
      ]);
      final state = container.read(replyComposerControllerProvider(args)).value;
      expect(state?.imageAttachments, isEmpty);
    },
  );

  test(
    'submit binds uploaded attachment aid when attach code remains',
    () async {
      final draftRepository = _MemoryReplyDraftRepository();
      final replyRepository = _FakeThreadReplyAdapter();
      final args = _threadArgs(tid: '572063');
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
              uploadedAt: DateTime.now(),
            ),
          ],
        ),
      );
      final container = _buildContainer(
        draftRepository: draftRepository,
        replyRepository: replyRepository,
      );
      addTearDown(container.dispose);
      final subscription = _keepComposerAlive(container, args);
      addTearDown(subscription.close);
      await container.read(replyComposerControllerProvider(args).future);

      final result = await container
          .read(replyComposerControllerProvider(args).notifier)
          .submit();

      expect(result.sent, isTrue);
      expect(replyRepository.sentDrafts.single.attachmentIds, ['123456']);
    },
  );

  test(
    'submit skips uploaded attachment aid when attach code is removed',
    () async {
      final draftRepository = _MemoryReplyDraftRepository();
      final replyRepository = _FakeThreadReplyAdapter();
      final args = _threadArgs(tid: '572063');
      await draftRepository.saveDraft(
        ComposerDraftSnapshot(
          identity: args.identity,
          message: '正文',
          useSignature: true,
          updatedAt: DateTime.utc(2026, 6, 8),
          imageAttachments: [
            _uploadedAttachment(
              localId: 'image-1',
              aid: '123456',
              uploadedAt: DateTime.now(),
            ),
          ],
        ),
      );
      final container = _buildContainer(
        draftRepository: draftRepository,
        replyRepository: replyRepository,
      );
      addTearDown(container.dispose);
      final subscription = _keepComposerAlive(container, args);
      addTearDown(subscription.close);
      await container.read(replyComposerControllerProvider(args).future);

      final result = await container
          .read(replyComposerControllerProvider(args).notifier)
          .submit();

      expect(result.sent, isTrue);
      expect(replyRepository.sentDrafts.single.attachmentIds, isEmpty);
    },
  );

  test('submit skips non-uploaded attachment statuses', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final replyRepository = _FakeThreadReplyAdapter();
    final args = _threadArgs(tid: '572063');
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '正文\n[attach]123[/attach]\n[attach]456[/attach]',
        useSignature: true,
        updatedAt: DateTime.utc(2026, 6, 8),
        imageAttachments: [
          _attachmentWithStatus(
            localId: 'local',
            aid: '123',
            status: ComposerImageAttachmentStatus.local,
          ),
          _attachmentWithStatus(
            localId: 'failed',
            aid: '456',
            status: ComposerImageAttachmentStatus.failed,
          ),
        ],
      ),
    );
    final container = _buildContainer(
      draftRepository: draftRepository,
      replyRepository: replyRepository,
    );
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);

    final result = await container
        .read(replyComposerControllerProvider(args).notifier)
        .submit();

    expect(result.sent, isTrue);
    expect(replyRepository.sentDrafts.single.attachmentIds, isEmpty);
  });

  test(
    'submit binds multiple uploaded aids by attach code source order',
    () async {
      final draftRepository = _MemoryReplyDraftRepository();
      final replyRepository = _FakeThreadReplyAdapter();
      final args = _threadArgs(tid: '572063');
      await draftRepository.saveDraft(
        ComposerDraftSnapshot(
          identity: args.identity,
          message: '[attach]222[/attach]\n正文\n[attach]111[/attach]',
          useSignature: true,
          updatedAt: DateTime.utc(2026, 6, 8),
          imageAttachments: [
            _uploadedAttachment(
              localId: 'first',
              aid: '111',
              uploadedAt: DateTime.now(),
            ),
            _uploadedAttachment(
              localId: 'second',
              aid: '222',
              uploadedAt: DateTime.now(),
            ),
          ],
        ),
      );
      final container = _buildContainer(
        draftRepository: draftRepository,
        replyRepository: replyRepository,
      );
      addTearDown(container.dispose);
      final subscription = _keepComposerAlive(container, args);
      addTearDown(subscription.close);
      await container.read(replyComposerControllerProvider(args).future);

      final result = await container
          .read(replyComposerControllerProvider(args).notifier)
          .submit();

      expect(result.sent, isTrue);
      expect(replyRepository.sentDrafts.single.attachmentIds, ['222', '111']);
    },
  );

  test('failed submit keeps draft and exposes error', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final replyRepository = _FakeThreadReplyAdapter(
      result: const DataCommandOutcomeUnknown<ThreadReplyReceipt>(
        DataCommandFailure(
          kind: DataCommandFailureKind.network,
          retryPolicy: DataCommandRetryPolicy.explicitOnly,
          diagnosticMessage: 'test_network_failure',
        ),
      ),
    );
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(
      draftRepository: draftRepository,
      replyRepository: replyRepository,
    );
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);
    final controller = container.read(
      replyComposerControllerProvider(args).notifier,
    );
    controller.updateMessage('失败也要保留');

    final result = await controller.submit();

    expect(result.sent, isFalse);
    expect(
      container.read(replyComposerControllerProvider(args)).value?.failure,
      isA<ComposerSubmissionFailure>()
          .having(
            (failure) => failure.code,
            'code',
            ComposerSubmissionFailureCode.outcomeUnknown,
          )
          .having((failure) => failure.kind, 'kind', ComposerKind.reply),
    );
    expect((await draftRepository.loadDraft(args.identity))?.message, '失败也要保留');
  });

  test('failed submit keeps uploaded attachment draft metadata', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final replyRepository = _FakeThreadReplyAdapter(
      result: const DataCommandOutcomeUnknown<ThreadReplyReceipt>(
        DataCommandFailure(
          kind: DataCommandFailureKind.network,
          retryPolicy: DataCommandRetryPolicy.explicitOnly,
          diagnosticMessage: 'test_network_failure',
        ),
      ),
    );
    final args = _threadArgs(tid: '572063');
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
            uploadedAt: DateTime.now(),
          ),
        ],
      ),
    );
    final container = _buildContainer(
      draftRepository: draftRepository,
      replyRepository: replyRepository,
    );
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);

    final result = await container
        .read(replyComposerControllerProvider(args).notifier)
        .submit();

    expect(result.sent, isFalse);
    expect(replyRepository.sentDrafts.single.attachmentIds, ['123456']);
    final saved = await draftRepository.loadDraft(args.identity);
    expect(saved?.message, '正文\n[attach]123456[/attach]');
    expect(saved?.imageAttachments, hasLength(1));
  });

  test('build prunes drafts and tolerates prune failure', () async {
    final draftRepository = _MemoryReplyDraftRepository()..throwOnPrune = true;
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(draftRepository: draftRepository);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);

    final state = await container.read(
      replyComposerControllerProvider(args).future,
    );

    expect(draftRepository.pruneCallCount, 1);
    expect(state.message, isEmpty);
  });

  test('restored draft flag is true when draft exists', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final args = _threadArgs(tid: '572063');
    await draftRepository.saveDraft(
      ComposerDraftSnapshot(
        identity: args.identity,
        message: '旧草稿',
        useSignature: true,
        updatedAt: DateTime.utc(2026, 6, 6),
      ),
    );
    final container = _buildContainer(draftRepository: draftRepository);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);

    final state = await container.read(
      replyComposerControllerProvider(args).future,
    );

    expect(state.restoredDraft, isTrue);
  });
}
