part of 'novel_reader_controller_test.dart';

void _chapterLifecycleCases() {
  test('NovelReaderController dispose cancels progress committer', () async {
    final repository = _ControllerNovelRepository();
    final progressCommitter = _FakeNovelReaderProgressCommitter();
    final container = _buildContainer(
      repository: repository,
      progressCommitter: progressCommitter,
    );
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final subscription = _keepReaderAlive(container, args);

    await container.read(novelReaderControllerProvider(args).future);
    subscription.close();
    container.dispose();

    expect(progressCommitter.cancelCallCount, 1);
  });

  test(
    'openEpisodeFromCatalog restores an unfinished target chapter',
    () async {
      final targetProgress = NovelReadingProgress(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5002',
        scrollOffset: 88,
        updatedAt: DateTime(2026, 6, 1),
      );
      final repository = _ControllerNovelRepository(
        readingProgress: targetProgress,
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

      final initial = await container.read(provider.future);
      expect(initial.currentEpisode.episodeId, 'novel:49:100:5001');
      expect(initial.currentOffset, 0);

      final controller = container.read(provider.notifier);
      await controller.openEpisodeFromCatalog('novel:49:100:5002');

      final state = await container.read(provider.future);
      expect(state.currentEpisode.episodeId, 'novel:49:100:5002');
      expect(state.currentOffset, 88);
      expect(repository.readingProgress, same(targetProgress));
      expect(repository.savedProgressEpisodeIds, isEmpty);
    },
  );

  test(
    'chapter transition never inherits the source pagination page',
    () async {
      final repository = _ControllerNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
        ),
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
      final controller = container.read(provider.notifier);
      _markReadingSurfaceReady(controller);
      controller.onPagedPositionChanged(
        const NovelReaderPaginationPosition(
          episodeId: 'novel:49:100:5001',
          paginationKey: 'source-layout',
          pageIndex: 4,
          pageCount: 6,
          hasUserNavigated: true,
          anchor: NovelReaderTextAnchor(
            episodeId: 'novel:49:100:5001',
            nodeId: 'source-node',
          ),
        ),
      );
      await controller.saveCurrentProgressNow(
        container.read(provider).value!.progressSnapshot,
      );

      await controller.openEpisodeFromCatalog('novel:49:100:5002');
      final target = container.read(provider).value!;
      expect(target.currentEpisode.episodeId, 'novel:49:100:5002');
      expect(target.progressSnapshot.pageIndex, 0);
      expect(target.progressSnapshot.pageCount, isNull);
      expect(target.progressSnapshot.paginationKey, isNull);
      expect(target.progressSnapshot.anchorNodeId, isNull);
    },
  );

  test(
    'initial start policy ignores the matching persisted progress',
    () async {
      final repository = _ControllerNovelRepository(
        readingProgress: NovelReadingProgress(
          novelId: 'novel:49:100',
          episodeId: 'novel:49:100:5002',
          scrollOffset: 320,
          updatedAt: DateTime(2026, 7, 21),
          progressPercent: 0.75,
        ),
      );
      final progressCommitter = _FakeNovelReaderProgressCommitter();
      final container = _buildContainer(
        repository: repository,
        progressCommitter: progressCommitter,
      );
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5002',
        openPolicy: NovelEpisodeOpenPolicy.startAtBeginning,
      );
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);

      final state = await container.read(
        novelReaderControllerProvider(args).future,
      );

      expect(state.progressSnapshot.scrollOffset, 0);
      expect(state.progressSnapshot.progressPercent, 0);
      expect(progressCommitter.flushCallCount, 0);

      final controller = container.read(
        novelReaderControllerProvider(args).notifier,
      );
      controller.updateReadingVisibility(frontmost: true, resumed: true);
      await controller.onVerticalContentReady('novel:49:100:5002');
      expect(progressCommitter.flushCallCount, 0);
      await controller.onVerticalContentReady(
        'novel:49:100:5002',
        bodySnapshot: state.progressSnapshot.copyWith(
          isProgressPercentValid: true,
          percentBasis: NovelProgressPercentBasis.bodyGeometryV1,
        ),
      );

      expect(progressCommitter.flushCallCount, 1);
      expect(
        progressCommitter.latestFlushedSnapshot?.episodeId,
        args.episodeId,
      );
      expect(progressCommitter.latestFlushedSnapshot?.progressPercent, 0);
    },
  );

  test(
    'initial build publishes critical state before supplemental completes',
    () async {
      final repository = _ControllerNovelRepository();
      final bootstrapService = _ControlledNovelReaderBootstrapService(
        initialCritical: _criticalBootstrap(episodeId: 'novel:49:100:5001'),
      );
      final hydrationService =
          _ControlledNovelReaderSupplementalHydrationService();
      final container = _buildContainer(
        repository: repository,
        bootstrapService: bootstrapService,
        supplementalHydrationService: hydrationService,
      );
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);

      final state = await container.read(provider.future);

      expect(state.currentEpisode.episodeId, 'novel:49:100:5001');
      expect(state.isHydratingSupplemental, isTrue);
      expect(state.novel, isNull);
      expect(state.bookmarks, isEmpty);

      hydrationService.completeInitialBookmarks(
        _supplementalBookmarks(episodeId: 'novel:49:100:5001'),
      );
      await Future<void>.delayed(Duration.zero);
      var hydrated = container.read(provider).value!;
      expect(hydrated.bookmarks, isNotEmpty);
      expect(hydrated.currentEpisodeBookmarks, isNotEmpty);
      expect(hydrated.novel, isNull);

      hydrationService.completeInitialNovel(_supplementalNovel());
      await Future<void>.delayed(Duration.zero);

      hydrated = container.read(provider).value!;
      expect(hydrated.isHydratingSupplemental, isFalse);
      expect(hydrated.novel?.title, '测试小说');
    },
  );

  test('openEpisodeFromCatalog keeps old content and sets switching transition before critical resolves', () async {
    final repository = _ControllerNovelRepository();
    final bootstrapService = _ControlledNovelReaderBootstrapService(
      initialCritical: _criticalBootstrap(episodeId: 'novel:49:100:5001'),
    );
    final hydrationService =
        _ControlledNovelReaderSupplementalHydrationService();
    final container = _buildContainer(
      repository: repository,
      bootstrapService: bootstrapService,
      supplementalHydrationService: hydrationService,
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
    hydrationService.completeInitialBookmarks(
      _supplementalBookmarks(episodeId: 'novel:49:100:5001'),
    );
    hydrationService.completeInitialNovel(_supplementalNovel());
    await Future<void>.delayed(Duration.zero);

    final future = container
        .read(provider.notifier)
        .openEpisodeFromCatalog('novel:49:100:5002');
    await Future<void>.delayed(Duration.zero);
    final transitioning = container.read(provider).value!;

    expect(container.read(provider).isLoading, isFalse);
    expect(transitioning.currentEpisode.episodeId, 'novel:49:100:5001');
    expect(
      transitioning.transition?.kind,
      NovelReaderTransitionKind.switchingEpisode,
    );
    expect(transitioning.transition?.targetEpisodeId, 'novel:49:100:5002');

    bootstrapService.completeEpisodeCritical(
      'novel:49:100:5002',
      _criticalBootstrap(
        episodeId: 'novel:49:100:5002',
        paragraphText: '第二章正文。',
      ),
    );
    final didSucceed = await future;

    expect(didSucceed, isTrue);
    final switched = container.read(provider).value!;
    expect(switched.currentEpisode.episodeId, 'novel:49:100:5002');
    expect(switched.transition, isNull);
    expect(switched.searchKeyword, isEmpty);
    expect(switched.searchResults, isEmpty);
    expect(switched.currentSearchIndex, -1);
    expect(switched.isHydratingSupplemental, isTrue);
  });

  test(
    'openEpisodeFromCatalog failure keeps old chapter and clears transition',
    () async {
      final repository = _ControllerNovelRepository();
      final bootstrapService = _ControlledNovelReaderBootstrapService(
        initialCritical: _criticalBootstrap(episodeId: 'novel:49:100:5001'),
      );
      bootstrapService.failEpisodeCritical(
        'novel:49:100:5002',
        StateError('critical failed'),
      );
      final container = _buildContainer(
        repository: repository,
        bootstrapService: bootstrapService,
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

      final didSucceed = await container
          .read(provider.notifier)
          .openEpisodeFromCatalog('novel:49:100:5002');

      expect(didSucceed, isFalse);
      final state = container.read(provider).value!;
      expect(state.currentEpisode.episodeId, 'novel:49:100:5001');
      expect(state.transition, isNull);
    },
  );

  test('stale supplemental does not override newer chapter state', () async {
    final repository = _ControllerNovelRepository();
    final bootstrapService = _ControlledNovelReaderBootstrapService(
      initialCritical: _criticalBootstrap(episodeId: 'novel:49:100:5001'),
    );
    final hydrationService =
        _ControlledNovelReaderSupplementalHydrationService();
    final container = _buildContainer(
      repository: repository,
      bootstrapService: bootstrapService,
      supplementalHydrationService: hydrationService,
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

    final switchFuture = container
        .read(provider.notifier)
        .openEpisodeFromCatalog('novel:49:100:5002');
    bootstrapService.completeEpisodeCritical(
      'novel:49:100:5002',
      _criticalBootstrap(
        episodeId: 'novel:49:100:5002',
        paragraphText: '第二章正文。',
      ),
    );
    await switchFuture;

    hydrationService.completeInitialBookmarks(
      _supplementalBookmarks(episodeId: 'novel:49:100:5001'),
    );
    hydrationService.completeInitialNovel(
      _supplementalNovel(novelTitle: '旧章节小说'),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(provider).value!;
    expect(state.currentEpisode.episodeId, 'novel:49:100:5002');
    expect(state.novel, isNull);
  });

  test('supplemental phase failure does not block later phases', () async {
    final repository = _ControllerNovelRepository();
    final bootstrapService = _ControlledNovelReaderBootstrapService(
      initialCritical: _criticalBootstrap(episodeId: 'novel:49:100:5001'),
    );
    final hydrationService =
        _ControlledNovelReaderSupplementalHydrationService();
    hydrationService.failInitialBookmarks(StateError('bookmark failed'));
    final container = _buildContainer(
      repository: repository,
      bootstrapService: bootstrapService,
      supplementalHydrationService: hydrationService,
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
    hydrationService.completeInitialNovel(_supplementalNovel());
    await Future<void>.delayed(Duration.zero);

    final state = container.read(provider).value!;
    expect(state.bookmarks, isEmpty);
    expect(state.novel?.title, '测试小说');
    expect(state.isHydratingSupplemental, isFalse);
  });
}
