part of 'novel_reader_controller_test.dart';

void _progressFlushCases() {
  test(
    'NovelReaderController preview and commit are no-op for equal preferences',
    () async {
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

      final initial = await container.read(provider.future);

      container
          .read(provider.notifier)
          .previewPreferences(initial.effectivePreferences);
      await container
          .read(provider.notifier)
          .commitPreferences(initial.persistedPreferences);
      final state = container.read(provider).value!;

      expect(state.persistedPreferences, initial.persistedPreferences);
      expect(state.effectivePreferences, initial.effectivePreferences);
      expect(repository.upsertPreferencesCallCount, 0);
    },
  );

  test('NovelReaderController saveCurrentProgressNow flushes and syncs readingProgress', () async {
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
    const snapshot = NovelReaderProgressSnapshot(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
      flowMode: NovelReaderFlowMode.vertical,
      scrollOffset: 42,
      pageIndex: 0,
      progressPercent: 0.5,
      anchorFormatVersion: 37,
      anchorTextIdentity: '  unsupported identity  ',
    );

    _markReadingSurfaceReady(container.read(provider.notifier));
    await container.read(provider.notifier).saveCurrentProgressNow(snapshot);

    final state = container.read(provider).value!;
    expect(progressCommitter.flushCallCount, 1);
    expect(progressCommitter.latestFlushedSnapshot, snapshot);
    expect(state.progressSnapshot, snapshot);
    expect(state.currentOffset, 42);
    expect(state.readingProgress?.episodeId, 'novel:49:100:5001');
    expect(state.readingProgress?.scrollOffset, 42);
    expect(state.readingProgress?.anchorFormatVersion, 37);
    expect(
      state.readingProgress?.anchorTextIdentity,
      '  unsupported identity  ',
    );
    expect(state.readingProgress?.isProgressPercentValid, isNull);
  });

  test(
    'progress flush rejects a snapshot from another novel or episode',
    () async {
      final repository = _ControllerNovelRepository();
      final committer = _FakeNovelReaderProgressCommitter();
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
      await container.read(provider.future);
      await Future<void>.delayed(Duration.zero);
      _markReadingSurfaceReady(container.read(provider.notifier));
      final initial = container.read(provider).value!;
      for (final identity in [
        (novelId: 'another-novel', episodeId: 'novel:49:100:5001'),
        (novelId: 'novel:49:100', episodeId: 'novel:49:100:5002'),
      ]) {
        await container
            .read(provider.notifier)
            .saveCurrentProgressNow(
              NovelReaderProgressSnapshot(
                novelId: identity.novelId,
                episodeId: identity.episodeId,
                flowMode: NovelReaderFlowMode.vertical,
                scrollOffset: 42,
                pageIndex: 0,
                progressPercent: 0.5,
              ),
            );
      }
      expect(committer.flushCallCount, 0);
      expect(container.read(provider).value, same(initial));
    },
  );

  for (final retirement in [
    'chapter',
    'return',
    'refresh',
    'refreshed',
    'dispose',
  ]) {
    test('a started progress flush does not project after $retirement', () async {
      final initialProgress = NovelReadingProgress(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
        scrollOffset: 7,
        updatedAt: DateTime(2026, 6, 1),
      );
      final repository = _ControllerNovelRepository(
        readingProgress: initialProgress,
      );
      final committer = _GatedProgressCommitter(repository);
      final bootstrap = retirement == 'refresh'
          ? _SequenceNovelReaderBootstrapService()
          : null;
      bootstrap?.completeAt(
        0,
        _criticalBootstrap(
          episodeId: 'novel:49:100:5001',
          readingProgress: initialProgress,
          preferences: repository.preferences,
        ),
      );
      final container = _buildContainer(
        repository: repository,
        progressCommitter: committer,
        bootstrapService: bootstrap,
      );
      var disposed = false;
      addTearDown(() {
        if (!disposed) container.dispose();
      });
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      addTearDown(() {
        if (!disposed) subscription.close();
      });
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      const snapshot = NovelReaderProgressSnapshot(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
        flowMode: NovelReaderFlowMode.vertical,
        scrollOffset: 42,
        pageIndex: 0,
        progressPercent: 0.5,
      );
      _markReadingSurfaceReady(controller);
      await controller.onScrollOffsetChanged(42, bodySnapshot: snapshot);
      final oldFlush = controller.saveCurrentProgressNow(snapshot);
      expect(committer.flushCallCount, 1);
      expect(container.read(provider).value!.currentOffset, 42);

      if (retirement == 'refresh') {
        container.invalidate(provider);
        final reloaded = container.read(provider.future);
        expect(container.read(provider.notifier), same(controller));
        expect(container.read(provider).isLoading, isTrue);
        await controller.saveCurrentProgressNow(snapshot);
        expect(
          committer.flushCallCount,
          1,
          reason: 'Loading has no active progress surface.',
        );
        committer.gate.complete();
        await oldFlush;
        expect(container.read(provider).isLoading, isTrue);
        bootstrap!.completeAt(
          1,
          _criticalBootstrap(
            episodeId: 'novel:49:100:5001',
            readingProgress: initialProgress,
            preferences: repository.preferences,
          ),
        );
        final fresh = await reloaded;
        expect(fresh.currentOffset, 7);
        expect(fresh.readingProgress, same(initialProgress));
      } else if (retirement == 'dispose') {
        container.dispose();
        disposed = true;
        committer.gate.complete();
        await oldFlush;
      } else if (retirement == 'refreshed') {
        container.invalidate(provider);
        await container.read(provider.future);
        expect(container.read(provider.notifier), same(controller));
        await Future<void>.delayed(Duration.zero);
        final fresh = container.read(provider).value!;
        expect(fresh.currentOffset, 7);
        committer.gate.complete();
        await oldFlush;
        final after = container.read(provider).value!;
        expect(after.progressSnapshot, fresh.progressSnapshot);
        expect(after.currentOffset, fresh.currentOffset);
        expect(after.readingProgress, same(fresh.readingProgress));
      } else {
        // Retire eligibility before changing owner: a transition now waits
        // for any new eligible source flush, while this issued write remains
        // deliberately pending until after the target has been published.
        controller.updateReadingVisibility(frontmost: false, resumed: true);
        expect(await controller.openEpisode('novel:49:100:5002'), isTrue);
        if (retirement == 'return') {
          expect(await controller.openEpisode('novel:49:100:5001'), isTrue);
        }
        await Future<void>.delayed(Duration.zero);
        final fresh = container.read(provider).value!;
        committer.gate.complete();
        await oldFlush;
        final after = container.read(provider).value!;
        expect(after.currentEpisode.episodeId, fresh.currentEpisode.episodeId);
        expect(after.progressSnapshot, fresh.progressSnapshot);
        expect(after.currentOffset, fresh.currentOffset);
        expect(after.readingProgress, same(fresh.readingProgress));
      }
      // Cancellation retires UI ownership, not the already issued local write.
      expect(committer.committed, [snapshot]);
      expect(repository.readingProgress!.scrollOffset, 42);
    });
  }
}
