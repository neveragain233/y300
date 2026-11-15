import 'package:y300/features/library_shared/domain/contracts/shelf_module_adapter.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/models/library_sort_models.dart';
import 'package:y300/features/library_shared/presentation/services/library_error_summary.dart';
import 'package:y300/features/library_shared/presentation/services/library_title_fallback_policy.dart';
import 'package:y300/l10n/app_localizations.dart';

abstract final class LibraryShelfTextResolver {
  static String moduleTitle(AppLocalizations l10n, LibraryModuleKey moduleKey) {
    return l10n.libraryShelfTitle(moduleKey.name);
  }

  static String categoryName(AppLocalizations l10n, LibraryCategory category) {
    if (category.source == LibraryModuleKey.bookshelf) {
      return l10n.libraryShelfAllWorks;
    }
    if (category.isSynthetic) {
      return category.source == LibraryModuleKey.novel
          ? l10n.libraryShelfTitle('novel')
          : l10n.libraryShelfTitle('comic');
    }
    final baseName = category.isDefault
        ? l10n.libraryShelfDefaultCategory
        : category.name;
    return switch (category.source) {
      LibraryModuleKey.comic => l10n.libraryShelfComicCategory(baseName),
      LibraryModuleKey.novel => l10n.libraryShelfNovelCategory(baseName),
      _ => baseName,
    };
  }

  static String workTypeBadge(AppLocalizations l10n, LibraryModuleKey? source) {
    return switch (source) {
      LibraryModuleKey.comic => l10n.libraryShelfComicBadge,
      LibraryModuleKey.novel => l10n.libraryShelfNovelBadge,
      _ => '',
    };
  }

  static String workTitle(
    AppLocalizations l10n,
    LibraryModuleKey moduleKey,
    String rawTitle,
    String workId,
  ) {
    if (!LibraryTitleFallbackPolicy.needsWorkFallback(moduleKey, rawTitle)) {
      return rawTitle;
    }
    return switch (moduleKey) {
      LibraryModuleKey.comic => l10n.comicUntitledWork(workId),
      LibraryModuleKey.novel => l10n.novelUntitledWork(workId),
      LibraryModuleKey.favorite => rawTitle,
      LibraryModuleKey.bookshelf => rawTitle,
    };
  }

  static String categoryLabel(
    AppLocalizations l10n,
    LibraryCategory category, {
    required bool showMatchCount,
    required int matchCount,
  }) {
    final name = categoryName(l10n, category);
    return showMatchCount
        ? l10n.libraryShelfCategoryMatchCount(name, matchCount)
        : name;
  }

  static String menuAction(
    AppLocalizations l10n,
    LibraryShelfMenuAction action,
  ) {
    return switch (action) {
      LibraryShelfMenuAction.mergeDuplicates =>
        l10n.libraryShelfMergeDuplicates,
    };
  }

  static String menuOutcome(
    AppLocalizations l10n,
    LibraryShelfMenuAction action,
    ShelfModuleActionOutcome outcome,
  ) {
    return switch ((action, outcome.code)) {
      (
        LibraryShelfMenuAction.mergeDuplicates,
        ShelfModuleActionOutcomeCode.success,
      ) =>
        l10n.libraryShelfMergeDuplicatesSuccess(outcome.affectedCount),
      (
        LibraryShelfMenuAction.mergeDuplicates,
        ShelfModuleActionOutcomeCode.noChange,
      ) =>
        l10n.libraryShelfMergeDuplicatesNoChange,
      (_, ShelfModuleActionOutcomeCode.unsupported) =>
        l10n.libraryShelfActionUnsupported,
    };
  }

  static String sortField(AppLocalizations l10n, LibraryShelfSortField field) {
    return switch (field) {
      LibraryShelfSortField.name => l10n.libraryShelfSortName,
      LibraryShelfSortField.chapterCount => l10n.libraryShelfSortChapterCount,
      LibraryShelfSortField.lastReadAt => l10n.libraryShelfSortLastReadAt,
      LibraryShelfSortField.lastCheckedAt => l10n.libraryShelfSortLastCheckedAt,
      LibraryShelfSortField.unreadCount => l10n.libraryShelfSortUnreadCount,
      LibraryShelfSortField.workUpdatedAt => l10n.libraryShelfSortWorkUpdatedAt,
      LibraryShelfSortField.fetchedAt => l10n.libraryShelfSortFetchedAt,
      LibraryShelfSortField.favoriteAddedAt =>
        l10n.libraryShelfSortFavoriteAddedAt,
    };
  }

  static String loadError(AppLocalizations l10n, Object? error) {
    return l10n.libraryShelfLoadFailed(
      LibraryErrorSummary.resolve(l10n, error),
    );
  }
}
