import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/navigation/main_navigation_settings_controller.dart';
import 'package:y300/app/settings/app_appearance_controller.dart';
import 'package:y300/app/settings/app_appearance_settings.dart';
import 'package:y300/app/settings/app_glass_level.dart';
import 'package:y300/app/settings/app_navigation_bar_style.dart';
import 'package:y300/app/settings/app_navigation_lens_motion.dart';
import 'package:y300/app/theme/app_dynamic_colors.dart';
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/app/theme/app_theme_color_source.dart';
import 'package:y300/app/theme/app_theme_family.dart';
import 'package:y300/features/more/presentation/appearance_preview.dart';
import 'package:y300/features/more/presentation/more_text_resolver.dart';
import 'package:y300/features/more/presentation/navigation_management_page.dart';
import 'package:y300/features/more/presentation/settings_search/settings_search_anchor.dart';
import 'package:y300/features/more/presentation/settings_search/settings_search_index.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_confirm_dialog.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';
import 'package:y300/shared/widgets/app_switch_row.dart';
import 'package:y300/shared/widgets/transient_feedback.dart';

/// 全屏外观页：顶部实时预览加主题模式、配色、玻璃、导航与语言分组。
///
/// 所有选项经 [appAppearanceControllerProvider] 即时生效，沿用控制器的串行
/// 保存与失败回滚；页面不读取论坛、书架或账号仓库，预览只消费当前
/// [ThemeData] 与外观快照。
class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key, this.initialSection});

  static const String routeName = '/more/appearance';

  /// 从设置搜索进入时要定位的分组；为 null 时停在页面顶部。
  final SettingsSearchTarget? initialSection;

  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  static const double _horizontalPadding = 16;

  final SettingsSearchRevealController _revealController =
      SettingsSearchRevealController();

  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    final initialSection = widget.initialSection;
    if (initialSection == null) {
      return;
    }
    // 首帧布局完成后再定位，锚点已在即时构建的列表里注册。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _revealController.reveal(initialSection);
      }
    });
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(appAppearanceControllerProvider);
    final settings =
        settingsState.asData?.value ?? AppAppearanceSettings.defaults();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dynamicColors = AppDynamicColors.maybeOf(context);
    final resolvedBrightness = _resolvedBrightness(
      settings,
      MediaQuery.platformBrightnessOf(context),
    );
    final dynamicAvailable =
        dynamicColors?.available(resolvedBrightness) ?? false;
    final navigationReady =
        ref.watch(mainNavigationSettingsControllerProvider).value != null;
    final scope = _CandidateScope(
      settings: settings,
      resolvedBrightness: resolvedBrightness,
      dynamicColors: dynamicColors,
    );

    return Scaffold(
      key: const Key('appearance-page'),
      appBar: AppPageAppBar(title: l10n.appearanceTitle),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              key: const Key('appearance-page-list'),
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _anchor(
                    SettingsSearchTarget.appearanceTop,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _horizontalPadding,
                        8,
                        _horizontalPadding,
                        0,
                      ),
                      child: Column(
                        children: [
                          AppearanceLivePreview(
                            theme: theme,
                            glassLevel: settings.glassLevel,
                            navigationStyle: settings.navigationBarStyle,
                            previewKey: _previewKey(
                              settings,
                              resolvedBrightness,
                              dynamicColors,
                            ),
                            title: l10n.appNavigationForum,
                            semanticsLabel:
                                l10n.appearancePreviewSemanticsLabel,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.appearancePreviewCaption,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _anchor(
                    SettingsSearchTarget.appearanceThemeMode,
                    _AppearanceGroup(
                      title: l10n.appearanceThemeModeSectionTitle,
                      child: _OptionGrid(
                        maxColumns: 3,
                        minCardWidth: 96,
                        children: [
                          for (final preference
                              in AppBrightnessPreference.values)
                            _AppearanceOptionCard(
                              key: Key(
                                'appearance-theme-mode-${preference.name}',
                              ),
                              title: MoreTextResolver.brightnessLabel(
                                l10n,
                                preference,
                              ),
                              description:
                                  MoreTextResolver.brightnessDescription(
                                    l10n,
                                    preference,
                                  ),
                              selected:
                                  settings.brightnessPreference == preference,
                              thumbnail: _ThemeModeThumb(
                                preference: preference,
                                scope: scope,
                              ),
                              onPressed: () => _commit(
                                () => ref
                                    .read(
                                      appAppearanceControllerProvider.notifier,
                                    )
                                    .setBrightnessPreference(preference),
                                failure: (error) =>
                                    l10n.moreThemeSaveFailed('$error'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _anchor(
                    SettingsSearchTarget.appearanceColorTheme,
                    _AppearanceGroup(
                      title: l10n.moreColorThemeSectionTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OptionGrid(
                            maxColumns: 4,
                            minCardWidth: 76,
                            children: [
                              for (final family in AppThemeFamily.values)
                                _AppearanceOptionCard(
                                  key: Key(
                                    'appearance-theme-family-${family.name}',
                                  ),
                                  title: MoreTextResolver.themeFamilyLabel(
                                    l10n,
                                    family,
                                  ),
                                  selected:
                                      settings.colorSource ==
                                          AppThemeColorSource.preset &&
                                      settings.themeFamily == family,
                                  thumbnail: _ColorOptionThumb(
                                    theme: scope.themeFor(
                                      brightness: resolvedBrightness,
                                      family: family,
                                      colorSource: AppThemeColorSource.preset,
                                    ),
                                    dotKeyPrefix:
                                        'appearance-theme-family-dot-${family.name}',
                                  ),
                                  onPressed: () => _commit(
                                    () => ref
                                        .read(
                                          appAppearanceControllerProvider
                                              .notifier,
                                        )
                                        .setThemeFamily(family),
                                    failure: (error) =>
                                        l10n.moreThemeSaveFailed('$error'),
                                  ),
                                ),
                              _AppearanceOptionCard(
                                key: const Key('appearance-theme-dynamic'),
                                title: l10n.appearanceDynamicColorLabel,
                                selected:
                                    settings.colorSource ==
                                    AppThemeColorSource.dynamic,
                                thumbnail: _ColorOptionThumb(
                                  theme: theme,
                                  dotKeyPrefix:
                                      'appearance-theme-family-dot-dynamic',
                                ),
                                onPressed: dynamicAvailable
                                    ? () => _commit(
                                        () => ref
                                            .read(
                                              appAppearanceControllerProvider
                                                  .notifier,
                                            )
                                            .setColorSource(
                                              AppThemeColorSource.dynamic,
                                            ),
                                        failure: (error) =>
                                            l10n.moreThemeSaveFailed('$error'),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (!dynamicAvailable)
                            _AppearanceCaption(
                              key: const Key('appearance-dynamic-fallback'),
                              text: l10n.moreThemeDynamicUnavailable(
                                MoreTextResolver.themeFamilyLabel(
                                  l10n,
                                  settings.themeFamily,
                                ),
                              ),
                            )
                          else if (settings.colorSource ==
                              AppThemeColorSource.dynamic)
                            _AppearanceCaption(
                              text: l10n.moreThemeDynamicDescription,
                            )
                          else
                            _AppearanceCaption(
                              text: MoreTextResolver.themeFamilyDescription(
                                l10n,
                                settings.themeFamily,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _anchor(
                    SettingsSearchTarget.appearanceGlass,
                    _AppearanceGroup(
                      title: l10n.moreGlassSectionTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OptionGrid(
                            maxColumns: 3,
                            minCardWidth: 96,
                            children: [
                              for (final level in AppGlassLevel.values)
                                _AppearanceOptionCard(
                                  key: Key(
                                    'appearance-glass-level-${level.name}',
                                  ),
                                  title: _glassLevelLabel(l10n, level),
                                  selected: settings.glassLevel == level,
                                  thumbnail: GlassLevelThumb(
                                    theme: theme,
                                    level: level,
                                  ),
                                  onPressed: () => _commit(
                                    () => ref
                                        .read(
                                          appAppearanceControllerProvider
                                              .notifier,
                                        )
                                        .setGlassLevel(level),
                                    failure: (error) =>
                                        l10n.moreThemeSaveFailed('$error'),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _AppearanceCaption(text: l10n.moreGlassDescription),
                        ],
                      ),
                    ),
                  ),
                  _anchor(
                    SettingsSearchTarget.appearanceNavigation,
                    _AppearanceGroup(
                      title: l10n.moreNavigationSectionTitle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _OptionGrid(
                            maxColumns: 2,
                            minCardWidth: 130,
                            children: [
                              for (final style in AppNavigationBarStyle.values)
                                _AppearanceOptionCard(
                                  key: Key(
                                    'appearance-navigation-style-${style.name}',
                                  ),
                                  title: _navigationStyleLabel(l10n, style),
                                  selected:
                                      settings.navigationBarStyle == style,
                                  thumbnail: NavigationStyleSample(
                                    theme: theme,
                                    style: style,
                                  ),
                                  onPressed: () => _commit(
                                    () => ref
                                        .read(
                                          appAppearanceControllerProvider
                                              .notifier,
                                        )
                                        .setNavigationBarStyle(style),
                                    failure: (error) =>
                                        l10n.moreThemeSaveFailed('$error'),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _AppearanceCaption(
                            text:
                                settings.navigationBarStyle ==
                                    AppNavigationBarStyle.immersive
                                ? l10n.moreNavigationStyleImmersiveDescription
                                : l10n.moreNavigationStyleLegacyDescription,
                          ),
                          const SizedBox(height: 10),
                          AppGroupedSection(
                            margin: EdgeInsets.zero,
                            children: [
                              AppSwitchRow(
                                key: const Key('appearance-navigation-swipe'),
                                title: l10n.moreNavigationSwipeTitle,
                                subtitle:
                                    settings.navigationBarStyle ==
                                        AppNavigationBarStyle.immersive
                                    ? l10n.moreNavigationSwipeDescription
                                    : l10n.moreNavigationSwipeUnavailable,
                                value: settings.navigationSwipeEnabled,
                                onChanged:
                                    settings.navigationBarStyle ==
                                        AppNavigationBarStyle.immersive
                                    ? (enabled) => _commit(
                                        () => ref
                                            .read(
                                              appAppearanceControllerProvider
                                                  .notifier,
                                            )
                                            .setNavigationSwipeEnabled(enabled),
                                        failure: (error) =>
                                            l10n.moreThemeSaveFailed('$error'),
                                      )
                                    : null,
                              ),
                              AppSwitchRow(
                                key: const Key('appearance-lens-follow'),
                                title: l10n.appearanceLensFollowTitle,
                                subtitle:
                                    settings.navigationLensMotion ==
                                        AppNavigationLensMotion.followPress
                                    ? l10n.appearanceLensFollowPressDescription
                                    : l10n.appearanceLensFromSelectionDescription,
                                value:
                                    settings.navigationLensMotion ==
                                    AppNavigationLensMotion.followPress,
                                onChanged: (followsPress) => _commit(
                                  () => ref
                                      .read(
                                        appAppearanceControllerProvider
                                            .notifier,
                                      )
                                      .setNavigationLensMotion(
                                        followsPress
                                            ? AppNavigationLensMotion
                                                  .followPress
                                            : AppNavigationLensMotion
                                                  .fromSelection,
                                      ),
                                  failure: (error) =>
                                      l10n.moreThemeSaveFailed('$error'),
                                ),
                              ),
                              AppGroupedRow(
                                key: const Key(
                                  'appearance-navigation-management-entry',
                                ),
                                leading: const Icon(Icons.view_week_outlined),
                                title: l10n.appearanceManageBarEntry,
                                enabled: navigationReady,
                                showChevron: true,
                                onTap: navigationReady
                                    ? () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const NavigationManagementPage(),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _anchor(
                    SettingsSearchTarget.appearanceLanguage,
                    _AppearanceGroup(
                      title: l10n.appLanguageSectionTitle,
                      child: AppGroupedSection(
                        margin: EdgeInsets.zero,
                        children: [
                          for (final language in AppLanguage.values)
                            AppGroupedRow(
                              key: Key(
                                'appearance-language-option-${language.name}',
                              ),
                              title: _languageLabel(l10n, language),
                              selected: settings.languagePreference == language,
                              trailing: settings.languagePreference == language
                                  ? Icon(
                                      Icons.check,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    )
                                  : null,
                              onTap: () => _commit(
                                () => ref
                                    .read(
                                      appAppearanceControllerProvider.notifier,
                                    )
                                    .setLanguagePreference(language),
                                failure: (error) =>
                                    l10n.appLanguageSaveFailed('$error'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  _anchor(
                    SettingsSearchTarget.appearanceReset,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _horizontalPadding,
                      ),
                      child: AppGroupedSection(
                        margin: const EdgeInsets.only(bottom: 8),
                        children: [
                          AppGroupedRow(
                            key: const Key('appearance-reset'),
                            leading: const Icon(Icons.restart_alt),
                            title: l10n.appearanceResetAction,
                            enabled: !_resetting,
                            onTap: _confirmReset,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _anchor(SettingsSearchTarget target, Widget child) {
    return SettingsSearchSectionAnchor(
      key: Key('settings-search-anchor-${target.name}'),
      revealController: _revealController,
      target: target,
      overlayInset: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: child,
    );
  }

  Brightness _resolvedBrightness(
    AppAppearanceSettings settings,
    Brightness platformBrightness,
  ) {
    return switch (settings.brightnessPreference) {
      AppBrightnessPreference.light => Brightness.light,
      AppBrightnessPreference.dark => Brightness.dark,
      AppBrightnessPreference.system => platformBrightness,
    };
  }

  /// 淡化签名只随设置快照与动态色输入变化，不随 MaterialApp 的主题插值抖动。
  String _previewKey(
    AppAppearanceSettings settings,
    Brightness brightness,
    AppDynamicColors? dynamicColors,
  ) {
    final dynamicScheme = brightness == Brightness.light
        ? dynamicColors?.light
        : dynamicColors?.dark;
    return [
      settings.colorSource.name,
      settings.themeFamily.name,
      brightness.name,
      settings.glassLevel.name,
      settings.navigationBarStyle.name,
      dynamicScheme?.primary.toARGB32() ?? 0,
    ].join('|');
  }

  String _glassLevelLabel(AppLocalizations l10n, AppGlassLevel level) {
    return switch (level) {
      AppGlassLevel.off => l10n.moreGlassLevelOff,
      AppGlassLevel.standard => l10n.moreGlassLevelStandard,
      AppGlassLevel.enhanced => l10n.moreGlassLevelEnhanced,
    };
  }

  String _navigationStyleLabel(
    AppLocalizations l10n,
    AppNavigationBarStyle style,
  ) {
    return switch (style) {
      AppNavigationBarStyle.immersive => l10n.moreNavigationStyleImmersive,
      AppNavigationBarStyle.legacy => l10n.moreNavigationStyleLegacy,
    };
  }

  String _languageLabel(AppLocalizations l10n, AppLanguage language) {
    return switch (language) {
      AppLanguage.system => l10n.appLanguageSystem,
      AppLanguage.simplifiedChinese => l10n.appLanguageSimplifiedChinese,
      AppLanguage.traditionalChinese => l10n.appLanguageTraditionalChinese,
    };
  }

  Future<void> _commit(
    Future<void> Function() action, {
    required String Function(Object error) failure,
  }) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showTransientSnackBar(context, failure(error));
    }
  }

  Future<void> _confirmReset() async {
    if (_resetting) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: l10n.appearanceResetConfirmTitle,
      message: l10n.appearanceResetConfirmBody,
      confirmLabel: l10n.appearanceResetConfirmAction,
      cancelLabel: l10n.commonCancel,
      destructive: true,
      confirmKey: const Key('appearance-reset-confirm'),
    );
    if (!mounted || !confirmed) {
      return;
    }
    setState(() => _resetting = true);
    try {
      await ref
          .read(appAppearanceControllerProvider.notifier)
          .resetAppearance();
      if (!mounted) return;
      showTransientSnackBar(context, l10n.appearanceResetDone);
    } catch (error) {
      if (!mounted) return;
      showTransientSnackBar(context, l10n.appearanceResetFailed('$error'));
    } finally {
      if (mounted) {
        setState(() => _resetting = false);
      }
    }
  }
}

/// 候选 `ThemeData` 的唯一入口：明暗、预设、动态色与当前解析亮度在此对齐。
class _CandidateScope {
  const _CandidateScope({
    required this.settings,
    required this.resolvedBrightness,
    required this.dynamicColors,
  });

  final AppAppearanceSettings settings;
  final Brightness resolvedBrightness;
  final AppDynamicColors? dynamicColors;

  ThemeData themeFor({
    required Brightness brightness,
    AppThemeFamily? family,
    AppThemeColorSource? colorSource,
  }) {
    final source = colorSource ?? settings.colorSource;
    final scheme = brightness == Brightness.light
        ? dynamicColors?.light
        : dynamicColors?.dark;
    return AppTheme.build(
      family: family ?? settings.themeFamily,
      brightness: brightness,
      colorSource: source,
      dynamicScheme: scheme,
    );
  }
}

class _ThemeModeThumb extends StatelessWidget {
  const _ThemeModeThumb({required this.preference, required this.scope});

  final AppBrightnessPreference preference;
  final _CandidateScope scope;

  @override
  Widget build(BuildContext context) {
    return switch (preference) {
      AppBrightnessPreference.light => MiniHomeThumb(
        child: MiniHomePreview(
          theme: scope.themeFor(brightness: Brightness.light),
        ),
      ),
      AppBrightnessPreference.dark => MiniHomeThumb(
        child: MiniHomePreview(
          theme: scope.themeFor(brightness: Brightness.dark),
        ),
      ),
      AppBrightnessPreference.system => MiniHomeThumb(
        child: SplitMiniHomePreview(
          light: scope.themeFor(brightness: Brightness.light),
          dark: scope.themeFor(brightness: Brightness.dark),
        ),
      ),
    };
  }
}

class _ColorOptionThumb extends StatelessWidget {
  const _ColorOptionThumb({required this.theme, required this.dotKeyPrefix});

  final ThemeData theme;
  final String dotKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ColorDot(key: Key('$dotKeyPrefix-primary'), color: scheme.primary),
            const SizedBox(width: 4),
            _ColorDot(key: Key('$dotKeyPrefix-surface'), color: scheme.surface),
            const SizedBox(width: 4),
            _ColorDot(
              key: Key('$dotKeyPrefix-secondary'),
              color: scheme.secondaryContainer,
            ),
          ],
        ),
        const SizedBox(height: 6),
        MiniHomeThumb(child: MiniHomePreview(theme: theme)),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: 0.7),
          width: 0.6,
        ),
      ),
    );
  }
}

class _AppearanceGroup extends StatelessWidget {
  const _AppearanceGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _AppearancePageState._horizontalPadding,
        16,
        _AppearancePageState._horizontalPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AppearanceCaption extends StatelessWidget {
  const _AppearanceCaption({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 选项网格：常规字号并排，大字号与窄屏改为单列，避免标签被截断。
class _OptionGrid extends StatelessWidget {
  const _OptionGrid({
    required this.children,
    required this.maxColumns,
    required this.minCardWidth,
  });

  final List<Widget> children;
  final int maxColumns;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = textScale > 1.4
            ? 1
            : math.max(
                1,
                math.min(
                  maxColumns,
                  math.max(1, (constraints.maxWidth / minCardWidth).floor()),
                ),
              );
        const spacing = 10.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// 选项卡：缩略图只作视觉展示，读屏读标题、选中状态与说明。
class _AppearanceOptionCard extends StatelessWidget {
  const _AppearanceOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.thumbnail,
    this.description,
    this.onPressed,
  });

  final String title;
  final String? description;
  final bool selected;
  final Widget thumbnail;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onPressed != null;
    final borderColor = selected
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: enabled ? 0.9 : 0.4);
    final surface = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainer
        : scheme.surfaceContainerLowest;
    final content = Material(
      color: surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: AlignmentDirectional.topEnd,
                  children: [
                    Opacity(opacity: enabled ? 1 : 0.45, child: thumbnail),
                    if (selected)
                      Container(
                        key: const Key('appearance-option-selected-check'),
                        margin: const EdgeInsets.all(2),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          size: 12,
                          color: scheme.onPrimary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: enabled
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: enabled
                          ? scheme.onSurfaceVariant
                          : scheme.onSurfaceVariant.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: title,
      hint: description,
      child: ExcludeSemantics(child: content),
    );
  }
}
