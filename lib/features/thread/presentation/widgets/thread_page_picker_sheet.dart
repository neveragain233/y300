import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prism_ui/popup.dart' as prism;
import 'package:prism_ui/theme_data.dart' as prism_theme;
import 'package:y300/app/theme/app_theme.dart';
import 'package:y300/core/eink/eink_mode_scope.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_prism_theme.dart';
import 'package:y300/shared/widgets/app_text_input.dart';

Future<int?> showThreadPagePicker(
  BuildContext context, {
  required int currentPage,
  required int? lastPage,
  required bool hasMore,
  BuildContext? anchorContext,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
  final scheme = Theme.of(context).colorScheme;
  final eInk = EInkModeScope.of(context);
  final route = prism.AnchoredPopupRoute<int>(
    anchorOf: () {
      final anchorRender = anchorContext?.mounted == true
          ? anchorContext!.findRenderObject()
          : null;
      if (anchorRender is RenderBox && anchorRender.hasSize) {
        return overlay.globalToLocal(anchorRender.localToGlobal(Offset.zero)) &
            anchorRender.size;
      }
      final size = overlay.size;
      return Rect.fromCenter(
        center: Offset(size.width / 2, math.max(120, size.height - 96)),
        width: 1,
        height: 1,
      );
    },
    placement: prism.PopupPlacement.overAnchorEnd,
    theme: prism_theme.ThemeData(colorScheme: prismColorSchemeOf(scheme)),
    bareSource: true,
    blursContent: !eInk,
    reduceMotion: AppMotion.reduceMotion(context),
    solidSurface: eInk,
    runsPickedAfterReturn: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: (_) => _ThreadPagePickerPopup(
      currentPage: math.max(1, currentPage),
      lastPage: lastPage,
      hasMore: hasMore,
    ),
  );
  return navigator.push<int>(route);
}

class _ThreadPagePickerPopup extends StatefulWidget {
  const _ThreadPagePickerPopup({
    required this.currentPage,
    required this.lastPage,
    required this.hasMore,
  });

  final int currentPage;
  final int? lastPage;
  final bool hasMore;

  @override
  State<_ThreadPagePickerPopup> createState() => _ThreadPagePickerPopupState();
}

class _ThreadPagePickerPopupState extends State<_ThreadPagePickerPopup> {
  static const double _itemExtent = 44.0;
  late final _input = TextEditingController(text: '${widget.currentPage}');
  late final _scroll = ScrollController(
    initialScrollOffset: math.max(0, widget.currentPage - 3) * _itemExtent,
  );
  bool _invalid = false;

  int get _maximum => math.max(
    widget.currentPage,
    widget.lastPage ?? widget.currentPage + (widget.hasMore ? 1 : 0),
  );

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit() {
    final page = int.tryParse(_input.text);
    final upperBound = widget.lastPage == null ? null : _maximum;
    if (page == null || page < 1 || (upperBound != null && page > upperBound)) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eInk = EInkModeScope.of(context);
    final width = math.min(280.0, MediaQuery.sizeOf(context).width - 24.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, minWidth: 220),
      child: Material(
        key: const Key('thread-page-picker-popup'),
        color: eInk ? scheme.surface : scheme.surfaceContainerHigh,
        elevation: eInk ? 0 : 4,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: eInk
              ? BorderSide(color: AppTheme.eInkBorderColor(scheme.brightness))
              : BorderSide.none,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.lastPage == null
                        ? l10n.threadControlsPageUnknown(widget.currentPage)
                        : l10n.threadControlsPageSummary(
                            widget.currentPage,
                            widget.lastPage!,
                          ),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextInput(
                          key: const Key('thread-detail-page-input'),
                          controller: _input,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          label: l10n.threadControlsPageInput,
                          errorText: _invalid
                              ? l10n.threadControlsInvalidPage
                              : null,
                          onSubmitted: (_) => _submit(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _submit,
                        child: Text(l10n.threadControlsJumpPage),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 264),
                child: ListView.builder(
                  key: const Key('thread-detail-page-list'),
                  controller: _scroll,
                  shrinkWrap: true,
                  itemExtent: _itemExtent,
                  itemCount: _maximum,
                  itemBuilder: (context, index) {
                    final page = index + 1;
                    final selected = page == widget.currentPage;
                    return ListTile(
                      key: Key('thread-detail-page-option-$page'),
                      dense: true,
                      selected: selected,
                      title: Text(l10n.commonPage(page)),
                      trailing: selected
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      onTap: () => Navigator.of(context).pop(page),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
