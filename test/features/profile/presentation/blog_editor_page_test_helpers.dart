part of 'blog_editor_page_test.dart';

IconButton _submitButton(WidgetTester tester) =>
    tester.widget(find.byKey(const Key('blog-editor-submit')));
QuillEditor _body(WidgetTester tester) =>
    tester.widget(find.byKey(const Key('blog-editor-body')));
Future<void> _replaceBody(WidgetTester tester, String text) async {
  final controller = _body(tester).controller;
  controller.replaceText(
    0,
    controller.document.length - 1,
    text,
    TextSelection.collapsed(offset: text.length),
  );
  await tester.pump();
}

BlogDraftSnapshot _savedDraft({
  String subject = 'saved draft',
  bool pending = false,
}) => BlogDraftSnapshot(
  accountId: '101',
  updatedAt: DateTime(2020),
  subject: subject,
  bodyHtml: '<p>restored</p>',
  pendingSubmission: pending,
);

String _plainText(String html) {
  final text = const BlogQuillHtmlCodec().decodeDocument(html).toPlainText();
  return text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(BlogEditorPage)));
String _visibilityLabel(AppLocalizations l10n, UserBlogVisibility visibility) =>
    switch (visibility) {
      UserBlogVisibility.public => l10n.profileBlogVisibilityPublic,
      UserBlogVisibility.friends => l10n.profileBlogVisibilityFriends,
      UserBlogVisibility.selectedFriends => l10n.profileBlogVisibilitySelected,
      UserBlogVisibility.private => l10n.profileBlogVisibilityPrivate,
      UserBlogVisibility.passwordProtected =>
        l10n.profileBlogVisibilityPassword,
    };
Future<void> _save(WidgetTester tester) async {
  if (find
      .byKey(const Key('blog-editor-settings-sheet'))
      .evaluate()
      .isNotEmpty) {
    await _closeSettings(tester);
  }
  await tester.pump();
  await tester.tap(find.byKey(const Key('blog-editor-submit')));
  await tester.pump();
}

Future<void> _choose(WidgetTester tester, String key, String label) async {
  if (find.byKey(const Key('blog-editor-settings-sheet')).evaluate().isEmpty) {
    await _openSettings(tester);
  }
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester) async {
  final entry = find.byKey(const Key('blog-editor-settings'));
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('blog-editor-settings-sheet')), findsOneWidget);
  expect(find.byKey(const Key('blog-editor-settings-done')), findsNothing);
}

