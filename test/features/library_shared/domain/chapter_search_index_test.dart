import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/domain/services/chapter_search_index.dart';

void main() {
  const index = ChapterSearchIndex();
  ChapterSearchEntry<String> entry(
    String id,
    String title, {
    List<String> aliases = const [],
    List<String> metadata = const [],
  }) => ChapterSearchEntry(
    id: id,
    title: title,
    value: id,
    aliases: aliases,
    metadata: metadata,
  );

  test('exact chapter matches precede substrings and order segments without changing source', () {
    final entries = [
      entry('other', '第137话'),
      entry('second', '第37话②'),
      entry('first', '第37话①'),
      entry('extra', '番外37'),
    ];
    expect(index.search(entries, '37').map((item) => item.id), [
      'first',
      'second',
      'other',
      'extra',
    ]);
    expect(index.search(entries, '37②').map((item) => item.id), ['second']);
    expect(entries.first.id, 'other');
    expect(index.search(entries, '').map((item) => item.id), [
      'other',
      'second',
      'first',
      'extra',
    ]);
  });

  test('custom display names retain searchable source names and metadata', () {
    final entries = [
      entry('one', '新名字', aliases: ['第七章 原名'], metadata: ['5002']),
    ];
    expect(index.search(entries, '7').single.title, '新名字');
    expect(index.search(entries, '原名').single.id, 'one');
    expect(index.search(entries, '5002').single.id, 'one');
    expect(index.search(entries, '不存在'), isEmpty);
  });

  test('converted text participates without changing display or supplying excluded entries', () {
    final entries = [entry('one', '特別篇')];
    final result = index.search(
      entries,
      '特别',
      normalizedTexts: {
        'one': ['特别篇'],
        'hidden': ['特别篇'],
      },
      normalizedQuery: '特别',
    );
    expect(result.single.title, '特別篇');
    expect(result.single.id, 'one');
  });
}
