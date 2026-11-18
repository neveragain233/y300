part of 'novel_reader_controller_test.dart';

void _searchAndBookmarkCases() {
  test('updateWork failure keeps old content and avoids AsyncError', () async {
    final repository = _ControllerNovelRepository();
    final updateService = _RecordingNovelChapterUpdateService();
    final bootstrapService = _ControlledNovelReaderBootstrapService(
      initialCritical: _criticalBootstrap(episodeId: 'novel:49:100:5001'),
    );
    bootstrapService.failEpisodeCritical(
      'novel:49:100:5001',
      StateError('refresh failed'),
    );
    final container = _buildContainer(
      repository: repository,
      bootstrapService: bootstrapService,
      chapterUpdateService: updateService,
    );
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);

    await container.read(provider.future);

    final didSucceed = await container.read(provider.notifier).updateWork();

    expect(didSucceed, isFalse);
    expect(updateService.novelIds, <String>['novel:49:100']);
    expect(container.read(provider).hasError, isFalse);
    final state = container.read(provider).value!;
    expect(state.currentEpisode.episodeId, 'novel:49:100:5001');
    expect(state.transition, isNull);
  });

  test('searchInCurrentChapter updates search results and selection', () async {
    final repository = _ControllerNovelRepository();
    repository.contentsByEpisodeId['novel:49:100:5001'] = _content(
      'novel:49:100:5001',
      '关键词在这里。关键词再次出现。',
    );
    final container = _buildContainer(repository: repository);
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);

    await container.read(provider.future);
    container.read(provider.notifier).searchInCurrentChapter('关键词');
    final state = container.read(provider).value!;

    expect(state.searchResults, hasLength(2));
    expect(state.currentSearchIndex, 0);
    container
        .read(provider.notifier)
        .selectSearchResult(state.searchResults.last.resultId);
    expect(container.read(provider).value!.currentSearchIndex, 1);
  });

  test('bookmark actions persist and reload state', () async {
    final repository = _ControllerNovelRepository();
    final container = _buildContainer(repository: repository);
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);

    await container.read(provider.future);
    await container.read(provider.notifier).toggleCurrentEpisodeBookmark();
    expect(container.read(provider).value!.hasCurrentEpisodeBookmark, isTrue);

    await container
        .read(provider.notifier)
        .addBookmarkAtCurrentPosition(
          const NovelReaderTextAnchor(
            episodeId: 'novel:49:100:5001',
            nodeId: 'node-0',
          ),
        );
    var state = container.read(provider).value!;
    expect(state.currentEpisodeBookmarks.length, 2);

    final positionBookmark = state.currentEpisodeBookmarks.firstWhere(
      (bookmark) => bookmark.bookmarkId.startsWith('reader-bookmark:'),
    );
    await container
        .read(provider.notifier)
        .removeBookmark(positionBookmark.bookmarkId);
    state = container.read(provider).value!;
    expect(state.currentEpisodeBookmarks.length, 1);
  });

  test(
    'bookmark snippets use exact rune coordinates and preserve whole graphemes',
    () async {
      const family = '👩‍👩‍👧‍👦';
      final repository = _ControllerNovelRepository();
      repository.contentsByEpisodeId['novel:49:100:5001'] = _content(
        'novel:49:100:5001',
        '  😀前文$family'
            '后文${'正文' * 30}',
      );
      final container = _buildContainer(repository: repository);
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);
      final loaded = await container.read(provider.future);
      final block = loaded.document.blocks.first;
      final text = block.novelPlainText;
      final familyStart = text.indexOf(family);
      expect(familyStart, greaterThanOrEqualTo(0));
      final anchor = NovelReaderTextAnchor(
        episodeId: args.episodeId,
        nodeId: block.anchorId,
        textOffset: text.substring(0, familyStart).runes.length + 2,
        formatVersion: 1,
        textIdentity: NovelReaderAnchorFormat.textIdentity(text),
      );
      final controller = container.read(provider.notifier);
      void expectPreservedAnchor(NovelReaderTextAnchor expected) {
        final actual = repository.bookmarks.last.anchor;
        expect(actual.episodeId, expected.episodeId);
        expect(actual.nodeId, expected.nodeId);
        expect(actual.textOffset, expected.textOffset);
        expect(actual.formatVersion, expected.formatVersion);
        expect(actual.textIdentity, expected.textIdentity);
        expect(actual.pageIndex, expected.pageIndex);
        expect(actual.scrollOffset, expected.scrollOffset);
        expect(actual.progressPercent, expected.progressPercent);
        expect(actual.isProgressPercentValid, expected.isProgressPercentValid);
      }

      await controller.addBookmarkAtCurrentPosition(anchor);
      expect(repository.bookmarks.last.snippet, contains(family));
      expect(repository.bookmarks.last.snippet, isNot(contains('😀前文')));
      expectPreservedAnchor(anchor);
      for (final unknown in [
        anchor.copyWith(formatVersion: 37),
        anchor.copyWith(textIdentity: 'different source text'),
      ]) {
        await controller.addBookmarkAtCurrentPosition(unknown);
        expect(repository.bookmarks.last.snippet, startsWith('😀前文'));
        expectPreservedAnchor(unknown);
      }
    },
  );
}
