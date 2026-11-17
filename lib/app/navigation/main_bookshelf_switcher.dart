import 'package:flutter/material.dart';
import 'package:y300/app/navigation/main_navigation_settings.dart';
import 'package:y300/app/navigation/main_shell_destination_presentation.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_popup_menu.dart';

class MainBookshelfSwitcher extends StatelessWidget {
  const MainBookshelfSwitcher({
    super.key,
    required this.current,
    required this.destinations,
    this.onSelected,
  });

  final MainShellDestination current;
  final List<MainShellDestination> destinations;
  final ValueChanged<MainShellDestination>? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (destinations.length < 2) return Text(current.localizedLabel(l10n));
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = MediaQuery.textScalerOf(context).scale(14) * 4 + 80;
        if (constraints.maxWidth < labelWidth) {
          return AppPopupMenuButton<MainShellDestination>(
            key: const Key('main-bookshelf-switcher'),
            tooltip: l10n.appNavigationBookshelf,
            enabled: onSelected != null,
            onSelected: onSelected,
            itemBuilder: (_) => [
              for (final destination in destinations)
                AppPopupMenuItem<MainShellDestination>(
                  value: destination,
                  label: destination.localizedLabel(l10n),
                  checked: destination == current,
                ),
            ],
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      current.localizedLabel(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          );
        }
        return SegmentedButton<MainShellDestination>(
          key: const Key('main-bookshelf-switcher'),
          showSelectedIcon: false,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              final theme = Theme.of(context);
              return states.contains(WidgetState.selected)
                  ? theme.colorScheme.onPrimary
                  : theme.appBarTheme.foregroundColor;
            }),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
            ),
          ),
          segments: [
            for (final destination in destinations)
              ButtonSegment(
                value: destination,
                label: Text(destination.localizedLabel(l10n)),
              ),
          ],
          selected: {current},
          onSelectionChanged: onSelected == null
              ? null
              : (value) => onSelected!(value.single),
        );
      },
    );
  }
}
