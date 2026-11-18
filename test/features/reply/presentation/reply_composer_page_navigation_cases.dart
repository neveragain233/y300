part of 'reply_composer_page_test.dart';

void _navigationCases() {
  testWidgets('ReplyComposerPage confirms leaving with unsent input', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildLauncher(draftRepository: _MemoryReplyDraftRepository()),
    );
    await tester.tap(find.byKey(const Key('open-reply-composer-page')));
    await tester.pumpAndSettle();
    await _enterReplySourceText(tester, '未发送内容');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('保存草稿并离开？'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('reply-composer-continue-edit-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('reply-composer-message-input')),
      findsOneWidget,
    );
  });

  testWidgets('ReplyComposerPage saves draft and leaves after confirmation', (
    tester,
  ) async {
    final draftRepository = _MemoryReplyDraftRepository();
    await tester.pumpWidget(_buildLauncher(draftRepository: draftRepository));
    await tester.tap(find.byKey(const Key('open-reply-composer-page')));
    await tester.pumpAndSettle();
    await _enterReplySourceText(tester, '离开前保存');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reply-composer-save-leave-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('open-reply-composer-page')), findsOneWidget);
    expect(
      (await draftRepository.loadDraft(_threadArgs().identity))?.message,
      '离开前保存',
    );
  });

  testWidgets('ReplyComposerPage leaves without confirmation for empty input', (
    tester,
  ) async {
    await tester.pumpWidget(_buildLauncher());
    await tester.tap(find.byKey(const Key('open-reply-composer-page')));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('保存草稿并离开？'), findsNothing);
    expect(find.byKey(const Key('open-reply-composer-page')), findsOneWidget);
  });

  testWidgets(
    'ReplyComposerPage successful submit does not show leave confirm',
    (tester) async {
      final replyRepository = _FakeThreadReplyAdapter(result: _replyApplied);
      await tester.pumpWidget(_buildLauncher(replyRepository: replyRepository));
      await tester.tap(find.byKey(const Key('open-reply-composer-page')));
      await tester.pumpAndSettle();
      await _enterReplySourceText(tester, '提交内容');
      await tester.pump();
      await tester.tap(find.byKey(const Key('reply-composer-send-button')));
      await tester.pumpAndSettle();

      expect(find.text('保存草稿并离开？'), findsNothing);
      expect(find.byKey(const Key('open-reply-composer-page')), findsOneWidget);
    },
  );
}
