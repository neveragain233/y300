import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/storage/data/app_data_backup_service.dart';
import 'package:y300/features/storage/domain/app_data_backup.dart';

final class _FakeBackupSection implements AppDataBackupSection {
  _FakeBackupSection({required this.sectionId, List<String>? initialItems})
    : items = List<String>.from(initialItems ?? const <String>[]);

  @override
  final String sectionId;

  @override
  int get sectionVersion => 1;

  final List<String> items;
  AppDataBackupImportMode? lastMode;

  @override
  Future<Map<String, Object?>> exportPayload() async {
    return <String, Object?>{'items': List<String>.from(items)};
  }

  @override
  AppDataBackupSectionPreview inspectPayload(Map<String, Object?> payload) {
    final rawItems = payload['items'];
    final count = rawItems is List ? rawItems.length : 0;
    return AppDataBackupSectionPreview(sectionId: sectionId, itemCount: count);
  }

  @override
  Future<AppDataBackupSectionReport> importPayload(
    Map<String, Object?> payload, {
    required AppDataBackupImportMode mode,
  }) async {
    lastMode = mode;
    final rawItems = payload['items'];
    final incoming = rawItems is List
        ? rawItems.whereType<String>().toList()
        : const <String>[];
    if (mode == AppDataBackupImportMode.replace) {
      items
        ..clear()
        ..addAll(incoming);
      return AppDataBackupSectionReport(
        sectionId: sectionId,
        importedCount: incoming.length,
        skippedCount: 0,
        replaced: true,
      );
    }
    var imported = 0;
    var skipped = 0;
    for (final entry in incoming) {
      if (items.contains(entry)) {
        skipped++;
      } else {
        items.add(entry);
        imported++;
      }
    }
    return AppDataBackupSectionReport(
      sectionId: sectionId,
      importedCount: imported,
      skippedCount: skipped,
      replaced: false,
    );
  }
}

void main() {
  group('AppDataBackupService', () {
    test('exports envelope and imports in merge and replace modes', () async {
      final sectionA = _FakeBackupSection(
        sectionId: 'alpha',
        initialItems: <String>['a1', 'a2'],
      );
      final sectionB = _FakeBackupSection(
        sectionId: 'beta',
        initialItems: <String>['b1'],
      );
      Uint8List? savedBytes;
      final service = AppDataBackupService(
        sections: <AppDataBackupSection>[sectionA, sectionB],
        clock: () => DateTime.utc(2026, 11, 25, 10, 0),
        saveJsonFile: ({required fileName, required bytes, dialogTitle}) async {
          savedBytes = bytes;
          return Uri.parse('file:///tmp/$fileName');
        },
        pickJsonFile: () async => utf8.decode(savedBytes!),
      );

      final uri = await service.exportToFile(
        fileName: 'backup.json',
        sectionIds: const <String>{'alpha'},
      );
      expect(uri, isNotNull);

      final raw = await service.pickJsonFromFile();
      expect(raw, isNotNull);

      final preview = service.inspectJson(raw!);
      expect(preview.formatVersion, AppDataBackupEnvelopeCodec.formatVersion);
      expect(preview.totalItems, 2);
      expect(preview.sections.single.sectionId, 'alpha');

      // Mutate local state and test merge vs replace.
      sectionA.items
        ..clear()
        ..addAll(<String>['a2', 'a3']);

      final mergeResult = await service.importJson(
        raw,
        mode: AppDataBackupImportMode.merge,
      );
      expect(mergeResult.totalImported, 1);
      expect(mergeResult.totalSkipped, 1);
      expect(sectionA.items, <String>['a2', 'a3', 'a1']);

      final replaceResult = await service.importJson(
        raw,
        mode: AppDataBackupImportMode.replace,
      );
      expect(replaceResult.totalImported, 2);
      expect(replaceResult.totalSkipped, 0);
      expect(sectionA.items, <String>['a1', 'a2']);
      expect(sectionB.items, <String>['b1']);
    });

    test('preserves unknown sections as unknownSectionIds', () async {
      final known = _FakeBackupSection(
        sectionId: 'known',
        initialItems: <String>['k1'],
      );
      final service = AppDataBackupService(
        sections: <AppDataBackupSection>[known],
      );
      final payload = jsonEncode(<String, Object?>{
        'formatVersion': 1,
        'exportedAt': DateTime.utc(2026, 11, 25).millisecondsSinceEpoch,
        'sections': <String, Object?>{
          'known': <String, Object?>{
            'version': 1,
            'data': <String, Object?>{
              'items': <String>['k2'],
            },
          },
          'future_feature': <String, Object?>{
            'version': 1,
            'data': <String, Object?>{
              'items': <String>['x1'],
            },
          },
        },
      });

      final preview = service.inspectJson(payload);
      expect(preview.totalItems, 1);
      expect(preview.unknownSectionIds, <String>['future_feature']);

      final result = await service.importJson(
        payload,
        mode: AppDataBackupImportMode.merge,
      );
      expect(result.totalImported, 1);
      expect(result.unknownSectionIds, <String>['future_feature']);
      expect(known.items, <String>['k1', 'k2']);
    });

    test(
      'throws typed AppDataBackupFormatException on invalid inputs',
      () async {
        final service = AppDataBackupService(
          sections: <AppDataBackupSection>[],
        );

        expect(
          () => service.inspectJson('{not json'),
          throwsA(
            isA<AppDataBackupFormatException>().having(
              (e) => e.reason,
              'reason',
              AppDataBackupFormatError.invalidJson,
            ),
          ),
        );

        expect(
          () => service.inspectJson(
            jsonEncode(<String, Object?>{
              'formatVersion': 99,
              'sections': <String, Object?>{},
            }),
          ),
          throwsA(
            isA<AppDataBackupFormatException>().having(
              (e) => e.reason,
              'reason',
              AppDataBackupFormatError.unsupportedVersion,
            ),
          ),
        );

        expect(
          () => service.inspectJson(
            jsonEncode(<String, Object?>{'formatVersion': 1}),
          ),
          throwsA(
            isA<AppDataBackupFormatException>().having(
              (e) => e.reason,
              'reason',
              AppDataBackupFormatError.missingSections,
            ),
          ),
        );

        final oversized = ' ' * (AppDataBackupEnvelopeCodec.maxBackupBytes + 1);
        expect(
          () => service.inspectJson(oversized),
          throwsA(
            isA<AppDataBackupFormatException>().having(
              (e) => e.reason,
              'reason',
              AppDataBackupFormatError.fileTooLarge,
            ),
          ),
        );
      },
    );
  });
}
