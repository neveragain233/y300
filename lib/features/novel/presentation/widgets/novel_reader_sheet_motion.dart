import 'package:flutter/widgets.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_page_turn_models.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_sheet_motion.dart';

import '../../domain/models/novel_reader_preferences.dart';

/// 委托共享 [ReaderSheetMotion] 处理小说整页渐隐与覆盖动效。
class NovelReaderSheetMotion extends StatelessWidget {
  const NovelReaderSheetMotion({
    super.key,
    required this.controller,
    required this.index,
    required this.effect,
    required this.reverse,
    required this.child,
  });

  final PageController controller;
  final int index;
  final NovelReaderPageEffect effect;
  final bool reverse;
  final Widget child;

  static ReaderPageEffect _mapEffect(NovelReaderPageEffect effect) =>
      switch (effect) {
        NovelReaderPageEffect.fade => ReaderPageEffect.fade,
        NovelReaderPageEffect.cover => ReaderPageEffect.cover,
        _ => ReaderPageEffect.slide,
      };

  @override
  Widget build(BuildContext context) {
    return ReaderSheetMotion(
      controller: controller,
      index: index,
      effect: _mapEffect(effect),
      reverse: reverse,
      child: child,
    );
  }
}
