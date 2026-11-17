import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_toolbar_actions.dart';

/// 帖子详情顶栏：固定两行高度，按正文首楼标题的可读性切换主行。
///
/// 初始状态主行是板块名；首楼标题滚出正文可读区后，主行换成帖子标题，次行用
/// 辅助色保持板块名。两行高度始终预留，切换不改变顶栏高度，正文不会被推动或
/// 重新挂载。表面沿用主题 `appBarTheme`，不另铺强调色。
class ThreadDetailAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ThreadDetailAppBar({
    super.key,
    required this.toolbarHeight,
    required this.forumName,
    this.initialForumName,
    required this.subject,
    required this.showSubject,
    this.leading,
    this.actions = const [],
    required this.onCopyLink,
  });

  /// 两行标题的顶栏高度，由 [resolveToolbarHeight] 按当前字号换算。
  final double toolbarHeight;
  final String? forumName;
  final String? initialForumName;
  final String subject;
  final ValueListenable<bool> showSubject;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback onCopyLink;

  static const Key titleMainKey = Key('thread-detail-appbar-title-main');
  static const Key titleForumKey = Key('thread-detail-appbar-title-forum');
  static const Key copyLinkAreaKey = Key('thread-detail-appbar-copy-link-area');

  /// 两行预留的最小高度；字号放大时按实际行高增加。
  static const double minimumToolbarHeight = 64;

  /// 主行与副行的行高、行距基准，[resolveToolbarHeight] 与标题共用。
  static const double mainLineHeightFactor = 1.25;
  static const double supportingLineHeightFactor = 1.3;
  static const double lineGap = 2;
  static const double verticalPadding = 8;

  static const Duration transitionDuration = Duration(milliseconds: 150);

  /// 标题随系统字号真实放大，顶栏按同一 `textScaler` 增长；变高由页面重算
  /// `toolbarHeight` 承担，标题区也不设字号上限。
  static double _mainLineHeight(BuildContext context) {
    final theme = Theme.of(context);
    final fontSize =
        theme.appBarTheme.titleTextStyle?.fontSize ??
        theme.textTheme.titleLarge?.fontSize ??
        20;
    return MediaQuery.textScalerOf(context).scale(fontSize) *
        mainLineHeightFactor;
  }

  static double _supportingLineHeight(BuildContext context) {
    final fontSize = Theme.of(context).textTheme.labelMedium?.fontSize ?? 12;
    return MediaQuery.textScalerOf(context).scale(fontSize) *
        supportingLineHeightFactor;
  }

  static double resolveToolbarHeight(BuildContext context) {
    final content =
        _mainLineHeight(context) + lineGap + _supportingLineHeight(context);
    return math.max(minimumToolbarHeight, content + verticalPadding * 2);
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final forumLabel = _resolveForumLabel(context);
    final subjectLabel = _resolveSubjectLabel(context);
    return AppBar(
      toolbarHeight: toolbarHeight,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: leading == null ? 16 : 2,
      leading: leading,
      // AppBar 默认把标题字号截到 1.34 倍，这里显式恢复页面字号；
      // 顶栏高度已按同一 textScaler 预留两行，不再需要那层保护。
      title: MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: MediaQuery.textScalerOf(context)),
        child: GestureDetector(
          key: copyLinkAreaKey,
          behavior: HitTestBehavior.opaque,
          onLongPress: onCopyLink,
          child: SizedBox(
            width: double.infinity,
            height: toolbarHeight,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _ThreadDetailAppBarTitle(
                forumLabel: forumLabel,
                subjectLabel: subjectLabel,
                showSubject: showSubject,
              ),
            ),
          ),
        ),
      ),
      actions: actions.isEmpty ? null : [AppToolbarActions(children: actions)],
    );
  }

  /// 板块名优先取正文投影，其次沿用入口带下来的板块名，最后退回本地化标题。
  String _resolveForumLabel(BuildContext context) {
    final parsed = forumName?.trim();
    if (parsed != null && parsed.isNotEmpty) return parsed;
    final initial = initialForumName?.trim();
    if (initial != null && initial.isNotEmpty) return initial;
    return AppLocalizations.of(context).threadDetailTitle;
  }

  /// 帖子标题取当前显示投影，确无标题时退回本地化详情标题。
  String _resolveSubjectLabel(BuildContext context) {
    final parsed = subject.trim();
    return parsed.isNotEmpty
        ? parsed
        : AppLocalizations.of(context).threadDetailTitle;
  }
}

class _ThreadDetailAppBarTitle extends StatelessWidget {
  const _ThreadDetailAppBarTitle({
    required this.forumLabel,
    required this.subjectLabel,
    required this.showSubject,
  });

