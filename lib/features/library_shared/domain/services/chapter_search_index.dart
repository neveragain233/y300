import 'package:content_title_core/content_title_core.dart';

/// 一条可检索的本地目录投影；值仍由各模块持有。
class ChapterSearchEntry<T> {
  const ChapterSearchEntry({
    required this.id,
    required this.title,
    required this.value,
    this.aliases = const [],
    this.metadata = const [],
  });

  final String id;
  final String title;
  final T value;
  final List<String> aliases;
  final List<String> metadata;

  List<String> get texts => [title, ...aliases, ...metadata];
}

/// 只检索调用方给出的可见索引，精确章号优先，其他匹配保持原有顺序。
class ChapterSearchIndex {
  const ChapterSearchIndex();

  List<ChapterSearchEntry<T>> search<T>(
    List<ChapterSearchEntry<T>> entries,
    String query, {
    Map<String, List<String>> normalizedTexts = const {},
    String? normalizedQuery,
  }) {
    final keyword = ChapterSearchMarker.normalize(query);
    if (keyword.isEmpty) return entries;
    final converted = ChapterSearchMarker.normalize(normalizedQuery ?? query);
    final requested = ChapterSearchMarker.fromQuery(keyword);
    final exact = <(ChapterSearchEntry<T>, int, int)>[];
    final other = <ChapterSearchEntry<T>>[];
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final titles = [entry.title, ...entry.aliases];
      ChapterSearchMarker? matched;
      if (requested != null) {
        for (final title in titles) {
          final marker = ChapterSearchMarker.fromTitle(title);
          if (marker?.number == requested.number &&
              (requested.segment == null ||
                  marker?.segment == requested.segment)) {
            matched = marker;
            break;
          }
        }
      }
      if (matched != null) {
        exact.add((entry, matched.segment ?? 0, index));
      } else if (entry.texts.any(
            (text) => ChapterSearchMarker.normalize(text).contains(keyword),
          ) ||
          (normalizedTexts[entry.id] ?? const []).any(
            (text) => ChapterSearchMarker.normalize(text).contains(converted),
          )) {
        other.add(entry);
      }
    }
    exact.sort((a, b) {
      final segment = a.$2.compareTo(b.$2);
      return segment == 0 ? a.$3.compareTo(b.$3) : segment;
    });
    return [for (final match in exact) match.$1, ...other];
  }
}
