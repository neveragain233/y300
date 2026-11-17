import 'package:flutter/material.dart';
import 'package:y300/app/navigation/adaptive_detail_host.dart';
import 'package:y300/features/posting/domain/models/posting_target.dart';
import 'package:y300/features/posting/presentation/posting_composer_page.dart';
import 'package:y300/features/posting/presentation/posting_composer_state.dart';

/// 打开新主题编辑器。
///
/// 发帖是覆盖整页的编辑任务：从论坛来源页进入时交给当前详情宿主打开，
/// 主壳据此按"已有详情"退出底栏，编辑器的底部工具栏不再被导航遮挡；
/// 没有详情宿主（独立路由或测试环境）时退化为普通路由。
Future<PostingComposerResult?> openPostingComposer(
  BuildContext context, {
  required PostingTarget target,
}) {
  return openAdaptiveDetail(
    context,
    MaterialPageRoute<PostingComposerResult>(
      builder: (_) =>
          PostingComposerPage(args: PostingComposerArgs(target: target)),
    ),
  );
}
