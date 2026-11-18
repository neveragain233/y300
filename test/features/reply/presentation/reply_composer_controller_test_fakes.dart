part of 'reply_composer_controller_test.dart';

ComposerImageAttachment _uploadedAttachment({
  required String localId,
  required String aid,
  required DateTime uploadedAt,
  String? cachePath,
}) {
  return _attachmentWithStatus(
    localId: localId,
    aid: aid,
    status: ComposerImageAttachmentStatus.uploaded,
    uploadedAt: uploadedAt,
    cachePath: cachePath,
  );
}

ComposerImageAttachment _attachmentWithStatus({
  required String localId,
  required String aid,
  required ComposerImageAttachmentStatus status,
  DateTime? uploadedAt,
  String? cachePath,
}) {
  return ComposerImageAttachment(
    localId: localId,
    localPath: '/gallery/$localId.jpg',
    fileName: '$localId.jpg',
    mimeType: 'image/jpeg',
    order: 0,
    status: status,
    aid: aid,
    uploadedAt: uploadedAt,
    cachePath: cachePath,
  );
}

ReplyComposerArgs _threadArgs({required String tid}) {
  return ReplyComposerArgs(
    target: ReplyTarget.thread(fid: '33', tid: tid),
  );
}

ReplyComposerArgs _postArgs() {
  final uri = Uri.parse(
    'https://bbs.yamibo.com/forum.php?mod=post&action=reply&fid=33&tid=572063&repquote=41554317&mobile=2',
  );
  return ReplyComposerArgs(
    target: ReplyTarget.post(
      fid: '33',
      tid: '572063',
      pid: '41554317',
      sourceUri: uri,
    ),
    replyFormUri: uri,
  );
}

ProviderContainer _buildContainer({
  ComposerDraftRepository? draftRepository,
  ComposerPreferencesRepository? preferencesRepository,
  _FakeThreadReplyAdapter? replyRepository,
  ComposerImagePicker? imagePicker,
  ComposerImageUploadCoordinator? imageUploadCoordinator,
  ComposerDraftAttachmentVerificationService? draftVerificationService,
}) {
  return ProviderContainer(
    overrides: [
      composerDraftRepositoryProvider.overrideWithValue(
        draftRepository ?? _MemoryReplyDraftRepository(),
      ),
      composerPreferencesRepositoryProvider.overrideWithValue(
        preferencesRepository ?? _MemoryComposerPreferencesRepository(),
      ),
      threadReplyPreparationProvider.overrideWithValue(
        replyRepository ?? _FakeThreadReplyAdapter(),
      ),
      threadReplyCommandProvider.overrideWithValue(
        replyRepository ?? _FakeThreadReplyAdapter(),
      ),
      composerImagePickerProvider.overrideWithValue(
        imagePicker ?? _FakeReplyImagePicker(),
      ),
      composerImageUploadCoordinatorProvider.overrideWithValue(
        imageUploadCoordinator ?? _FakeReplyImageUploadCoordinator(),
      ),
      composerDraftAttachmentVerificationServiceProvider.overrideWithValue(
        draftVerificationService ??
            const _NoopDraftAttachmentVerificationService(),
      ),
    ],
  );
}

class _NoopDraftAttachmentVerificationService
    implements ComposerDraftAttachmentVerificationService {
  const _NoopDraftAttachmentVerificationService();

  @override
  Future<ComposerDraftAttachmentVerificationResult> verify(
    ComposerDraftSnapshot draft,
  ) async {
    return ComposerDraftAttachmentVerificationResult(
      draft: draft,
      verification: const ComposerDraftAttachmentVerification.notRequired(),
    );
  }
}

