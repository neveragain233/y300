import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:y300/l10n/app_localizations.dart';

Future<int?> showThreadPagePicker(
  BuildContext context, {
  required int currentPage,
  required int? lastPage,
  required bool hasMore,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ThreadPagePicker(
    currentPage: math.max(1, currentPage),
    lastPage: lastPage,
    hasMore: hasMore,
  ),
);

class _ThreadPagePicker extends StatefulWidget {
  const _ThreadPagePicker({
    required this.currentPage,
    required this.lastPage,
    required this.hasMore,
  });
  final int currentPage;
  final int? lastPage;
  final bool hasMore;
  @override
  State<_ThreadPagePicker> createState() => _ThreadPagePickerState();
}

class _ThreadPagePickerState extends State<_ThreadPagePicker> {
  late final _input = TextEditingController(text: '${widget.currentPage}');
  late final _scroll = ScrollController(
    initialScrollOffset: math.max(0, widget.currentPage - 3) * 48.0,
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
    if (page == null || page < 1 || page > _maximum) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.lastPage == null
                    ? l10n.threadControlsPageUnknown(widget.currentPage)
                    : l10n.threadControlsPageSummary(
                        widget.currentPage,
                        widget.lastPage!,
                      ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('thread-detail-page-input'),
                      controller: _input,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: l10n.threadControlsPageInput,
                        errorText: _invalid
                            ? l10n.threadControlsInvalidPage
                            : null,
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(l10n.threadControlsJumpPage),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  key: const Key('thread-detail-page-list'),
                  controller: _scroll,
                  itemExtent: 48,
                  itemCount: _maximum,
                  itemBuilder: (context, index) {
                    final page = index + 1;
                    return ListTile(
                      key: Key('thread-detail-page-option-$page'),
                      selected: page == widget.currentPage,
                      title: Text(l10n.commonPage(page)),
                      trailing: page == widget.currentPage
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.of(context).pop(page),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
