import 'package:flutter/widgets.dart';
import 'package:y300/features/library_shared/domain/services/recent_reading.dart';

typedef RecentReadingResolveCallback = Future<RecentReadingTarget?> Function();
typedef RecentReadingOpenCallback =
    Future<void> Function(BuildContext context, RecentReadingTarget target);

/// 书架宿主注入的“继续上次阅读”行为。
///
/// 共享页只负责按钮状态与定位；解析范围、阅读器恢复策略和页面路由由宿主
/// 决定，避免共享层反向依赖漫画／小说。
class RecentReadingAction {
  const RecentReadingAction({required this.resolve, required this.open});

  final RecentReadingResolveCallback resolve;
  final RecentReadingOpenCallback open;
}
