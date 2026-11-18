part of 'local_comic_repository_test.dart';

void _episodeImageCases() {
  test(
    'saveEpisodeImages promotes smallest tid first image as initial cover',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:700',
        tid: '700',
        fid: '30',
        title: '测试漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-701-1-1.html',
              rawText: '后话',
              episodeTitle: '后话',
            ),
            ComicEpisodeLink(
              url: 'thread-699-1-1.html',
              rawText: '首话',
              episodeTitle: '首话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );

      await repository.saveEpisodeImages(
        episodeId: 'yamibo:700:701',
        imageUrls: const <String>['https://img.test/701-1.jpg'],
      );
      var detail = await repository.getComicDetail(comicId: 'yamibo:700');
      expect(detail?.coverImageUrl, isNull);

      await repository.saveEpisodeImages(
        episodeId: 'yamibo:700:699',
        imageUrls: const <String>['https://img.test/699-1.jpg'],
      );
      detail = await repository.getComicDetail(comicId: 'yamibo:700');

      expect(detail?.coverImageUrl, 'https://img.test/699-1.jpg');
    },
  );

  test(
    'saveEpisodeImages corrects parsed first-floor cover to smallest tid image',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:701',
        tid: '701',
        fid: '30',
        title: '测试漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>['https://img.test/first-floor.jpg'],
          episodeLinks: <ComicEpisodeLink>[
            ComicEpisodeLink(
              url: 'thread-702-1-1.html',
              rawText: '后话',
              episodeTitle: '后话',
            ),
            ComicEpisodeLink(
              url: 'thread-700-1-1.html',
              rawText: '首话',
              episodeTitle: '首话',
            ),
          ],
          plainTextSummary: '摘要',
        ),
      );

      await repository.saveEpisodeImages(
        episodeId: 'yamibo:701:700',
        imageUrls: const <String>['https://img.test/700-1.jpg'],
      );

      final detail = await repository.getComicDetail(comicId: 'yamibo:701');
      expect(detail?.coverImageUrl, 'https://img.test/700-1.jpg');
    },
  );

  test('mergeEpisodesFromLinks extracts tid from viewthread links and keeps unique episodes', () async {
    await repository.addToShelf(
      comicId: 'yamibo:300',
      tid: '300',
      fid: '30',
      title: '测试漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>[],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
      ),
    );

    await repository.mergeEpisodesFromLinks(
      comicId: 'yamibo:300',
      fallbackSourceTid: '300',
      episodeLinks: const <ComicEpisodeLink>[
        ComicEpisodeLink(
          url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=530646&highlight=a',
          rawText: '01',
          episodeTitle: '01',
        ),
        ComicEpisodeLink(
          url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=533029&highlight=a',
          rawText: '02',
          episodeTitle: '02',
        ),
        ComicEpisodeLink(
          url: 'https://bbs.yamibo.com/forum.php?mod=viewthread&tid=533956&highlight=a',
          rawText: '03',
          episodeTitle: '03',
        ),
      ],
    );

    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:300',
      descending: false,
    );

    expect(episodes.length, 3);
    expect(episodes.map((e) => e.sourceTid).toList(), <String>[
      '530646',
      '533029',
      '533956',
    ]);
  });

  test('detail order uses reverse of message order when reading with descending=true', () async {
    await repository.addToShelf(
      comicId: 'yamibo:400',
      tid: '400',
      fid: '30',
      title: '测试漫画',
      parsedPost: const ParsedComicPost(
        imageUrls: <String>[],
        episodeLinks: <ComicEpisodeLink>[],
        plainTextSummary: '摘要',
      ),
    );

    await repository.mergeEpisodesFromLinks(
      comicId: 'yamibo:400',
      fallbackSourceTid: '400',
      episodeLinks: const <ComicEpisodeLink>[
        ComicEpisodeLink(
          url: 'thread-4001-1-1.html',
          rawText: '01',
          episodeTitle: '01',
        ),
        ComicEpisodeLink(
          url: 'thread-4002-1-1.html',
          rawText: '02',
          episodeTitle: '02',
        ),
        ComicEpisodeLink(
          url: 'thread-4003-1-1.html',
          rawText: '特典',
          episodeTitle: '特典',
        ),
        ComicEpisodeLink(
          url: 'thread-4004-1-1.html',
          rawText: '03',
          episodeTitle: '03',
        ),
      ],
    );

    final episodes = await repository.getComicEpisodes(
      comicId: 'yamibo:400',
      descending: true,
    );

    expect(episodes.map((e) => e.episodeTitle).toList(), <String?>[
      '03',
      '特典',
      '02',
      '01',
    ]);
  });

  test(
    'detail descending order keeps specials interleaved by message order',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:500',
        tid: '500',
        fid: '30',
        title: '测试漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[],
          plainTextSummary: '摘要',
        ),
      );

      await repository.mergeEpisodesFromLinks(
        comicId: 'yamibo:500',
        fallbackSourceTid: '500',
        episodeLinks: const <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-5001-1-1.html',
            rawText: '09',
            episodeTitle: '09',
          ),
          ComicEpisodeLink(
            url: 'thread-5002-1-1.html',
            rawText: '第一卷特典',
            episodeTitle: '第一卷特典',
          ),
          ComicEpisodeLink(
            url: 'thread-5003-1-1.html',
            rawText: '10',
            episodeTitle: '10',
          ),
          ComicEpisodeLink(
            url: 'thread-5004-1-1.html',
            rawText: '11',
            episodeTitle: '11',
          ),
          ComicEpisodeLink(
            url: 'thread-5005-1-1.html',
            rawText: '第二卷特典',
            episodeTitle: '第二卷特典',
          ),
          ComicEpisodeLink(
            url: 'thread-5006-1-1.html',
            rawText: '12',
            episodeTitle: '12',
          ),
        ],
      );

      final episodes = await repository.getComicEpisodes(
        comicId: 'yamibo:500',
        descending: true,
      );

      expect(episodes.map((e) => e.episodeTitle).toList(), <String?>[
        '12',
        '第二卷特典',
        '11',
        '10',
        '第一卷特典',
        '09',
      ]);
    },
  );

  test(
    'mergeEpisodesFromLinks normalizes long subject to parsed episode label',
    () async {
      await repository.addToShelf(
        comicId: 'yamibo:600',
        tid: '600',
        fid: '30',
        title: '测试漫画',
        parsedPost: const ParsedComicPost(
          imageUrls: <String>[],
          episodeLinks: <ComicEpisodeLink>[],
          plainTextSummary: '摘要',
        ),
      );

      await repository.mergeEpisodesFromLinks(
        comicId: 'yamibo:600',
        fallbackSourceTid: '600',
        episodeLinks: const <ComicEpisodeLink>[
          ComicEpisodeLink(
            url: 'thread-558227-1-1.html',
            rawText: '【萌木汉化组】[ななつ藤][貴女へささげるサディスティック]献予你的支配之礼 第1.1话',
            episodeTitle: '【萌木汉化组】[ななつ藤][貴女へささげるサディスティック]献予你的支配之礼 第1.1话',
          ),
        ],
      );

      final episodes = await repository.getComicEpisodes(
        comicId: 'yamibo:600',
        descending: false,
      );
      expect(episodes.length, 1);
      expect(episodes.first.episodeTitle, '第1.1话');
    },
  );
}
