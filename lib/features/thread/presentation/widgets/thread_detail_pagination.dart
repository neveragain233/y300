part of 'thread_detail_widgets.dart';

// Pagination widgets for thread detail: load-more row and page controls.

class ThreadLoadMoreSection extends StatelessWidget {
  const ThreadLoadMoreSection({
    super.key,
    required this.hasMore,
    required this.isLoadingMore,
    required this.currentPage,
    required this.lastPage,
    required this.canLoadPrevious,
    required this.onLoadPreviousPage,
    required this.onLoadNextPage,
    this.onOpenPagePicker,
    this.failure,
  });

  final bool hasMore;
  final bool isLoadingMore;
  final int currentPage;
  final int? lastPage;
  final bool canLoadPrevious;
  final VoidCallback onLoadPreviousPage;
  final VoidCallback onLoadNextPage;
  final ValueChanged<BuildContext>? onOpenPagePicker;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (isLoadingMore) {
      if (AppMotion.reduceMotion(context)) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Text(
                l10n.threadDetailPageLoading,
                key: const Key('thread-detail-pagination-loading-text'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Column(
        children: [
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                failure!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              NativePaginationButton(
                key: const Key('thread-detail-previous-page-button'),
                label: l10n.threadDetailPreviousPage,
                onPressed: canLoadPrevious ? onLoadPreviousPage : null,
              ),
              Builder(
                builder: (buttonContext) {
                  final effectiveLast =
                      lastPage != null && lastPage! < currentPage
                      ? currentPage
                      : lastPage;
                  final pageLabel = effectiveLast == null
                      ? l10n.threadDetailPage(currentPage)
                      : l10n.threadControlsPageSummary(
                          currentPage,
                          effectiveLast,
                        );
                  return NativePaginationButton(
                    key: const Key('thread-detail-page-label'),
                    label: pageLabel,
                    onPressed: onOpenPagePicker == null
                        ? null
                        : () => onOpenPagePicker!(buttonContext),
                  );
                },
              ),
              NativePaginationButton(
                key: const Key('thread-detail-load-more-button'),
                label: hasMore
                    ? l10n.threadDetailNextPage
                    : l10n.threadDetailNoMore,
                onPressed: hasMore ? onLoadNextPage : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
