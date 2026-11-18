part of 'blog_editor_page_test.dart';

void _inputCases() {
  testWidgets('settings have one AppBar entry and a noninteractive summary', (
    tester,
  ) async {
    final service = BlogOperationFixture(autoPrepare: true);
    await _open(tester, service);
    final summary = find.byKey(const Key('blog-editor-settings-summary'));
    expect(summary, findsOneWidget);
    expect(find.byKey(const Key('blog-editor-settings')), findsOneWidget);
    expect(
      find.ancestor(of: summary, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(find.byKey(const Key('blog-body-mode-menu')), findsNothing);
    expect(find.byKey(const Key('blog-insert-image')), findsNothing);
    await tester.tap(summary);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blog-editor-settings-sheet')), findsNothing);
    await _openSettings(tester);
  });

  testWidgets(
    'bold italic underline and font size edit the selected visual text',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      await _open(tester, service);
      await _replaceBody(tester, 'formatted text');
      final body = _body(tester).controller;
      body.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 9),
        ChangeSource.local,
      );
      await tester.pump();
      for (final key in [
        'blog-format-bold',
        'blog-format-italic',
        'blog-format-underline',
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('blog-format-size')));
      await tester.pumpAndSettle();
      _expectNoSheetHandle(tester);
      await tester.tap(find.byKey(const Key('blog-font-size-4')));
      await tester.pumpAndSettle();
      await _save(tester);
      final html = service.editorSubmissions.single.input.bodyHtml;
      expect(html, contains('<b>'));
      expect(html, contains('<i>'));
      expect(html, contains('<u>'));
      expect(html, contains('<font size="4">'));
      expect(html, isNot(contains('style=')));
      expect(_plainText(html), 'formatted text');
      service.saved();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'the dedicated thirty-smiley picker inserts a journal HTML image',
    (tester) async {
      final service = BlogOperationFixture(autoPrepare: true);
      final smilies = List.generate(
        30,
        (index) => UserBlogSmiley(
          index: index + 1,
          imageUri: Uri.parse(
            'https://example.test/static/image/smiley/comcom/${index + 1}.gif',
          ),
        ),
      );
      service.editorForm = (target) =>
          blogEditorPreparation(target, bodyHtml: '', blogSmilies: smilies);
      await _open(tester, service);
      await tester.tap(find.byKey(const Key('blog-insert-smiley')));
      await tester.pumpAndSettle();
      final picker = find.byKey(const Key('blog-smiley-picker'));
      expect(picker, findsOneWidget);
      _expectNoSheetHandle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('blog-smiley-30')),
        200,
        scrollable: find
            .descendant(of: picker, matching: find.byType(Scrollable))
            .first,
      );
      await tester.tap(find.byKey(const Key('blog-smiley-30')));
      await tester.pumpAndSettle();
      expect(picker, findsNothing);
      await _save(tester);
      final html = service.editorSubmissions.single.input.bodyHtml;
      expect(html, contains('<img src="${smilies.last.imageUri}">'));
      expect(html, isNot(contains('[attach')));
      service.saved();
      await tester.pumpAndSettle();
    },
  );

  for (final outcomeUnknown in [false, true]) {
    testWidgets(
      outcomeUnknown
          ? 'unknown image uploads stay uninserted and are not automatically replayed'
          : 'image selection uploads once then inserts its confirmed album receipt',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('blog-upload-ui-'),
        ))!;
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}/picked.png';
        await tester.runAsync(
          () => File(path).writeAsBytes(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
          ),
        );
        final service = BlogOperationFixture(autoPrepare: true);
        service.editorForm = (target) => blogEditorPreparation(
          target,
          bodyHtml: '',
          imageUploadLimits: const UserBlogImageUploadLimits(
            extensionRules: [
              ForumImageAttachmentExtensionRule(extension: 'png'),
            ],
          ),
        );
        final picker = _PageImagePicker(path);
        final media = _PageMediaService();
        await _open(tester, service, imagePicker: picker, media: media);
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('blog-insert-image')));
          for (var i = 0; i < 100 && media.request == null; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
        });
        await tester.pump();
        expect(picker.calls, 1);
        expect(media.request, isNotNull);
        expect(_submitButton(tester).onPressed, isNull);
        expect(_body(tester).controller.readOnly, isTrue);
        final image = UserBlogUploadedImage(
          picId: '41',
          imageUri: Uri.parse('https://example.test/album/41.png.thumb.jpg'),
          originalImageUri: Uri.parse('https://example.test/album/41.png'),
          token: _PageImageToken(),
        );
        media.result.complete(
          outcomeUnknown
              ? const DataCommandOutcomeUnknown(
                  DataCommandFailure(
                    kind: DataCommandFailureKind.network,
                    retryPolicy: DataCommandRetryPolicy.never,
                    code: 'blog_image_upload_outcome_unknown',
                    diagnosticMessage: 'blog_image_upload_outcome_unknown',
                  ),
                )
              : DataCommandApplied(image),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(_body(tester).controller.readOnly, isFalse);
        if (outcomeUnknown) {
          expect(
            find.text(_l10n(tester).profileBlogImageUploadUnknown),
            findsOneWidget,
          );
          expect(media.calls, 1);
          expect(picker.calls, 1);
          expect(_body(tester).controller.document.toPlainText(), '\n');
          expect(service.editorSubmissions, isEmpty);
          return;
        }
        expect(
          const BlogQuillHtmlCodec().encodeDocument(
            _body(tester).controller.document,
          ),
          contains(image.imageUri.toString()),
        );
        await _save(tester);
        final submission = service.editorSubmissions.single.input;
        expect(submission.uploadedImages, [image]);
        expect(submission.bodyHtml, contains(image.imageUri.toString()));
        expect(submission.bodyHtml, isNot(contains(path)));
        expect(submission.bodyHtml, isNot(contains('[attach')));
        service.saved();
        await tester.pumpAndSettle();
      },
    );
  }

  for (final smileySheet in [false, true]) {
    testWidgets(
      'an empty editor rejects old ${smileySheet ? 'smiley' : 'size'} actions after account change',
      (tester) async {
        final service = BlogOperationFixture(autoPrepare: true);
        service.editorForm = (target) => blogEditorPreparation(
          target,
          bodyHtml: '',
          blogSmilies: [
            UserBlogSmiley(
              index: 1,
              imageUri: Uri.parse(
                'https://example.test/static/image/smiley/comcom/1.gif',
              ),
            ),
          ],
        );
        final host = await _open(tester, service);
        final original = _body(tester).controller;
        await tester.tap(
          find.byKey(
            Key(smileySheet ? 'blog-insert-smiley' : 'blog-format-size'),
          ),
        );
        await tester.pumpAndSettle();
        host.changeActor('202');
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key(smileySheet ? 'blog-smiley-1' : 'blog-font-size-4')),
        );
        await tester.pumpAndSettle();
        expect(original.document.toPlainText(), '\n');
        expect(
          original.getSelectionStyle().attributes[Attribute.size.key],
          isNull,
        );
        expect(find.byType(QuillEditor), findsNothing);
        expect(service.editorSubmissions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
