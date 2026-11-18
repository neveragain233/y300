part of 'novel_reader_controller_test.dart';

void _progressPositionCases() {
  test(
    'NovelReaderController onScrollOffsetChanged schedules progress update',
    () async {
      final repository = _ControllerNovelRepository();
      final progressCommitter = _FakeNovelReaderProgressCommitter();
      final container = _buildContainer(
        repository: repository,
        progressCommitter: progressCommitter,
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
      await container
          .read(provider.notifier)
          .onScrollOffsetChanged(24, maxScrollExtent: 120);

      final state = container.read(provider).value!;
      expect(state.currentOffset, 24);
      expect(state.progressSnapshot.scrollOffset, 24);
      expect(progressCommitter.scheduleCallCount, 1);
      expect(progressCommitter.flushCallCount, 0);
      expect(repository.readingProgress, isNull);
    },
  );

  test(
    'NovelReaderController persists only the reported paged position',
    () async {
      final repository = _ControllerNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
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
        episodeId: 'novel:49:100:5001',
      );
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);

      final provider = novelReaderControllerProvider(args);
      await container.read(provider.future);
      container
          .read(provider.notifier)
          .onPagedPositionChanged(
            const NovelReaderPaginationPosition(
              episodeId: 'novel:49:100:5001',
              paginationKey: 'layout-v1',
              pageIndex: 2,
              pageCount: 5,
              anchor: NovelReaderTextAnchor(
                episodeId: 'novel:49:100:5001',
                nodeId: 'node-2',
                textOffset: 14,
                formatVersion: 1,
                textIdentity: 'semantic-text-v1',
              ),
            ),
          );

      final state = container.read(provider).value!;
      expect(state.progressSnapshot.pageIndex, 2);
      expect(state.progressSnapshot.pageCount, 5);
      expect(state.progressSnapshot.paginationKey, 'layout-v1');
      expect(state.progressSnapshot.anchorNodeId, 'node-2');
      expect(state.progressSnapshot.anchorTextOffset, 14);
      expect(state.progressSnapshot.anchorFormatVersion, 1);
      expect(state.progressSnapshot.anchorTextIdentity, 'semantic-text-v1');
      expect(state.progressSnapshot.progressPercent, 0.4);
      expect(state.progressSnapshot.isProgressPercentValid, isTrue);
      expect(progressCommitter.scheduleCallCount, 1);
    },
  );

  test('progress committer persists metadata-only changes and deduplicates repeats', () async {
    final repository = _ControllerNovelRepository();
    final committer = DefaultNovelReaderProgressCommitter(
      repository: repository,
    );
    addTearDown(committer.cancel);
    const baseline = NovelReaderProgressSnapshot(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
      flowMode: NovelReaderFlowMode.pagedLtr,
      scrollOffset: 0,
      pageIndex: 2,
      anchorNodeId: 'node-2',
      anchorTextOffset: 14,
      anchorFormatVersion: 37,
      anchorTextIdentity: '  unsupported identity  ',
      progressPercent: 0.4,
    );
    for (final changed in <NovelReaderProgressSnapshot>[
      baseline.copyWith(anchorFormatVersion: 1),
      baseline.copyWith(anchorTextIdentity: 'semantic-text-v1'),
      baseline.copyWith(isProgressPercentValid: false),
    ]) {
      await committer.flush(baseline);
      final savesBeforeChange = repository.savedProgressEpisodeIds.length;
      await committer.flush(changed);
      await committer.flush(changed.copyWith());

      expect(repository.savedProgressEpisodeIds.length, savesBeforeChange + 1);
      expect(
        repository.readingProgress?.anchorFormatVersion,
        changed.anchorFormatVersion,
      );
      expect(
        repository.readingProgress?.anchorTextIdentity,
        changed.anchorTextIdentity,
      );
      expect(
        repository.readingProgress?.isProgressPercentValid,
        changed.isProgressPercentValid,
      );
    }
  });

  for (final version in [0, 1, 37]) {
    test(
      'passive compatibility restore version $version preserves the row until user confirmation',
      () async {
        final original = NovelReadingProgress(
          novelId: 'novel:49:100',
          episodeId: 'novel:49:100:5001',
          scrollOffset: 0,
          updatedAt: DateTime(2026, 10, 4),
          flowMode: NovelReaderFlowMode.pagedLtr,
          pageIndex: 8,
          pageCount: 10,
          anchorNodeId: 'node-8',
          anchorTextOffset: 777,
          anchorFormatVersion: version,
          anchorTextIdentity: version == 0 ? null : '  old identity  ',
          paginationKey: 'old-layout',
          progressPercent: 0.8,
          isProgressPercentValid: true,
        );
        final repository = _ControllerNovelRepository(
          preferences: NovelReaderPreferences.defaults().copyWith(
            flowMode: NovelReaderFlowMode.pagedLtr,
          ),
          readingProgress: original,
        );
        final committer = DefaultNovelReaderProgressCommitter(
          repository: repository,
        );
        final container = _buildContainer(
          repository: repository,
          progressCommitter: committer,
        );
        addTearDown(container.dispose);
        const args = NovelReaderArgs(
          novelId: 'novel:49:100',
          episodeId: 'novel:49:100:5001',
        );
        final provider = novelReaderControllerProvider(args);
        final subscription = _keepReaderAlive(container, args);
        addTearDown(subscription.close);
        final loaded = await container.read(provider.future);
        final controller = container.read(provider.notifier);
        // Exit can precede the first surface report, so it is protected too.
        await controller.saveCurrentProgressNow(loaded.progressSnapshot);
        _markReadingSurfaceReady(controller);
        for (final isFinal in [false, true]) {
          controller.onPagedPositionChanged(
            NovelReaderPaginationPosition(
              episodeId: args.episodeId,
              paginationKey: 'new-layout',
              pageIndex: 1,
              pageCount: isFinal ? 5 : 2,
              isPageCountFinal: isFinal,
              isReadOnlyCompatibilityRestore: true,
              anchor: NovelReaderTextAnchor(
                episodeId: args.episodeId,
                nodeId: 'new-node',
                textOffset: 10,
                formatVersion: 1,
                textIdentity: 'new exact text',
              ),
            ),
          );
          final restored = container.read(provider).value!.progressSnapshot;
          expect(restored, loaded.progressSnapshot);
          await controller.saveCurrentProgressNow(restored);
        }
        expect(repository.savedProgressEpisodeIds, isEmpty);
        expect(repository.readingProgress, same(original));
        expect(container.read(provider).value!.readingProgress, same(original));

        controller.onPagedPositionChanged(
          NovelReaderPaginationPosition(
            episodeId: args.episodeId,
            paginationKey: 'new-layout',
            pageIndex: 2,
            pageCount: 5,
            hasUserNavigated: true,
            anchor: NovelReaderTextAnchor(
              episodeId: args.episodeId,
              nodeId: 'new-node',
              textOffset: 20,
              formatVersion: 1,
              textIdentity: 'new exact text',
            ),
          ),
        );
        await controller.saveCurrentProgressNow(
          container.read(provider).value!.progressSnapshot,
        );
        expect(repository.savedProgressEpisodeIds, [args.episodeId]);
        expect(repository.readingProgress?.anchorFormatVersion, 1);
        expect(
          repository.readingProgress?.anchorTextIdentity,
          'new exact text',
        );
        expect(repository.readingProgress?.anchorTextOffset, 20);
        expect(repository.readingProgress?.progressPercent, 0.4);
      },
    );
  }

  test(
    'a new paged chapter saves its first visible position without a page turn',
    () async {
      final repository = _ControllerNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
        ),
      );
      final committer = DefaultNovelReaderProgressCommitter(
        repository: repository,
      );
      final container = _buildContainer(
        repository: repository,
        progressCommitter: committer,
      );
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);
      final loaded = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      await controller.saveCurrentProgressNow(loaded.progressSnapshot);
      expect(repository.savedProgressEpisodeIds, isEmpty);
      _markReadingSurfaceReady(controller);
      controller.onPagedPositionChanged(
        const NovelReaderPaginationPosition(
          episodeId: 'novel:49:100:5001',
          paginationKey: 'new-layout',
          pageIndex: 0,
          pageCount: 2,
          anchor: NovelReaderTextAnchor(
            episodeId: 'novel:49:100:5001',
            nodeId: 'node-0',
            formatVersion: 1,
            textIdentity: 'first text',
          ),
        ),
      );
      await controller.saveCurrentProgressNow(
        container.read(provider).value!.progressSnapshot,
      );
      expect(repository.savedProgressEpisodeIds, [args.episodeId]);
      expect(repository.readingProgress?.anchorFormatVersion, 1);
      expect(repository.readingProgress?.pageIndex, 0);
    },
  );

  test(
    'explicit paged fromBeginning commits its first reported position',
    () async {
      final repository = _ControllerNovelRepository(
        preferences: NovelReaderPreferences.defaults().copyWith(
          flowMode: NovelReaderFlowMode.pagedLtr,
        ),
      );
      final committer = _FakeNovelReaderProgressCommitter();
      final container = _buildContainer(
        repository: repository,
        progressCommitter: committer,
      );
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
        openPolicy: NovelEpisodeOpenPolicy.startAtBeginning,
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);
      await container.read(provider.future);
      _markReadingSurfaceReady(container.read(provider.notifier));
      container
          .read(provider.notifier)
          .onPagedPositionChanged(
            const NovelReaderPaginationPosition(
              episodeId: 'novel:49:100:5001',
              paginationKey: 'new-layout',
              pageIndex: 0,
              pageCount: 2,
              anchor: NovelReaderTextAnchor(
                episodeId: 'novel:49:100:5001',
                nodeId: 'node-0',
                formatVersion: 1,
                textIdentity: 'first text',
              ),
            ),
          );
      await Future<void>.delayed(Duration.zero);
      expect(committer.flushCallCount, 1);
      expect(committer.latestFlushedSnapshot?.anchorFormatVersion, 1);
      expect(committer.latestFlushedSnapshot?.pageIndex, 0);
    },
  );

  test('a saved partial position reopens into a complete reflowed plan by its new anchor', () async {
    final repository = _ControllerNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      ),
      readingProgress: NovelReadingProgress(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
        scrollOffset: 0,
        updatedAt: DateTime(2026, 10, 4),
        flowMode: NovelReaderFlowMode.pagedLtr,
        pageIndex: 8,
        pageCount: 10,
        anchorNodeId: 'node-8',
        anchorFormatVersion: 1,
        anchorTextIdentity: 'semantic-text-v1',
        progressPercent: 0.8,
        isProgressPercentValid: true,
      ),
    );
    final committer = DefaultNovelReaderProgressCommitter(
      repository: repository,
    );
    final container = _buildContainer(
      repository: repository,
      progressCommitter: committer,
    );
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);
    final loaded = await container.read(provider.future);
    expect(loaded.progressSnapshot.progressPercent, 0.8);
    expect(loaded.progressSnapshot.isProgressPercentValid, isTrue);

    final controller = container.read(provider.notifier);
    _markReadingSurfaceReady(controller);
    controller.onPagedPositionChanged(
      const NovelReaderPaginationPosition(
        episodeId: 'novel:49:100:5001',
        paginationKey: 'layout-v1',
        pageIndex: 1,
        pageCount: 2,
        isPageCountFinal: false,
        hasUserNavigated: true,
        anchor: NovelReaderTextAnchor(
          episodeId: 'novel:49:100:5001',
          nodeId: 'node-2',
          textOffset: 14,
          formatVersion: 1,
          textIdentity: 'semantic-text-v1',
        ),
      ),
    );
    final partial = container.read(provider).value!.progressSnapshot;
    expect(partial.progressPercent, 0);
    expect(partial.isProgressPercentValid, isFalse);
    expect(partial.pageCount, isNull);
    await controller.saveCurrentProgressNow(partial);
    expect(repository.readingProgress?.isProgressPercentValid, isFalse);
    expect(repository.readingProgress?.progressPercent, 0);

    final reopened = _buildContainer(repository: repository);
    addTearDown(reopened.dispose);
    final reopenedSubscription = _keepReaderAlive(reopened, args);
    addTearDown(reopenedSubscription.close);
    final restored = await reopened.read(provider.future);
    expect(restored.progressSnapshot.anchorFormatVersion, 1);
    expect(restored.progressSnapshot.anchorTextIdentity, 'semantic-text-v1');
    expect(restored.progressSnapshot.anchorTextOffset, 14);
    expect(restored.progressSnapshot.progressPercent, 0);
    expect(restored.progressSnapshot.isProgressPercentValid, isFalse);
    expect(restored.progressSnapshot.pageCount, isNull);

    // Reflow changes both the page index for offset 14 and the layout key.
    // The reopened persisted snapshot must drive the real restore policy,
    // rather than independently reconstructing its expected metadata.
    const completeKey = NovelReaderPaginationKey(
      episodeId: 'novel:49:100:5001',
      contentHash: 'same-semantic-content',
      viewportWidthPx: 320,
      viewportHeightPx: 600,
      typographySignature: 'reflowed-type',
      themeSignature: 'theme',
      imageDimensionRevision: 1,
      rendererRevision: 19,
    );
    const boundaries = [0, 5, 10, 20, 30];
    const text = '0123456789abcdefghijklmnopqrst';
    final completePlan = NovelReaderPaginationPlan(
      key: completeKey,
      episodeId: args.episodeId,
      pages: [
        for (var index = 0; index < boundaries.length - 1; index++)
          NovelReaderPageFragment(
            index: index,
            html:
                '<p>${text.substring(boundaries[index], boundaries[index + 1])}</p>',
            startAnchor: NovelReaderTextAnchor(
              episodeId: args.episodeId,
              nodeId: 'node-2',
              textOffset: boundaries[index],
              formatVersion: 1,
              textIdentity: 'semantic-text-v1',
            ),
            endAnchor: NovelReaderTextAnchor(
              episodeId: args.episodeId,
              nodeId: 'node-2',
              textOffset: boundaries[index + 1],
              formatVersion: 1,
              textIdentity: 'semantic-text-v1',
            ),
            imageIndices: const [],
          ),
      ],
    );
    final reopenedSnapshot = restored.progressSnapshot;
    expect(reopenedSnapshot.pageIndex, 1);
    expect(
      reopenedSnapshot.paginationKey,
      isNot(completeKey.layoutFingerprint),
    );
    const restorePolicy = NovelReaderPaginationRestorePolicy();
    final resolution = restorePolicy.resolveAvailablePage(
      plan: completePlan,
      snapshot: reopenedSnapshot,
      isPlanComplete: true,
    );
    expect(resolution, isNotNull);
    expect(resolution!.pageIndex, 2);
    expect(resolution.isReadOnlyCompatibilityRestore, isFalse);
    expect(completePlan.pages[resolution.pageIndex].html, '<p>abcdefghij</p>');
    // The previous valid percentage would select a different page. Keeping
    // it alongside the new anchor would therefore regress this round trip.
    expect(
      restorePolicy
          .resolveInitialPage(
            plan: completePlan,
            snapshot: loaded.progressSnapshot,
          )
          .pageIndex,
      3,
    );
    expect(reopenedSnapshot.anchorTextOffset, 14);
    expect(reopenedSnapshot.isProgressPercentValid, isFalse);
  });
}
