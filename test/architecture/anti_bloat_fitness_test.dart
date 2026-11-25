import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const int _maxAllowedLines = 1500;

/// Ratchet for existing large files in `lib/` (excluding `lib/l10n/`).
///
/// Counts may stay flat or shrink; any net line growth fails the check so new
/// logic is extracted into cohesive helpers instead of inflating mega-files.
const Map<String, int> _existingGiantFileRatchet = <String, int>{
  'lib/features/reader_shared/presentation/engine/image_reader_engine.dart':
      3866,
  'lib/features/novel/presentation/novel_reader_page.dart': 3498,
  'lib/features/novel/presentation/widgets/novel_reader_html_paged_surface.dart':
      2905,
  'lib/features/library_shared/presentation/pages/unified_shelf_page.dart':
      2532,
  'lib/features/thread/presentation/widgets/thread_detail_widgets.dart': 2274,
  'lib/features/library_shared/presentation/pages/unified_detail_page.dart':
      2251,
  'lib/features/composer_shared/presentation/widgets/composer_quill_prototype_editor.dart':
      2178,
  'lib/features/thread/presentation/thread_detail_page.dart': 2095,
  'lib/features/novel/presentation/controllers/novel_reader_controller.dart':
      2050,
  'lib/features/comic/presentation/controllers/comic_reader_controller.dart':
      1818,
  'lib/features/forum/presentation/widgets/forum_display_widgets.dart': 1805,
  'lib/features/comic/data/local/comic_duplicate_merge_store.dart': 1659,
  'lib/features/profile/presentation/profile_blog_page.dart': 1537,
};

const List<String> _personalFeatureRoots = <String>[
  'lib/features/content_filter',
  'lib/features/blacklist',
  'lib/features/recent_search',
  'lib/features/fonts',
];

/// Frozen single-implementation abstract interface debt in personal modules.
const Set<String> _allowedPersonalInterfaceDebt = <String>{
  'FontLibraryRepository',
  'FontLibraryStorageUsage',
  'FontWeightPreferenceRepository',
  'FontImportPicker',
  'FontRuntimeLoader',
};

final RegExp _abstractInterfaceDecl = RegExp(
  r'^\s*abstract\s+(?:interface\s+|base\s+)?class\s+([A-Za-z_]\w*)\b',
  multiLine: true,
);

void main() {
  test('personal-branch feature modules do not add single-implementation abstract interfaces', () {
    final libSources = _readDartSources('lib');
    final violations = <String>[];

    for (final root in _personalFeatureRoots) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entry in dir.listSync(recursive: true, followLinks: false)) {
        if (entry is! File || !entry.path.endsWith('.dart')) continue;
        final source = entry.readAsStringSync(encoding: utf8);
        for (final match in _abstractInterfaceDecl.allMatches(source)) {
          final name = match.group(1)!;
          if (_allowedPersonalInterfaceDebt.contains(name)) continue;
          final implPattern = RegExp(
            r'\b(?:implements|extends)\s+[^\{;]*\b'
            '${RegExp.escape(name)}'
            r'\b',
          );
          var concreteCount = 0;
          for (final libContent in libSources.values) {
            concreteCount += implPattern.allMatches(libContent).length;
          }
          if (concreteCount < 2) {
            violations.add(
              '${entry.path}: $name has $concreteCount production '
              'implementation(s). Use a concrete class directly unless '
              'there are 2+ production implementations.',
            );
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('production files in lib/ do not exceed 1500 lines or their ratchet ceiling', () {
    final violations = <String>[];
    for (final entry in _readDartSources('lib').entries) {
      final path = entry.key;
      if (path.startsWith('lib/l10n/')) continue;
      final lines =
          '\n'.allMatches(entry.value).length +
          (entry.value.endsWith('\n') ? 0 : 1);
      final ceiling = _existingGiantFileRatchet[path] ?? _maxAllowedLines;
      if (lines > ceiling) {
        violations.add(
          '$path: $lines lines exceeds ceiling $ceiling. Extract cohesive '
          'helpers instead of growing large files.',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

Map<String, String> _readDartSources(String root) {
  final result = <String, String>{};
  for (final entity in Directory(
    root,
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final normalized = entity.path.replaceAll('\\', '/');
      result[normalized] = entity.readAsStringSync(encoding: utf8);
    }
  }
  return result;
}
