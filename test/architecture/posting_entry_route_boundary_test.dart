import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 发帖页是覆盖主壳底栏的整页编辑任务，论坛入口必须走统一的详情路由助手；
/// 直接构造页面会把编辑器放回来源栈，主壳底栏遮住编辑器底部工具栏。
const _forumPostingEntryPoints = <String>[
  'lib/features/forum/presentation/forum_display_page.dart',
  'lib/features/forum/presentation/webview/forum_webview_page.dart',
];

void main() {
  test('forum posting entries use the shared detail-host composer route', () {
    for (final path in _forumPostingEntryPoints) {
      final source = File(path).readAsStringSync();
      expect(source, contains('openPostingComposer('), reason: path);
      expect(source, isNot(contains('PostingComposerPage(')), reason: path);
      expect(source, isNot(contains('PostingComposerArgs(')), reason: path);
    }
  });
}
