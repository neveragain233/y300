import 'package:flutter/material.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

/// 外观页顶部的实时预览与各选项缩略图共用同一套迷你首页画面。
///
/// 画面只使用传入的 [ThemeData] 绘制根页大标题、搜索条、论坛卡片和底栏示意，
/// 不读取论坛、书架或账号仓库，也不加载头像与网络图片。缩略图由调用方包在
/// `ExcludeSemantics` 内，读屏只读选项本身。
class MiniHomePreview extends StatelessWidget {
  const MiniHomePreview({
    super.key,
    required this.theme,
    this.title,
    this.glassLevel = AppGlassLevel.off,
    this.navigationStyle = AppNavigationBarStyle.immersive,
    this.useGlassShell = false,
  });

  /// 当前解析出的主题；所有颜色、表面和文字都从它取值。
  final ThemeData theme;

  /// 根页大标题文字；缩略图不传时改画抽象的标题条。
  final String? title;

  /// 底栏示意的玻璃档位；顶部预览把它交给唯一的玻璃外壳。
  final AppGlassLevel glassLevel;

  final AppNavigationBarStyle navigationStyle;

  /// 只有顶部预览使用真实玻璃外壳；缩略卡用实底加高光近似。
  final bool useGlassShell;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    // 迷你首页是固定尺寸的示意图，字号不随系统文字缩放增长，避免溢出。
    return MediaQuery.withNoTextScaling(
      child: ColoredBox(
        key: const Key('appearance-preview-page'),
        color: theme.scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                )
              else
                _PreviewBar(
                  height: 9,
                  widthFactor: 0.5,
                  color: scheme.onSurface,
                ),
              const SizedBox(height: 8),
              Container(
                key: const Key('appearance-preview-search'),
                height: 16,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 6),
                    child: _PreviewBar(
                      height: 4,
                      widthFactor: 0.1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _PreviewCard(
                scheme: scheme,
                cardKey: 'appearance-preview-card-0',
              ),
              const SizedBox(height: 8),
              _PreviewCard(
                scheme: scheme,
                cardKey: 'appearance-preview-card-1',
              ),
              const SizedBox(height: 8),
              Row(
                key: const Key('appearance-preview-group-strip'),
                children: [
                  for (var index = 0; index < 3; index++) ...[
                    if (index > 0) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 13,
                        decoration: BoxDecoration(
                          color: index == 0
                              ? scheme.primary.withValues(alpha: 0.18)
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              _BottomBar(
                theme: theme,
                glassLevel: glassLevel,
                navigationStyle: navigationStyle,
                useGlassShell: useGlassShell,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// 跟随系统明暗的左右分屏缩略图：左浅右深，共用同一构图。
class SplitMiniHomePreview extends StatelessWidget {
  const SplitMiniHomePreview({
    super.key,
    required this.light,
    required this.dark,
  });

  final ThemeData light;
  final ThemeData dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: MiniHomePreview(theme: light)),
        Expanded(child: MiniHomePreview(theme: dark)),
      ],
    );
  }
}

/// 顶部实时预览：168 逻辑像素宽、9:17 的手机框，主题变化后交叉淡化。
///
/// [previewKey] 只由设置快照与主题输入派生，MaterialApp 的主题插值不会
/// 触发新的淡化；淡化期间旧画面保留自己的 [ThemeData]。减少动态效果时
/// 直接切换。
class AppearanceLivePreview extends StatelessWidget {
  const AppearanceLivePreview({
    super.key,
    required this.theme,
    required this.glassLevel,
    required this.navigationStyle,
    required this.previewKey,
    this.title,
    this.semanticsLabel,
  });

  static const double width = 168;
  static const double height = width * 17 / 9;
  static const Duration fadeDuration = Duration(milliseconds: 240);

  final ThemeData theme;
  final AppGlassLevel glassLevel;
  final AppNavigationBarStyle navigationStyle;
  final String previewKey;
  final String? title;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scene = RepaintBoundary(
      key: ValueKey<String>(previewKey),
      child: _PhoneFrame(
        theme: theme,
        child: MiniHomePreview(
          theme: theme,
          title: title,
          glassLevel: glassLevel,
          navigationStyle: navigationStyle,
          useGlassShell: true,
        ),
      ),
    );
    final preview = SizedBox(
      key: const Key('appearance-preview'),
      width: width,
      height: height,
      child: reduceMotion
          ? scene
          : AnimatedSwitcher(
              duration: fadeDuration,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: scene,
            ),
    );
    if (semanticsLabel == null) {
      return preview;
    }
    return Semantics(
      label: semanticsLabel,
      image: true,
      child: ExcludeSemantics(child: preview),
    );
  }
}

/// 缩略卡中的候选主题迷你屏，固定 9:17 并带细描边。
///
/// 迷你屏按顶部预览的 168 逻辑像素构图，再整体缩放到缩略卡尺寸；窄屏和
/// 三、四列排布下不会因为画面内部行宽过小而出错。
class MiniHomeThumb extends StatelessWidget {
  const MiniHomeThumb({super.key, required this.child});

  static const double _referenceWidth = AppearanceLivePreview.width;
  static const double _referenceHeight = AppearanceLivePreview.height;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 9 / 17,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: _referenceWidth,
            height: _referenceHeight,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 玻璃档位缩略图：同色实底加高光近似，不在缩略卡建立玻璃捕获。
class GlassLevelThumb extends StatelessWidget {
  const GlassLevelThumb({super.key, required this.theme, required this.level});

  final ThemeData theme;
  final AppGlassLevel level;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final tinted = level != AppGlassLevel.off;
    final highlight = scheme.brightness == Brightness.light
        ? Colors.white.withValues(
            alpha: level == AppGlassLevel.enhanced ? 0.55 : 0.35,
          )
        : Colors.white.withValues(
            alpha: level == AppGlassLevel.enhanced ? 0.28 : 0.16,
          );
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < 2; index++) ...[
            if (index > 0) const SizedBox(height: 6),
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
          const Spacer(),
          Container(
            key: Key('appearance-glass-thumb-${level.name}'),
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: tinted
                  ? scheme.surfaceContainerHigh.withValues(alpha: 0.82)
                  : (theme.navigationBarTheme.backgroundColor ??
                        scheme.surfaceContainer),
              border: Border.all(
                color: tinted
                    ? highlight
                    : scheme.outlineVariant.withValues(alpha: 0.6),
                width: tinted ? 1 : 0.8,
              ),
              gradient: tinted
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(
                          alpha: level == AppGlassLevel.enhanced ? 0.30 : 0.18,
                        ),
                        Colors.transparent,
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.theme, required this.child});

  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Center(
      child: Container(
        width: AppearanceLivePreview.width,
        height: AppearanceLivePreview.height,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(
                alpha: scheme.brightness == Brightness.dark ? 0.24 : 0.10,
              ),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(25), child: child),
      ),
    );
  }
}

/// 导航样式缩略：只画页面底部区域，区分沉浸式悬浮胶囊与旧式整条底栏。
class NavigationStyleSample extends StatelessWidget {
  const NavigationStyleSample({
    super.key,
    required this.theme,
    required this.style,
  });

