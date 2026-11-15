import 'package:y300/features/comic/domain/repositories/comic_repository.dart';
import 'package:y300/core/persistence/library_shelf_category_constants.dart';
import 'package:y300/features/library_shared/domain/models/library_category_targets.dart';
import 'package:y300/features/library_shared/domain/services/shelf_category_assign_use_case.dart';

class DefaultComicShelfCategoryAssignUseCase
    implements ShelfCategoryAssignUseCase {
  const DefaultComicShelfCategoryAssignUseCase({
    required ComicRepository repository,
  }) : _repository = repository;

  final ComicRepository _repository;

  @override
  Future<ShelfCategoryAssignResult> assign({
    required Set<String> workIds,
    required String sourceCategoryId,
    required String targetCategoryId,
  }) async {
    final assignedWorkIds = <String>[];
    final failedWorkIds = <String>[];
    final normalizedTargetCategoryId = targetCategoryId.trim();
    final resolvedTargetCategoryId =
        LibraryCategoryTargets.isHome(normalizedTargetCategoryId)
        ? comicDefaultCategoryId
        : normalizedTargetCategoryId;

    for (final rawWorkId in workIds) {
      final workId = rawWorkId.trim();
      if (workId.isEmpty) {
        failedWorkIds.add(rawWorkId);
        continue;
      }
      try {
        await _repository.moveComicToCategory(
          comicId: workId,
          fromCategoryId: '',
          toCategoryId: resolvedTargetCategoryId,
        );
        assignedWorkIds.add(workId);
      } catch (_) {
        failedWorkIds.add(workId);
      }
    }

    return ShelfCategoryAssignResult(
      assignedWorkIds: assignedWorkIds,
      failedWorkIds: failedWorkIds,
      targetCategoryId: resolvedTargetCategoryId,
    );
  }
}
