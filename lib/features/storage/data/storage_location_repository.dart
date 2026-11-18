import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';

/// 从应用专属外部目录推导共享媒体目录 `Android/media/<package>/Y300`。
///
/// Android 上 `getExternalStorageDirectory()` 返回
/// `<volume>/Android/data/<package>/files`；同级 `media` 目录是该应用无需额外
/// 存储权限即可读写的用户可见位置。应用标识来自构建配置（本机可用
/// `android/local.properties` 的 `y300.applicationId` 覆盖），不能在 Dart 里
/// 再硬编码一份。目录布局不符合预期时返回 null，由调用方退回应用专属目录。
String? androidMediaRootFor(String? externalFilesPath) {
  if (externalFilesPath == null || externalFilesPath.trim().isEmpty) {
    return null;
  }
  final packageDirectory = p.dirname(externalFilesPath);
  final dataDirectory = p.dirname(packageDirectory);
  final androidDirectory = p.dirname(dataDirectory);
  final packageName = p.basename(packageDirectory);
  if (packageName.isEmpty) return null;
  if (p.basename(dataDirectory) != 'data') return null;
  if (p.basename(androidDirectory) != 'Android') return null;
  return p.join(androidDirectory, 'media', packageName, 'Y300');
}

abstract class StorageLocationRepository {
  Future<String> getDefaultStorageRoot();

  Future<String?> getCustomStorageRoot();

  Future<void> setCustomStorageRoot(String? path);

  Future<String?> pickDirectory();
}

abstract interface class ExistingStorageRootLocator {
  Future<String?> getExistingStorageRoot();
}

class StorageLocationRepositoryImpl
    implements StorageLocationRepository, ExistingStorageRootLocator {
  StorageLocationRepositoryImpl({PreferencesStore? preferencesStore})
    : _preferencesStore = preferencesStore ?? SharedPreferencesStore();

  final PreferencesStore _preferencesStore;

  @override
  Future<String?> getExistingStorageRoot() async {
    final custom = await getCustomStorageRoot();
    if (custom != null) {
      return await io.Directory(custom).exists() ? custom : null;
    }
    final candidates = <String>[];
    if (io.Platform.isAndroid) {
      for (final directory in await _androidRootCandidates()) {
        candidates.add(directory.path);
      }
    }
    candidates.add(
      p.join((await getApplicationDocumentsDirectory()).path, 'Y300'),
    );
    for (final path in candidates) {
      if (await io.Directory(path).exists()) return path;
    }
    return null;
  }

  @override
  Future<String> getDefaultStorageRoot() async {
    if (io.Platform.isAndroid) {
      final candidates = await _androidRootCandidates();
      // 先沿用已有根目录：修复应用标识后媒体目录会变成可写，但旧版本的下载
      // 仍在应用专属目录里，直接改用新目录会让已有缓存和书架“消失”。
      for (final directory in candidates) {
        if (await _hasContent(directory)) return directory.path;
      }
      for (final directory in candidates) {
        if (await _canPrepare(directory)) return directory.path;
      }
    }

    final documents = await getApplicationDocumentsDirectory();
    final fallback = io.Directory(p.join(documents.path, 'Y300'));
    await fallback.create(recursive: true);
    return fallback.path;
  }

  /// 媒体目录优先，其次是应用专属外部目录；两者都在同一个存储卷上。
  Future<List<io.Directory>> _androidRootCandidates() async {
    final external = await getExternalStorageDirectory();
    final candidates = <io.Directory>[];
    final mediaRoot = androidMediaRootFor(external?.path);
    if (mediaRoot != null) candidates.add(io.Directory(mediaRoot));
    if (external != null) {
      candidates.add(io.Directory(p.join(external.path, 'Y300')));
    }
    return candidates;
  }

  @override
  Future<String?> getCustomStorageRoot() async {
    final value = (await _preferencesStore.read(
      PreferenceKeys.downloadStorageDirectory,
    ))?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<void> setCustomStorageRoot(String? path) async {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) {
      if (await _preferencesStore.contains(
        PreferenceKeys.downloadStorageDirectory,
      )) {
        await _preferencesStore.remove(PreferenceKeys.downloadStorageDirectory);
      }
      return;
    }
    await _preferencesStore.write(
      PreferenceKeys.downloadStorageDirectory,
      normalized,
    );
  }

  @override
  Future<String?> pickDirectory() {
    return FilePicker.getDirectoryPath();
  }

  Future<bool> _hasContent(io.Directory directory) async {
    try {
      if (!await directory.exists()) return false;
      return !await directory.list(followLinks: false).isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canPrepare(io.Directory directory) async {
    try {
      await directory.create(recursive: true);
      final probe = io.File(p.join(directory.path, '.write_probe'));
      await probe.writeAsString('');
      if (await probe.exists()) {
        await probe.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
