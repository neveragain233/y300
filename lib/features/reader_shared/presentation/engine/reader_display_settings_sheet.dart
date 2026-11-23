import 'package:flutter/material.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_background_resolver.dart';
import 'package:y300/features/reader_shared/presentation/reader_text_resolver.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_select_menu.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';

/// 阅读器显示设置抽屉（排版 / 主题 / 阅读三段）。
///
/// 由漫画阅读器与帖内图集引擎共用；仅产出 UI 与本地预览状态，
/// 实际持久化通过回调交回上层共享偏好控制器。
class ReaderDisplaySettingsSheet extends StatelessWidget {
  const ReaderDisplaySettingsSheet({
    super.key,
    required this.preferences,
    required this.onModeChanged,
    required this.onPageFitChanged,
    required this.onBackgroundChanged,
    required this.onPageSpacingChanged,
    this.onPageSpacingPreview,
    required this.onShowPageIndicatorChanged,
    this.onPageEffectChanged,
    this.onPageSpeedChanged,
    this.backgroundNote,
    this.pagedCanvasColor,
    this.hardwarePageKeysEnabled = false,
    this.onHardwarePageKeysChanged,
    this.fullscreenEnabled = true,
    this.onFullscreenChanged,
    this.initialTab = ReaderDisplayTab.typography,
  });

  final ReaderPreferences preferences;
  final ValueChanged<ReaderModePreference> onModeChanged;
  final ValueChanged<ReaderPageFitPreference> onPageFitChanged;
  final ValueChanged<ReaderBackgroundPreference> onBackgroundChanged;
  final ValueChanged<double> onPageSpacingChanged;
  final ValueChanged<double>? onPageSpacingPreview;
  final ValueChanged<bool> onShowPageIndicatorChanged;
  final ValueChanged<ReaderPageEffect>? onPageEffectChanged;
  final ValueChanged<ReaderPageSpeed>? onPageSpeedChanged;

  /// 横向模式下背景选项的补充说明；null 不占位。
  final String? backgroundNote;

  /// 横向模式下由阅读器固定的画布颜色，决定面板是否按常黑表面配色。
  final Color? pagedCanvasColor;

  /// 硬件键翻页开关；持久化由上层阅读器负责。
  final bool hardwarePageKeysEnabled;
  final ValueChanged<bool>? onHardwarePageKeysChanged;

  /// 沉浸全屏阅读开关；持久化由上层阅读器负责。
  final bool fullscreenEnabled;
  final ValueChanged<bool>? onFullscreenChanged;

  final ReaderDisplayTab initialTab;

  @override
  Widget build(BuildContext context) {
    return _ReaderDisplaySettingsContent(
      preferences: preferences,
      onModeChanged: onModeChanged,
      onPageFitChanged: onPageFitChanged,
      onBackgroundChanged: onBackgroundChanged,
      onPageSpacingChanged: onPageSpacingChanged,
      onPageSpacingPreview: onPageSpacingPreview,
      onShowPageIndicatorChanged: onShowPageIndicatorChanged,
      onPageEffectChanged: onPageEffectChanged,
      onPageSpeedChanged: onPageSpeedChanged,
      backgroundNote: backgroundNote,
      pagedCanvasColor: pagedCanvasColor,
      hardwarePageKeysEnabled: hardwarePageKeysEnabled,
      onHardwarePageKeysChanged: onHardwarePageKeysChanged,
      fullscreenEnabled: fullscreenEnabled,
      onFullscreenChanged: onFullscreenChanged,
      initialTab: initialTab,
    );
  }
}

/// 阅读模式快捷选择抽屉（垂直 / 左到右 / 右到左）。
class ReaderModeSheet extends StatelessWidget {
  const ReaderModeSheet({
    super.key,
    required this.currentMode,
    this.canvasBackground,
  });

