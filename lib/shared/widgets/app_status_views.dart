import 'dart:async';

import 'package:flutter/material.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:prism_ui/common_button.dart' as prism_button;
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/loading.dart' as prism_loading;
import 'package:prism_ui/null_status.dart' as prism_status;
import 'package:y300/shared/widgets/app_prism_theme.dart';

/// 应用内加载、空态与错误态的公共视图。
///
/// 三个状态共用同一套居中约束、文字层级、触区与读屏节奏：加载状态延迟显示
/// 指示器，避免缓存命中时闪一下；空态与错误态沿用 prism_ui 的状态插图、
/// 标题／说明层级和可滚动布局。文案由调用方经 `AppLocalizations` 传入，
/// 组件不读取任何 App、provider 或仓储。视图只占页面背景，不额外叠卡片，
/// 与 FlClash 页面状态保持一致。
class AppLoadingState extends StatefulWidget {
  const AppLoadingState({
    super.key,
    this.label,
    this.indicatorDelay = const Duration(milliseconds: 300),
  });

  /// 加载说明；为 null 时只显示指示器。
  final String? label;

  /// 指示器出现前的静默期，快速读取不闪进度。
  final Duration indicatorDelay;

  static const Key indicatorKey = Key('app-loading-indicator');
  static const Key labelKey = Key('app-loading-label');

  @override
  State<AppLoadingState> createState() => _AppLoadingStateState();
}

class _AppLoadingStateState extends State<AppLoadingState> {
  Timer? _indicatorTimer;
  late bool _showIndicator = widget.indicatorDelay <= Duration.zero;

  @override
  void initState() {
    super.initState();
    if (!_showIndicator) {
      _indicatorTimer = Timer(widget.indicatorDelay, () {
        if (mounted) {
          setState(() => _showIndicator = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 减少动态效果时不画持续旋转的指示器，文字仍说明正在读取。
    final showIndicator = _showIndicator && !AppMotion.reduceMotion(context);
    final label = widget.label;
    return Semantics(
      container: true,
      liveRegion: _showIndicator,
      // 与视觉就绪一致：延迟结束后才把加载说明交给读屏。
      label: _showIndicator ? label : null,
      child: ExcludeSemantics(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: showIndicator
                        ? const Center(
                            child: AppPrismTheme(
                              child: prism_loading.ActivityIndicator(
                                key: AppLoadingState.indicatorKey,
                                size: 22,
                              ),
                            ),
                          )
                        : null,
                  ),
                  if (label != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        label,
                        key: AppLoadingState.labelKey,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 空态：无内容可展示时的标题、说明与可选动作。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, this.title, this.message, this.action})
    : assert(title != null || message != null, '空态至少需要标题或说明，避免出现空白区域');

  final String? title;
  final String? message;

  /// 可选动作；组件保证至少 48 逻辑像素的触区高度。
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppPrismTheme(
      child: prism_status.NullStatus(
        label: title,
        description: message,
        action: _withTouchTarget(action),
        illustration: _emptyIllustration,
      ),
    );
  }
}

/// 错误态：失败说明、重试和可选的次级动作。
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.retryKey,
    this.secondaryAction,
  });

  final String? title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  /// 重试按钮 key，供页面与测试沿用原入口定位。
  final Key? retryKey;

  /// 例如“回到首页”；与重试保持同层次、各自独立触区。
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return AppPrismTheme(
      child: prism_status.NullStatus(
        label: title,
        description: message,
        illustration: _errorIllustration,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: prism_button.FilledButton(
                key: retryKey,
                onPressed: onRetry,
                child: Text(retryLabel),
              ),
            ),
            if (secondaryAction != null) ...[
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: secondaryAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget? _withTouchTarget(Widget? action) {
  if (action == null) {
    return null;
  }
  return ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: action,
  );
}

class _AppStatusIllustration implements prism_status.Illustration {
  const _AppStatusIllustration(this.glyph, {this.isError = false});

  @override
  final Glyph glyph;

  @override
  final bool isError;
}

/// 空态插图：一个没有内容的圆角容器轮廓。
const _emptyGlyph = Glyph([
  GlyphBox(4.5, 5.5, 19.5, 18.5, 2.5, role: GlyphRole.line),
  GlyphPolyline([
    GlyphVertex(8.5, 10.5),
    GlyphVertex(15.5, 10.5),
  ], role: GlyphRole.detail),
  GlyphPolyline([
    GlyphVertex(8.5, 14.5),
    GlyphVertex(12.5, 14.5),
  ], role: GlyphRole.detail),
]);

/// 错误态插图：圆框内的感叹号。
const _errorGlyph = Glyph([
  GlyphCircle(12, 12, 8.4, role: GlyphRole.line),
  GlyphPolyline([
    GlyphVertex(12, 7.6),
    GlyphVertex(12, 12.8),
  ], role: GlyphRole.line),
  GlyphCircle(12, 16.4, 1, role: GlyphRole.line, solid: true),
]);

const _emptyIllustration = _AppStatusIllustration(_emptyGlyph);
const _errorIllustration = _AppStatusIllustration(_errorGlyph, isError: true);
