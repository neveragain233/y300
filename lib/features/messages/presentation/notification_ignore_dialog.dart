import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/messages/data/message_repository_provider.dart';
import 'package:y300/features/messages/presentation/message_feed_providers.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_confirm_dialog.dart';
import 'package:y300/shared/widgets/app_grouped_list.dart';
import 'package:y300/shared/services/localized_error_summary.dart';

/// The dialog owns one explicit write, even if the originating row scrolls away.
class NotificationIgnoreDialog extends ConsumerStatefulWidget {
  const NotificationIgnoreDialog({
    super.key,
    required this.accountId,
    required this.item,
  });
  final String accountId;
  final ForumNotificationItem item;

  @override
  ConsumerState<NotificationIgnoreDialog> createState() =>
      _NotificationIgnoreDialogState();
}

class _NotificationIgnoreDialogState
    extends ConsumerState<NotificationIgnoreDialog> {
  late ForumNotificationIgnoreScope _scope;
  bool _busy = false;
  DataCommandResult<ForumNotificationIgnoreReceipt>? _result;
  final _cancellation = ForumRequestCancellation();
  bool get _hasAuthor => RegExp(r'^[1-9]\d*$').hasMatch(widget.item.authorId);

  @override
  void initState() {
    super.initState();
    _scope = _hasAuthor
        ? ForumNotificationIgnoreScope.author
        : ForumNotificationIgnoreScope.allAuthors;
  }

  @override
  void dispose() {
    _cancellation.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || ref.read(messageAccountIdProvider) != widget.accountId) return;
    setState(() => _busy = true);
    DataCommandResult<ForumNotificationIgnoreReceipt> result;
    try {
      result = await ref
          .read(messageRepositoryProvider)
          .ignore(
            ForumNotificationIgnoreSubmission(
              notificationId: widget.item.id,
              type: widget.item.type,
              authorId: widget.item.authorId,
              scope: _scope,
              cancellation: _cancellation,
            ),
          );
    } on Object {
      result = const DataCommandOutcomeUnknown(
        DataCommandFailure(
          kind: DataCommandFailureKind.unknown,
          retryPolicy: DataCommandRetryPolicy.explicitOnly,
          diagnosticMessage: 'notification_ignore_failed',
        ),
      );
    }
    if (!mounted || ref.read(messageAccountIdProvider) != widget.accountId) {
      return;
    }
    if (result case DataCommandApplied<ForumNotificationIgnoreReceipt>(
      :final receipt,
    )) {
      Navigator.of(context).pop(receipt);
    } else {
      setState(() {
        _busy = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ownsAccount = ref.watch(messageAccountIdProvider) == widget.accountId;
    final result = _result;
    return AppFormDialog(
      title: l10n.messageIgnore,
      hasFields: true,
      content: !ownsAccount
          ? Text(l10n.messageLoginRequired)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.messageIgnoreExplanation),
                const SizedBox(height: 12),
                AppGroupedSection(
                  margin: EdgeInsets.zero,
                  children: [
                    if (_hasAuthor)
                      AppGroupedRow(
                        title: l10n.messageIgnoreAuthor,
                        subtitle: widget.item.authorName.isEmpty
                            ? null
                            : widget.item.authorName,
                        selected: _scope == ForumNotificationIgnoreScope.author,
                        enabled: !_busy,
                        trailing: _scope == ForumNotificationIgnoreScope.author
                            ? Icon(Icons.check, size: 20, color: scheme.primary)
                            : null,
                        onTap: () => setState(
                          () => _scope = ForumNotificationIgnoreScope.author,
                        ),
                      ),
                    AppGroupedRow(
                      title: l10n.messageIgnoreEveryone,
                      selected:
                          _scope == ForumNotificationIgnoreScope.allAuthors,
                      enabled: !_busy,
                      trailing:
                          _scope == ForumNotificationIgnoreScope.allAuthors
                          ? Icon(Icons.check, size: 20, color: scheme.primary)
                          : null,
                      onTap: () => setState(
                        () => _scope = ForumNotificationIgnoreScope.allAuthors,
                      ),
                    ),
                  ],
                ),
                if (result?.failureOrNull != null) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      result is DataCommandOutcomeUnknown
                          ? l10n.messageIgnoreUnknown
                          : LocalizedErrorSummary.resolve(l10n, result),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
              ],
            ),
      actions: [
        AppDialogAction(
          label: l10n.commonClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (ownsAccount)
          AppDialogAction(
            key: const Key('notification-ignore-save'),
            label: _busy ? l10n.messageIgnoreSaving : l10n.commonConfirm,
            enabled: !_busy,
            onPressed: _save,
          ),
      ],
    );
  }
}
