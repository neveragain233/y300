import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/comic/domain/services/comic_episode_sequence.dart';
import 'package:y300/features/comic/presentation/comic_reader_capability.dart';
import 'package:y300/features/comic/presentation/controllers/comic_reader_controller.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';
import 'package:y300/l10n/app_localizations.dart';

void main() {
  test(
    'comic capability fixes the paged canvas and enables thumbnails',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      final capability = ComicReaderCapability(
        viewState: _viewState(),
        preferences: ReaderPreferences.defaults(),
        imageReferer: null,
        controller: ComicReaderController(
          const ComicReaderArgs(comicId: 'comic', episodeId: 'episode'),
        ),
        l10n: l10n,
        moreMenu: const [],
        onShowChapterList: () {},
        onOpenSourceThread: () {},
        onToggleBookmark: () {},
        onOpenAdjacentEpisode: ({required ComicEpisodeDirection direction}) {},
        buildNextChapterTransition: (context) => const SizedBox.shrink(),
        exitResult: null,
      );

      expect(capability.pagedCanvasColor, Colors.black);
      expect(
        capability.pagedBackgroundSettingsNote,
        l10n.readerPagedBackgroundBlackNote,
      );
      expect(capability.showsThumbnailStrip, isTrue);
    },
  );
}

ComicReaderViewState _viewState() {
  return const ComicReaderViewState(
    comicId: 'comic',
    episodeId: 'episode',
    comicTitle: 'work',
    episodeTitle: 'chapter',
    sourceTid: '',
    images: <ComicReaderImageState>[
      ComicReaderImageState(
        imageUrl: 'https://img.test/0.jpg',
        imageIndex: 0,
        cacheStatus: 'pending',
      ),
      ComicReaderImageState(
        imageUrl: 'https://img.test/1.jpg',
        imageIndex: 1,
        cacheStatus: 'pending',
      ),
    ],
    chapters: [
      ComicReaderChapterEntry(
        episodeId: 'episode',
        title: 'chapter',
        orderIndex: 0,
        sourceTid: '',
        isCurrent: true,
        isRead: false,
      ),
    ],
    currentImageIndex: 0,
    lastScrollOffset: 0,
    hasPreviousEpisode: false,
    hasNextEpisode: false,
  );
}
