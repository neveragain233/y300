import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/features/fonts/fonts.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/domain/models/novel_reader_spacing.dart';
import 'package:y300/features/novel/presentation/controllers/novel_chapter_interactions_dock_controller.dart';
import 'package:y300/features/novel/presentation/novel_text_resolver.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_display_resolvers.dart';
import 'package:y300/features/reader_shared/presentation/reader_preferences/hardware_page_keys_provider.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_select_menu.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

class NovelReaderDisplaySettingsSheet extends StatefulWidget {
  const NovelReaderDisplaySettingsSheet({
    super.key,
    required this.initialPreferences,
    required this.onPreferencesChanged,
    this.onPreferencesCommitted,
    this.fontPreviewStyle,
    this.initialTab = ReaderDisplayTab.typography,
  });

  final NovelReaderPreferences initialPreferences;
  final ValueChanged<NovelReaderPreferences> onPreferencesChanged;
  final ValueChanged<NovelReaderPreferences>? onPreferencesCommitted;
  final TextStyle? fontPreviewStyle;
  final ReaderDisplayTab initialTab;

  @override
  State<NovelReaderDisplaySettingsSheet> createState() =>
      _NovelReaderDisplaySettingsSheetState();
}

class _NovelReaderDisplaySettingsSheetState
    extends State<NovelReaderDisplaySettingsSheet> {
  static const NovelReaderThemeResolver _themeResolver =
      NovelReaderThemeResolver();

  late NovelReaderPreferences _draft;
  int _fontRequest = 0;
  bool _isChoosingFont = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialPreferences;
  }

  @override
  void didUpdateWidget(covariant NovelReaderDisplaySettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPreferences != widget.initialPreferences ||
        oldWidget.onPreferencesChanged != widget.onPreferencesChanged) {
      // A replacement settings owner must not receive the old picker's result.
      _fontRequest++;
      _isChoosingFont = false;
      if (oldWidget.initialPreferences != widget.initialPreferences) {
        _draft = widget.initialPreferences;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final baseTheme = Theme.of(context);
    final eInk = EInkModeScope.of(context);
    final effectivePreset = NovelReaderThemeResolver.effectivePreset(
      _draft.themePreset,
      eInkMode: eInk,
    );
    final novelPalette = _themeResolver.resolve(
      preferences: _draft,
      theme: baseTheme,
      eInkMode: eInk,
    );
    final panelPalette = ReaderPanelPalette.fromNovelPalette(
      brightness: novelPalette.brightness,
      background: novelPalette.background,
      surface: novelPalette.surface,
      foreground: novelPalette.controlForeground,
      muted: novelPalette.controlMuted,
      accent: novelPalette.accent,
      baseTheme: baseTheme,
    );
    final summary =
        '${_draft.fontSize.toStringAsFixed(1)}${l10n.readerUnitPoint} · '
        '${_draft.lineHeight.toStringAsFixed(2)}${l10n.readerUnitMultiple} · '
        '${_paragraphIndentLabel(l10n, _draft.paragraphIndent)} · '
        '${_themeLabel(l10n, effectivePreset)}';

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: ReaderDisplayPanel(
        panelKey: const Key('novel-reader-display-settings-sheet'),
        palette: panelPalette,
        initialTab: widget.initialTab,
        summary: summary,
        typographyChildren: _buildTypographyTab(l10n),
        themeChildren: _buildThemeTab(
          l10n,
          eInk: eInk,
          effectivePreset: effectivePreset,
        ),
        readingChildren: _buildReadingTab(l10n),
      ),
    );
  }

  List<Widget> _buildTypographyTab(AppLocalizations l10n) {
    return [
      AppGroupedRow(
        key: const Key('novel-reader-font-selector'),
        title: l10n.fontSelectorTitle,
        subtitle: _draft.fontFamily == FontIdentity.system
            ? l10n.fontSelectorSystemDefault
            : l10n.novelCustomFont,
        showChevron: true,
        minHeight: 50,
        onTap: _isChoosingFont ? null : _chooseFont,
      ),
      ReaderStepper(
        key: const Key('novel-reader-font-size-stepper'),
        keyPrefix: 'novel-reader-font-size',
        label: l10n.novelFontSize,
        value: _draft.fontSize,
        min: 14,
        max: 30,
        step: 0.5,
        fractionDigits: 1,
        unit: l10n.readerUnitPoint,
        onChanged: (value) =>
            _applyPreferences(_draft.copyWith(fontSize: _snap(value, 0.5))),
        onChangeEnd: (value) => _commitStepperPreferences(
          _draft.copyWith(fontSize: _snap(value, 0.5)),
        ),
      ),
      ReaderStepper(
        key: const Key('novel-reader-line-height-stepper'),
        keyPrefix: 'novel-reader-line-height',
        label: l10n.novelLineSpacing,
        value: _draft.lineHeight,
        min: 1.2,
        max: 2.4,
        step: 0.05,
        fractionDigits: 2,
        unit: l10n.readerUnitMultiple,
        onChanged: (value) =>
            _applyPreferences(_draft.copyWith(lineHeight: _snap(value, 0.05))),
        onChangeEnd: (value) => _commitStepperPreferences(
          _draft.copyWith(lineHeight: _snap(value, 0.05)),
        ),
      ),
      ReaderStepper(
        key: const Key('novel-reader-page-padding-stepper'),
        keyPrefix: 'novel-reader-page-padding',
        label: l10n.novelPagePadding,
        value: _draft.pagePadding,
        min: NovelReaderSpacing.minimumPagePadding,
        max: NovelReaderSpacing.maximumPagePadding,
        step: 1,
        fractionDigits: 0,
        unit: l10n.readerUnitPixel,
        onChanged: (value) =>
            _applyPreferences(_draft.copyWith(pagePadding: _snap(value, 1))),
        onChangeEnd: (value) => _commitStepperPreferences(
          _draft.copyWith(pagePadding: _snap(value, 1)),
        ),
      ),
      ReaderOptionRow<NovelReaderParagraphIndentMode>(
        key: const Key('novel-reader-paragraph-indent-control'),
        label: l10n.novelParagraphIndent,
        stacked: true,
        value: _draft.paragraphIndent,
        options: [
          for (final mode in NovelReaderParagraphIndentMode.values)
            (mode, _paragraphIndentLabel(l10n, mode)),
        ],
        onChanged: (value) =>
            _applyPreferences(_draft.copyWith(paragraphIndent: value)),
      ),
    ];
  }

  List<Widget> _buildThemeTab(
    AppLocalizations l10n, {
    required bool eInk,
    required NovelReaderThemePreset effectivePreset,
  }) {
    final presets = eInk
        ? NovelReaderThemeResolver.eInkPresets
        : NovelReaderThemePreset.values;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final preset in presets)
              _ThemeChip(
                key: Key('novel-theme-${_themeKey(preset)}'),
                label: _themeLabel(l10n, preset),
                selected: effectivePreset == preset,
                onSelected: () =>
                    _applyPreferences(_draft.copyWith(themePreset: preset)),
              ),
          ],
        ),
      ),
      ReaderStepper(
        key: const Key('novel-reader-body-brightness-stepper'),
        keyPrefix: 'novel-reader-body-brightness',
        label: l10n.novelBodyBrightness,
        value: _draft.bodyBrightness,
        min: NovelReaderPreferences.minimumBodyBrightness,
        max: NovelReaderPreferences.maximumBodyBrightness,
        step: 0.05,
        displayScale: 100,
        fractionDigits: 0,
        unit: l10n.readerUnitPercent,
        onChanged: (value) => _applyPreferences(
          _draft.copyWith(bodyBrightness: _snap(value, 0.05)),
        ),
        onChangeEnd: (value) => _commitStepperPreferences(
          _draft.copyWith(bodyBrightness: _snap(value, 0.05)),
        ),
      ),
      if (!eInk)
        ReaderOptionRow<NovelReaderBackgroundTexture>(
          key: const Key('novel-reader-background-texture-control'),
          label: l10n.novelBackgroundTexture,
          value: _draft.backgroundTexture,
          options: [
            for (final texture in NovelReaderBackgroundTexture.values)
              (texture, _textureLabel(l10n, texture)),
          ],
          onChanged: (value) =>
              _applyPreferences(_draft.copyWith(backgroundTexture: value)),
        ),
      ReaderOptionRow<NovelReaderBodyColorMode>(
        key: const Key('novel-reader-body-color-mode-control'),
        label: l10n.novelBodyColor,
        stacked: true,
        value: _draft.bodyColorMode,
        options: [
          for (final mode in NovelReaderBodyColorMode.values)
            (mode, _bodyColorLabel(l10n, mode)),
        ],
        onChanged: (value) =>
            _applyPreferences(_draft.copyWith(bodyColorMode: value)),
      ),
    ];
  }

  List<Widget> _buildReadingTab(AppLocalizations l10n) {
    return [
      ReaderOptionRow<NovelReaderFlowMode>(
        key: const Key('novel-reader-flow-mode-control'),
        label: l10n.novelReadingMode,
        value: _draft.flowMode,
        options: [
          for (final mode in NovelReaderFlowMode.values)
            (mode, NovelTextResolver.flowMode(l10n, mode)),
        ],
        onChanged: (value) =>
            _applyPreferences(_draft.copyWith(flowMode: value)),
      ),
      if (_draft.flowMode != NovelReaderFlowMode.vertical)
        _PagedEffectSpeedRow(
          effectLabel: l10n.novelPageEffect,
          effect: _draft.pageEffect,
          effectOptions: [
            for (final effect in NovelReaderPageEffect.values)
              AppSelectOption(
                value: effect,
                label: NovelTextResolver.pageEffect(l10n, effect),
              ),
          ],
          onEffectChanged: (value) =>
              _applyPreferences(_draft.copyWith(pageEffect: value)),
          speedLabel: l10n.novelPageSpeed,
          speed: _draft.pageSpeed,
          speedOptions: [
            for (final speed in NovelReaderPageSpeed.values)
              AppSelectOption(
                value: speed,
                label: NovelTextResolver.pageSpeed(l10n, speed),
              ),
          ],
          onSpeedChanged: (value) =>
              _applyPreferences(_draft.copyWith(pageSpeed: value)),
        ),
      ReaderOptionRow<NovelReaderConversionMode>(
        key: const Key('novel-reader-conversion-mode-control'),
        label: l10n.novelConversionMode,
        value: _draft.conversionMode,
        options: [
          for (final mode in NovelReaderConversionMode.values)
            (mode, NovelTextResolver.conversionMode(l10n, mode)),
        ],
        onChanged: (value) =>
            _applyPreferences(_draft.copyWith(conversionMode: value)),
      ),
      AppSwitchRow(
        switchKey: const Key('novel-reader-safe-area-switch'),
        title: l10n.novelSafeContent,
        value: _draft.safeAreaEnabled,
        onChanged: (value) =>
            _applyPreferences(_draft.copyWith(safeAreaEnabled: value)),
      ),
      Consumer(
        builder: (context, ref, _) {
          final enabled = ref.watch(hardwarePageKeysEnabledProvider);
          return AppSwitchRow(
            switchKey: const Key('novel-reader-hardware-page-keys-switch'),
            title: l10n.readerHardwarePageKeys,
            value: enabled.value ?? false,
            onChanged: enabled.value == null
                ? null
                : (value) {
                    unawaited(
                      ref
                          .read(hardwarePageKeysEnabledProvider.notifier)
                          .setEnabled(value),
                    );
                  },
          );
        },
      ),
      Consumer(
        builder: (context, ref, _) {
          final dock = ref.watch(
            novelChapterInteractionsDockControllerProvider,
          );
          return AppSwitchRow(
            switchKey: const Key(
              'novel-reader-chapter-interactions-dock-switch',
            ),
            title: l10n.novelChapterInteractionsDockSetting,
            value: dock.value?.enabled ?? true,
            onChanged: dock.value == null
                ? null
                : (enabled) {
                    unawaited(() async {
                      final saved = await ref
                          .read(
                            novelChapterInteractionsDockControllerProvider
                                .notifier,
                          )
                          .setEnabled(enabled);
                      if (!saved && context.mounted) {
                        showTransientSnackBar(
                          context,
                          AppLocalizations.of(context)
                              .novelChapterInteractionsSettingSaveFailed,
                        );
                      }
                    }());
                  },
          );
        },
      ),
    ];
  }

  String _themeKey(NovelReaderThemePreset preset) {
    switch (preset) {
      case NovelReaderThemePreset.followApp:
        return 'follow-app';
      case NovelReaderThemePreset.light:
        return 'light';
      case NovelReaderThemePreset.paperWhite:
        return 'paper-white';
      case NovelReaderThemePreset.cream:
        return 'cream';
      case NovelReaderThemePreset.sepia:
        return 'sepia';
      case NovelReaderThemePreset.sage:
        return 'sage';
      case NovelReaderThemePreset.gray:
        return 'gray';
      case NovelReaderThemePreset.dark:
        return 'dark';
      case NovelReaderThemePreset.charcoal:
        return 'charcoal';
      case NovelReaderThemePreset.ink:
        return 'ink';
    }
  }

  String _themeLabel(AppLocalizations l10n, NovelReaderThemePreset preset) {
    switch (preset) {
      case NovelReaderThemePreset.followApp:
        return l10n.novelThemeFollowApp;
      case NovelReaderThemePreset.light:
        return l10n.novelThemeLight;
      case NovelReaderThemePreset.paperWhite:
        return l10n.novelThemePaperWhite;
      case NovelReaderThemePreset.cream:
        return l10n.novelThemeCream;
      case NovelReaderThemePreset.sepia:
        return l10n.novelThemeSepia;
      case NovelReaderThemePreset.sage:
        return l10n.novelThemeSage;
      case NovelReaderThemePreset.gray:
        return l10n.novelThemeGray;
      case NovelReaderThemePreset.dark:
        return l10n.novelThemeDark;
      case NovelReaderThemePreset.charcoal:
        return l10n.novelThemeCharcoal;
      case NovelReaderThemePreset.ink:
        return l10n.novelThemeInk;
    }
  }

  String _textureLabel(
    AppLocalizations l10n,
    NovelReaderBackgroundTexture texture,
  ) {
    switch (texture) {
      case NovelReaderBackgroundTexture.solid:
        return l10n.novelTextureSolid;
      case NovelReaderBackgroundTexture.paper:
        return l10n.novelTexturePaper;
      case NovelReaderBackgroundTexture.grain:
        return l10n.novelTextureGrain;
    }
  }

  String _bodyColorLabel(AppLocalizations l10n, NovelReaderBodyColorMode mode) {
    switch (mode) {
      case NovelReaderBodyColorMode.followReadingTheme:
        return l10n.novelBodyColorFollowReadingTheme;
      case NovelReaderBodyColorMode.preserveAuthorColors:
        return l10n.novelBodyColorPreserveAuthor;
    }
  }

  String _paragraphIndentLabel(
    AppLocalizations l10n,
    NovelReaderParagraphIndentMode mode,
  ) {
    switch (mode) {
      case NovelReaderParagraphIndentMode.increase:
        return l10n.novelParagraphIndentIncrease;
      case NovelReaderParagraphIndentMode.keep:
        return l10n.novelParagraphIndentKeep;
      case NovelReaderParagraphIndentMode.remove:
        return l10n.novelParagraphIndentRemove;
    }
  }

  void _applyPreferences(NovelReaderPreferences next) {
    if (next == _draft) {
      return;
    }
    setState(() {
      _draft = next;
    });
    widget.onPreferencesChanged(next);
  }

  void _commitStepperPreferences(NovelReaderPreferences next) {
    if (next != _draft) {
      _applyPreferences(next);
    }
    widget.onPreferencesCommitted?.call(next);
  }

  Future<void> _chooseFont() async {
    if (_isChoosingFont) return;
    final request = ++_fontRequest;
    setState(() => _isChoosingFont = true);
    try {
      final selected = await showBodyFontSelector(
        context: context,
        initialFontId: _draft.fontFamily,
        previewStyle: (widget.fontPreviewStyle ?? const TextStyle()).copyWith(
          fontSize: _draft.fontSize,
          height: _draft.lineHeight,
        ),
      );
      if (!mounted || request != _fontRequest || selected == null) return;
      _applyPreferences(_draft.copyWith(fontFamily: selected.id));
    } finally {
      if (mounted && request == _fontRequest) {
        setState(() => _isChoosingFont = false);
      }
    }
  }

  @override
  void dispose() {
    _fontRequest++;
    super.dispose();
  }

  double _snap(double value, double step) {
    return (value / step).roundToDouble() * step;
  }
}

class _PagedEffectSpeedRow extends StatelessWidget {
  const _PagedEffectSpeedRow({
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
  final NovelReaderPageEffect effect;
  final List<AppSelectOption<NovelReaderPageEffect>> effectOptions;
  final ValueChanged<NovelReaderPageEffect> onEffectChanged;
  final String speedLabel;
  final NovelReaderPageSpeed speed;
  final List<AppSelectOption<NovelReaderPageSpeed>> speedOptions;
  final ValueChanged<NovelReaderPageSpeed> onSpeedChanged;

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
                      child: AppSelectMenu<NovelReaderPageEffect>(
                        key: const Key('novel-reader-page-effect-control'),
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
                      child: AppSelectMenu<NovelReaderPageSpeed>(
                        key: const Key('novel-reader-page-speed-control'),
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

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.primary,
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
      ),
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimary : scheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
