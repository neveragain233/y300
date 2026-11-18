part of 'comic_detail_adapter_test.dart';

void _readingStateCases() {
  test(
    'resetChapterReadingState clears only the selected chapter progress',
    () async {
      final repository = _FakeComicRepository();
      final stateRepository = _RecordingChapterResetStateRepository();
      final adapter = ComicDetailAdapter(
        repository,
        stateRepository: stateRepository,
      );

      await adapter.resetChapterReadingState(
        workId: 'comic:1',
        episodeId: 'comic:1:120',
      );

      expect(stateRepository.lastEpisodeId, 'comic:1:120');
      expect(stateRepository.lastIsRead, isFalse);
      expect(stateRepository.lastReadAt, isNull);
      expect(repository.clearedProgress, const <String>['comic:1:120']);
    },
  );

  test(
    'markChaptersReadThrough follows comic tid order and includes the target',
    () async {
      final stateRepository = _RecordingRangeStateRepository();
      final adapter = ComicDetailAdapter(
        _FakeComicRepository(),
        stateRepository: stateRepository,
      );

      final outcome = await adapter.markChaptersReadThrough(
        workId: 'comic:1',
        targetEpisodeId: 'comic:1:120',
      );

      expect(stateRepository.lastEpisodeIds, <String>{
        'comic:1:90',
        'comic:1:120',
      });
      expect(stateRepository.lastWorkId, 'comic:1');
      expect(outcome?.changedEpisodeIds, <String>['comic:1:90', 'comic:1:120']);

      await adapter.restoreChaptersRead(
        workId: 'comic:1',
        episodeIds: outcome!.changedEpisodeIds,
        readAt: outcome.readAt,
      );
      expect(stateRepository.restoreCalls.single, <String>{
        'comic:1:90',
        'comic:1:120',
      });
    },
  );

  test('markChaptersReadThrough returns null for a removed target', () async {
    final stateRepository = _RecordingRangeStateRepository();
    final adapter = ComicDetailAdapter(
      _FakeComicRepository(),
      stateRepository: stateRepository,
    );

    final outcome = await adapter.markChaptersReadThrough(
      workId: 'comic:1',
      targetEpisodeId: 'comic:1:removed',
    );

    expect(outcome, isNull);
    expect(stateRepository.lastEpisodeIds, isEmpty);
  });

  test(
    'resetWorkReadingState delegates to the comic reset capability',
    () async {
      final repository = _FakeComicRepository();
      final adapter = ComicDetailAdapter(
        repository,
        stateRepository: _FakeLibraryStateRepository(),
      );

      await adapter.resetWorkReadingState(workId: 'comic:1');

      expect(repository.resetComicIds, const <String>['comic:1']);
    },
  );
}
