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
    required this.onLoadPageNumber,
    this.failure,
  });

  final bool hasMore;
  final bool isLoadingMore;
  final int currentPage;
  final int? lastPage;
  final bool canLoadPrevious;
  final VoidCallback onLoadPreviousPage;
  final VoidCallback onLoadNextPage;
  final ValueChanged<int> onLoadPageNumber;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (isLoadingMore) {
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
              TextButton(
                key: const Key('thread-detail-previous-page-button'),
                onPressed: canLoadPrevious ? onLoadPreviousPage : null,
                child: Text(l10n.threadDetailPreviousPage),
              ),
              Text(
                lastPage == null
                    ? l10n.threadDetailPage(currentPage)
                    : l10n.threadControlsPageSummary(currentPage, lastPage!),
                key: const Key('thread-detail-page-label'),
              ),
              TextButton(
                key: const Key('thread-detail-load-more-button'),
                onPressed: hasMore ? onLoadNextPage : null,
                child: Text(
                  hasMore ? l10n.threadDetailNextPage : l10n.threadDetailNoMore,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
