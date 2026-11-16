import 'package:y300/features/novel/data/models/novel_models.dart';

enum NovelReaderPreferenceImpact {
  none,
  repaintOnly,
  relayout,
  flowModeSwitch,

  /// The source document must be re-parsed/re-built (e.g. traditional/
  /// simplified conversion changed). Most expensive impact.
  contentRebuild,
}

class NovelReaderPreferenceDiff {
  const NovelReaderPreferenceDiff({
    required this.previous,
    required this.next,
    required this.impacts,
  });

  final NovelReaderPreferences previous;
  final NovelReaderPreferences next;
  final Set<NovelReaderPreferenceImpact> impacts;

  bool get hasChanges => previous != next;
}

abstract interface class NovelReaderPreferenceImpactAnalyzer {
  NovelReaderPreferenceDiff compare(
    NovelReaderPreferences previous,
    NovelReaderPreferences next,
  );
}

class DefaultNovelReaderPreferenceImpactAnalyzer
    implements NovelReaderPreferenceImpactAnalyzer {
  const DefaultNovelReaderPreferenceImpactAnalyzer();

  @override
  NovelReaderPreferenceDiff compare(
    NovelReaderPreferences previous,
    NovelReaderPreferences next,
  ) {
    if (previous == next) {
      return NovelReaderPreferenceDiff(
        previous: previous,
        next: next,
        impacts: const <NovelReaderPreferenceImpact>{
          NovelReaderPreferenceImpact.none,
        },
      );
    }

    final impacts = <NovelReaderPreferenceImpact>{};
    if (previous.conversionMode != next.conversionMode) {
      impacts.add(NovelReaderPreferenceImpact.contentRebuild);
    }
    if (previous.flowMode != next.flowMode) {
      impacts.add(NovelReaderPreferenceImpact.flowModeSwitch);
    }
    if (previous.themePreset != next.themePreset ||
        previous.pageEffect != next.pageEffect ||
        previous.pageSpeed != next.pageSpeed ||
        previous.showProgressIndicator != next.showProgressIndicator ||
        previous.bodyBrightness != next.bodyBrightness ||
        previous.backgroundTexture != next.backgroundTexture) {
      impacts.add(NovelReaderPreferenceImpact.repaintOnly);
    }
    if (previous.bodyColorMode != next.bodyColorMode) {
      // Body color ownership rewrites prepared HTML, not just paint.
      impacts.add(NovelReaderPreferenceImpact.contentRebuild);
    }
    if (previous.fontSize != next.fontSize ||
        previous.lineHeight != next.lineHeight ||
        previous.paragraphSpacing != next.paragraphSpacing ||
        previous.pagePadding != next.pagePadding ||
        previous.fontFamily != next.fontFamily ||
        previous.contentMaxWidth != next.contentMaxWidth ||
        previous.paragraphIndent != next.paragraphIndent ||
        previous.fontWeight != next.fontWeight ||
        previous.textAlign != next.textAlign ||
        previous.safeAreaEnabled != next.safeAreaEnabled) {
      impacts.add(NovelReaderPreferenceImpact.relayout);
    }
    if (impacts.isEmpty) {
      impacts.add(NovelReaderPreferenceImpact.none);
    }
    return NovelReaderPreferenceDiff(
      previous: previous,
      next: next,
      impacts: impacts,
    );
  }
}
