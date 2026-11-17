import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/features/messages/presentation/message_feed_providers.dart';
import 'package:y300/features/messages/presentation/widgets/message_read_status.dart';
import 'package:y300/features/messages/presentation/widgets/private_message_batch_composer.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_page_app_bar.dart';

class NewPrivateMessagePage extends ConsumerWidget {
  const NewPrivateMessagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(messageAccountIdProvider);
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).y300NativeContent;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppPageAppBar(title: l10n.messageNew),
      body: account == null
          ? const MessageLoginPrompt()
          : PrivateMessageBatchComposer(
              key: ValueKey(account),
              accountId: account,
            ),
    );
  }
}
