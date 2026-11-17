import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:prism_ui/l10n.dart';
import 'package:y300/l10n/app_localizations.dart';

/// prism_ui 自绘控件的内置文案（返回、取消、菜单、文本选择等）。
///
/// 界面焕新阶段二的菜单、对话框、面板和开关使用 prism_ui 实现，这些控件会
/// 通过 [UiLocalizations] 读取无障碍标签和栏位文案。应用没有另建一套
/// prism 文案表，而是把通用控件文案映射到 Flutter 自带的 Material 本地化，
/// 应用自有文案仍走 `AppLocalizations`，避免两套语言资源漂移。
class AppPrismUiLocalizations extends UiLocalizations {
  AppPrismUiLocalizations(this._app, this._material);

  final AppLocalizations _app;
  final MaterialLocalizations _material;

  static const LocalizationsDelegate<UiLocalizations> delegate =
      _AppPrismUiLocalizationsDelegate();

  @override
  String get back => _material.backButtonTooltip;

  @override
  String get cancel => _material.cancelButtonLabel;

  @override
  String get clearSearch => _app.appPrismClearSearch;

  @override
  String get close => _material.closeButtonLabel;

  @override
  String get copy => _material.copyButtonLabel;

  @override
  String get cut => _material.cutButtonLabel;

  @override
  String get dialog => _app.appPrismDialog;

  @override
  String get hidePassword => _app.appPrismHidePassword;

  @override
  String get more => _material.moreButtonTooltip;

  @override
  String get noSearchResults => _app.appPrismNoSearchResults;

  @override
  String get paste => _material.pasteButtonLabel;

  @override
  String get reset => _app.commonReset;

  @override
  String get search => _material.searchFieldLabel;

  @override
  String get select => _app.appPrismSelect;

  @override
  String get selectAll => _material.selectAllButtonLabel;

  @override
  String get showLess => _app.appPrismShowLess;

  @override
  String get showMore => _app.appPrismShowMore;

  @override
  String get showPassword => _app.appPrismShowPassword;

  @override
  String get sort => _app.appPrismSort;

  @override
  String get submit => _app.appPrismSubmit;
}

class _AppPrismUiLocalizationsDelegate
    extends LocalizationsDelegate<UiLocalizations> {
  const _AppPrismUiLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<UiLocalizations> load(Locale locale) {
    // 保持同步装载链：两个子委托都返回 SynchronousFuture 时，Localizations
    // 在首帧就能拿到 UiLocalizations；若改写成 async/await，返回普通 Future，
    // 首帧会缺少 prism 文案并使既有“pump 一次即断言”的页面测试空白。
    return AppLocalizations.delegate.load(locale).then((app) {
      return GlobalMaterialLocalizations.delegate
          .load(locale)
          .then((material) => AppPrismUiLocalizations(app, material));
    });
  }

  @override
  bool shouldReload(_AppPrismUiLocalizationsDelegate old) => false;
}
