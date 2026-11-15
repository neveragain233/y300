import 'package:flutter/widgets.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';

/// 书架批量操作声明。
class SelectionAction {
  const SelectionAction({
    required this.id,
    required this.icon,
    this.destructive = false,
    this.needsConfirm = false,
  });

  final String id;
  final IconData icon;
  final bool destructive;
  final bool needsConfirm;
}

enum SelectionActionOutcomeCode {
  success,
  partialFailure,
  unsupported,
  missingTargetCategory,
  noValidItems,
  noChange,
}

/// 书架批量操作执行结果。
class SelectionActionOutcome {
  const SelectionActionOutcome({
    required this.code,
    this.changed = false,
    this.succeededCount = 0,
    this.failedCount = 0,
    this.enqueuedCount = 0,
    this.deduplicatedCount = 0,
  });

  final SelectionActionOutcomeCode code;
  final bool changed;
  final int succeededCount;
  final int failedCount;
  final int enqueuedCount;
  final int deduplicatedCount;

  bool get hasFailure =>
      failedCount > 0 || code == SelectionActionOutcomeCode.partialFailure;
}

/// 一次批量操作请求。
///
/// [activeCategoryId] 表示当前可见分类页；批量改分类时它就是来源分类。
/// [targetCategoryId] 仅在 `assign-category` 场景下使用。
class SelectionActionExecutionRequest {
  const SelectionActionExecutionRequest({
    required this.actionId,
    required this.workIds,
    required this.activeCategoryId,
    this.targetCategoryId,
    this.targetCategoryIdsBySource = const <LibraryModuleKey, String>{},
  });

  final String actionId;
  final Set<String> workIds;
  final String activeCategoryId;
  final String? targetCategoryId;

  /// 跨类型批量改分类时，每个来源各自的目标分类。
  ///
  /// 非空表示按来源分段提交；未列出的来源保持原分类。单模块请求继续使用
  /// [targetCategoryId]，两者不会同时生效。
  final Map<LibraryModuleKey, String> targetCategoryIdsBySource;
}

/// 书架模块的批量操作能力。
abstract class ShelfSelectionActionAdapter {
  List<SelectionAction> get selectionActions;

  Future<SelectionActionOutcome> runSelectionAction(
    SelectionActionExecutionRequest request,
  );
}

/// 批量动作稳定 id。
class SelectionActionIds {
  const SelectionActionIds._();

  static const String assignCategory = 'assign-category';
  static const String markAllRead = 'mark-all-read';
  static const String markAllUnread = 'mark-all-unread';
  static const String download = 'download';
  static const String unfavorite = 'unfavorite';
  static const String parse = 'parse';
}
