part of 'composer_quill_prototype_editor_test.dart';

bool _currentLineIsQuoted(QuillController controller) {
  final index = controller.selection.start
      .clamp(0, controller.document.length)
      .toInt();
  final query = controller.document.queryChild(index);
  final line = query.node;
  if (line is! Line) {
    return false;
  }
  return line.style.attributes[Attribute.blockQuote.key]?.value == true ||
      line.parent is Block &&
          (line.parent as Block)
                  .style
                  .attributes[Attribute.blockQuote.key]
                  ?.value ==
              true;
}

Object? _currentLineAlignment(QuillController controller) {
  final index = controller.selection.start
      .clamp(0, controller.document.length)
      .toInt();
  final query = controller.document.queryChild(index);
  final line = query.node;
  if (line is! Line) {
    return null;
  }
  return line.style.attributes[Attribute.align.key]?.value;
}

FocusNode _editorFocusNode(WidgetTester tester) {
  return tester.widget<QuillEditor>(find.byType(QuillEditor)).focusNode;
}

void _dispatchEditorTap(
  WidgetTester tester, {
  required QuillController controller,
  required int offset,
}) {
  final editor = tester.widget<QuillEditor>(find.byType(QuillEditor));
  TextPosition positionResolver(Offset _) => TextPosition(offset: offset);
  final details = TapDownDetails(
    globalPosition: Offset.zero,
    kind: PointerDeviceKind.touch,
  );
  expect(editor.config.onTapDown!(details, positionResolver), isFalse);
  expect(
    editor.config.onTapUp!(
      TapUpDetails(globalPosition: Offset.zero, kind: PointerDeviceKind.touch),
      positionResolver,
    ),
    isFalse,
  );
  controller.updateSelection(
    TextSelection.collapsed(offset: offset),
    ChangeSource.local,
  );
}

double _toolbarBottomGap(WidgetTester tester) {
  final scaffoldBottom = tester.getBottomLeft(find.byType(Scaffold)).dy;
  final toolbarBottom = tester
      .getBottomLeft(find.byKey(const Key('test-quill-format-button')))
      .dy;
  return scaffoldBottom - toolbarBottom;
}

void _expectIconButtonIcon(
  WidgetTester tester,
  Key buttonKey,
  IconData expectedIcon,
) {
  final icon = tester.widget<Icon>(
    find
        .descendant(of: find.byKey(buttonKey), matching: find.byType(Icon))
        .first,
  );
  expect(icon.icon, expectedIcon);
}

void _expectSizeControlsStayOnOneLine(WidgetTester tester) {
  final firstTop = tester
      .getTopLeft(find.byKey(const Key('test-quill-format-size-1')))
      .dy;
  for (var size = 2; size <= 7; size += 1) {
    final top = tester
        .getTopLeft(find.byKey(Key('test-quill-format-size-$size')))
        .dy;
    expect(top, firstTop);
  }
}

void _expectClearStateOnFormatRow(WidgetTester tester) {
  final strikeCenter = tester.getCenter(
    find.byKey(const Key('test-quill-format-strike-toggle')),
  );
  final clearCenter = tester.getCenter(
    find.byKey(const Key('test-quill-format-clear-state-button')),
  );
  expect(clearCenter.dx, greaterThan(strikeCenter.dx));
  expect(clearCenter.dy, closeTo(strikeCenter.dy, 2));
}

Future<void> _createSecondLevelCollapse(WidgetTester tester) async {
  const firstBodyCollapseButton = Key(
    'test-quill-collapse-editor-body-collapse-button',
  );
  const secondPagePrefix = 'test-quill-collapse-editor-body-collapse-editor';
  expect(find.byKey(firstBodyCollapseButton), findsOneWidget);
  await tester.tap(find.byKey(firstBodyCollapseButton));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('$secondPagePrefix-page')), findsOneWidget);
  expect(
    find.byKey(const Key('$secondPagePrefix-body-collapse-button')),
    findsNothing,
  );
  await tester.enterText(
    find.byKey(const Key('$secondPagePrefix-title-field')),
    '内层',
  );
  const nestedBody = '内层正文';
  final bodyEditor = tester.widget<QuillEditor>(
    find.byKey(const Key('$secondPagePrefix-body-editor')),
  );
  bodyEditor.controller.replaceText(
    0,
    0,
    nestedBody,
    const TextSelection.collapsed(offset: nestedBody.length),
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('$secondPagePrefix-save-button')));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('$secondPagePrefix-page')), findsNothing);
}