  final ThemeData theme;
  final AppNavigationBarStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final immersive = style == AppNavigationBarStyle.immersive;
    final destination = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        shape: BoxShape.circle,
      ),
    );
    final selected = Container(
      width: 16,
      height: 10,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(5),
      ),
    );
    final bar = Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: immersive
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.9)
            : (theme.navigationBarTheme.backgroundColor ??
                  scheme.surfaceContainer),
        borderRadius: immersive ? BorderRadius.circular(11) : null,
        border: immersive
            ? Border.all(color: scheme.outlineVariant, width: 0.6)
            : Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [selected, destination, destination, destination],
      ),
    );
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PreviewBar(height: 5, widthFactor: 0.44, color: scheme.onSurface),
          const SizedBox(height: 5),
          _PreviewBar(
            height: 5,
            widthFactor: 0.78,
            color: scheme.onSurfaceVariant,
          ),
          const Spacer(),
          if (immersive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: bar,
            )
          else
            Padding(padding: const EdgeInsets.only(bottom: 6), child: bar),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.theme,
    required this.glassLevel,
    required this.navigationStyle,
    required this.useGlassShell,
  });

  final ThemeData theme;
  final AppGlassLevel glassLevel;
  final AppNavigationBarStyle navigationStyle;
  final bool useGlassShell;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final destinations = _destinations(scheme);
    if (navigationStyle == AppNavigationBarStyle.legacy) {
      return Container(
        key: const Key('appearance-preview-navigation'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:
              theme.navigationBarTheme.backgroundColor ??
              scheme.surfaceContainer,
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: destinations,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: AppGlassSurface(
        level: useGlassShell ? glassLevel : AppGlassLevel.off,
        borderRadius: 14,
        elevation: 2,
        baseColor: scheme.surfaceContainerHigh,
        child: SizedBox(
          key: const Key('appearance-preview-navigation'),
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: destinations,
          ),
        ),
      ),
    );
  }

  List<Widget> _destinations(ColorScheme scheme) {
    return [
      for (var index = 0; index < 4; index++)
        if (index == 0)
          Container(
            key: const Key('appearance-preview-nav-selected'),
            width: 20,
            height: 14,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(7),
            ),
          )
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
          ),
    ];
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.scheme, required this.cardKey});

  final ColorScheme scheme;
  final String cardKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(cardKey),
      height: 42,
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PreviewBar(height: 6, widthFactor: 0.62, color: scheme.onSurface),
          const SizedBox(height: 5),
          _PreviewBar(
            height: 4,
            widthFactor: 0.94,
            color: scheme.onSurfaceVariant,
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 26,
              height: 5,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({
    required this.height,
    required this.widthFactor,
    required this.color,
  });

  final double height;
  final double widthFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}
