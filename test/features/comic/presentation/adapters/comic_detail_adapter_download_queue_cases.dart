part of 'comic_detail_adapter_test.dart';

void _downloadQueueCases() {
  test('downloadAll delegates to BulkDownloadUseCase when injected', () async {
    final bulkDownloadUseCase = _RecordingBulkDownloadUseCase();
    final adapter = ComicDetailAdapter(
      _FakeComicRepository(),
      bulkDownloadUseCase: bulkDownloadUseCase,
      stateRepository: _FakeLibraryStateRepository(),
    );

    await adapter.downloadAll(workId: 'comic:1');

    expect(bulkDownloadUseCase.requestedComicIds, <Set<String>>[
      <String>{'comic:1'},
    ]);
  });

  test('downloadUnread only enqueues unread episodes', () async {
    final stateRepository = _RecordingLibraryStateRepository(
      episodeStates: <String, LibraryEpisodeState>{
        'comic:1:120': const LibraryEpisodeState(
          moduleKey: LibraryModuleKey.comic,
          episodeId: 'comic:1:120',
          workId: 'comic:1',
          isRead: true,
        ),
      },
    );
    final queue = _RecordingComicDownloadQueue();
    final adapter = ComicDetailAdapter(
      _FakeComicRepository(),
      stateRepository: stateRepository,
      downloadQueue: queue,
    );

    await adapter.downloadUnread(workId: 'comic:1');

    expect(queue.targets.map((target) => target.episodeId), <String>[
      'comic:1:90',
    ]);
    expect(stateRepository.downloadedEpisodeIds, isEmpty);
  });

  test('single chapter download only enqueues the selected episode', () async {
    final stateRepository = _RecordingLibraryStateRepository();
    final queue = _RecordingComicDownloadQueue();
    final adapter = ComicDetailAdapter(
      _FakeComicRepository(),
      stateRepository: stateRepository,
      downloadQueue: queue,
    );

    await adapter.markChapterDownloaded(
      workId: 'comic:1',
      episodeId: 'comic:1:120',
      isDownloaded: true,
    );

    expect(queue.targets, hasLength(1));
    expect(queue.targets.single.comicId, 'comic:1');
    expect(queue.targets.single.episodeId, 'comic:1:120');
    expect(queue.targets.single.comicTitle, 'Test Comic');
    expect(queue.targets.single.episodeTitle, '后续');
    expect(stateRepository.downloadedEpisodeIds, isEmpty);
  });

  test('chapter download activity follows active queue statuses', () {
    final queue = _RecordingComicDownloadQueue();
    final adapter = ComicDetailAdapter(
      _FakeComicRepository(),
      stateRepository: _FakeLibraryStateRepository(),
      downloadQueue: queue,
    );

    queue.setStatus(ComicDownloadQueueStatus.pending);
    expect(
      adapter.isChapterDownloadActive(
        workId: 'comic:1',
        episodeId: 'comic:1:120',
      ),
      isTrue,
    );

    queue.setStatus(ComicDownloadQueueStatus.failed);
    expect(
      adapter.isChapterDownloadActive(
        workId: 'comic:1',
        episodeId: 'comic:1:120',
      ),
      isFalse,
    );
  });
}
