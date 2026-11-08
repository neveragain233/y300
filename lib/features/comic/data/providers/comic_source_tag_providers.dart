import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/comic/data/providers/comic_providers.dart';
import 'package:y300/features/comic/domain/services/comic_source_tag_reader.dart';
import 'package:y300/features/thread/data/providers/thread_repository_providers.dart';

final comicSourceTagReaderProvider = Provider<ComicSourceTagReader>((ref) {
  return DefaultComicSourceTagReader(
    repository: ref.watch(comicRepositoryProvider),
    threadRepository: ref.watch(threadRepositoryProvider),
  );
});
