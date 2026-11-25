import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:y300/features/storage/domain/app_data_backup.dart';

typedef SaveBackupJsonFile = Future<Uri?> Function({
  required String fileName,
  required Uint8List bytes,
  String? dialogTitle,
});

typedef PickBackupJsonFile = Future<String?> Function();

/// 通用应用数据与规则备份服务。
///
/// 通过注入多组 [AppDataBackupSection] 统一处理导出封包、体积限制、导入预览
/// 与按分区落盘，供内容屏蔽规则及后续应用缓存/设置备份共同复用。
final class AppDataBackupService {
  AppDataBackupService({
    required List<AppDataBackupSection> sections,
    DateTime Function()? clock,
    SaveBackupJsonFile? saveJsonFile,
    PickBackupJsonFile? pickJsonFile,
  }) : _sectionsById = <String, AppDataBackupSection>{
         for (final section in sections) section.sectionId: section,
       },
       _clock = clock ?? DateTime.now,
       _saveJsonFile = saveJsonFile ?? _defaultSaveJsonFile,
       _pickJsonFile = pickJsonFile ?? _defaultPickJsonFile;

  final Map<String, AppDataBackupSection> _sectionsById;
  final DateTime Function() _clock;
  final SaveBackupJsonFile _saveJsonFile;
  final PickBackupJsonFile _pickJsonFile;

  Future<String> exportJson({Set<String>? sectionIds}) async {
    final targetIds = sectionIds ?? _sectionsById.keys.toSet();
    final encodedSections = <String, DecodedBackupSectionEntry>{};
    for (final id in targetIds) {
      final section = _sectionsById[id];
      if (section == null) continue;
      encodedSections[id] = DecodedBackupSectionEntry(
        version: section.sectionVersion,
        data: await section.exportPayload(),
      );
    }
    return AppDataBackupEnvelopeCodec.encode(
      exportedAt: _clock(),
      sections: encodedSections,
    );
  }

  Future<Uri?> exportToFile({
    required String fileName,
    Set<String>? sectionIds,
    String? dialogTitle,
  }) async {
    final jsonText = await exportJson(sectionIds: sectionIds);
    final bytes = Uint8List.fromList(utf8.encode(jsonText));
    return _saveJsonFile(
      fileName: fileName,
      bytes: bytes,
      dialogTitle: dialogTitle,
    );
  }

  Future<String?> pickJsonFromFile() => _pickJsonFile();

  AppDataBackupPreview inspectJson(
    String rawJson, {
    Set<String>? allowedSectionIds,
  }) {
    final envelope = AppDataBackupEnvelopeCodec.decode(rawJson);
    final previews = <AppDataBackupSectionPreview>[];
    final unknownIds = <String>[];
    for (final entry in envelope.sections.entries) {
      final allowed =
          allowedSectionIds == null || allowedSectionIds.contains(entry.key);
      final section = allowed ? _sectionsById[entry.key] : null;
      if (section == null) {
        unknownIds.add(entry.key);
        continue;
      }
      previews.add(section.inspectPayload(entry.value.data));
    }
    return AppDataBackupPreview(
      formatVersion: envelope.formatVersion,
      exportedAt: envelope.exportedAt,
      sections: List<AppDataBackupSectionPreview>.unmodifiable(previews),
      unknownSectionIds: List<String>.unmodifiable(unknownIds),
    );
  }

  Future<AppDataBackupImportResult> importJson(
    String rawJson, {
    required AppDataBackupImportMode mode,
    Set<String>? allowedSectionIds,
  }) async {
    final envelope = AppDataBackupEnvelopeCodec.decode(rawJson);
    final reports = <AppDataBackupSectionReport>[];
    final unknownIds = <String>[];
    for (final entry in envelope.sections.entries) {
      final allowed =
          allowedSectionIds == null || allowedSectionIds.contains(entry.key);
      final section = allowed ? _sectionsById[entry.key] : null;
      if (section == null) {
        unknownIds.add(entry.key);
        continue;
      }
      reports.add(await section.importPayload(entry.value.data, mode: mode));
    }
    return AppDataBackupImportResult(
      sections: List<AppDataBackupSectionReport>.unmodifiable(reports),
      unknownSectionIds: List<String>.unmodifiable(unknownIds),
    );
  }

  static Future<Uri?> _defaultSaveJsonFile({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
  }) {
    return FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: dialogTitle,
    );
  }

  static Future<String?> _defaultPickJsonFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    final knownLength = file.lengthSync();
    if (knownLength != null &&
        knownLength > AppDataBackupEnvelopeCodec.maxBackupBytes) {
      throw const AppDataBackupFormatException(
        AppDataBackupFormatError.fileTooLarge,
      );
    }
    final builder = BytesBuilder();
    await for (final chunk in file.readAsByteStream()) {
      if (chunk.length >
          AppDataBackupEnvelopeCodec.maxBackupBytes - builder.length) {
        throw const AppDataBackupFormatException(
          AppDataBackupFormatError.fileTooLarge,
        );
      }
      builder.add(chunk);
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: false);
  }
}
