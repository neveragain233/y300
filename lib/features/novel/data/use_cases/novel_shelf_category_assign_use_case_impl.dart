import 'package:y300/core/persistence/library_shelf_category_constants.dart';
import 'package:y300/features/library_shared/domain/models/library_category_targets.dart';
import 'package:y300/features/library_shared/domain/services/shelf_category_assign_use_case.dart';
import 'package:y300/features/novel/data/repositories/novel_repository.dart';

class DefaultNovelShelfCategoryAssignUseCase
    implements ShelfCategoryAssignUseCase {
  const DefaultNovelShelfCategoryAssignUseCase({
    required NovelRepository repository,
  }) : _repository = repository;

  final NovelRepository _repository;

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
        ? novelDefaultCategoryId
        : normalizedTargetCategoryId;

    for (final rawWorkId in workIds) {
      final workId = rawWorkId.trim();
      if (workId.isEmpty) {
        failedWorkIds.add(rawWorkId);
        continue;
      }
      try {
        await _repository.moveNovelToCategory(
          novelId: workId,
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
