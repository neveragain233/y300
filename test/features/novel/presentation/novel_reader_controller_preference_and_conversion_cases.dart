part of 'novel_reader_controller_test.dart';

void _preferenceAndConversionCases() {
  test('NovelReaderViewState derives episode boundaries', () {
    final episodes = _episodes();

    final first = _viewState(
      episodes: episodes,
      currentEpisode: episodes.first,
    );
    expect(first.currentEpisodeIndex, 0);
    expect(first.previousEpisode, isNull);
    expect(first.nextEpisode?.episodeId, episodes[1].episodeId);
    expect(first.hasPreviousEpisode, isFalse);
    expect(first.hasNextEpisode, isTrue);

    final middle = _viewState(episodes: episodes, currentEpisode: episodes[1]);
    expect(middle.currentEpisodeIndex, 1);
    expect(middle.previousEpisode?.episodeId, episodes.first.episodeId);
    expect(middle.nextEpisode?.episodeId, episodes.last.episodeId);
    expect(middle.hasPreviousEpisode, isTrue);
    expect(middle.hasNextEpisode, isTrue);

    final last = _viewState(episodes: episodes, currentEpisode: episodes.last);
    expect(last.currentEpisodeIndex, 2);
    expect(last.previousEpisode?.episodeId, episodes[1].episodeId);
    expect(last.nextEpisode, isNull);
    expect(last.hasPreviousEpisode, isTrue);
    expect(last.hasNextEpisode, isFalse);
  });

  test('NovelReaderController loads readingProgress into state', () async {
    final progress = NovelReadingProgress(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5002',
      scrollOffset: 88,
      updatedAt: DateTime(2026, 6, 1),
      anchorFormatVersion: 37,
      anchorTextIdentity: '  unsupported identity  ',
      isProgressPercentValid: false,
    );
    final repository = _ControllerNovelRepository(readingProgress: progress);
    final container = _buildContainer(repository: repository);
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5002',
    );
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);

    final state = await container.read(
      novelReaderControllerProvider(args).future,
    );

    expect(state.readingProgress?.episodeId, 'novel:49:100:5002');
    expect(state.currentOffset, 88);
    expect(state.progressSnapshot.anchorFormatVersion, 37);
    expect(
      state.progressSnapshot.anchorTextIdentity,
      '  unsupported identity  ',
    );
    expect(state.progressSnapshot.isProgressPercentValid, isFalse);
  });

  test('NovelReaderController exposes the persisted paged preference as effective mode', () async {
    final repository = _ControllerNovelRepository(
      preferences: NovelReaderPreferences.defaults().copyWith(
        flowMode: NovelReaderFlowMode.pagedRtl,
      ),
    );
    final container = _buildContainer(repository: repository);
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);

    final state = await container.read(
      novelReaderControllerProvider(args).future,
    );

    expect(state.persistedPreferences.flowMode, NovelReaderFlowMode.pagedRtl);
    expect(state.effectivePreferences.flowMode, NovelReaderFlowMode.pagedRtl);
    expect(state.progressSnapshot.flowMode, NovelReaderFlowMode.pagedRtl);
  });

  test(
    'NovelReaderController exposes paged LTR for new-reader defaults',
    () async {
      final repository = _ControllerNovelRepository(
        preferences: NovelReaderPreferences.defaults(),
      );
      final container = _buildContainer(repository: repository);
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);

      final state = await container.read(
        novelReaderControllerProvider(args).future,
      );

      expect(state.persistedPreferences.flowMode, NovelReaderFlowMode.pagedLtr);
      expect(state.effectivePreferences.flowMode, NovelReaderFlowMode.pagedLtr);
      expect(state.progressSnapshot.flowMode, NovelReaderFlowMode.pagedLtr);
    },
  );

  test(
    'NovelReaderController previewPreferences only updates effective state',
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
      final next = initial.persistedPreferences.copyWith(
        themePreset: NovelReaderThemePreset.sepia,
        flowMode: NovelReaderFlowMode.pagedLtr,
      );

      container.read(provider.notifier).previewPreferences(next);
      final state = container.read(provider).value!;

      expect(state.persistedPreferences, initial.persistedPreferences);
      expect(state.effectivePreferences, next);
      expect(state.progressSnapshot.flowMode, NovelReaderFlowMode.vertical);
      expect(repository.latestPreferences, isNull);
      expect(repository.upsertPreferencesCallCount, 0);
    },
  );

  test(
    'NovelReaderController commitPreferences persists once and syncs state',
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
      final next = initial.persistedPreferences.copyWith(
        themePreset: NovelReaderThemePreset.dark,
      );

      container.read(provider.notifier).previewPreferences(next);
      await container.read(provider.notifier).commitPreferences(next);
      final state = container.read(provider).value!;

      expect(repository.latestPreferences, next);
      expect(repository.upsertPreferencesCallCount, 1);
      expect(state.persistedPreferences, next);
      expect(state.effectivePreferences, next);
    },
  );

  test(
    'NovelReaderController revertPreferencePreview rolls back effective state',
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
      final next = initial.persistedPreferences.copyWith(
        flowMode: NovelReaderFlowMode.pagedLtr,
      );

      container.read(provider.notifier).previewPreferences(next);
      container.read(provider.notifier).revertPreferencePreview();
      final state = container.read(provider).value!;

      expect(state.persistedPreferences, initial.persistedPreferences);
      expect(state.effectivePreferences, initial.persistedPreferences);
      expect(
        state.progressSnapshot.flowMode,
        initial.persistedPreferences.flowMode,
      );
      expect(repository.upsertPreferencesCallCount, 0);
    },
  );

  test('late preference save preserves a newer preview and progress', () async {
    final repository = _ControllerNovelRepository();
    final preferencesRepository = _DelayedPreferencesRepository(repository);
    final container = _buildContainer(
      repository: repository,
      preferencesRepository: preferencesRepository,
    );
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);
    final initial = await container.read(provider.future);
    final controller = container.read(provider.notifier);
    final first = initial.preferences.copyWith(fontSize: 20);
    final latest = first.copyWith(fontSize: 24);
    controller.previewPreferences(first);
    final commit = controller.commitPreferences(first);
    controller.previewPreferences(latest);
    preferencesRepository.saveGate.complete();
    await commit;

    final state = container.read(provider).value!;
    expect(state.persistedPreferences, first);
    expect(state.effectivePreferences, latest);
    expect(state.progressSnapshot, initial.progressSnapshot);
    expect(state.document, initial.document);
  });

  test(
    'preference save finishing after disposal does not use disposed ref',
    () async {
      final repository = _ControllerNovelRepository();
      final preferencesRepository = _DelayedPreferencesRepository(repository);
      final container = _buildContainer(
        repository: repository,
        preferencesRepository: preferencesRepository,
      );
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      final initial = await container.read(provider.future);
      final next = initial.preferences.copyWith(fontSize: 24);
      final commit = container.read(provider.notifier).commitPreferences(next);
      subscription.close();
      container.dispose();
      preferencesRepository.saveGate.complete();

      await expectLater(commit, completes);
      expect(repository.latestPreferences, next);
    },
  );

  test('an old save cannot mutate a rebuilt reader generation', () async {
    final repository = _ControllerNovelRepository();
    final preferencesRepository = _DelayedPreferencesRepository(repository);
    final container = _buildContainer(
      repository: repository,
      preferencesRepository: preferencesRepository,
    );
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);
    final initial = await container.read(provider.future);
    final first = initial.preferences.copyWith(fontSize: 20);
    final commit = container.read(provider.notifier).commitPreferences(first);
    container.invalidate(provider);
    final rebuilt = await container.read(provider.future);
    final latest = rebuilt.preferences.copyWith(fontSize: 24);
    container.read(provider.notifier).previewPreferences(latest);
    preferencesRepository.saveGate.complete();
    await commit;

    final state = container.read(provider).value!;
    expect(state.persistedPreferences, rebuilt.persistedPreferences);
    expect(state.effectivePreferences, latest);
    expect(state.document, rebuilt.document);
    expect(state.progressSnapshot, rebuilt.progressSnapshot);
  });

  test(
    'equal baseline is saved when an old write finished after rebuild',
    () async {
      final repository = _ControllerNovelRepository();
      final preferencesRepository = _DelayedPreferencesRepository(repository);
      final container = _buildContainer(
        repository: repository,
        preferencesRepository: preferencesRepository,
      );
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final oldCommit = container
          .read(provider.notifier)
          .commitPreferences(initial.preferences.copyWith(fontSize: 20));
      container.invalidate(provider);
      final rebuilt = await container.read(provider.future);
      preferencesRepository.saveGate.complete();
      await oldCommit;
      expect(repository.preferences, isNot(rebuilt.persistedPreferences));

      await container
          .read(provider.notifier)
          .commitPreferences(rebuilt.persistedPreferences);
      expect(repository.preferences, rebuilt.persistedPreferences);
      expect(repository.upsertPreferencesCallCount, 2);
      await container
          .read(provider.notifier)
          .commitPreferences(rebuilt.persistedPreferences);
      expect(repository.upsertPreferencesCallCount, 2);
    },
  );

  test('conversion preview switches document and rendering together and save reuses it', () async {
    final repository = _ControllerNovelRepository();
    final builder = _ControlledConversionDocumentBuildService();
    final container = _buildContainer(
      repository: repository,
      documentBuildService: builder,
    );
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);
    final initial = await container.read(provider.future);
    final controller = container.read(provider.notifier);
    final next = initial.preferences.copyWith(
      conversionMode: NovelReaderConversionMode.toTraditional,
    );

    controller.previewPreferences(next);
    final commit = controller.commitPreferences(next);
    final waiting = container.read(provider).value!;
    expect(waiting.preferences, next);
    expect(
      waiting.renderPreferences.conversionMode,
      NovelReaderConversionMode.none,
    );
    expect(waiting.document, same(initial.document));
    expect(repository.upsertPreferencesCallCount, 0);
    expect(builder.requests, hasLength(1));

    builder.completeAt(0);
    await commit;
    final converted = container.read(provider).value!;
    expect(converted.renderPreferences, next);
    expect(converted.document.textConversionIdentity, next.conversionMode.name);
    expect(converted.progressSnapshot, same(initial.progressSnapshot));
    expect(repository.upsertPreferencesCallCount, 1);
    await controller.commitPreferences(next);
    expect(container.read(provider).value!.document, same(converted.document));
    expect(builder.requests, hasLength(1));
    expect(repository.upsertPreferencesCallCount, 1);
  });

  test(
    'returning to persisted conversion retires a pending conversion commit',
    () async {
      final repository = _ControllerNovelRepository();
      final builder = _ControlledConversionDocumentBuildService();
      final container = _buildContainer(
        repository: repository,
        documentBuildService: builder,
      );
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final next = initial.preferences.copyWith(
        conversionMode: NovelReaderConversionMode.toTraditional,
      );
      controller.previewPreferences(next);
      final pendingCommit = controller.commitPreferences(next);
      controller.previewPreferences(initial.preferences);
      await controller.commitPreferences(initial.preferences);
      builder.completeAt(0);
      await pendingCommit;
      final state = container.read(provider).value!;
      expect(state.document, same(initial.document));
      expect(state.renderPreferences, initial.preferences);
      expect(state.persistedPreferences, initial.preferences);
      expect(repository.upsertPreferencesCallCount, 0);
    },
  );

  test(
    'out of order conversion previews keep the latest selected document',
    () async {
      final repository = _ControllerNovelRepository();
      final builder = _ControlledConversionDocumentBuildService();
      final container = _buildContainer(
        repository: repository,
        documentBuildService: builder,
      );
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      controller.previewPreferences(
        initial.preferences.copyWith(
          conversionMode: NovelReaderConversionMode.toTraditional,
        ),
      );
      final latest = initial.preferences.copyWith(
        conversionMode: NovelReaderConversionMode.toSimplified,
      );
      controller.previewPreferences(latest);
      builder.completeAt(1);
      await Future<void>.delayed(Duration.zero);
      final converted = container.read(provider).value!;
      expect(converted.renderPreferences, latest);
      builder.completeAt(0);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(provider).value!.document,
        same(converted.document),
      );
      await controller.commitPreferences(latest);
      expect(builder.requests, hasLength(2));
      expect(repository.latestPreferences, latest);
    },
  );

  test(
    'failed conversion keeps readable content and does not persist its mode',
    () async {
      final repository = _ControllerNovelRepository();
      final builder = _ControlledConversionDocumentBuildService();
      final container = _buildContainer(
        repository: repository,
        documentBuildService: builder,
      );
      addTearDown(container.dispose);
      const args = NovelReaderArgs(
        novelId: 'novel:49:100',
        episodeId: 'novel:49:100:5001',
      );
      final provider = novelReaderControllerProvider(args);
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);
      final initial = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final next = initial.preferences.copyWith(
        conversionMode: NovelReaderConversionMode.toTraditional,
      );
      controller.previewPreferences(next);
      final commit = controller.commitPreferences(next);
      final failure = expectLater(commit, throwsStateError);
      builder.failAt(0);
      await failure;
      controller.revertPreferencePreview();
      expect(container.read(provider).value!.document, same(initial.document));
      expect(
        container.read(provider).value!.renderPreferences,
        initial.preferences,
      );
      expect(repository.upsertPreferencesCallCount, 0);
    },
  );

  test('conversion save crossing a chapter transition does not replace its document or preview', () async {
    final repository = _ControllerNovelRepository();
    final preferencesRepository = _DelayedPreferencesRepository(repository);
    final builder = _ControlledConversionDocumentBuildService();
    final bootstrap = _SequenceNovelReaderBootstrapService();
    bootstrap.completeAt(0, _criticalBootstrap(episodeId: 'novel:49:100:5001'));
    final container = _buildContainer(
      repository: repository,
      preferencesRepository: preferencesRepository,
      documentBuildService: builder,
      bootstrapService: bootstrap,
    );
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);
    final initial = await container.read(provider.future);
    final controller = container.read(provider.notifier);
    final next = initial.preferences.copyWith(
      conversionMode: NovelReaderConversionMode.toTraditional,
    );
    final commit = controller.commitPreferences(next);
    builder.completeAt(0);
    await Future<void>.delayed(Duration.zero);
    expect(repository.upsertPreferencesCallCount, 1);
    final transition = controller.openEpisodeFromCatalog('novel:49:100:5002');
    bootstrap.completeAt(
      1,
      _criticalBootstrap(
        episodeId: 'novel:49:100:5002',
        paragraphText: '第二章当前正文。',
      ),
    );
    expect(await transition, isTrue);
    final current = container.read(provider).value!;
    preferencesRepository.saveGate.complete();
    await commit;
    final state = container.read(provider).value!;
    expect(state.document, same(current.document));
    expect(state.effectivePreferences, current.effectivePreferences);
    expect(state.renderPreferences, current.renderPreferences);
    expect(state.progressSnapshot, same(current.progressSnapshot));
    expect(repository.latestPreferences, next);
  });

  test('returning to the original mode after a completed preview restores source text', () async {
    final repository = _ControllerNovelRepository();
    final builder = _ControlledConversionDocumentBuildService();
    final container = _buildContainer(
      repository: repository,
      documentBuildService: builder,
    );
    addTearDown(container.dispose);
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);
    final subscription = _keepReaderAlive(container, args);
    addTearDown(subscription.close);
    final initial = await container.read(provider.future);
    final controller = container.read(provider.notifier);
    controller.previewPreferences(
      initial.preferences.copyWith(
        conversionMode: NovelReaderConversionMode.toTraditional,
      ),
    );
    builder.completeAt(0);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(provider).value!.renderPreferences.conversionMode,
      NovelReaderConversionMode.toTraditional,
    );
    await controller.commitPreferences(initial.persistedPreferences);
    await Future<void>.delayed(Duration.zero);
    final state = container.read(provider).value!;
    expect(state.renderPreferences, initial.preferences);
    expect(state.document.plainText, initial.document.plainText);
    expect(
      state.document.textConversionIdentity,
      NovelReaderConversionMode.none.name,
    );
    expect(repository.upsertPreferencesCallCount, 0);
  });

  for (final returnToOriginal in [false, true]) {
    test(
      returnToOriginal
          ? 'late converted document cannot replace a new session of the same episode'
          : 'late converted document cannot replace the next episode',
      () async {
        final repository = _ControllerNovelRepository();
        final builder = _ControlledConversionDocumentBuildService();
        final bootstrap = _SequenceNovelReaderBootstrapService();
        bootstrap.completeAt(
          0,
          _criticalBootstrap(episodeId: 'novel:49:100:5001'),
        );
        final container = _buildContainer(
          repository: repository,
          bootstrapService: bootstrap,
          documentBuildService: builder,
        );
        addTearDown(container.dispose);
        const args = NovelReaderArgs(
          novelId: 'novel:49:100',
          episodeId: 'novel:49:100:5001',
        );
        final provider = novelReaderControllerProvider(args);
        final subscription = _keepReaderAlive(container, args);
        addTearDown(subscription.close);
        final initial = await container.read(provider.future);
        final controller = container.read(provider.notifier);
        final next = initial.preferences.copyWith(
          conversionMode: NovelReaderConversionMode.toTraditional,
        );
        controller.previewPreferences(next);
        final commit = controller.commitPreferences(next);
        await Future<void>.delayed(Duration.zero);
        expect(bootstrap.contexts, hasLength(1));
        expect(builder.requests, hasLength(1));
        final transition = controller.openEpisodeFromCatalog(
          'novel:49:100:5002',
        );
        bootstrap.completeAt(
          1,
          _criticalBootstrap(
            episodeId: 'novel:49:100:5002',
            paragraphText: '第二章当前正文。',
            preferences: next,
          ),
        );
        expect(await transition, isTrue);
        if (returnToOriginal) {
          final returnTransition = controller.openEpisodeFromCatalog(
            'novel:49:100:5001',
          );
          bootstrap.completeAt(
            2,
            _criticalBootstrap(
              episodeId: 'novel:49:100:5001',
              paragraphText: '第一章新会话正文。',
              preferences: next,
            ),
          );
          expect(await returnTransition, isTrue);
        }
        final current = container.read(provider).value!;
        builder.completeAt(0);
        await commit;

        final state = container.read(provider).value!;
        expect(state.currentEpisode, current.currentEpisode);
        expect(state.currentContent, current.currentContent);
        expect(state.document, current.document);
        expect(state.progressSnapshot, current.progressSnapshot);
      },
    );
  }
}
