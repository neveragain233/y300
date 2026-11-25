import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/application/blocked_keywords_controller.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/application/whitelisted_users_controller.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_keyword_snapshot_codec.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_thread_snapshot_codec.dart';
import 'package:y300/features/content_filter/data/codecs/whitelisted_user_snapshot_codec.dart';
import 'package:y300/features/content_filter/domain/models/blocked_keyword.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/features/content_filter/domain/models/whitelisted_user.dart';
import 'package:y300/features/storage/domain/app_data_backup.dart';

/// 内容屏蔽模块注册到通用备份服务的分区标识集合。
abstract final class ContentFilterBackupSectionIds {
  static const String blockedKeywords = 'content_filter.blocked_keywords';
  static const String blockedThreads = 'content_filter.blocked_threads';
  static const String whitelistedUsers = 'content_filter.whitelisted_users';

  static const Set<String> all = <String>{
    blockedKeywords,
    blockedThreads,
    whitelistedUsers,
  };
}

/// 关键词屏蔽与豁免规则备份分区。
final class BlockedKeywordsBackupSection implements AppDataBackupSection {
  BlockedKeywordsBackupSection(this._ref);

  final Ref _ref;

  @override
  String get sectionId => ContentFilterBackupSectionIds.blockedKeywords;

  @override
  int get sectionVersion => BlockedKeywordSnapshotCodec.schemaVersion;

  @override
  Future<Map<String, Object?>> exportPayload() async {
    final rules = await _ref.read(blockedKeywordsControllerProvider.future);
    return Map<String, Object?>.from(
      jsonDecode(BlockedKeywordSnapshotCodec.encode(rules)) as Map,
    );
  }

  @override
  AppDataBackupSectionPreview inspectPayload(Map<String, Object?> payload) {
    final items = _decodePayload(payload);
    return AppDataBackupSectionPreview(
      sectionId: sectionId,
      itemCount: items.length,
    );
  }

  @override
  Future<AppDataBackupSectionReport> importPayload(
    Map<String, Object?> payload, {
    required AppDataBackupImportMode mode,
  }) async {
    final items = _decodePayload(payload);
    final replace = mode == AppDataBackupImportMode.replace;
    final (imported, skipped) = await _ref
        .read(blockedKeywordsControllerProvider.notifier)
        .importRules(items, replace: replace);
    return AppDataBackupSectionReport(
      sectionId: sectionId,
      importedCount: imported,
      skippedCount: skipped,
      replaced: replace,
    );
  }

  List<BlockedKeyword> _decodePayload(Map<String, Object?> payload) {
    return BlockedKeywordSnapshotCodec.decode(jsonEncode(payload));
  }
}

/// 屏蔽主题贴备份分区。
final class BlockedThreadsBackupSection implements AppDataBackupSection {
  BlockedThreadsBackupSection(this._ref);

  final Ref _ref;

  @override
  String get sectionId => ContentFilterBackupSectionIds.blockedThreads;

  @override
  int get sectionVersion => BlockedThreadSnapshotCodec.schemaVersion;

  @override
  Future<Map<String, Object?>> exportPayload() async {
    final threads = await _ref.read(blockedThreadsControllerProvider.future);
    return Map<String, Object?>.from(
      jsonDecode(BlockedThreadSnapshotCodec.encode(threads)) as Map,
    );
  }

  @override
  AppDataBackupSectionPreview inspectPayload(Map<String, Object?> payload) {
    final items = _decodePayload(payload);
    return AppDataBackupSectionPreview(
      sectionId: sectionId,
      itemCount: items.length,
    );
  }

  @override
  Future<AppDataBackupSectionReport> importPayload(
    Map<String, Object?> payload, {
    required AppDataBackupImportMode mode,
  }) async {
    final items = _decodePayload(payload);
    final replace = mode == AppDataBackupImportMode.replace;
    final (imported, skipped) = await _ref
        .read(blockedThreadsControllerProvider.notifier)
        .importThreads(items, replace: replace);
    return AppDataBackupSectionReport(
      sectionId: sectionId,
      importedCount: imported,
      skippedCount: skipped,
      replaced: replace,
    );
  }

  List<BlockedThread> _decodePayload(Map<String, Object?> payload) {
    return BlockedThreadSnapshotCodec.decode(jsonEncode(payload));
  }
}

/// 可信用户白名单备份分区。
final class WhitelistedUsersBackupSection implements AppDataBackupSection {
  WhitelistedUsersBackupSection(this._ref);

  final Ref _ref;

  @override
  String get sectionId => ContentFilterBackupSectionIds.whitelistedUsers;

  @override
  int get sectionVersion => WhitelistedUserSnapshotCodec.schemaVersion;

  @override
  Future<Map<String, Object?>> exportPayload() async {
    final users = await _ref.read(whitelistedUsersControllerProvider.future);
    return Map<String, Object?>.from(
      jsonDecode(WhitelistedUserSnapshotCodec.encode(users)) as Map,
    );
  }

  @override
  AppDataBackupSectionPreview inspectPayload(Map<String, Object?> payload) {
    final items = _decodePayload(payload);
    return AppDataBackupSectionPreview(
      sectionId: sectionId,
      itemCount: items.length,
    );
  }

  @override
  Future<AppDataBackupSectionReport> importPayload(
    Map<String, Object?> payload, {
    required AppDataBackupImportMode mode,
  }) async {
    final items = _decodePayload(payload);
    final replace = mode == AppDataBackupImportMode.replace;
    final (imported, skipped) = await _ref
        .read(whitelistedUsersControllerProvider.notifier)
        .importEntries(items, replace: replace);
    return AppDataBackupSectionReport(
      sectionId: sectionId,
      importedCount: imported,
      skippedCount: skipped,
      replaced: replace,
    );
  }

  List<WhitelistedUser> _decodePayload(Map<String, Object?> payload) {
    return WhitelistedUserSnapshotCodec.decode(jsonEncode(payload));
  }
}
