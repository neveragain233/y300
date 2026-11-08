import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:y300/features/library_shared/domain/services/chapter_search_index.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/opencc_text_converter.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/plain_text_batch_conversion_service.dart';
import 'package:y300/features/reader_shared/domain/rich_text/text_conversion/text_conversion_mode.dart';

typedef ChapterSearchTextNormalizer = Future<List<String>> Function(
  List<String>,
);

/// 管理目录转换与输入代次，迟到的简繁转换不覆盖新查询或新目录。
class ChapterSearchController<T> extends ChangeNotifier {
  ChapterSearchController({ChapterSearchTextNormalizer? normalizeTexts})
    : _normalizeTexts = normalizeTexts ?? _defaultNormalizer();

  final ChapterSearchTextNormalizer _normalizeTexts;
  List<ChapterSearchEntry<T>> _entries = [];
  Map<String, List<String>> _normalizedTexts = {};
  List<String> _textIdentity = [];
  String _query = '';
  String? _normalizedQuery;
  int _entriesRevision = 0;
  int _queryRevision = 0;
  bool _disposed = false;

  String get query => _query;
  List<ChapterSearchEntry<T>> get results => const ChapterSearchIndex().search(
    _entries,
    _query,
    normalizedTexts: _normalizedTexts,
    normalizedQuery: _normalizedQuery,
  );

  void updateEntries(List<ChapterSearchEntry<T>> entries) {
    _entries = List.unmodifiable(entries);
    final identity = [
      for (final entry in entries) ...[entry.id, ...entry.texts, '\u0000'],
    ];
    if (listEquals(identity, _textIdentity)) return;
    _textIdentity = identity;
    _normalizedTexts = {};
    final revision = ++_entriesRevision;
    unawaited(_convertEntries(entries, revision));
  }

  Future<void> _convertEntries(
    List<ChapterSearchEntry<T>> entries,
    int revision,
  ) async {
    final texts = [for (final entry in entries) ...entry.texts];
    final converted = await _normalizeTexts(texts);
    if (_disposed ||
        revision != _entriesRevision ||
        converted.length != texts.length) {
      return;
    }
    var offset = 0;
    _normalizedTexts = {
      for (final entry in entries)
        entry.id: converted.sublist(offset, offset += entry.texts.length),
    };
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value.trim();
    _normalizedQuery = null;
    final revision = ++_queryRevision;
    notifyListeners();
    if (_query.isNotEmpty) unawaited(_convertQuery(_query, revision));
  }

  Future<void> _convertQuery(String query, int revision) async {
    final converted = await _normalizeTexts([query]);
    if (_disposed || revision != _queryRevision || converted.length != 1) {
      return;
    }
    _normalizedQuery = converted.single;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _entriesRevision++;
    _queryRevision++;
    super.dispose();
  }

  static ChapterSearchTextNormalizer _defaultNormalizer() {
    final service = DefaultPlainTextBatchConversionService();
    return (texts) async {
      try {
        return await service.convertAll(
          sources: texts,
          converter: const OpenccTextConverter(
            mode: TextConversionMode.toSimplified,
          ),
        );
      } on MissingPluginException {
        return texts;
      } on PlatformException {
        return texts;
      }
    };
  }
}