class _PassThroughDraftVerificationService
    implements ComposerDraftAttachmentVerificationService {
  const _PassThroughDraftVerificationService();

  @override
  Future<ComposerDraftAttachmentVerificationResult> verify(
    ComposerDraftSnapshot draft,
  ) async {
    final aids = const ComposerAttachBbCodeService()
        .extractAttachAids(draft.message)
        .toSet();
    return ComposerDraftAttachmentVerificationResult(
      draft: draft,
      verification: ComposerDraftAttachmentVerification.verified(
        imagesByAid: <String, ComposerUnusedImage>{
          for (final aid in aids)
            aid: ComposerUnusedImage(
              aid: aid,
              thumbnailUri: Uri.parse(
                'https://bbs.yamibo.com/forum.php?mod=image&aid=$aid&size=300x300',
              ),
              thumbnailRefererUri: Uri.parse(
                'https://bbs.yamibo.com/forum.php?mod=ajax&action=imagelist&posttime=0',
              ),
            ),
        },
        checkedAids: aids,
        invalidAidCount: 0,
      ),
    );
  }
}

ProviderSubscription<AsyncValue<ReplyComposerState>> _keepComposerAlive(
  ProviderContainer container,
  ReplyComposerArgs args,
) {
  return container.listen<AsyncValue<ReplyComposerState>>(
    replyComposerControllerProvider(args),
    (_, _) {},
  );
}

