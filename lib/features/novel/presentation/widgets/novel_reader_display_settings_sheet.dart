import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prism_ui/switch.dart' as prism;
import 'package:y300/features/fonts/fonts.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';
import 'package:y300/features/novel/data/models/novel_models.dart';
import 'package:y300/features/novel/domain/models/novel_reader_spacing.dart';
import 'package:y300/features/novel/presentation/novel_text_resolver.dart';
import 'package:y300/features/novel/presentation/controllers/novel_chapter_interactions_dock_controller.dart';
import 'package:y300/features/reader_shared/presentation/reader_preferences/hardware_page_keys_provider.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';

class NovelReaderDisplaySettingsSheet extends StatefulWidget {
  const NovelReaderDisplaySettingsSheet({
    super.key,
    required this.initialPreferences,
    required this.onPreferencesChanged,
    this.fontPreviewStyle,
  });

  final NovelReaderPreferences initialPreferences;
  final ValueChanged<NovelReaderPreferences> onPreferencesChanged;
  final TextStyle? fontPreviewStyle;

  @override
  State<NovelReaderDisplaySettingsSheet> createState() =>
      _NovelReaderDisplaySettingsSheetState();
}

class _NovelReaderDisplaySettingsSheetState
    extends State<NovelReaderDisplaySettingsSheet> {
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
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: SingleChildScrollView(
          key: const Key('novel-reader-display-settings-sheet'),
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReaderSheetTitle(title: l10n.novelDisplaySettings),
              _SettingsSection(
                title: l10n.novelTypography,
                children: [
                  ListTile(
                    key: const Key('novel-reader-font-selector'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    title: Text(l10n.fontSelectorTitle),
                    subtitle: Text(
                      _draft.fontFamily == FontIdentity.system
                          ? l10n.fontSelectorSystemDefault
                          : l10n.novelCustomFont,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _isChoosingFont ? null : _chooseFont,
                  ),
                  _SettingsSlider(
                    key: const Key('novel-reader-font-size-slider'),
                    label: l10n.novelFontSize,
                    value: _draft.fontSize,
                    min: 14,
                    max: 30,
                    displayValue: _draft.fontSize.toStringAsFixed(1),
                    onChanged: (value) => _applyPreferences(
                      _draft.copyWith(fontSize: _snap(value, 0.5)),
                    ),
                  ),
                  _SettingsSlider(
                    key: const Key('novel-reader-line-height-slider'),
                    label: l10n.novelLineSpacing,
                    value: _draft.lineHeight,
                    min: 1.2,
                    max: 2.4,
                    displayValue: _draft.lineHeight.toStringAsFixed(1),
                    onChanged: (value) => _applyPreferences(
                      _draft.copyWith(lineHeight: _snap(value, 0.05)),
                    ),
                  ),
                  _SettingsSlider(
                    key: const Key('novel-reader-page-padding-slider'),
                    label: l10n.novelPagePadding,
                    value: _draft.pagePadding,
                    min: NovelReaderSpacing.minimumPagePadding,
                    max: NovelReaderSpacing.maximumPagePadding,
                    displayValue: _draft.pagePadding.toStringAsFixed(0),
                    onChanged: (value) => _applyPreferences(
                      _draft.copyWith(pagePadding: _snap(value, 1)),
                    ),
                  ),
                  ReaderSegmentControl<NovelReaderParagraphIndentMode>(
                    key: const Key('novel-reader-paragraph-indent-control'),
                    scrollable: true,
                    label: l10n.novelParagraphIndent,
                    value: _draft.paragraphIndent,
                    values: NovelReaderParagraphIndentMode.values,
                    labelBuilder: (value) => _paragraphIndentLabel(l10n, value),
                    onChanged: (value) => _applyPreferences(
                      _draft.copyWith(paragraphIndent: value),
                    ),
                  ),
                ],
              ),
              _SettingsSection(
                title: l10n.novelTheme,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in NovelReaderThemePreset.values)
                          _ThemeChip(
                            key: Key('novel-theme-${_themeKey(preset)}'),
                            label: _themeLabel(l10n, preset),
                            selected: _draft.themePreset == preset,
                            onSelected: () => _applyPreferences(
                              _draft.copyWith(themePreset: preset),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _SettingsSlider(
                    key: const Key('novel-reader-body-brightness-slider'),
                    label: l10n.novelBodyBrightness,
                    value: _draft.bodyBrightness,
                    min: NovelReaderPreferences.minimumBodyBrightness,
                    max: NovelReaderPreferences.maximumBodyBrightness,
                    displayValue: '${(_draft.bodyBrightness * 100).round()}%',
                    onChanged: (value) => _applyPreferences(
                      _draft.copyWith(bodyBrightness: _snap(value, 0.05)),
                    ),
                  ),
                  ReaderSegmentControl<NovelReaderBackgroundTexture>(
                    key: const Key('novel-reader-background-texture-control'),
                    label: l10n.novelBackgroundTexture,
                    value: _draft.backgroundTexture,
                    values: NovelReaderBackgroundTexture.values,
                    labelBuilder: (value) => _textureLabel(l10n, value),
                    onChanged: (value) => _applyPreferences(
                      _draft.copyWith(backgroundTexture: value),
                    ),
                  ),
                  ReaderSegmentControl<NovelReaderBodyColorMode>(
                    key: const Key('novel-reader-body-color-mode-control'),
                    scrollable: true,
                    label: l10n.novelBodyColor,
                    value: _draft.bodyColorMode,
                    values: NovelReaderBodyColorMode.values,
                    labelBuilder: (value) => _bodyColorLabel(l10n, value),
                    onChanged: (value) => _applyPreferences(
                      _draft.copyWith(bodyColorMode: value),
                    ),
                  ),
                ],
              ),
              _SettingsSection(
                title: l10n.novelReading,
                children: [
                  ReaderSegmentControl<NovelReaderFlowMode>(
                    key: const Key('novel-reader-flow-mode-control'),
                    label: l10n.novelReadingMode,
                    value: _draft.flowMode,
                    values: NovelReaderFlowMode.values,
                    labelBuilder: (value) =>
                        NovelTextResolver.flowMode(l10n, value),
                    onChanged: (value) =>
                        _applyPreferences(_draft.copyWith(flowMode: value)),
                  ),
                  if (_draft.flowMode != NovelReaderFlowMode.vertical) ...[
                    ReaderSegmentControl<NovelReaderPageEffect>(
                      key: const Key('novel-reader-page-effect-control'),
                      scrollable: true,
                      label: l10n.novelPageEffect,
                      value: _draft.pageEffect,
                      values: NovelReaderPageEffect.values,
                      labelBuilder: (value) =>
                          NovelTextResolver.pageEffect(l10n, value),
                      onChanged: (value) =>
                          _applyPreferences(_draft.copyWith(pageEffect: value)),
                    ),
                    ReaderSegmentControl<NovelReaderPageSpeed>(
                      key: const Key('novel-reader-page-speed-control'),
                      label: l10n.novelPageSpeed,
                      value: _draft.pageSpeed,
                      values: NovelReaderPageSpeed.values,
                      labelBuilder: (value) =>
                          NovelTextResolver.pageSpeed(l10n, value),
                      onChanged: (value) =>
                          _applyPreferences(_draft.copyWith(pageSpeed: value)),
                    ),
                  ],
                  ReaderSegmentControl<NovelReaderConversionMode>(
                    key: const Key('novel-reader-conversion-mode-control'),
                    label: l10n.novelConversionMode,
                    value: _draft.conversionMode,
                    values: NovelReaderConversionMode.values,
                    labelBuilder: (value) =>
                        NovelTextResolver.conversionMode(l10n, value),
                    onChanged: (value) => _applyPreferences(
                      _draft.copyWith(conversionMode: value),
                    ),
                  ),
                  _PanelSwitchRow(
                    controlKey: const Key('novel-reader-safe-area-switch'),
                    title: l10n.novelSafeContent,
                    value: _draft.safeAreaEnabled,
                    onChanged: (value) => _applyPreferences(
                      _draft.copyWith(safeAreaEnabled: value),
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final enabled = ref.watch(
                        hardwarePageKeysEnabledProvider,
                      );
                      return _PanelSwitchRow(
                        controlKey: const Key(
                          'novel-reader-hardware-page-keys-switch',
                        ),
                        title: l10n.readerHardwarePageKeys,
                        value: enabled.value ?? false,
                        onChanged: enabled.value == null
                            ? null
                            : (value) {
                                unawaited(
                                  ref
                                      .read(
                                        hardwarePageKeysEnabledProvider
                                            .notifier,
                                      )
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
                      return _PanelSwitchRow(
                        controlKey: const Key(
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(
                                            context,
                                          ).novelChapterInteractionsSettingSaveFailed,
                                        ),
                                      ),
                                    );
                                  }
                                }());
                              },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// 阅读设置面板中的开关行。
///
/// 面板自身已有水平内边距和紧凑行距，不套用分组列表的 `AppSwitchRow`；
/// 这里只取同一 prism 开关外观，整行与尾部开关都可切换。
class _PanelSwitchRow extends StatelessWidget {
  const _PanelSwitchRow({
    required this.controlKey,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final Key controlKey;
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    void toggle() {
      if (enabled) {
        onChanged!(!value);
      }
    }

    return Semantics(
      container: true,
      label: title,
      toggled: value,
      enabled: enabled,
      onTap: enabled ? toggle : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? toggle : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: enabled
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ),
                AppPrismTheme(
                  child: prism.Switch(
                    key: controlKey,
                    value: value,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSlider extends StatelessWidget {
  const _SettingsSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(label)),
          Expanded(
            child: Slider(
              value: value.clamp(min, max).toDouble(),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              displayValue,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}
