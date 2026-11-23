import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/comic/data/providers/comic_providers.dart';
import 'package:y300/features/comic/domain/services/comic_episode_sequence.dart';
import 'package:y300/features/comic/presentation/comic_reader_page.dart';
import 'package:y300/features/novel/data/providers/novel_providers.dart';
import 'package:y300/features/novel/domain/models/novel_episode_open_policy.dart';
import 'package:y300/features/novel/presentation/novel_reader_page.dart';
import 'package:y300/features/reader_shared/application/active_reader_session.dart';

final readerRestorePageProvider =
    Provider<Future<Widget?> Function(ActiveReaderTarget)>((ref) {
      return (target) async {
        switch (target.module) {
          case ActiveReaderModule.comic:
            final episodes = await ref
                .read(comicRepositoryProvider)
                .getComicEpisodes(comicId: target.workId);
            if (!episodes.any((e) => e.episodeId == target.episodeId)) {
              return null;
            }
            return ComicReaderPage(
              comicId: target.workId,
              episodeId: target.episodeId,
              openPolicy: ComicEpisodeOpenPolicy.restoreSavedPosition,
            );
          case ActiveReaderModule.novel:
            final episodes = await ref
                .read(novelRepositoryProvider)
                .getEpisodes(novelId: target.workId);
            if (!episodes.any((e) => e.episodeId == target.episodeId)) {
              return null;
            }
            return NovelReaderPage(
              novelId: target.workId,
              initialEpisodeId: target.episodeId,
              openPolicy: NovelEpisodeOpenPolicy.restoreLastPosition,
            );
        }
      };
    });
