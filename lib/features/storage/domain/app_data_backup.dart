import 'dart:convert';

/// 导入应用数据备份时的合并策略。
enum AppDataBackupImportMode { merge, replace }

/// 备份包解析与校验失败原因。
enum AppDataBackupFormatError {
  invalidJson,
  unsupportedVersion,
  missingSections,
  fileTooLarge,
}

/// 备份文件格式或体积校验异常。
final class AppDataBackupFormatException implements Exception {
  const AppDataBackupFormatException(this.reason);

  final AppDataBackupFormatError reason;

  @override
  String toString() => 'AppDataBackupFormatException($reason)';
}

/// 单个备份分区的预览摘要。
final class AppDataBackupSectionPreview {
  const AppDataBackupSectionPreview({
    required this.sectionId,
    required this.itemCount,
  });

  final String sectionId;
  final int itemCount;
}

/// 备份文件导入前的结构化预览。
final class AppDataBackupPreview {
  const AppDataBackupPreview({
    required this.formatVersion,
    required this.exportedAt,
    required this.sections,
    this.unknownSectionIds = const <String>[],
  });

  final int formatVersion;
  final DateTime? exportedAt;
  final List<AppDataBackupSectionPreview> sections;
  final List<String> unknownSectionIds;

  int get totalItems =>
      sections.fold<int>(0, (sum, section) => sum + section.itemCount);
}

/// 单个分区导入后的结果统计。
final class AppDataBackupSectionReport {
  const AppDataBackupSectionReport({
    required this.sectionId,
    required this.importedCount,
    required this.skippedCount,
    required this.replaced,
  });

  final String sectionId;
  final int importedCount;
  final int skippedCount;
  final bool replaced;
}

/// 整份备份导入完成后的汇总报告。
final class AppDataBackupImportResult {
  const AppDataBackupImportResult({
    required this.sections,
    this.unknownSectionIds = const <String>[],
  });

  final List<AppDataBackupSectionReport> sections;
  final List<String> unknownSectionIds;

  int get totalImported =>
      sections.fold<int>(0, (sum, section) => sum + section.importedCount);

  int get totalSkipped =>
      sections.fold<int>(0, (sum, section) => sum + section.skippedCount);
}

/// 可注册到通用数据备份服务中的业务分区契约。
///
/// 后续新增设置、历史、书架或缓存元数据备份时，只需实现此接口并注册到
/// `appDataBackupServiceProvider`，即可复用同一套文件封包、预览与导入导出流程。
abstract interface class AppDataBackupSection {
  String get sectionId;
  int get sectionVersion;

  Future<Map<String, Object?>> exportPayload();

  AppDataBackupSectionPreview inspectPayload(Map<String, Object?> payload);

  Future<AppDataBackupSectionReport> importPayload(
    Map<String, Object?> payload, {
    required AppDataBackupImportMode mode,
  });
}

/// 已解包的单个分区原始数据。
final class DecodedBackupSectionEntry {
  const DecodedBackupSectionEntry({required this.version, required this.data});

  final int version;
  final Map<String, Object?> data;
}

/// 已解包的通用备份封包。
final class DecodedAppDataBackupEnvelope {
  const DecodedAppDataBackupEnvelope({
    required this.formatVersion,
    required this.exportedAt,
    required this.sections,
  });

  final int formatVersion;
  final DateTime? exportedAt;
  final Map<String, DecodedBackupSectionEntry> sections;
}

/// 通用应用数据备份 JSON 封包编解码器。
abstract final class AppDataBackupEnvelopeCodec {
  static const int formatVersion = 1;
  static const String appId = 'y300';
  static const int maxBackupBytes = 10 * 1024 * 1024;

  static String encode({
    required DateTime exportedAt,
    required Map<String, DecodedBackupSectionEntry> sections,
  }) {
    final encodedSections = <String, Object?>{
      for (final entry in sections.entries)
        entry.key: <String, Object?>{
          'version': entry.value.version,
          'data': entry.value.data,
        },
    };
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'app': appId,
      'formatVersion': formatVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'sections': encodedSections,
    });
  }

  static DecodedAppDataBackupEnvelope decode(String rawJson) {
    if (utf8.encode(rawJson).length > maxBackupBytes) {
      throw const AppDataBackupFormatException(
        AppDataBackupFormatError.fileTooLarge,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException {
      throw const AppDataBackupFormatException(
        AppDataBackupFormatError.invalidJson,
      );
    }
    if (decoded is! Map) {
      throw const AppDataBackupFormatException(
        AppDataBackupFormatError.invalidJson,
      );
    }
    final app = decoded['app'];
    if (app != null && app != appId) {
      throw const AppDataBackupFormatException(
        AppDataBackupFormatError.unsupportedVersion,
      );
    }
    final version = decoded['formatVersion'];
    if (version is! int || version != formatVersion) {
      throw const AppDataBackupFormatException(
        AppDataBackupFormatError.unsupportedVersion,
      );
    }
    final rawSections = decoded['sections'];
    if (rawSections is! Map || rawSections.isEmpty) {
      throw const AppDataBackupFormatException(
        AppDataBackupFormatError.missingSections,
      );
    }
    final sections = <String, DecodedBackupSectionEntry>{};
    for (final entry in rawSections.entries) {
      final id = entry.key;
      final value = entry.value;
      if (id is! String || id.trim().isEmpty || value is! Map) {
        continue;
      }
      final sectionVersion = value['version'];
      final data = value['data'];
      if (sectionVersion is! int || sectionVersion <= 0 || data is! Map) {
        continue;
      }
      sections[id.trim()] = DecodedBackupSectionEntry(
        version: sectionVersion,
        data: Map<String, Object?>.from(data),
      );
    }
    if (sections.isEmpty) {
      throw const AppDataBackupFormatException(
        AppDataBackupFormatError.missingSections,
      );
    }
    final rawExportedAt = decoded['exportedAt'];
    final exportedAt = rawExportedAt is String
        ? DateTime.tryParse(rawExportedAt)?.toLocal()
        : null;
    return DecodedAppDataBackupEnvelope(
      formatVersion: version,
      exportedAt: exportedAt,
      sections: Map<String, DecodedBackupSectionEntry>.unmodifiable(sections),
    );
  }
}
