import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/network/forum_availability.dart';
import 'package:y300/core/network/yamibo_forum_transport_providers.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_glass_surface.dart';

enum ForumAvailabilityBannerVariant { docked, floating }

class ForumAvailabilityBanner extends ConsumerWidget {
  const ForumAvailabilityBanner({
    super.key,
    this.onBookshelf,
    this.variant = ForumAvailabilityBannerVariant.docked,
    this.glassLevel,
  });

  final VoidCallback? onBookshelf;
  final ForumAvailabilityBannerVariant variant;
  final AppGlassLevel? glassLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(forumAvailabilityProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eInk = EInkModeScope.of(context);
    final modeSpec = switch (availability.mode) {
      ForumAccessMode.offline => (
        status: l10n.networkOffline,
        icon: Icons.cloud_off_outlined,
      ),
      ForumAccessMode.manual => (
        status: l10n.networkCacheBrowsing,
        icon: Icons.offline_pin_outlined,
      ),
      ForumAccessMode.maintenance => (
        status: l10n.networkMaintenanceShort,
        icon: Icons.warning_amber_rounded,
      ),
      _ => null,
    };
    if (modeSpec == null) return const SizedBox.shrink();

    final textButtonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(
          AppLayoutTokens.minimumTapTarget,
          AppLayoutTokens.minimumTapTarget,
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10),
      ),
      foregroundColor: WidgetStatePropertyAll(
        eInk ? scheme.onSurface : scheme.primary,
      ),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: eInk ? NoSplash.splashFactory : null,
      animationDuration: eInk ? Duration.zero : null,
    );

    final iconButtonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(40, AppLayoutTokens.minimumTapTarget),
      ),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      foregroundColor: WidgetStatePropertyAll(scheme.onSurfaceVariant),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: eInk ? NoSplash.splashFactory : null,
      animationDuration: eInk ? Duration.zero : null,
    );

    final rowContent = Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 14,
        end: 6,
        top: 1,
        bottom: 1,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              modeSpec.icon,
              size: 16,
              color: availability.mode == ForumAccessMode.maintenance
                  ? (eInk ? scheme.onSurface : scheme.error)
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  modeSpec.status,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                  semanticsLabel:
                      availability.mode == ForumAccessMode.maintenance
                      ? l10n.networkMaintenance
                      : null,
                ),
              ),
            ),
          ),
          _CompactActionHitSlot(
            visualHeight: 36,
            child: Tooltip(
              message: l10n.networkRetry,
              excludeFromSemantics: true,
              child: TextButton(
                style: textButtonStyle,
                onPressed: () => availability.retry(
                  ref.read(yamiboHttpGatewayProvider).probeAvailability,
                ),
                child: Text(
                  l10n.commonRetry,
                  semanticsLabel: l10n.networkRetry,
                ),
              ),
            ),
          ),
          if (onBookshelf != null)
            _CompactActionHitSlot(
              visualHeight: 36,
              child: IconButton(
                tooltip: l10n.appNavigationBookshelf,
                style: iconButtonStyle,
                iconSize: 17,
                icon: const Icon(Icons.library_books_outlined),
                onPressed: onBookshelf,
              ),
            ),
          if (availability.connected)
            _CompactActionHitSlot(
              visualHeight: 36,
              child: IconButton(
                tooltip: l10n.networkLeave,
                style: iconButtonStyle,
                iconSize: 17,
                icon: const Icon(Icons.close),
                onPressed: () => availability.setManual(false),
              ),
            ),
        ],
      ),
    );

    if (variant == ForumAvailabilityBannerVariant.floating) {
      return AppGlassSurface(
        borderRadius: 19,
        level: eInk ? AppGlassLevel.off : glassLevel,
        baseColor: eInk
            ? scheme.surface
            : (theme.navigationBarTheme.backgroundColor ??
                  scheme.surfaceContainerHigh),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: rowContent,
        ),
      );
    }

    return Material(
      color: eInk
          ? scheme.surface
          : (theme.navigationBarTheme.backgroundColor ??
                scheme.surfaceContainer),
      shape: Border(
        top: BorderSide(
          color: eInk
              ? AppTheme.eInkBorderColor(scheme.brightness)
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: eInk ? 1 : 0.6,
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutTokens.readingMaxWidth,
              minHeight: 38,
            ),
            child: rowContent,
          ),
        ),
      ),
    );
  }
}

/// 维持按钮 48dp 命中区，同时将外层视觉条高收敛到 36–40dp。
class _CompactActionHitSlot extends SingleChildRenderObjectWidget {
  const _CompactActionHitSlot({required this.visualHeight, super.child});

  final double visualHeight;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderCompactActionHitSlot(visualHeight);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCompactActionHitSlot renderObject,
  ) {
    if (renderObject.visualHeight != visualHeight) {
      renderObject.visualHeight = visualHeight;
      renderObject.markNeedsLayout();
    }
  }
}

class _RenderCompactActionHitSlot extends RenderProxyBox {
  _RenderCompactActionHitSlot(this.visualHeight);

  double visualHeight;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, visualHeight));
      return;
    }
    child.layout(
      BoxConstraints(
        minWidth: constraints.minWidth,
        maxWidth: constraints.maxWidth,
        minHeight: 0,
        maxHeight: double.infinity,
      ),
      parentUsesSize: true,
    );
    size = constraints.constrain(Size(child.size.width, visualHeight));
  }

  double get _verticalOffset {
    final child = this.child;
    if (child == null) return 0;
    return (size.height - child.size.height) / 2;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.paintChild(child, offset + Offset(0, _verticalOffset));
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(0, _verticalOffset, 0, 1);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    final dy = _verticalOffset;
    if (position.dx >= 0 &&
        position.dx < size.width &&
        position.dy >= dy &&
        position.dy < dy + child.size.height) {
      return result.addWithPaintOffset(
        offset: Offset(0, dy),
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
    }
    return false;
  }
}