Future<void> _drainMicrotasks({int rounds = 4}) async {
  for (var index = 0; index < rounds; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _MemoryComposerPreferencesRepository
    implements ComposerPreferencesRepository {
  _MemoryComposerPreferencesRepository({ComposerPreferences? preferences})
    : preferences = preferences ?? ComposerPreferences.defaults();

  ComposerPreferences preferences;

  @override
  Future<ComposerPreferences> load() async => preferences;

  @override
  Future<void> save(ComposerPreferences preferences) async {
    this.preferences = preferences;
  }
}

class _MemoryReplyDraftRepository implements ComposerDraftRepository {
  final Map<String, ComposerDraftSnapshot> _drafts =
      <String, ComposerDraftSnapshot>{};
  bool throwOnPrune = false;
  int pruneCallCount = 0;

  @override
  Future<void> deleteDraft(ComposerDraftIdentity identity) async {
    _drafts.remove(identity.storageKey);
  }

  @override
  Future<List<ComposerDraftSnapshot>> listDraftsForThread({
    required String fid,
    required String tid,
  }) async {
    return _drafts.values
        .where(
          (draft) => draft.identity.fid == fid && draft.identity.tid == tid,
        )
        .toList(growable: false);
  }

  @override
  Future<ComposerDraftSnapshot?> loadDraft(
    ComposerDraftIdentity identity,
  ) async {
    return _drafts[identity.storageKey];
  }

  @override
  Future<ComposerDraftPruneResult> pruneDrafts({
    Duration maxAge = const Duration(days: 30),
    int maxCount = 100,
  }) async {
    pruneCallCount += 1;
    if (throwOnPrune) {
      throw StateError('prune failed');
    }
    return ComposerDraftPruneResult(removedCount: 0, keptCount: _drafts.length);
  }

  @override
  Future<void> saveDraft(ComposerDraftSnapshot draft) async {
    if (draft.isEmpty) {
      _drafts.remove(draft.identity.storageKey);
      return;
    }
    _drafts[draft.identity.storageKey] = draft;
  }
}

class _FakeReplyImagePicker implements ComposerImagePicker {
  _FakeReplyImagePicker({
    this.images = const <ComposerPickedImage>[],
    this.error,
  });

  final List<ComposerPickedImage> images;
  final ComposerImagePickerException? error;
  int pickCallCount = 0;

  @override
  Future<List<ComposerPickedImage>> pickImagesInOrder() async {
    pickCallCount += 1;
    final error = this.error;
    if (error != null) {
      throw error;
    }
    return images;
  }
}

class _FakeReplyImageUploadCoordinator
    implements ComposerImageUploadCoordinator {
  _FakeReplyImageUploadCoordinator({
    this.events = const <ComposerImageUploadEvent>[],
    this.holdUntil,
  });

  final List<ComposerImageUploadEvent> events;
  final Future<void>? holdUntil;
  bool cancelled = false;

  @override
  void cancel() {
    cancelled = true;
  }

  @override
  Stream<ComposerImageUploadEvent> uploadInOrder({
    required String fid,
    required List<ComposerImageAttachment> attachments,
  }) async* {
    for (var index = 0; index < events.length; index += 1) {
      if (cancelled) {
        return;
      }
      final event = events[index];
      if (event.type == ComposerImageUploadEventType.completed) {
        yield ComposerImageUploadEvent.completed(total: event.total);
        continue;
      }
      final localId = event.localId.isNotEmpty
          ? event.localId
          : attachments[(event.current - 1)
                    .clamp(0, attachments.length - 1)
                    .toInt()]
                .localId;
      yield _eventWithLocalId(event, localId);
    }
    final holdUntil = this.holdUntil;
    if (holdUntil != null) {
      await holdUntil;
    }
  }

  ComposerImageUploadEvent _eventWithLocalId(
    ComposerImageUploadEvent event,
    String localId,
  ) {
    return switch (event.type) {
      ComposerImageUploadEventType.started => ComposerImageUploadEvent.started(
        localId: localId,
        current: event.current,
        total: event.total,
      ),
      ComposerImageUploadEventType.progress =>
        ComposerImageUploadEvent.progress(
          localId: localId,
          current: event.current,
          total: event.total,
          progress: event.progress ?? 0,
        ),
      ComposerImageUploadEventType.uploaded =>
        ComposerImageUploadEvent.uploaded(
          localId: localId,
          current: event.current,
          total: event.total,
          uploadedImage: ComposerUploadedImage(
            localId: localId,
            aid: event.uploadedImage!.aid,
            uploadedAt: event.uploadedImage!.uploadedAt,
          ),
        ),
      ComposerImageUploadEventType.failed => ComposerImageUploadEvent.failed(
        localId: localId,
        current: event.current,
        total: event.total,
        failure:
            event.failure ??
            const ComposerImageUploadFailure(
              code: ComposerImageUploadFailureCode.unknown,
            ),
      ),
      ComposerImageUploadEventType.completed =>
        ComposerImageUploadEvent.completed(total: event.total),
    };
  }
}

final class _TestThreadReplyToken implements ThreadReplyPreparationToken {
  const _TestThreadReplyToken();
}

final ThreadReplyCapabilities _threadReplyCapabilities =
    ThreadReplyCapabilities(
      values: DataCapabilitySet<ThreadReplyCapability>.supported(
        ThreadReplyCapability.values,
      ),
    );

class _FakeThreadReplyAdapter
    implements ThreadReplyPreparationRepository, ThreadReplyCommand {
  _FakeThreadReplyAdapter({
    DataCommandResult<ThreadReplyReceipt>? result,
    this.asyncResult,
    DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>?
    preparationResult,
  }) : result =
           result ??
           const DataCommandApplied<ThreadReplyReceipt>(
             ThreadReplyReceipt(
               tid: '572063',
               pid: '41554318',
               publicationState: ThreadPublicationState.published,
             ),
           ),
       preparationResult =
           preparationResult ??
           DataReadSuccess<ThreadReplyPreparation, ThreadReplyCapabilities>(
             data: const ThreadReplyPreparation(
               target: ThreadReplyTarget.post(
                 fid: '33',
                 tid: '572063',
                 pid: '41554317',
               ),
               quotePreview: '[quote]引用[/quote]',
               token: _TestThreadReplyToken(),
             ),
             capabilities: _threadReplyCapabilities,
             metadata: const DataReadMetadata.network(),
           );

  final DataCommandResult<ThreadReplyReceipt> result;
  final Future<DataCommandResult<ThreadReplyReceipt>>? asyncResult;
  final DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>
  preparationResult;
  final List<ThreadReplySubmission> sentDrafts = <ThreadReplySubmission>[];
  int prepareCallCount = 0;

  @override
  ThreadReplyCapabilities get capabilities => _threadReplyCapabilities;

  @override
  Future<DataCommandResult<ThreadReplyReceipt>> execute(
    ThreadReplySubmission submission,
  ) async {
    sentDrafts.add(submission);
    final asyncResult = this.asyncResult;
    if (asyncResult != null) {
      return asyncResult;
    }
    return result;
  }

  @override
  Future<DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>> load(
    ThreadReplyPreparationRequest request,
  ) async {
    prepareCallCount += 1;
    return preparationResult;
  }
}
