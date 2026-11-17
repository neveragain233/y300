import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/library_shared/data/providers/library_cover_providers.dart';
import 'package:y300/features/library_shared/domain/models/library_cover_asset.dart';
import 'package:y300/features/library_shared/domain/services/library_cover_decode_policy.dart';
import 'package:y300/features/library_shared/presentation/images/library_cover_image_provider.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/library_cover_placeholder.dart';

/// Full-resolution viewer whose bitmap is evicted when the route closes so it
/// cannot displace shelf thumbnails from the shared Flutter image cache.
class LibraryCoverOriginalPage extends ConsumerStatefulWidget {
  const LibraryCoverOriginalPage({super.key, required this.asset});

  final LibraryCoverAssetRef asset;

  @override
  ConsumerState<LibraryCoverOriginalPage> createState() =>
      _LibraryCoverOriginalPageState();
}

class _LibraryCoverOriginalPageState
    extends ConsumerState<LibraryCoverOriginalPage> {
  late final LibraryCoverImageProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = LibraryCoverImageProvider(
      asset: widget.asset,
      usage: LibraryCoverUsage.original,
      decodeTarget: const LibraryCoverDecodeTarget.original(),
      store: ref.read(libraryCoverStoreProvider),
      scheduler: ref.read(libraryCoverDecodeSchedulerProvider),
    );
  }

  @override
  void dispose() {
    PaintingBinding.instance.imageCache.evict(
      _provider.cacheKey,
      includeLive: true,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 原图页的底色由图片表面提供，不跟随应用页面表面；这里只把顶栏换成
    // 公共压入页外壳，并在局部主题里保留黑色图片表面与浅色状态栏图标。
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: base.colorScheme.primary,
          brightness: Brightness.dark,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: const AppPageAppBar(titleWidget: SizedBox.shrink()),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 6,
            child: Image(
              image: _provider,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) =>
                  const LibraryCoverPlaceholder(
                    key: Key('library-cover-original-placeholder'),
                    color: Colors.black,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
