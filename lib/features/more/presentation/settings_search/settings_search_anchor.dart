import 'dart:async';

import 'package:flutter/material.dart';
import 'package:y300/features/more/presentation/settings_search/settings_search_index.dart';

/// 设置搜索的定位请求：页面把目标分组滚到可见区并短暂高亮。
///
/// 同一目标可以重复请求；每次请求都会通知所有锚点，由目标锚点响应。
class SettingsSearchRevealController extends ChangeNotifier {
  SettingsSearchTarget? _target;

  SettingsSearchTarget? get target => _target;

  void reveal(SettingsSearchTarget target) {
    _target = target;
    notifyListeners();
  }
}

/// 设置分组锚点：收到定位请求时滚动到自身，并让强调描边淡入后淡出。
///
/// 页面即时构建分组（`SingleChildScrollView` 加 `Column`），锚点始终存在，
/// 滚动使用 [Scrollable.ensureVisible]，不重建页面实例也不改动返回栈。
class SettingsSearchSectionAnchor extends StatefulWidget {
  const SettingsSearchSectionAnchor({
    super.key,
    required this.revealController,
    required this.target,
    required this.child,
    this.overlayInset = EdgeInsets.zero,
  });

  final SettingsSearchRevealController revealController;
  final SettingsSearchTarget target;
  final Widget child;

  /// 高亮描边相对锚点区域的内缩，用于对齐调用页自己的水平留白。
  final EdgeInsetsGeometry overlayInset;

  @override
  State<SettingsSearchSectionAnchor> createState() =>
      _SettingsSearchSectionAnchorState();
}

class _SettingsSearchSectionAnchorState
    extends State<SettingsSearchSectionAnchor> {
  static const Duration _highlightDuration = Duration(milliseconds: 1200);
  static const Duration _fadeDuration = Duration(milliseconds: 220);
  static const Duration _scrollDuration = Duration(milliseconds: 260);

  Timer? _highlightTimer;
  bool _highlighted = false;

  @override
  void initState() {
    super.initState();
    widget.revealController.addListener(_handleReveal);
  }

  @override
  void didUpdateWidget(covariant SettingsSearchSectionAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealController != widget.revealController) {
      oldWidget.revealController.removeListener(_handleReveal);
      widget.revealController.addListener(_handleReveal);
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    widget.revealController.removeListener(_handleReveal);
    super.dispose();
  }

  void _handleReveal() {
    if (widget.revealController.target != widget.target) {
      return;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      context,
      alignment: 0.05,
      duration: reduceMotion ? Duration.zero : _scrollDuration,
      curve: Curves.easeOutCubic,
    );
    _highlightTimer?.cancel();
    setState(() => _highlighted = true);
    _highlightTimer = Timer(_highlightDuration, () {
      if (!mounted) {
        return;
      }
      setState(() => _highlighted = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Padding(
            padding: widget.overlayInset,
            child: IgnorePointer(
              child: AnimatedOpacity(
                key: Key('settings-search-highlight-${widget.target.name}'),
                opacity: _highlighted ? 1 : 0,
                duration: _fadeDuration,
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
