part of 'reply_composer_controller_test.dart';

void _attachmentCases() {
  test('pickImages uploads selected images and appends attach codes', () async {
    final imagePicker = _FakeReplyImagePicker(
      images: const [
        ComposerPickedImage(
          path: '/gallery/first.jpg',
          fileName: 'first.jpg',
          mimeType: 'image/jpeg',
          originalIndex: 0,
        ),
        ComposerPickedImage(
          path: '/gallery/second.png',
          fileName: 'second.png',
          mimeType: 'image/png',
          originalIndex: 1,
        ),
      ],
    );
    final uploadCoordinator = _FakeReplyImageUploadCoordinator(
      events: [
        const ComposerImageUploadEvent.started(
          localId: '',
          current: 1,
          total: 2,
        ),
        ComposerImageUploadEvent.uploaded(
          localId: '',
          current: 1,
          total: 2,
          uploadedImage: ComposerUploadedImage(
            localId: '',
            aid: '111',
            uploadedAt: DateTime.utc(2026, 6, 8),
          ),
        ),
        const ComposerImageUploadEvent.started(
          localId: '',
          current: 2,
          total: 2,
        ),
        ComposerImageUploadEvent.uploaded(
          localId: '',
          current: 2,
          total: 2,
          uploadedImage: ComposerUploadedImage(
            localId: '',
            aid: '222',
            uploadedAt: DateTime.utc(2026, 6, 8),
          ),
        ),
        const ComposerImageUploadEvent.completed(total: 2),
      ],
    );
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(
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

    final state = container.read(replyComposerControllerProvider(args)).value!;
    expect(imagePicker.pickCallCount, 1);
    expect(state.imageAttachments, hasLength(2));
    expect(state.imageAttachments.map((item) => item.fileName), [
      'first.jpg',
      'second.png',
    ]);
    expect(state.imageAttachments.map((item) => item.status), [
      ComposerImageAttachmentStatus.uploaded,
      ComposerImageAttachmentStatus.uploaded,
    ]);
    expect(state.message, '[attach]111[/attach]\n[attach]222[/attach]\n');
  });

  test('pickImages cancellation does not change state or draft', () async {
    final draftRepository = _MemoryReplyDraftRepository();
    final imagePicker = _FakeReplyImagePicker();
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(
      draftRepository: draftRepository,
      imagePicker: imagePicker,
    );
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);
    final controller = container.read(
      replyComposerControllerProvider(args).notifier,
    );
    controller.updateMessage('正文');

    await controller.pickImages();

    final state = container.read(replyComposerControllerProvider(args)).value!;
    expect(state.imageAttachments, isEmpty);
    expect(state.message, '正文');
    expect(await draftRepository.loadDraft(args.identity), isNull);
  });

  test(
    'pickImages marks failed upload and keeps failed aid out of message',
    () async {
      final imagePicker = _FakeReplyImagePicker(
        images: const [
          ComposerPickedImage(
            path: '/gallery/first.jpg',
            fileName: 'first.jpg',
            mimeType: 'image/jpeg',
            originalIndex: 0,
          ),
          ComposerPickedImage(
            path: '/gallery/second.jpg',
            fileName: 'second.jpg',
            mimeType: 'image/jpeg',
            originalIndex: 1,
          ),
        ],
      );
      final uploadCoordinator = _FakeReplyImageUploadCoordinator(
        events: [
          const ComposerImageUploadEvent.failed(
            localId: '',
            current: 1,
            total: 2,
            failure: ComposerImageUploadFailure(
              code: ComposerImageUploadFailureCode.server,
              detail: '第一张失败',
            ),
          ),
          ComposerImageUploadEvent.uploaded(
            localId: '',
            current: 2,
            total: 2,
            uploadedImage: ComposerUploadedImage(
              localId: '',
              aid: '222',
              uploadedAt: DateTime.utc(2026, 6, 8),
            ),
          ),
          const ComposerImageUploadEvent.completed(total: 2),
        ],
      );
      final args = _threadArgs(tid: '572063');
      final container = _buildContainer(
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

      final state = container
          .read(replyComposerControllerProvider(args))
          .value!;
      expect(state.imageAttachments.map((attachment) => attachment.status), [
        ComposerImageAttachmentStatus.failed,
        ComposerImageAttachmentStatus.uploaded,
      ]);
      expect(state.message, '[attach]222[/attach]\n');
      expect(
        state.imageUploadFailure?.code,
        ComposerImageUploadFailureCode.server,
      );
    },
  );

  test('pickImages does not run while upload is active', () async {
    final uploadCompleter = Completer<void>();
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
      events: const [
        ComposerImageUploadEvent.started(localId: '', current: 1, total: 1),
      ],
      holdUntil: uploadCompleter.future,
    );
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(
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
    unawaited(controller.pickImages());
    await _drainMicrotasks();
    await controller.pickImages();
    uploadCompleter.complete();

    expect(imagePicker.pickCallCount, 1);
  });

  test('pickImages exposes picker error', () async {
    final imagePicker = _FakeReplyImagePicker(
      error: const ComposerImagePickerException(cause: 'failed'),
    );
    final args = _threadArgs(tid: '572063');
    final container = _buildContainer(imagePicker: imagePicker);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);

    await container
        .read(replyComposerControllerProvider(args).notifier)
        .pickImages();

    expect(
      container
          .read(replyComposerControllerProvider(args))
          .value
          ?.imageUploadFailure
          ?.code,
      ComposerImageUploadFailureCode.pickerFailed,
    );
  });

  test('pickImages does not run while preparing post reply', () async {
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
    final args = _postArgs();
    final container = _buildContainer(imagePicker: imagePicker);
    addTearDown(container.dispose);
    final subscription = _keepComposerAlive(container, args);
    addTearDown(subscription.close);
    await container.read(replyComposerControllerProvider(args).future);

    await container
        .read(replyComposerControllerProvider(args).notifier)
        .pickImages();

    expect(imagePicker.pickCallCount, 0);
    expect(
      container
          .read(replyComposerControllerProvider(args))
          .value
          ?.imageAttachments,
      isEmpty,
    );
  });

  test(
    'duplicate submit while submitting does not call repository twice',
    () async {
      final completer = Completer<DataCommandResult<ThreadReplyReceipt>>();
      final replyRepository = _FakeThreadReplyAdapter(
        asyncResult: completer.future,
      );
      final args = _threadArgs(tid: '572063');
      final container = _buildContainer(replyRepository: replyRepository);
      addTearDown(container.dispose);
      final subscription = _keepComposerAlive(container, args);
      addTearDown(subscription.close);
      await container.read(replyComposerControllerProvider(args).future);
      final controller = container.read(
        replyComposerControllerProvider(args).notifier,
      );
      controller.updateMessage('提交内容');

      final first = controller.submit();
      final second = await controller.submit();
      completer.complete(
        const DataCommandApplied<ThreadReplyReceipt>(
          ThreadReplyReceipt(
            tid: '572063',
            pid: '41554318',
            publicationState: ThreadPublicationState.published,
          ),
        ),
      );
      await first;

      expect(second.sent, isFalse);
      expect(replyRepository.sentDrafts, hasLength(1));
    },
  );
}
