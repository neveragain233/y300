import 'package:flutter/foundation.dart';

enum LibraryCoverAssetKind { source, custom }

/// A stable business identity for a library cover.
///
/// [legacyLocalPath] only exists to adopt files created by the retired cover
/// cache. It is deliberately excluded from equality and image cache keys.
@immutable
class LibraryCoverAssetRef {
  const LibraryCoverAssetRef({
    required this.assetId,
    required this.revision,
    required this.kind,
    this.sourceUrl,
    this.legacyLocalPath,
  });

  final String assetId;
  final int revision;
  final LibraryCoverAssetKind kind;
  final String? sourceUrl;
  final String? legacyLocalPath;

  String get versionedId => '$assetId@$revision';

  bool get canLoad {
    return _hasText(sourceUrl) || _hasText(legacyLocalPath);
  }

  LibraryCoverAssetRef copyWith({
    int? revision,
    String? sourceUrl,
    String? legacyLocalPath,
    bool clearSourceUrl = false,
    bool clearLegacyLocalPath = false,
  }) {
    return LibraryCoverAssetRef(
      assetId: assetId,
      revision: revision ?? this.revision,
      kind: kind,
      sourceUrl: clearSourceUrl ? null : (sourceUrl ?? this.sourceUrl),
      legacyLocalPath: clearLegacyLocalPath
          ? null
          : (legacyLocalPath ?? this.legacyLocalPath),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryCoverAssetRef &&
        other.assetId == assetId &&
        other.revision == revision &&
        other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(assetId, revision, kind);

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;
}

abstract final class LibraryCoverAssetIds {
  static String source({required String ownerType, required String ownerId}) {
    return '${ownerType.trim()}/${ownerId.trim()}/source';
  }

  static String custom({required String ownerType, required String ownerId}) {
    return '${ownerType.trim()}/${ownerId.trim()}/custom';
  }

  /// 读回资产编号中的归属（`<ownerType>/<ownerId>/<kind>`）。
  ///
  /// 书架卡片需要按“来源类型＋作品编号”取稳定身份色，而收藏页只缓存线程
  /// 信息，作品编号可能与模块内编号不同。资产编号由本类生成，这里按同一
  /// 格式解析，避免为配色再复制一份归属字段。
  static LibraryCoverAssetOwner? ownerOf(String assetId) {
    final parts = assetId.split('/');
    if (parts.length < 3) {
      return null;
    }
    final ownerType = parts.first.trim();
    final ownerId = parts[parts.length - 2].trim();
    if (ownerType.isEmpty || ownerId.isEmpty) {
      return null;
    }
    return LibraryCoverAssetOwner(ownerType: ownerType, ownerId: ownerId);
  }
}

/// 封面资源是否存在的统一判断。
///
/// 没有任何来源封面、自定义封面或已在路径的封面时展示排版封面；只要存在一种
/// 资源就交给图片控件处理加载与失败态。
abstract final class LibraryCoverSources {
  static bool hasAny({
    required LibraryCoverAssetRef? asset,
    String? customLocalPath,
    String? customImageUrl,
    String? coverLocalPath,
    String? coverImageUrl,
  }) {
    if (asset != null) {
      return true;
    }
    for (final value in <String?>[
      customLocalPath,
      customImageUrl,
      coverLocalPath,
      coverImageUrl,
    ]) {
      if (value != null && value.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}

/// 封面资产的业务归属。
class LibraryCoverAssetOwner {
  const LibraryCoverAssetOwner({
    required this.ownerType,
    required this.ownerId,
  });

  final String ownerType;
  final String ownerId;
}
