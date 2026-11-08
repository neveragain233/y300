import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/domain/services/chapter_search_index.dart';
import 'package:y300/features/library_shared/presentation/controllers/chapter_search_controller.dart';

void main() {
  ChapterSearchEntry<String> entry(String id, String title, {String? value}) =>
      ChapterSearchEntry(id: id, title: title, value: value ?? id);

  test(
    'late query and index conversions cannot restore retired matches',
    () async {
      final calls = <Completer<List<String>>>[];
      final controller = ChapterSearchController<String>(
        normalizeTexts: (_) {
          final result = Completer<List<String>>();
          calls.add(result);
          return result.future;
        },
      );
      addTearDown(controller.dispose);
      controller.updateEntries([entry('old', '旧目录')]);
      controller.setQuery('旧输入');
      controller.updateEntries([entry('new', '新目录')]);
      controller.setQuery('新输入');
      calls[2].complete(['规范新词']);
      calls[3].complete(['规范新词']);
      await Future<void>.delayed(Duration.zero);
      expect(controller.results.single.id, 'new');
      calls[0].complete(['规范旧词']);
      calls[1].complete(['规范旧词']);
      await Future<void>.delayed(Duration.zero);
      expect(controller.results.single.id, 'new');
      controller.setQuery('');
      expect(controller.results.single.id, 'new');
    },
  );

  test('same text reuses conversion but row values stay current', () async {
    var calls = 0;
    final controller = ChapterSearchController<String>(
      normalizeTexts: (texts) async {
        calls++;
        return texts;
      },
    );
    controller.updateEntries([entry('one', '标题', value: 'before')]);
    await Future<void>.delayed(Duration.zero);
    controller.updateEntries([entry('one', '标题', value: 'after')]);
    expect(calls, 1);
    expect(controller.results.single.value, 'after');
    controller.dispose();
  });

  test('disposing rejects in-flight conversion notifications', () async {
    final pending = Completer<List<String>>();
    final controller = ChapterSearchController<String>(
      normalizeTexts: (_) => pending.future,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.updateEntries([entry('one', '标题')]);
    controller.dispose();
    pending.complete(['标题']);
    await Future<void>.delayed(Duration.zero);
    expect(notifications, 0);
  });
}