Future<void> _closeSettings(
  WidgetTester tester, {
  bool tapBarrier = false,
}) async {
  expect(find.byKey(const Key('blog-editor-settings-done')), findsNothing);
  if (tapBarrier) {
    // 左右两侧都是遮罩：侧面板与底部抽屉都能在这里点击关闭。
    await tester.tapAt(const Offset(8, 100));
  } else {
    await tester.binding.handlePopRoute();
  }
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('blog-editor-settings-sheet')), findsNothing);
}

Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 200,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byKey(
            Key(
              find
                      .byKey(const Key('blog-editor-settings-sheet'))
                      .evaluate()
                      .isEmpty
                  ? 'blog-editor-scroll'
                  : 'blog-editor-settings-sheet',
            ),
          ),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<_Host> _open(
  WidgetTester tester,
  BlogOperationFixture service, {
  bool create = false,
  ThemeData? theme,
  bool largeKeyboard = false,
  ValueListenable<double>? keyboardInsets,
  ComposerImagePicker? imagePicker,
  UserBlogMediaOperations? media,
  MemoryBlogDraftRepository? drafts,
}) async {
  final host = _Host(
    service,
    imagePicker: imagePicker,
    media: media,
    drafts: drafts,
  );
  addTearDown(host.container.dispose);
  final target = UserBlogTarget(
    actorUserId: '101',
    ownerUserId: '101',
    action: create ? UserBlogAction.create : UserBlogAction.edit,
    blogId: create ? null : '11',
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: host.container,
      child: LocalizedTestApp(
        navigatorKey: host.navigator,
        theme: theme ?? AppTheme.light(),
        builder: (context, child) {
          Widget withInsets(double inset) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: largeKeyboard,
              textScaler: TextScaler.linear(largeKeyboard ? 2 : 1),
              viewInsets: EdgeInsets.only(bottom: inset),
            ),
            child: child!,
          );
          if (keyboardInsets == null) {
            return withInsets(largeKeyboard ? 260 : 0);
          }
          return ValueListenableBuilder<double>(
            valueListenable: keyboardInsets,
            builder: (context, inset, _) => withInsets(inset),
          );
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-editor'),
              onPressed: () {
                host.result = Navigator.of(context).push<BlogEditorResult>(
                  MaterialPageRoute(
                    builder: (_) => BlogEditorPage(target: target),
                  ),
                );
              },
              child: const Text('fixture open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-editor')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  if (service.autoPrepare) await tester.pumpAndSettle();
  return host;
}

final class _Host {
  _Host(
    this.service, {
    this.imagePicker,
    this.media,
    MemoryBlogDraftRepository? drafts,
  }) : drafts = drafts ?? MemoryBlogDraftRepository() {
    container = ProviderContainer(
      overrides: [
        blogAccountIdProvider.overrideWithValue('101'),
        blogDraftRepositoryProvider.overrideWithValue(this.drafts),
        userBlogOperationsProvider.overrideWithValue(service),
        userBlogMediaOperationsProvider.overrideWithValue(media),
        if (imagePicker != null)
          composerImagePickerProvider.overrideWithValue(imagePicker!),
        composerStickerImageCacheLoaderProvider.overrideWithValue(
          stickerLoader,
        ),
        userBlogNavigationProvider.overrideWithValue(navigation),
        forumImageRefererProvider.overrideWithValue('https://example.test/'),
        forumWebViewRouteFactoryProvider.overrideWithValue(_webRoute),
      ],
    );
  }
  final BlogOperationFixture service;
  final MemoryBlogDraftRepository drafts;
  final ComposerImagePicker? imagePicker;
  final UserBlogMediaOperations? media;
  final stickerLoader = ComposerStickerImageCacheLoader(
    imageCacheService: _NoImages(),
    networkGap: Duration.zero,
  );
  late final ProviderContainer container;
  final navigator = GlobalKey<NavigatorState>();
  final navigation = BlogNavigationFixture();
  final webLaunches = <ForumWebViewLaunchConfig>[];
  late Future<BlogEditorResult?> result;
  void changeActor(String? actor) => container.updateOverrides([
    blogAccountIdProvider.overrideWithValue(actor),
    blogDraftRepositoryProvider.overrideWithValue(drafts),
    userBlogOperationsProvider.overrideWithValue(service),
    userBlogMediaOperationsProvider.overrideWithValue(media),
    if (imagePicker != null)
      composerImagePickerProvider.overrideWithValue(imagePicker!),
    composerStickerImageCacheLoaderProvider.overrideWithValue(stickerLoader),
    userBlogNavigationProvider.overrideWithValue(navigation),
    forumImageRefererProvider.overrideWithValue('https://example.test/'),
    forumWebViewRouteFactoryProvider.overrideWithValue(_webRoute),
  ]);
  Route<Object?> _webRoute(ForumWebViewLaunchConfig config) {
    webLaunches.add(config);
    return MaterialPageRoute(
      builder: (_) =>
          Scaffold(appBar: AppBar(), body: const Text('browser fixture')),
    );
  }
}

final class _NoImages implements ImageCacheService {
  @override
  Future<CachedImageResult?> getCached(String cacheKey) async => null;
  @override
  Future<CachedImageResult> ensureCached(ImageCacheRequest request) async =>
      CachedImageResult.failed;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _PageImagePicker implements ComposerImagePicker {
  _PageImagePicker(this.path);
  final String path;
  int calls = 0;
  @override
  Future<List<ComposerPickedImage>> pickImagesInOrder() async {
    calls++;
    return [
      ComposerPickedImage(
        path: path,
        fileName: 'picked.png',
        mimeType: 'image/png',
        originalIndex: 0,
      ),
    ];
  }
}

final class _PageMediaService implements UserBlogMediaOperations {
  UserBlogImageUploadSubmission? request;
  int calls = 0;
  final result = Completer<DataCommandResult<UserBlogUploadedImage>>();
  @override
  Future<DataCommandResult<UserBlogUploadedImage>> uploadImage(
    UserBlogImageUploadSubmission submission,
  ) {
    calls++;
    request = submission;
    return result.future;
  }
}

final class _PageImageToken implements UserBlogUploadedImageToken {}
