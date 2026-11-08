import 'package:content_title_core/content_title_core.dart';
import 'package:test/test.dart';

import 'fixtures/comic_title_fixtures.dart';
import 'fixtures/novel_title_fixtures.dart';

void main() {
  for (final sample in [
    ...comicChapterSearchMarkers,
    ...novelChapterSearchMarkers,
  ]) {
    test('chapter marker ${sample.text}', () {
      final marker = sample.query
          ? ChapterSearchMarker.fromQuery(sample.text)
          : ChapterSearchMarker.fromTitle(sample.text);
      expect(marker?.number, sample.number);
      expect(marker?.segment, sample.segment);
    });
  }
}