  final String forumLabel;
  final String subjectLabel;
  final ValueListenable<bool> showSubject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mainStyle =
        (theme.appBarTheme.titleTextStyle ??
                theme.textTheme.titleLarge ??
                const TextStyle())
            .copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: ThreadDetailAppBar.mainLineHeightFactor,
            );
    final supportingStyle =
        theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          height: ThreadDetailAppBar.supportingLineHeightFactor,
        ) ??
        TextStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
          height: ThreadDetailAppBar.supportingLineHeightFactor,
        );
    return ValueListenableBuilder<bool>(
      valueListenable: showSubject,
      builder: (context, showingSubject, _) {
        final mainLabel = showingSubject ? subjectLabel : forumLabel;
        // 初始只显示板块名时按顶栏高度上下居中；帖子标题接管后显示两行，
        // 两行整体居中。顶栏高度固定，切换不会推动正文。
        final mainTitle = Text(
          mainLabel,
          key: ThreadDetailAppBar.titleMainKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          semanticsLabel: mainLabel,
          style: mainStyle,
        );
        final block = showingSubject
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  mainTitle,
                  const SizedBox(height: ThreadDetailAppBar.lineGap),
                  Text(
                    forumLabel,
                    key: ThreadDetailAppBar.titleForumKey,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    semanticsLabel: forumLabel,
                    style: supportingStyle,
                  ),
                ],
              )
            : mainTitle;
        if (MediaQuery.disableAnimationsOf(context)) {
          return block;
        }
        return AnimatedSwitcher(
          duration: ThreadDetailAppBar.transitionDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          // 入场块淡入期间也立即进入语义树；离场块由 layoutBuilder 排除，
          // 切换窗口内读屏只拿到当前状态的一份标题。
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            alwaysIncludeSemantics: true,
            child: child,
          ),
          // 两种高度都以顶栏中心为基准，淡出层不改变点击区和顶栏高度。
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              for (final child in previousChildren)
                ExcludeSemantics(child: child),
              ?currentChild,
            ],
          ),
          child: KeyedSubtree(
            key: ValueKey<bool>(showingSubject),
            child: block,
          ),
        );
      },
    );
  }
}

/// 观测首楼标题在正文可读区顶部的位置，驱动顶栏主行切换。
///
/// 页面在滚动与布局通知后调用 [schedule]；几何读取发生在 post-frame，由代次和
/// 挂载判断丢弃迟到帧，翻页或换帖后不会污染新状态。首楼标题不在当前渲染序列
/// （跳楼、目标居中、已被列表回收）时视为滚出可读区。
final class ThreadDetailScrollTitleObserver {
  ThreadDetailScrollTitleObserver({required bool Function() isMounted})
    : _isMounted = isMounted;

  /// 首楼标题测点，由正文卡片或分块 header 两条渲染路径挂载。
  final GlobalKey titleKey = GlobalKey(
    debugLabel: 'thread-detail-first-post-title-anchor',
  );

  /// 正文视口测点，用作可读区顶边。
  final GlobalKey viewportKey = GlobalKey(
    debugLabel: 'thread-detail-body-viewport',
  );

  /// 首楼标题滚出可读区后为 true，顶栏主行显示帖子标题。
  final ValueNotifier<bool> showSubject = ValueNotifier<bool>(false);

  /// 临界点两侧各保留的滞回量，标题贴边时不反复切换。
  static const double hysteresis = 4;

  final bool Function() _isMounted;
  bool _tracking = false;
  bool _forceSubject = false;
  bool _scheduled = false;
  int _generation = 0;

  /// 页面结构声明：当前是否可能看到首楼标题，以及是否已因翻页/倒序直接显示标题。
  void updateStructure({required bool tracks, required bool forceSubject}) {
    _tracking = tracks;
    _forceSubject = forceSubject;
    schedule();
  }

  void schedule() {
    if (_scheduled) return;
    _scheduled = true;
    final generation = _generation;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (generation != _generation || !_isMounted()) return;
      _apply();
    });
  }

  /// 换帖或路由身份变化：丢弃在途测量，回到板块名初始状态。
  void reset() {
    _generation++;
    _scheduled = false;
    _tracking = false;
    _forceSubject = false;
    _set(false);
  }

  void dispose() {
    _generation++;
    showSubject.dispose();
  }

  void _apply() {
    if (_forceSubject) {
      _set(true);
      return;
    }
    if (!_tracking) return;
    final viewportContext = viewportKey.currentContext;
    if (viewportContext == null) return;
    final titleContext = titleKey.currentContext;
    if (titleContext == null) {
      _set(true);
      return;
    }
    final titleBox = titleContext.findRenderObject();
    final viewportBox = viewportContext.findRenderObject();
    if (titleBox is! RenderBox ||
        viewportBox is! RenderBox ||
        !titleBox.attached ||
        !titleBox.hasSize ||
        !viewportBox.attached ||
        !viewportBox.hasSize) {
      // 布局未完成时保留上一结果，避免中间帧写入错误状态。
      return;
    }
    final titleBottom = titleBox
        .localToGlobal(Offset(0, titleBox.size.height))
        .dy;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    if (!showSubject.value) {
      if (titleBottom < viewportTop - hysteresis) _set(true);
    } else if (titleBottom > viewportTop + hysteresis) {
      _set(false);
    }
  }

  void _set(bool value) {
    if (showSubject.value == value) return;
    showSubject.value = value;
  }
}
