import 'package:flutter/material.dart';
import 'package:y300/features/cache/presentation/widgets/library_cached_image.dart';
import 'package:y300/features/library_shared/domain/contracts/detail_module_adapter.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_status_views.dart';

/// 详情页“从帖子图片选择封面”的候选面板。
class UnifiedDetailCoverCandidatesSheet extends StatelessWidget {
  const UnifiedDetailCoverCandidatesSheet({
    super.key,
    required this.candidates,
    required this.imageReferer,
  });

  final Future<List<DetailCoverCandidate>> candidates;
  final String? imageReferer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        key: const Key('unified-detail-cover-candidates-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.libraryDetailCoverCandidatesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<List<DetailCoverCandidate>>(
                future: candidates,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return SizedBox(
                      height: 160,
                      child: AppLoadingState(label: l10n.commonLoading),
                    );
                  }
                  if (snapshot.hasError) {
                    return _Message(
                      key: const Key('unified-detail-cover-candidates-error'),
                      message: l10n.libraryDetailCoverCandidatesLoadFailed,
                    );
                  }
                  final items = snapshot.data ?? const <DetailCoverCandidate>[];
                  if (items.isEmpty) {
                    return _Message(
                      key: const Key('unified-detail-cover-candidates-empty'),
                      message: l10n.libraryDetailCoverCandidatesEmpty,
                    );
                  }
                  return GridView.builder(
                    key: const Key('unified-detail-cover-candidates-grid'),
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2 / 3,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Semantics(
                        button: true,
                        label: l10n.libraryDetailCoverCandidateSemantics(
                          index + 1,
                        ),
                        child: InkWell(
                          key: ValueKey<String>(
                            'unified-detail-cover-candidate-$index',
                          ),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => Navigator.of(context).pop(item.imageUrl),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LibraryCachedImage(
                              imageUrl: item.imageUrl,
                              referer: imageReferer,
                              fit: BoxFit.cover,
                              placeholder: ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}
