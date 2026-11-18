part of 'novel_reader_controller_test.dart';

void _importedFontCases() {
  group('imported novel fonts', () {
    late _FontRepositoryForNovel fonts;
    late _DelayedFontRuntime runtime;
    late FontLibraryService fontService;
    late _ControllerNovelRepository repository;
    late ProviderContainer container;
    const args = NovelReaderArgs(
      novelId: 'novel:49:100',
      episodeId: 'novel:49:100:5001',
    );
    final provider = novelReaderControllerProvider(args);

    setUp(() {
      fonts = _FontRepositoryForNovel();
      runtime = _DelayedFontRuntime();
      fontService = FontLibraryService(
        repository: fonts,
        runtimeLoader: runtime,
      );
      repository = _ControllerNovelRepository();
      container = _buildContainer(
        repository: repository,
        fontService: fontService,
      );
      final subscription = _keepReaderAlive(container, args);
      addTearDown(subscription.close);
    });

    tearDown(() async {
      container.dispose();
      fontService.dispose();
      await fonts.dispose();
    });

    test(
      'cold start waits for the persisted font before publishing text',
      () async {
        repository.preferences = repository.preferences.copyWith(
          fontFamily: fonts.firstId,
        );
        final gate = runtime.block(fonts.firstId);
        final loading = container.read(provider.future);
        await runtime.started(fonts.firstId);
        expect(container.read(provider).isLoading, isTrue);
        gate.complete(FontIdentity.runtimeFamily(fonts.firstId));
        final loaded = await loading;
        expect(loaded.preferences.fontFamily, fonts.firstId);
        expect(
          loaded.bodyFont.fontFamily,
          FontIdentity.runtimeFamily(fonts.firstId),
        );
      },
    );

    test('a later preview supersedes an older font still loading', () async {
      final loaded = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final gate = runtime.block(fonts.firstId);
      controller.previewPreferences(
        loaded.preferences.copyWith(fontFamily: fonts.firstId),
      );
      await runtime.started(fonts.firstId);
      expect(container.read(provider).value!.bodyFont.isSystem, isTrue);
      controller.previewPreferences(
        loaded.preferences.copyWith(fontFamily: fonts.secondId),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).value!.bodyFont.id, fonts.secondId);
      gate.complete(FontIdentity.runtimeFamily(fonts.firstId));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(provider).value!.preferences.fontFamily,
        fonts.secondId,
      );
      expect(container.read(provider).value!.bodyFont.id, fonts.secondId);
    });

    test(
      'older save cannot publish over a newer pending font preview',
      () async {
        final loaded = await container.read(provider.future);
        final controller = container.read(provider.notifier);
        final firstGate = runtime.block(fonts.firstId);
        final secondGate = runtime.block(fonts.secondId);
        final first = loaded.preferences.copyWith(fontFamily: fonts.firstId);
        controller.previewPreferences(first);
        final saving = controller.commitPreferences(first);
        await runtime.started(fonts.firstId);
        controller.previewPreferences(
          loaded.preferences.copyWith(fontFamily: fonts.secondId),
        );
        await runtime.started(fonts.secondId);
        firstGate.complete(FontIdentity.runtimeFamily(fonts.firstId));
        await saving;
        expect(container.read(provider).value!.bodyFont.isSystem, isTrue);
        secondGate.complete(FontIdentity.runtimeFamily(fonts.secondId));
        await Future<void>.delayed(Duration.zero);
        expect(container.read(provider).value!.bodyFont.id, fonts.secondId);
      },
    );

    test(
      'deleted active font falls back without altering the reading snapshot',
      () async {
        repository.preferences = repository.preferences.copyWith(
          fontFamily: fonts.firstId,
        );
        final loaded = await container.read(provider.future);
        await fontService.deleteFont(fonts.firstId);
        await Future<void>.delayed(Duration.zero);
        final latest = container.read(provider).value!;
        expect(latest.bodyFont.isSystem, isTrue);
        expect(latest.preferences.fontFamily, FontIdentity.system);
        expect(latest.fontResolution.failure, FontLibraryFailure.notFound);
        expect(latest.fontResolution.requestedId, fonts.firstId);
        expect(latest.progressSnapshot, loaded.progressSnapshot);
        expect(identical(latest.document, loaded.document), isTrue);
      },
    );

    test(
      'missing saved font retains unrelated preferences on system fallback',
      () async {
        repository.preferences = repository.preferences.copyWith(
          fontFamily: fonts.firstId,
          fontSize: 23,
          lineHeight: 1.9,
        );
        await fontService.deleteFont(fonts.firstId);
        final loaded = await container.read(provider.future);
        expect(loaded.bodyFont.isSystem, isTrue);
        expect(loaded.preferences.fontSize, 23);
        expect(loaded.preferences.lineHeight, 1.9);
        expect(loaded.fontResolution.failure, FontLibraryFailure.notFound);
        await container
            .read(provider.notifier)
            .commitPreferences(loaded.preferences);
        expect(repository.preferences.fontFamily, FontIdentity.system);
        expect(repository.preferences.fontSize, 23);
      },
    );

    test(
      'catalog repair retries a temporarily unavailable saved font',
      () async {
        repository.preferences = repository.preferences.copyWith(
          fontFamily: fonts.firstId,
        );
        fonts.failReads = true;
        final loaded = await container.read(provider.future);
        expect(loaded.bodyFont.isSystem, isTrue);
        expect(loaded.persistedPreferences.fontFamily, fonts.firstId);
        expect(loaded.fontResolution.failure, FontLibraryFailure.storage);
        fonts.failReads = false;
        fonts.announceChange();
        await Future<void>.delayed(Duration.zero);
        expect(container.read(provider).value!.bodyFont.id, fonts.firstId);
        expect(
          container.read(provider).value!.preferences.fontFamily,
          fonts.firstId,
        );
      },
    );

    test('chapter navigation retires a pending font preview', () async {
      final loaded = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final gate = runtime.block(fonts.firstId);
      controller.previewPreferences(
        loaded.preferences.copyWith(fontFamily: fonts.firstId),
      );
      await runtime.started(fonts.firstId);
      await controller.openEpisodeFromCatalog('novel:49:100:5002');
      gate.complete(FontIdentity.runtimeFamily(fonts.firstId));
      await Future<void>.delayed(Duration.zero);
      final latest = container.read(provider).value!;
      expect(latest.currentEpisode.episodeId, 'novel:49:100:5002');
      expect(latest.bodyFont.isSystem, isTrue);
      expect(latest.preferences.fontFamily, FontIdentity.system);
    });
  });
}
