import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/content_filter/data/backup/content_filter_backup_sections.dart';
import 'package:y300/features/storage/data/app_data_backup_service.dart';
import 'package:y300/features/storage/domain/app_data_backup.dart';

/// 应用级通用数据备份服务入口，聚合各业务模块注册的 [AppDataBackupSection]。
final appDataBackupServiceProvider = Provider<AppDataBackupService>((ref) {
  return AppDataBackupService(
    sections: <AppDataBackupSection>[
      BlockedKeywordsBackupSection(ref),
      BlockedThreadsBackupSection(ref),
      WhitelistedUsersBackupSection(ref),
    ],
  );
});
