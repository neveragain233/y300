import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/library_shared/domain/services/library_cover_asset_factory.dart';

void main() {
  test('keeps migrated source identity when legacy locators are cleared', () {
    final asset = LibraryCoverAssetFactory.preferred(
      ownerType: 'comic',
      ownerId: 'comic-1',
      sourceRevision: 3,
    );

    expect(asset, isNotNull);
    expect(asset!.assetId, 'comic/comic-1/source');
    expect(asset.revision, 3);
    expect(asset.kind, LibraryCoverAssetKind.source);
    expect(asset.sourceUrl, isNull);
    expect(asset.legacyLocalPath, isNull);
  });

  test('does not invent a source asset without revision or locator', () {
    final asset = LibraryCoverAssetFactory.preferred(
      ownerType: 'novel',
      ownerId: 'novel-1',
    );

    expect(asset, isNull);
  });

  test('cover asset ids expose their owner for stable identity colors', () {
    final owner = LibraryCoverAssetIds.ownerOf('comic/yamibo:9/custom');

    expect(owner, isNotNull);
    expect(owner!.ownerType, 'comic');
    expect(owner.ownerId, 'yamibo:9');
    expect(LibraryCoverAssetIds.ownerOf('comic'), isNull);
    expect(LibraryCoverAssetIds.ownerOf('/id/source'), isNull);
  });

  test('cover source detection distinguishes empty and configured covers', () {
    expect(LibraryCoverSources.hasAny(asset: null), isFalse);
    expect(
      LibraryCoverSources.hasAny(asset: null, coverImageUrl: '  '),
      isFalse,
    );
    expect(
      LibraryCoverSources.hasAny(
        asset: null,
        customLocalPath: 'covers/custom.img',
      ),
      isTrue,
    );
    expect(
      LibraryCoverSources.hasAny(
        asset: const LibraryCoverAssetRef(
          assetId: 'novel/1/source',
          revision: 1,
          kind: LibraryCoverAssetKind.source,
        ),
      ),
      isTrue,
    );
  });
}
