part of 'novel_reader_controller_test.dart';

void _chapterTransitionCases() {
  test('chapter transition waits for its eligible source flush', () async {
    final repository = _ControllerNovelRepository();
    final committer = _GatedProgressCommitter(repository);
    final bootstrap = _SequenceNovelReaderBootstrapService();
    bootstrap.completeAt(
      0,
      _criticalBootstrap(
        episodeId: 'novel:49:100:5001',
        preferences: repository.preferences,
      ),
    );
    final container = _buildContainer(
      repository: repository,
      progressCommitter: committer,
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
    await container.read(provider.future);
    final controller = container.read(provider.notifier);
    _markReadingSurfaceReady(controller);
    await controller.onScrollOffsetChanged(42, maxScrollExtent: 84);
    final sourceSnapshot = container.read(provider).value!.progressSnapshot;

    final transition = controller.openEpisode('novel:49:100:5002');
    await Future<void>.delayed(Duration.zero);
    expect(committer.flushCallCount, 1);
    expect(bootstrap.contexts, hasLength(1));
    expect(container.read(provider).value!.transition, isNull);
    expect(repository.savedProgressEpisodeIds, isEmpty);

    committer.gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(committer.committed, [sourceSnapshot]);
    expect(bootstrap.contexts, hasLength(2));
    expect(
      container.read(provider).value!.transition?.targetEpisodeId,
      'novel:49:100:5002',
    );
    bootstrap.completeAt(1, _criticalBootstrap(episodeId: 'novel:49:100:5002'));
    expect(await transition, isTrue);
    expect(
      container.read(provider).value!.currentEpisode.episodeId,
      'novel:49:100:5002',
    );
  });

  for (final dispose in [false, true]) {
    for (final fail in [false, true]) {
      test(
        'late chapter ${fail ? 'failure' : 'success'} is retired by ${dispose ? 'dispose' : 'same-notifier refresh'}',
        () async {
          final repository = _ControllerNovelRepository();
          final bootstrap = _SequenceNovelReaderBootstrapService();
          bootstrap.completeAt(
            0,
            _criticalBootstrap(episodeId: 'novel:49:100:5001'),
          );
          final container = _buildContainer(
            repository: repository,
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
          final oldTransition = controller.openEpisode('novel:49:100:5002');
          await Future<void>.delayed(Duration.zero);
          expect(bootstrap.contexts, hasLength(2));
          expect(
            container.read(provider).value!.transition!.targetEpisodeId,
            'novel:49:100:5002',
          );
          NovelReaderViewState? fresh;
          if (dispose) {
            container.dispose();
            disposed = true;
          } else {
            bootstrap.completeAt(
              2,
              _criticalBootstrap(episodeId: 'novel:49:100:5001'),
            );
            container.invalidate(provider);
            await container.read(provider.future);
            expect(container.read(provider.notifier), same(controller));
            await Future<void>.delayed(Duration.zero);
            fresh = container.read(provider).value!;
            expect(fresh.transition, isNull);
          }
          if (fail) {
            bootstrap.failAt(1, StateError('retired chapter load failed'));
          } else {
            bootstrap.completeAt(
              1,
              _criticalBootstrap(episodeId: 'novel:49:100:5002'),
            );
          }
          expect(await oldTransition, isFalse);
          if (!dispose) {
            expect(container.read(provider).value, same(fresh));
            expect(
              container.read(provider).value!.currentEpisode.episodeId,
              'novel:49:100:5001',
            );
          }
        },
      );
    }
  }

  for (final dispose in [false, true]) {
    for (final fail in [false, true]) {
      test(
        'error-view update ${fail ? 'failure' : 'success'} is retired by ${dispose ? 'dispose' : 'same-notifier refresh'}',
        () async {
          final bootstrap = _SequenceNovelReaderBootstrapService();
          bootstrap.failAt(0, StateError('initial chapter unavailable'));
          final updates = _GatedNovelChapterUpdateService();
          final container = _buildContainer(
            repository: _ControllerNovelRepository(),
            bootstrapService: bootstrap,
            chapterUpdateService: updates,
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
          await expectLater(container.read(provider.future), throwsStateError);
          expect(container.read(provider).hasError, isTrue);
          final controller = container.read(provider.notifier);
          final oldUpdate = controller.updateWork();
          expect(updates.started, 1);
          expect(container.read(provider).isLoading, isTrue);
          expect(bootstrap.contexts, hasLength(1));
          NovelReaderViewState? fresh;
          if (dispose) {
            container.dispose();
            disposed = true;
          } else {
            bootstrap.completeAt(
              1,
              _criticalBootstrap(episodeId: 'novel:49:100:5001'),
            );
            container.invalidate(provider);
            await container.read(provider.future);
            expect(container.read(provider.notifier), same(controller));
            await Future<void>.delayed(Duration.zero);
            fresh = container.read(provider).value!;
          }
          updates.complete(fail: fail);
          expect(await oldUpdate, isFalse);
          expect(
            bootstrap.contexts,
            hasLength(dispose ? 1 : 2),
            reason: 'A retired update must not start another bootstrap.',
          );
          if (!dispose) {
            expect(container.read(provider).value, same(fresh));
            expect(container.read(provider).hasError, isFalse);
          }
        },
      );
    }
  }

  for (final fail in [false, true]) {
    test(
      'active error-view update preserves its ${fail ? 'failure' : 'success'} result',
      () async {
        final bootstrap = _SequenceNovelReaderBootstrapService();
        bootstrap.failAt(0, StateError('initial chapter unavailable'));
        bootstrap.completeAt(
          1,
          _criticalBootstrap(episodeId: 'novel:49:100:5001'),
        );
        final updates = _GatedNovelChapterUpdateService();
        final container = _buildContainer(
          repository: _ControllerNovelRepository(),
          bootstrapService: bootstrap,
          chapterUpdateService: updates,
        );
        addTearDown(container.dispose);
        const args = NovelReaderArgs(
          novelId: 'novel:49:100',
          episodeId: 'novel:49:100:5001',
        );
        final provider = novelReaderControllerProvider(args);
        final subscription = _keepReaderAlive(container, args);
        addTearDown(subscription.close);
        await expectLater(container.read(provider.future), throwsStateError);
        final update = container.read(provider.notifier).updateWork();
        expect(container.read(provider).isLoading, isTrue);
        updates.complete(fail: fail);
        expect(await update, !fail);
        expect(bootstrap.contexts, hasLength(fail ? 1 : 2));
        if (fail) {
          expect(container.read(provider).error, isA<StateError>());
        } else {
          expect(
            container.read(provider).value!.currentEpisode.episodeId,
            'novel:49:100:5001',
          );
          expect(container.read(provider).hasError, isFalse);
        }
      },
    );
  }
}
