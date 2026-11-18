part of 'forum_html_widget_post_renderer_test.dart';

void _imageLayoutCases() {
  testWidgets(
    'does not retain a tall trailing line box after consecutive attachment images',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            imageCacheServiceProvider.overrideWithValue(
              _RecordingImageCacheService(),
            ),
          ],
          child: const LocalizedTestApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    child: ForumHtmlWidgetPostRenderer(
                      theme: forumHtmlTestTheme,
                      sourceId: 'consecutive-attachment-images',
                      threadId: '573549',
                      html:
                          '<i class="pstatus">本帖最后编辑</i><br><br>'
                          '7月12日是辉夜的生日哦<br>辉夜生日快乐<br>'
                          '<a href="data/attachment/forum/first.jpg" '
                          'class="orange" />'
                          '<img src="data/attachment/forum/first.jpg">'
                          '</a>'
                          '<a href="data/attachment/forum/second.jpg" '
                          'class="orange" />'
                          '<img src="data/attachment/forum/second.jpg">'
                          '</a>'
                          '<a href="data/attachment/forum/third.jpg" '
                          'class="orange" />'
                          '<img src="data/attachment/forum/third.jpg">'
                          '</a><br><br>',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      const decodedSizes = <Size>[
        Size(1600, 1550),
        Size(1880, 3008),
        Size(1880, 3002),
      ];
      final imageWidgets = tester
          .widgetList<CachedLibraryImage>(find.byType(CachedLibraryImage))
          .toList(growable: false);
      expect(imageWidgets, hasLength(decodedSizes.length));
      for (var index = 0; index < imageWidgets.length; index++) {
        imageWidgets[index].onImageResolved?.call(decodedSizes[index]);
      }
      await tester.pump();

      final imageHeight = find
          .byType(CachedLibraryImage)
          .evaluate()
          .map(
            (element) => (element.findRenderObject()! as RenderBox).size.height,
          )
          .fold<double>(0, (sum, height) => sum + height);
      final rendererHeight = tester
          .getSize(
            find.byKey(
              const Key('forum-html-renderer-consecutive-attachment-images'),
            ),
          )
          .height;

      expect(rendererHeight - imageHeight, lessThan(160));
    },
  );

  testWidgets('keeps fallback layout for decoded sizes near the comic ratio', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageCacheServiceProvider.overrideWithValue(
            _RecordingImageCacheService(),
          ),
        ],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'decoded-comic-ratio-image',
              threadId: '573279',
              html: '<img src="data/attachment/forum/page-comic.jpg">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    tester
        .widget<CachedLibraryImage>(find.byType(CachedLibraryImage).first)
        .onImageResolved
        ?.call(const Size(700, 1000));
    await tester.pump();

    final aspectRatio = tester
        .getSize(find.byType(CachedLibraryImage).first)
        .aspectRatio;

    expect(aspectRatio, closeTo(0.7, 0.001));
  });

  testWidgets('uses cached aspect ratio for unsized thread images', (
    tester,
  ) async {
    final cacheService = _RecordingImageCacheService();
    final request = ForumImageCacheRequests.threadInline(
      tid: '573279',
      url: 'https://bbs.yamibo.com/data/attachment/forum/page-cached.jpg',
      imageIndex: 0,
    );
    cacheService.cachedResults[request.cacheKey] = CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      width: 320,
      height: 200,
      fromCache: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'cached-ratio-image',
              threadId: '573279',
              html: '<img src="data/attachment/forum/page-cached.jpg">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final aspectRatio = tester
        .getSize(find.byType(CachedLibraryImage).first)
        .aspectRatio;
    final image = tester.widget<CachedLibraryImage>(
      find.byType(CachedLibraryImage).first,
    );
    image.onImageResolved?.call(const Size(1600, 900));
    await tester.pump();
    final stableAspectRatio = tester
        .getSize(find.byType(CachedLibraryImage).first)
        .aspectRatio;

    expect(aspectRatio, closeTo(1.6, 0.001));
    expect(stableAspectRatio, closeTo(1.6, 0.001));
    expect(image.width, isNull);
    expect(image.height, isNull);
  });

  testWidgets('keeps html aspect ratio ahead of cached thread dimensions', (
    tester,
  ) async {
    final cacheService = _RecordingImageCacheService();
    final request = ForumImageCacheRequests.threadInline(
      tid: '573279',
      url: 'https://bbs.yamibo.com/data/attachment/forum/page-html.jpg',
      imageIndex: 0,
    );
    cacheService.cachedResults[request.cacheKey] = CachedImageResult(
      success: true,
      cacheKey: request.cacheKey,
      width: 320,
      height: 200,
      fromCache: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [imageCacheServiceProvider.overrideWithValue(cacheService)],
        child: const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'html-ratio-image',
              threadId: '573279',
              html:
                  '<img src="data/attachment/forum/page-html.jpg" '
                  'width="640" height="480">',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final aspectRatio = tester
        .getSize(find.byType(CachedLibraryImage).first)
        .aspectRatio;
    tester
        .widget<CachedLibraryImage>(find.byType(CachedLibraryImage).first)
        .onImageResolved
        ?.call(const Size(1600, 900));
    await tester.pump();
    final stableAspectRatio = tester
        .getSize(find.byType(CachedLibraryImage).first)
        .aspectRatio;

    expect(aspectRatio, closeTo(640 / 480, 0.001));
    expect(stableAspectRatio, closeTo(640 / 480, 0.001));
  });

  testWidgets(
    'keeps non-network data images on the html library default path',
    (tester) async {
      await tester.pumpWidget(
        const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'data-image',
              threadId: '573279',
              html:
                  '<img src="data:image/png;base64,'
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=">',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CachedLibraryImage), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      final clip = tester.widget<ClipRRect>(
        find
            .ancestor(of: find.byType(Image), matching: find.byType(ClipRRect))
            .first,
      );
      expect(clip.borderRadius, const BorderRadius.all(Radius.circular(4)));
    },
  );

  testWidgets(
    'deduplicates repeated forum attachment images before rendering',
    (tester) async {
      await tester.pumpWidget(
        const LocalizedTestApp(
          home: Scaffold(
            body: ForumHtmlWidgetPostRenderer(
              theme: forumHtmlTestTheme,
              sourceId: 'dedupe',
              html:
                  '<p>正文</p>'
                  '<img id="aimg_1" src="data/attachment/forum/page-1.jpg">'
                  '<img id="aimg_2" src="data/attachment/forum/page-2.jpg">'
                  '<img id="aimg_1" src="data/attachment/forum/page-1.jpg">'
                  '<img id="aimg_2" src="data/attachment/forum/page-2.jpg">',
            ),
          ),
        ),
      );
      await tester.pump();

      final htmlWidget = tester.widget<HtmlWidget>(
        find.byKey(const Key('forum-html-renderer-dedupe')),
      );
      final fragment = html_parser.parseFragment(htmlWidget.html);

      expect(fragment.querySelectorAll('img'), hasLength(2));
      expect(
        htmlWidget.html.indexOf('page-1.jpg'),
        htmlWidget.html.lastIndexOf('page-1.jpg'),
      );
      expect(
        htmlWidget.html.indexOf('page-2.jpg'),
        htmlWidget.html.lastIndexOf('page-2.jpg'),
      );
    },
  );

  testWidgets('marks forum smiley images as stickers', (tester) async {
    ForumHtmlImageRequest? tappedImage;
    var interactions = 0;
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: ForumHtmlWidgetPostRenderer(
            theme: forumHtmlTestTheme,
            sourceId: 'sticker',
            html:
                '<img src="static/image/smiley/gexing/008.gif" '
                'alt="" width="24" height="24">',
            callbacks: ForumHtmlRenderCallbacks(
              onInteraction: () => interactions += 1,
              onTapImage: (request) => tappedImage = request,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final imageTap = find.descendant(
      of: find.byKey(const Key('forum-html-renderer-sticker')),
      matching: find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.onTap != null,
      ),
    );
    expect(imageTap, findsOneWidget);
    await tester.tap(imageTap);
    await tester.pump();

    expect(tappedImage?.isSticker, isTrue);
    expect(tappedImage?.attachmentId, isNull);
    expect(interactions, 1);
  });
}