  final ReaderModePreference currentMode;
  final Color? canvasBackground;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final baseTheme = Theme.of(context);
    final panelPalette = ReaderPanelPalette.fromCanvas(
      canvasBackground: canvasBackground ?? baseTheme.colorScheme.surface,
      baseTheme: baseTheme,
    );
    final modes = <(ReaderModePreference, IconData, String)>[
      (
        ReaderModePreference.vertical,
        Icons.view_stream_outlined,
        ReaderTextResolver.modeChoice(l10n, ReaderModePreference.vertical),
      ),
      (
        ReaderModePreference.ltr,
        Icons.swipe_left_outlined,
        ReaderTextResolver.modeChoice(l10n, ReaderModePreference.ltr),
      ),
      (
        ReaderModePreference.rtl,
        Icons.swipe_right_outlined,
        ReaderTextResolver.modeChoice(l10n, ReaderModePreference.rtl),
      ),
    ];

    return ReaderPanelTheme(
      palette: panelPalette,
      child: Material(
        color: panelPalette.panelSurface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    l10n.readerReadingMode,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: panelPalette.foreground),
                  ),
                ),
                AppGroupedSection(
                  margin: EdgeInsets.zero,
                  children: [
                    for (final (mode, icon, label) in modes)
                      AppGroupedRow(
                        key: ValueKey<String>('comic-reader-mode-${mode.name}'),
                        leading: Icon(icon),
                        title: label,
                        selected: mode == currentMode,
                        trailing: mode == currentMode
                            ? Icon(
                                Icons.check,
                                size: 20,
                                color: panelPalette.accent,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(mode),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderDisplaySettingsContent extends StatefulWidget {
  const _ReaderDisplaySettingsContent({
    required this.preferences,
    required this.onModeChanged,
    required this.onPageFitChanged,
    required this.onBackgroundChanged,
    required this.onPageSpacingChanged,
    required this.onPageSpacingPreview,
    required this.onShowPageIndicatorChanged,
    required this.onPageEffectChanged,
    required this.onPageSpeedChanged,
    required this.backgroundNote,
    required this.pagedCanvasColor,
    required this.hardwarePageKeysEnabled,
    required this.onHardwarePageKeysChanged,
    required this.fullscreenEnabled,
    required this.onFullscreenChanged,
    required this.initialTab,
  });

  final ReaderPreferences preferences;
  final ValueChanged<ReaderModePreference> onModeChanged;
  final ValueChanged<ReaderPageFitPreference> onPageFitChanged;
  final ValueChanged<ReaderBackgroundPreference> onBackgroundChanged;
  final ValueChanged<double> onPageSpacingChanged;
  final ValueChanged<double>? onPageSpacingPreview;
  final ValueChanged<bool> onShowPageIndicatorChanged;
  final ValueChanged<ReaderPageEffect>? onPageEffectChanged;
  final ValueChanged<ReaderPageSpeed>? onPageSpeedChanged;
  final String? backgroundNote;
  final Color? pagedCanvasColor;
  final bool hardwarePageKeysEnabled;
  final ValueChanged<bool>? onHardwarePageKeysChanged;
  final bool fullscreenEnabled;
  final ValueChanged<bool>? onFullscreenChanged;
  final ReaderDisplayTab initialTab;

  @override
  State<_ReaderDisplaySettingsContent> createState() =>
      _ReaderDisplaySettingsContentState();
}

class _ReaderDisplaySettingsContentState
    extends State<_ReaderDisplaySettingsContent> {
  late ReaderPreferences _current;
  late bool _hardwarePageKeysEnabled;
  late bool _fullscreenEnabled;

  @override
  void initState() {
    super.initState();
    _current = widget.preferences;
    _hardwarePageKeysEnabled = widget.hardwarePageKeysEnabled;
    _fullscreenEnabled = widget.fullscreenEnabled;
  }

  @override
  void didUpdateWidget(covariant _ReaderDisplaySettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences != widget.preferences) {
      _current = widget.preferences;
    }
    if (oldWidget.hardwarePageKeysEnabled != widget.hardwarePageKeysEnabled) {
      _hardwarePageKeysEnabled = widget.hardwarePageKeysEnabled;
    }
    if (oldWidget.fullscreenEnabled != widget.fullscreenEnabled) {
      _fullscreenEnabled = widget.fullscreenEnabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final baseTheme = Theme.of(context);
    final eInk = EInkModeScope.of(context);
    final effectiveBackground = effectiveReaderBackgroundPreference(
      _current.background,
      eInkMode: eInk,
    );
    final canvasBackground = resolveReaderBackground(
      themeSurface: baseTheme.colorScheme.surface,
      background: effectiveBackground,
      readerMode: _current.readerMode,
      pagedCanvasColor: widget.pagedCanvasColor,
      eInkMode: eInk,
    );
    final panelPalette = ReaderPanelPalette.fromCanvas(
      canvasBackground: canvasBackground,
      baseTheme: baseTheme,
    );
    final backgroundNote = widget.backgroundNote?.trim();
    final showBackgroundNote =
        _current.readerMode != ReaderModePreference.vertical &&
        backgroundNote != null &&
        backgroundNote.isNotEmpty;
    final summary =
        '${ReaderTextResolver.pageFit(l10n, _current.pageFit)} · '
        '${_current.pageSpacing.round()}${l10n.readerUnitPixel} · '
        '${ReaderTextResolver.background(l10n, effectiveBackground)} · '
        '${ReaderTextResolver.mode(l10n, _current.readerMode)}';

    return ReaderDisplayPanel(
      panelKey: const Key('comic-reader-display-settings-sheet'),
      palette: panelPalette,
      initialTab: widget.initialTab,
      summary: summary,
      typographyChildren: [
        ReaderOptionRow<ReaderPageFitPreference>(
          label: l10n.readerPageFit,
          value: _current.pageFit,
          options: [
            for (final fit in ReaderPageFitPreference.values)
              (fit, ReaderTextResolver.pageFit(l10n, fit)),
          ],
          onChanged: (value) {
            setState(() => _current = _current.copyWith(pageFit: value));
            widget.onPageFitChanged(value);
          },
        ),
        ReaderStepper(
          key: const Key('comic-reader-page-spacing-stepper'),
          keyPrefix: 'comic-reader-page-spacing',
          label: l10n.readerPageSpacing,
          value: _current.pageSpacing.clamp(0.0, 48.0).toDouble(),
          min: 0,
          max: 48,
          step: 4,
          fractionDigits: 0,
          unit: l10n.readerUnitPixel,
          onChanged: (value) {
            setState(() => _current = _current.copyWith(pageSpacing: value));
            widget.onPageSpacingPreview?.call(value);
          },
          onChangeEnd: widget.onPageSpacingChanged,
        ),
      ],
      themeChildren: [
        ReaderOptionRow<ReaderBackgroundPreference>(
          label: l10n.readerBackground,
          value: effectiveBackground,
          options: [
            for (final bg
                in eInk
                    ? const <ReaderBackgroundPreference>[
                        ReaderBackgroundPreference.followTheme,
                        ReaderBackgroundPreference.white,
                        ReaderBackgroundPreference.black,
                      ]
                    : ReaderBackgroundPreference.values)
              (bg, ReaderTextResolver.background(l10n, bg)),
          ],
          onChanged: (value) {
            setState(() => _current = _current.copyWith(background: value));
            widget.onBackgroundChanged(value);
          },
        ),
        if (showBackgroundNote)
          Padding(
            key: const Key('comic-reader-paged-background-note'),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Builder(
              builder: (context) {
                final variant = Theme.of(context).colorScheme.onSurfaceVariant;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: variant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        backgroundNote,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: variant),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
      readingChildren: [
        ReaderOptionRow<ReaderModePreference>(
          label: l10n.readerReadingMode,
          value: _current.readerMode,
          options: [
            for (final mode in ReaderModePreference.values)
              (mode, ReaderTextResolver.mode(l10n, mode)),
          ],
          onChanged: (value) {
            setState(() => _current = _current.copyWith(readerMode: value));
            widget.onModeChanged(value);
          },
        ),
        if (_current.readerMode != ReaderModePreference.vertical &&
            !eInk &&
            widget.onPageEffectChanged != null &&
            widget.onPageSpeedChanged != null)
          _ImagePagedEffectSpeedRow(
            effectLabel: l10n.novelPageEffect,
            effect: _current.pageEffect,
            effectOptions: [
              for (final effect in ReaderPageEffect.values)
                AppSelectOption(
                  value: effect,
                  label: ReaderTextResolver.pageEffect(l10n, effect),
                ),
            ],
            onEffectChanged: (value) {
              setState(() => _current = _current.copyWith(pageEffect: value));
              widget.onPageEffectChanged?.call(value);
            },
            speedLabel: l10n.novelPageSpeed,
            speed: _current.pageSpeed,
            speedOptions: [
              for (final speed in ReaderPageSpeed.values)
                AppSelectOption(
                  value: speed,
                  label: ReaderTextResolver.pageSpeed(l10n, speed),
                ),
            ],
            onSpeedChanged: (value) {
              setState(() => _current = _current.copyWith(pageSpeed: value));
              widget.onPageSpeedChanged?.call(value);
            },
          ),
        AppSwitchRow(
          key: const Key('comic-reader-page-indicator-switch'),
          title: l10n.readerPageIndicator,
          value: _current.showPageIndicator,
          onChanged: (value) {
            setState(
              () => _current = _current.copyWith(showPageIndicator: value),
            );
            widget.onShowPageIndicatorChanged(value);
          },
        ),
        AppSwitchRow(
          key: const Key('comic-reader-fullscreen-switch'),
          title: l10n.readerImmersiveFullscreen,
          subtitle: l10n.readerImmersiveFullscreenSubtitle,
          value: _fullscreenEnabled,
          onChanged: widget.onFullscreenChanged == null
              ? null
              : (value) {
                  setState(() => _fullscreenEnabled = value);
                  widget.onFullscreenChanged!(value);
                },
        ),
        AppSwitchRow(
          key: const Key('comic-reader-hardware-page-keys-switch'),
          title: l10n.readerHardwarePageKeys,
          subtitle: l10n.readerHardwarePageKeysSubtitle,
          value: _hardwarePageKeysEnabled,
          onChanged: widget.onHardwarePageKeysChanged == null
              ? null
              : (value) {
                  setState(() => _hardwarePageKeysEnabled = value);
                  widget.onHardwarePageKeysChanged!(value);
                },
        ),
      ],
    );
  }
}

class _ImagePagedEffectSpeedRow extends StatelessWidget {
  const _ImagePagedEffectSpeedRow({
    required this.effectLabel,
    required this.effect,
    required this.effectOptions,
    required this.onEffectChanged,
    required this.speedLabel,
    required this.speed,
    required this.speedOptions,
    required this.onSpeedChanged,
  });

  final String effectLabel;
  final ReaderPageEffect effect;
  final List<AppSelectOption<ReaderPageEffect>> effectOptions;
  final ValueChanged<ReaderPageEffect> onEffectChanged;
  final String speedLabel;
  final ReaderPageSpeed speed;
  final List<AppSelectOption<ReaderPageSpeed>> speedOptions;
  final ValueChanged<ReaderPageSpeed> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(effectLabel, style: labelStyle),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: AppSelectMenu<ReaderPageEffect>(
                        key: const Key('comic-reader-page-effect-select'),
                        value: effect,
                        options: effectOptions,
                        onSelected: onEffectChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Text(speedLabel, style: labelStyle),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: AppSelectMenu<ReaderPageSpeed>(
                        key: const Key('comic-reader-page-speed-select'),
                        value: speed,
                        options: speedOptions,
                        onSelected: onSpeedChanged,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
