part of 'reply_composer_page_test.dart';

_FakeReplyImageUploadCoordinator _uploadedAidCoordinator(
  String aid, {
  Completer<void>? holdUntil,
}) {
  return _FakeReplyImageUploadCoordinator(
    holdUntil: holdUntil,
    events: [
      ComposerImageUploadEvent.uploaded(
        localId: '',
        current: 1,
        total: 1,
        uploadedImage: ComposerUploadedImage(
          localId: '',
          aid: aid,
          uploadedAt: DateTime(2026, 7, 26),
        ),
      ),
      const ComposerImageUploadEvent.completed(total: 1),
    ],
  );
}

Widget _buildPage({
  ReplyComposerArgs? args,
  ComposerDraftRepository? draftRepository,
  ComposerPreferencesRepository? preferencesRepository,
  _FakeThreadReplyAdapter? replyRepository,
  ComposerImagePicker? imagePicker,
  ComposerImageUploadCoordinator? imageUploadCoordinator,
  ComposerDraftAttachmentVerificationService? draftVerificationService,
  List<StickerGroup> stickerGroups = const [],
  ThemeData? theme,
  Locale locale = const Locale('zh'),
}) {
  return ProviderScope(
    overrides: [
      composerDraftRepositoryProvider.overrideWithValue(
        draftRepository ?? _MemoryReplyDraftRepository(),
      ),
      composerPreferencesRepositoryProvider.overrideWithValue(
        preferencesRepository ?? _FakeComposerPreferencesRepository(),
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
      forumBbCodeRendererProvider.overrideWithValue(_testRenderer),
      stickerGroupsProvider.overrideWith((_) async => stickerGroups),
      stickerPickerPreferencesRepositoryProvider.overrideWithValue(
        _FakeStickerPickerPreferencesRepository(),
      ),
      imageCacheServiceProvider.overrideWithValue(_FailingImageCacheService()),
    ],
    child: LocalizedTestApp(
      locale: locale,
      theme: theme,
      home: ReplyComposerPage(args: args ?? _threadArgs()),
    ),
  );
}

Future<void> _pumpUntilMessageContains(
  WidgetTester tester,
  String expected, {
  int maxPumps = 12,
}) async {
  for (var i = 0; i < maxPumps; i += 1) {
    await tester.pump();
    if (find
        .byKey(const Key('reply-composer-message-input'))
        .evaluate()
        .isEmpty) {
      await _openReplySourceEditor(tester);
    }
    final sourceField = tester.widget<AppTextInput>(
      find.byKey(const Key('reply-composer-message-input')),
    );
    if ((sourceField.controller?.text ?? '').contains(expected)) {
      return;
    }
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 12,
}) async {
  for (var i = 0; i < maxPumps; i += 1) {
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _enterReplySourceText(WidgetTester tester, String text) async {
  await _openReplySourceEditor(tester);
  await tester.enterText(
    find.byKey(const Key('reply-composer-message-input')),
    text,
  );
}

Future<void> _openReplySourceEditor(WidgetTester tester) async {
  if (find
      .byKey(const Key('reply-composer-message-input'))
      .evaluate()
      .isNotEmpty) {
    return;
  }
  await tester.tap(find.byKey(const Key('reply-composer-source-button')));
  await tester.pumpAndSettle();
}

Widget _buildLauncher({
  ComposerDraftRepository? draftRepository,
  _FakeThreadReplyAdapter? replyRepository,
  List<StickerGroup> stickerGroups = const [],
  ThemeData? theme,
  ValueChanged<ReplyComposerResult>? onResult,
}) {
  return ProviderScope(
    overrides: [
      composerDraftRepositoryProvider.overrideWithValue(
        draftRepository ?? _MemoryReplyDraftRepository(),
      ),
      composerPreferencesRepositoryProvider.overrideWithValue(
        _FakeComposerPreferencesRepository(),
      ),
      threadReplyPreparationProvider.overrideWithValue(
        replyRepository ?? _FakeThreadReplyAdapter(),
      ),
      threadReplyCommandProvider.overrideWithValue(
        replyRepository ?? _FakeThreadReplyAdapter(),
      ),
      composerImagePickerProvider.overrideWithValue(_FakeReplyImagePicker()),
      composerImageUploadCoordinatorProvider.overrideWithValue(
        _FakeReplyImageUploadCoordinator(),
      ),
      composerDraftAttachmentVerificationServiceProvider.overrideWithValue(
        const _NoopDraftAttachmentVerificationService(),
      ),
      forumBbCodeRendererProvider.overrideWithValue(_testRenderer),
      stickerGroupsProvider.overrideWith((_) async => stickerGroups),
      stickerPickerPreferencesRepositoryProvider.overrideWithValue(
        _FakeStickerPickerPreferencesRepository(),
      ),
      imageCacheServiceProvider.overrideWithValue(_FailingImageCacheService()),
    ],
    child: LocalizedTestApp(
      theme: theme,
      home: _ReplyComposerLauncher(onResult: onResult ?? ((_) {})),
    ),
  );
}

final _stickerGroups = [
  StickerGroup(
    id: 'bugcat',
    title: '貓貓蟲',
    stickers: [_sticker(code: '{:9_656:}', imagePath: 'bugcat/Capoo16.gif')],
  ),
];

class _FakeComposerPreferencesRepository
    implements ComposerPreferencesRepository {
  _FakeComposerPreferencesRepository({ComposerPreferences? preferences})
    : preferences = preferences ?? ComposerPreferences.defaults();

  ComposerPreferences preferences;

  @override
  Future<ComposerPreferences> load() async => preferences;

  @override
  Future<void> save(ComposerPreferences preferences) async {
    this.preferences = preferences;
  }
}

StickerItem _sticker({required String code, required String imagePath}) {
  return StickerItem(
    code: code,
    rawCodePattern: code,
    imagePath: imagePath,
    imageUrl: 'https://bbs.yamibo.com/static/image/smiley/$imagePath',
    cacheKey: ImageCacheKeys.remoteSmiley(imagePath),
  );
}

ReplyComposerArgs _threadArgs() {
  return const ReplyComposerArgs(
    target: ReplyTarget.thread(fid: '33', tid: '572063'),
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

class _ReplyComposerLauncher extends StatelessWidget {
  const _ReplyComposerLauncher({required this.onResult});

  final ValueChanged<ReplyComposerResult> onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-reply-composer-page'),
          onPressed: () async {
            final result = await Navigator.of(context)
                .push<ReplyComposerResult>(
                  MaterialPageRoute<ReplyComposerResult>(
                    builder: (_) => ReplyComposerPage(args: _threadArgs()),
                  ),
                );
            if (result != null) {
              onResult(result);
            }
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

class _MemoryReplyDraftRepository implements ComposerDraftRepository {
  _MemoryReplyDraftRepository({DateTime Function()? now}) : _now = now;

  final Map<String, ComposerDraftSnapshot> _drafts =
      <String, ComposerDraftSnapshot>{};
  final DateTime Function()? _now;
  static const ComposerDraftAttachmentSanitizer _sanitizer =
      ComposerDraftAttachmentSanitizer();

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
    final draft = _drafts[identity.storageKey];
    final now = _now;
    if (draft == null || now == null) {
      return draft;
    }
    final result = _sanitizer.sanitize(
      message: draft.message,
      imageAttachments: draft.imageAttachments,
      now: now(),
    );
    final sanitized = ComposerDraftSnapshot(
      identity: draft.identity,
      message: result.message,
      useSignature: draft.useSignature,
      updatedAt: draft.updatedAt,
      imageAttachments: result.imageAttachments,
    );
    if (sanitized.isEmpty) {
      _drafts.remove(identity.storageKey);
      return null;
    }
    _drafts[identity.storageKey] = sanitized;
    return sanitized;
  }

  @override
  Future<ComposerDraftPruneResult> pruneDrafts({
    Duration maxAge = const Duration(days: 30),
    int maxCount = 100,
  }) async {
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

ComposerImageAttachment _uploadedAttachment({
  required String localId,
  required String aid,
  required DateTime uploadedAt,
  String? localPath,
  String? cachePath,
}) {
  return ComposerImageAttachment(
    localId: localId,
    localPath: localPath ?? '/gallery/$localId.jpg',
    fileName: '$localId.jpg',
    mimeType: 'image/jpeg',
    order: 0,
    status: ComposerImageAttachmentStatus.uploaded,
    aid: aid,
    uploadedAt: uploadedAt,
    cachePath: cachePath,
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

class _FailedDraftAttachmentVerificationService
    implements ComposerDraftAttachmentVerificationService {
  const _FailedDraftAttachmentVerificationService();

  @override
  Future<ComposerDraftAttachmentVerificationResult> verify(
    ComposerDraftSnapshot draft,
  ) async {
    return ComposerDraftAttachmentVerificationResult(
      draft: draft,
      verification: ComposerDraftAttachmentVerification.failed(
        unverifiedAids: const <String>{'123456'},
      ),
    );
  }
}

class _InvalidDraftAttachmentVerificationService
    implements ComposerDraftAttachmentVerificationService {
  const _InvalidDraftAttachmentVerificationService();

  @override
  Future<ComposerDraftAttachmentVerificationResult> verify(
    ComposerDraftSnapshot draft,
  ) async {
    return ComposerDraftAttachmentVerificationResult(
      draft: ComposerDraftSnapshot(
        identity: draft.identity,
        message: draft.message,
        subject: draft.subject,
        extras: draft.extras,
        useSignature: draft.useSignature,
        updatedAt: draft.updatedAt,
        imageAttachments: const [],
      ),
      verification: ComposerDraftAttachmentVerification.verified(
        imagesByAid: const {},
        checkedAids: const <String>{'123456'},
        invalidAidCount: 1,
      ),
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

const _testRenderer = FlutterBbCodeForumRenderer(
  attachImageBuilder: _buildTestAttachPreviewImage,
  attachFileExists: _testAttachFileExists,
  stickerImageBuilder: _buildTestStickerPreviewImage,
);

Widget _buildTestAttachPreviewImage(File file, Key key) {
  return _TestAttachPreviewImage(file: file, key: key);
}

Widget _buildTestStickerPreviewImage(StickerItem sticker, Key key) {
  return _TestStickerPreviewImage(sticker: sticker, key: key);
}

bool _testAttachFileExists(File file) {
  return !file.path.contains('/missing/');
}

class _TestAttachPreviewImage extends StatelessWidget {
  const _TestAttachPreviewImage({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 28, height: 28);
  }
}

class _TestStickerPreviewImage extends StatelessWidget {
  const _TestStickerPreviewImage({super.key, required this.sticker});

  final StickerItem sticker;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 28, height: 28);
  }
}

class _FakeStickerPickerPreferencesRepository
    implements StickerPickerPreferencesRepository {
  String? lastGroupId;

  @override
  Future<String?> loadLastGroupId() async {
    return lastGroupId;
  }

  @override
  Future<void> saveLastGroupId(String groupId) async {
    lastGroupId = groupId;
  }
}

class _FailingImageCacheService implements ImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult.failed;
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) async => null;

  @override
  Future<CachedImageResult> copyProtectedLocalFile(
    ImageCacheLocalCopyRequest request,
  ) async {
    return CachedImageResult.failed;
  }

  @override
  Future<int> deleteByOwner({
    required ImageCacheOwnerType ownerType,
    required String ownerId,
  }) async {
    return 0;
  }

  @override
  Future<int> calculateUsageBytes({bool includeProtected = false}) async => 0;

  @override
  Future<void> pruneToLimit({required int maxBytes}) async {}

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }

  @override
  Future<void> clearUnprotected() async {}
}

class _FakeReplyImagePicker implements ComposerImagePicker {
  _FakeReplyImagePicker({this.images = const <ComposerPickedImage>[]});

  final List<ComposerPickedImage> images;

  @override
  Future<List<ComposerPickedImage>> pickImagesInOrder() async {
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

  /// 用来把"上传中"停在一个可控的点上，好在期间改动正文。
  final Completer<void>? holdUntil;

  @override
  void cancel() {}

  @override
  Stream<ComposerImageUploadEvent> uploadInOrder({
    required String fid,
    required List<ComposerImageAttachment> attachments,
  }) async* {
    if (holdUntil != null) {
      await holdUntil!.future;
    }
    for (final event in events) {
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
      yield switch (event.type) {
        ComposerImageUploadEventType.started =>
          ComposerImageUploadEvent.started(
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
    DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>?
    preparationResult,
    this.asyncPreparationResult,
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
               quotePreview: '引用正文',
               token: _TestThreadReplyToken(),
             ),
             capabilities: _threadReplyCapabilities,
             metadata: const DataReadMetadata.network(),
           );

  final DataCommandResult<ThreadReplyReceipt> result;
  final DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>
  preparationResult;
  final Future<DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>>?
  asyncPreparationResult;
  final List<ThreadReplySubmission> sentDrafts = <ThreadReplySubmission>[];

  @override
  ThreadReplyCapabilities get capabilities => _threadReplyCapabilities;

  @override
  Future<DataCommandResult<ThreadReplyReceipt>> execute(
    ThreadReplySubmission submission,
  ) async {
    sentDrafts.add(submission);
    return result;
  }

  @override
  Future<DataReadResult<ThreadReplyPreparation, ThreadReplyCapabilities>> load(
    ThreadReplyPreparationRequest request,
  ) async {
    final asyncPreparationResult = this.asyncPreparationResult;
    if (asyncPreparationResult != null) {
      return asyncPreparationResult;
    }
    return preparationResult;
  }
}
