import 'package:flutter/material.dart';
import 'package:y300/app/navigation/main_shell_bottom_inset.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/features/messages/presentation/message_feed_controller.dart';
import 'package:y300/features/messages/presentation/widgets/message_feed_view.dart';
import 'package:y300/features/messages/presentation/widgets/message_read_status.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_status_views.dart';

/// Shared list chrome; private messages and notifications keep separate state.
class MessageFeedList<P> extends StatelessWidget {
  const MessageFeedList({
    super.key,
    required this.controller,
    required this.isActive,
    required this.listKey,
    required this.itemCount,
    required this.itemBuilder,
    required this.emptyText,
  });
  final MessageFeedController<P> controller;
  final bool isActive;
  final PageStorageKey<String> listKey;
  final int Function(P) itemCount;
  final Widget Function(BuildContext, P, int) itemBuilder;
  final String emptyText;

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: isActive,
    child: MessageFeedView<P>(
      controller: controller,
      isActive: isActive,
      builder: (context, state) {
        final data = state.data;
        final count = data == null ? 0 : itemCount(data);
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            key: listKey,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (data == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: MessageReadStatus(
                      failure: state.failure,
                      onRetry: controller.refresh,
                    ),
                  ),
                )
              else if (count == 0)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(title: emptyText),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  sliver: SliverList.separated(
                    itemCount: count,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        itemBuilder(context, data, index),
                  ),
                ),
              if (data != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: state.failure != null
                        ? MessageReadStatus(
                            failure: state.failure,
                            onRetry:
                                state.failedOperation ==
                                    MessageFeedOperation.more
                                ? controller.loadMore
                                : controller.refresh,
                          )
                        : state.operation == MessageFeedOperation.more
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).y300NativeContent.accent,
                            ),
                          )
                        : controller.hasMore
                        ? Center(
                            child: TextButton(
                              onPressed: state.isBusy
                                  ? null
                                  : controller.loadMore,
                              child: Text(
                                AppLocalizations.of(context).messageLoadMore,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: mainShellBottomScrollInset(context)),
              ),
            ],
          ),
        );
      },
    ),
  );
}
