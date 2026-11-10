import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/app/theme/app_system_ui.dart';

/// 工具栏只在预留区域内移动，收起不会改变正文和分页的布局预算。
class Y300PageScaffold extends StatelessWidget {
  const Y300PageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomBar,
    this.toolbarVisible = true,
    this.bottomBarVisible = true,
    this.floatingActionButton,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomBar;
  final bool toolbarVisible;
  final bool bottomBarVisible;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = backgroundColor ?? theme.scaffoldBackgroundColor;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppSystemUi.onSurfaces(
        top: appBar == null
            ? background
            : theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        bottom: bottomBar == null
            ? background
            : theme.navigationBarTheme.backgroundColor ??
                  theme.colorScheme.surface,
      ),
      child: Scaffold(
        backgroundColor: background,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        appBar: appBar == null
            ? null
            : PreferredSize(
                preferredSize: appBar!.preferredSize,
                child: _StableChromeSlot(
                  visible: toolbarVisible,
                  offset: const Offset(0, -1),
                  child: appBar!,
                ),
              ),
        body: SafeArea(
          top: appBar == null,
          bottom: bottomBar == null,
          child: body,
        ),
        bottomNavigationBar: bottomBar == null
            ? null
            : Padding(
                padding: EdgeInsets.only(
                  bottom: resizeToAvoidBottomInset
                      ? MediaQuery.viewInsetsOf(context).bottom
                      : 0,
                ),
                child: _StableChromeSlot(
                  visible: bottomBarVisible,
                  offset: const Offset(0, 1),
                  child: SafeArea(top: false, child: bottomBar!),
                ),
              ),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}

class _StableChromeSlot extends StatelessWidget {
  const _StableChromeSlot({
    required this.visible,
    required this.offset,
    required this.child,
  });

  final bool visible;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = AppLayoutTokens.motionDuration(context);
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeFocus(
        excluding: !visible,
        child: ExcludeSemantics(
          excluding: !visible,
          child: ClipRect(
            child: AnimatedSlide(
              offset: visible ? Offset.zero : offset,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: duration,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