Widget _buildEditor({
  QuillController? controller,
  String? initialBbCode,
  ValueChanged<String>? onBbCodeChanged,
  ComposerImageInsertCallback? onImagePressed,
  List<ComposerImageAttachment> imageAttachments =
      const <ComposerImageAttachment>[],
  ForumAttachPreviewImageBuilder? attachImageBuilder,
  ForumAttachPreviewFileExists? attachFileExists,
  List<StickerItem> stickers = const <StickerItem>[],
  List<StickerGroup> stickerGroups = const <StickerGroup>[],
  List<ComposerToolbarAction> extraToolbarActions =
      const <ComposerToolbarAction>[],
  String? initialStickerGroupId,
  ValueChanged<String>? onStickerGroupChanged,
  bool isUploadingImages = false,
  int imageUploadCurrent = 0,
  int imageUploadTotal = 0,
  EdgeInsets viewInsets = EdgeInsets.zero,
  double? surfaceWidth,
  double textScale = 1,
}) {
  final editor = ComposerQuillPrototypeEditor(
    keyPrefix: 'test-quill',
    controller: controller,
    initialBbCode: initialBbCode,
    onBbCodeChanged: onBbCodeChanged,
    onImagePressed: onImagePressed,
    imageAttachments: imageAttachments,
    attachImageBuilder: attachImageBuilder,
    attachFileExists: attachFileExists,
    stickers: stickers,
    stickerGroups: stickerGroups,
    extraToolbarActions: extraToolbarActions,
    initialStickerGroupId: initialStickerGroupId,
    onStickerGroupChanged: onStickerGroupChanged,
    isUploadingImages: isUploadingImages,
    imageUploadCurrent: imageUploadCurrent,
    imageUploadTotal: imageUploadTotal,
  );
  return ProviderScope(
    overrides: [
      imageCacheServiceProvider.overrideWithValue(_FailingImageCacheService()),
      composerStickerImageCacheLoaderProvider.overrideWithValue(
        ComposerStickerImageCacheLoader(
          imageCacheService: _FailingImageCacheService(),
          networkGap: Duration.zero,
          delay: (_) async {},
        ),
      ),
    ],
    child: LocalizedTestApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: const Size(800, 600),
            viewInsets: viewInsets,
            textScaler: TextScaler.linear(textScale),
          ),
          child: surfaceWidth == null
              ? editor
              : Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: surfaceWidth,
                    height: 600,
                    child: editor,
                  ),
                ),
        ),
      ),
    ),
  );
}

Widget _buildControlledCollapseEditor({
  required GlobalKey<_ControlledCollapseHarnessState> key,
  required String initialBbCode,
}) {
  return LocalizedTestApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SizedBox(
        width: 800,
        height: 600,
        child: _ControlledCollapseHarness(
          key: key,
          initialBbCode: initialBbCode,
        ),
      ),
    ),
  );
}

class _ControlledCollapseHarness extends StatefulWidget {
  const _ControlledCollapseHarness({super.key, required this.initialBbCode});

  final String initialBbCode;

  @override
  State<_ControlledCollapseHarness> createState() =>
      _ControlledCollapseHarnessState();
}

