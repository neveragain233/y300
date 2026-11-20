import 'package:flutter/material.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/app/theme/app_theme_semantics.dart';
import 'package:y300/features/auth/presentation/login_page.dart';
import 'package:y300/features/profile/presentation/blog/blog_surface.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/app_status_views.dart';
import 'package:y300/shared/services/localized_error_summary.dart';

class FriendLoginPrompt extends StatelessWidget {
  const FriendLoginPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      message: l10n.profileFriendsLoginRequired,
      action: FilledButton(
        key: const Key('my-friends-login'),
        onPressed: () => Navigator.of(context)
            .push<void>(MaterialPageRoute(builder: (_) => const LoginPage())),
        child: Text(l10n.authLoginTitle),
      ),
    );
  }
}

class FriendReadFailure extends StatelessWidget {
  const FriendReadFailure({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  final DataReadFailure<ForumFriendFeedPage, ForumFriendFeedReadCapabilities>?
  failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (failure?.kind == DataReadFailureKind.unauthorized) {
      return const FriendLoginPrompt();
    }
    final l10n = AppLocalizations.of(context);
    return AppErrorState(
      message: failure == null
          ? l10n.profileFriendsLoadFailed
          : LocalizedErrorSummary.resolve(l10n, failure),
      retryLabel: l10n.commonRetry,
      retryKey: const Key('my-friends-retry'),
      onRetry: onRetry,
    );
  }
}

class FriendEmptyState extends StatelessWidget {
  const FriendEmptyState({super.key, required this.scope});

  final ForumFriendFeedScope scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppEmptyState(
      title: switch (scope) {
        ForumFriendFeedScope.friends => l10n.profileFriendsEmpty,
        ForumFriendFeedScope.online => l10n.profileFriendsOnlineEmpty,
        ForumFriendFeedScope.visitors => l10n.profileFriendsVisitorsEmpty,
        ForumFriendFeedScope.footprints => l10n.profileFriendsFootprintsEmpty,
      },
    );
  }
}

/// Stays above the scrollable list while a sent removal awaits verification.
class FriendRemovalVerification extends StatelessWidget {
  const FriendRemovalVerification({
    super.key,
    required this.isBusy,
    required this.onVerify,
  });

  final bool isBusy;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: BlogSurface(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.profileFriendRemovalUnknown,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.y300NativeContent.supportingText,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('my-friends-removal-verify'),
                  onPressed: isBusy ? null : onVerify,
                  child: Text(l10n.profileFriendRemovalVerify),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