class _ControlledCollapseHarnessState
    extends State<_ControlledCollapseHarness> {
  late String source;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    source = widget.initialBbCode;
  }

  void replaceExternally(String value) {
    setState(() {
      source = value;
      revision += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ComposerQuillEditorSurface(
      keyPrefix: 'conflict-quill',
      bbCode: source,
      messageRevision: revision,
      onBbCodeChanged: (value) {
        setState(() {
          source = value;
          revision += 1;
        });
      },
    );
  }
}

ComposerImageAttachment _uploadedAttachment() {
  return ComposerImageAttachment(
    localId: 'local-123456',
    localPath: '/gallery/123456.png',
    fileName: '123456.png',
    mimeType: 'image/png',
    order: 0,
    status: ComposerImageAttachmentStatus.uploaded,
    aid: '123456',
    uploadedAt: DateTime.utc(2026, 7, 4),
  );
}

void _insertTestAttachment(
  QuillController controller,
  ComposerInsertionAnchor? anchor,
) {
  if (anchor == null) {
    return;
  }
  final localInsertion = anchor.localAttachmentInsertion;
  if (localInsertion != null) {
    localInsertion(const ['[attach]123456[/attach]']);
    return;
  }
  const codec = ComposerQuillBbCodeCodec();
  const insertionService = ComposerMessageInsertionService();
  const selectionAdapter = ComposerQuillSelectionAdapter();
  final source = codec.encodeDocument(controller.document);
  final sourceSelection = selectionAdapter.toSourceSelection(
    source: source,
    document: controller.document,
    selection: controller.selection,
  );
  if (sourceSelection == null) {
    return;
  }
  final mutation = insertionService.insertAttachmentBlock(
    source: source,
    selection: sourceSelection,
    attachmentCodes: const ['[attach]123456[/attach]'],
    revision: 1,
  );
  final document = codec.decodeDocument(mutation.nextSource);
  controller.document = document;
  final selection = selectionAdapter.toQuillSelection(
    source: mutation.nextSource,
    document: document,
    selection: mutation.resultSelection,
  );
  controller.updateSelection(
    selection ?? TextSelection.collapsed(offset: document.length - 1),
    ChangeSource.local,
  );
}

List<StickerGroup> _stickerGroups() {
  return [
    StickerGroup(id: 'bugcat', title: '貓貓蟲', stickers: [_sticker()]),
    StickerGroup(id: 'azukisan', title: '小豆泥', stickers: [_secondSticker()]),
  ];
}

StickerItem _sticker() {
  return _stickerWith(
    code: '{:9_656:}',
    imagePath: 'bugcat/Capoo16.gif',
    cacheKey: 'remote-smiley:bugcat/Capoo16.gif',
  );
}

StickerItem _secondSticker() {
  return _stickerWith(
    code: '{:6_1:}',
    imagePath: 'azukisan/1.gif',
    cacheKey: 'remote-smiley:azukisan/1.gif',
  );
}

StickerItem _stickerWith({
  required String code,
  required String imagePath,
  required String cacheKey,
}) {
  return StickerItem(
    code: code,
    rawCodePattern: code,
    imagePath: imagePath,
    imageUrl: 'https://bbs.yamibo.com/static/image/smiley/$imagePath',
    cacheKey: cacheKey,
  );
}

Widget _buildTestAttachPreviewImage(File file, Key key) {
  return _TestAttachPreviewImage(file: file, key: key);
}

Widget _buildWideTestAttachPreviewImage(File file, Key key) {
  return AspectRatio(key: key, aspectRatio: 2);
}

double _expectedAttachmentMaxWidth(double surfaceWidth) {
  return surfaceWidth -
      (ForumContentSpacing.composerQuillSurfaceHorizontal * 2) -
      (ForumContentSpacing.quillInnerHorizontal * 2) -
      4;
}

bool _testAttachFileExists(File file) {
  return file.path.isNotEmpty && !file.path.contains('/missing/');
}

class _TestAttachPreviewImage extends StatelessWidget {
  const _TestAttachPreviewImage({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 32, height: 32);
  }
}

class _FailingImageCacheService implements ImageCacheService {
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async {
    return CachedImageResult.failed;
  }

  @override
  Future<CachedImageResult?> getCached(String cacheKey) async {
    return null;
  }

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
  Future<int> calculateUsageBytes({bool includeProtected = false}) async {
    return 0;
  }

  @override
  Future<void> pruneToLimit({required int maxBytes}) async {}

  @override
  Future<void> clearUnprotected() async {}

  @override
  Future<int> clearUnprotectedByRoles({
    required List<ImageCacheRole> roles,
  }) async {
    return 0;
  }
}
