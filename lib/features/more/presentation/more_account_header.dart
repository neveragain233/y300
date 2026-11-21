import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';
import 'package:y300/core/motion/app_motion.dart';
import 'package:y300/features/more/presentation/more_account_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yamibo_forum_client/yamibo_forum_client_contracts.dart';
import 'package:y300/features/auth/application/auth_session_controller.dart';
import 'package:y300/features/cache/domain/models/image_cache_models.dart';
import 'package:y300/features/profile/presentation/current_account_summary_controller.dart';
import 'package:y300/features/profile/presentation/daily_auto_sign_in_toggle.dart';
import 'package:y300/features/profile/presentation/daily_sign_in_controller.dart';
import 'package:y300/features/auth/application/verified_session_owner.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/forum_cached_avatar.dart';

/// Account presentation stays independent of the menu's navigation flows.
class MoreAccountHeader extends ConsumerWidget {
  const MoreAccountHeader({
    super.key,
    required this.onOpenProfile,
    this.onOpenThreads,
    this.onOpenReplies,
    this.onOpenCredits,
    this.isAccountActionPending = false,
  });

  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenThreads;
  final VoidCallback? onOpenReplies;
  final VoidCallback? onOpenCredits;
  final bool isAccountActionPending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authSessionControllerProvider);
    final session = auth.asData?.value;
    final owner = ref.watch(verifiedSessionOwnerProvider);
    final summary = ref.watch(currentAccountSummaryControllerProvider);
    final canPreview =
        auth.isLoading ||
        auth.hasError ||
        session?.verificationInconclusive == true;
    final current = owner != null
        ? summary.owner == owner
        : canPreview && summary.previewUid != null;
    final displayUid = current ? summary.displayUid : owner?.uid;
    final hasAccount = displayUid != null;
    final data = current ? summary.data : null;
    final capabilities = current ? summary.capabilities : null;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final signedIn = session?.isLoggedIn == true;
    final loggingOut = session?.isLoggingOut == true;
    final verifying =
        auth.isLoading || (signedIn && owner == null && !loggingOut);
    final displayName =
        capabilities?.supports(CurrentUserProfileCapability.userName) == true
        ? data?.identity.displayName
        : null;
    final name = !hasAccount
        ? verifying || loggingOut
              ? l10n.moreAccountChecking
              : l10n.moreAccountSignedOut
        : _nonEmpty(displayName) ??
              _nonEmpty(session?.username) ??
              (owner == null
                  ? l10n.moreAccountChecking
                  : l10n.moreAccountSignedIn);
    final groupName =
        capabilities?.supports(CurrentUserProfileCapability.groupName) == true
        ? _nonEmpty(data?.groupName)
        : null;
    final credits =
        capabilities?.supports(CurrentUserProfileCapability.creditTotal) == true
        ? data?.creditTotal
        : null;
    final threads =
        capabilities?.supports(CurrentUserProfileCapability.threadCount) == true
        ? data?.threadCount
        : null;
    final replies =
        capabilities?.supports(CurrentUserProfileCapability.replyCount) == true
        ? data?.replyCount
        : null;
    final busy = verifying || loggingOut || isAccountActionPending;
    final openProfile = owner != null && !busy ? onOpenProfile : null;
    final motion200 = AppMotion.duration(
      context,
      const Duration(milliseconds: 200),
    );
    final showAutoSignIn =
        hasAccount &&
        owner != null &&
        ref.watch(
          dailySignInControllerProvider.select((s) => s.owner == owner),
        );
    final avatar = Semantics(
      label: l10n.moreAccountAvatar(name),
      image: true,
      child: InkWell(
        key: const Key('more-account-avatar'),
        customBorder: const CircleBorder(),
        onTap: openProfile,
        child: hasAccount
            ? MoreAccountAvatar(
                key: ValueKey('account-avatar-$displayUid'),
                uid: displayUid,
                size: 64,
              )
            : ForumCachedAvatar(
                imageUrl: null,
                ownerId: '',
                ownerType: ImageCacheOwnerType.profile,
                size: 56,
                transitionDuration: Duration.zero,
                fallbackPolicy:
                    verifying ||
                        auth.hasError ||
                        session?.verificationInconclusive == true
                    ? ForumAvatarFallbackPolicy.neutralSurface
                    : ForumAvatarFallbackPolicy.localDefaultAvatar,
              ),
      ),
    );
    final identityChildren = <Widget>[
      Semantics(
        label: openProfile == null ? null : l10n.moreAccountOpenProfile(name),
        child: InkWell(
          key: const Key('more-account-name'),
          onTap: openProfile,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AnimatedSwitcher(
              key: ValueKey((displayUid, data != null)),
              duration: motion200,
              child: Text(
                name,
                key: ValueKey(name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: hasAccount ? 20 : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
      if (hasAccount && groupName != null) ...[
        const SizedBox(height: 6),
        Semantics(
          label: l10n.moreAccountGroup(groupName),
          excludeSemantics: true,
          child: AnimatedSwitcher(
            key: ValueKey(displayUid),
            duration: motion200,
            child: KeyedSubtree(
              key: ValueKey(groupName),
              child: Container(
                key: const Key('more-account-group'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  groupName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ];
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: identityChildren,
    );

    final scheme = theme.colorScheme;
    final cardColor = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainer
        : scheme.surfaceContainerLowest;
    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppLayoutTokens.contentSpacing,
        12,
        AppLayoutTokens.contentSpacing,
        0,
      ),
      child: ClipRRect(
        key: const Key('more-account-header'),
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 16),
                    avatar,
                  ],
                ),
              ),
              if (hasAccount) ...[
                Divider(height: 1, thickness: 0.6, color: dividerColor),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _AccountStatistic(
                          key: const Key('more-account-threads'),
                          label: l10n.moreAccountThreads,
                          value: threads,
                          accountUid: displayUid,
                          onTap: owner != null && !busy ? onOpenThreads : null,
                        ),
                      ),
                      const SizedBox(
                        height: 32,
                        width: 16,
                        child: VerticalDivider(indent: 5, endIndent: 5),
                      ),
                      Expanded(
                        child: _AccountStatistic(
                          key: const Key('more-account-replies'),
                          label: l10n.moreAccountReplies,
                          value: replies,
                          accountUid: displayUid,
                          onTap: owner != null && !busy ? onOpenReplies : null,
                        ),
                      ),
                      const SizedBox(
                        height: 32,
                        width: 16,
                        child: VerticalDivider(indent: 5, endIndent: 5),
                      ),
                      Expanded(
                        child: _AccountStatistic(
                          key: const Key('more-account-credits'),
                          label: l10n.moreAccountCreditLabel,
                          value: credits,
                          accountUid: displayUid,
                          onTap: owner != null && !busy ? onOpenCredits : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (showAutoSignIn) ...[
                Divider(height: 1, thickness: 0.6, color: dividerColor),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: DailyAutoSignInToggle(expand: true),
                ),
              ],
              if (current && summary.failure != null) ...[
                Divider(height: 1, thickness: 0.6, color: dividerColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        l10n.moreAccountLoadFailed,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        key: const Key('more-account-retry'),
                        onPressed: summary.isLoading
                            ? null
                            : () => ref
                                  .read(
                                    currentAccountSummaryControllerProvider
                                        .notifier,
                                  )
                                  .refresh(),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

class _AccountStatistic extends StatelessWidget {
  const _AccountStatistic({
    super.key,
    required this.label,
    this.value,
    this.accountUid,
    this.onTap,
  });

  final String? accountUid;

  final String label;
  final int? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = value?.toString() ?? l10n.moreAccountUnavailable;
    return Semantics(
      label: l10n.moreAccountStatistic(label, text),
      button: onTap != null,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final style = theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  );
                  final measurement = TextPainter(
                    text: TextSpan(text: text, style: style),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  final fits = measurement.width + 2 <= constraints.maxWidth;
                  measurement.dispose();
                  // The counter converts through double; preserve large integers exactly.
                  if (value == null ||
                      (value! < -9007199254740991 ||
                          value! > 9007199254740991) ||
                      !fits) {
                    return Text(
                      text,
                      textAlign: TextAlign.center,
                      style: style,
                    );
                  }
                  return AnimatedFlipCounter(
                    key: ValueKey(accountUid),
                    value: value!,
                    duration: AppMotion.duration(
                      context,
                      const Duration(milliseconds: 260),
                    ),
                    negativeSignDuration: AppMotion.duration(
                      context,
                      const Duration(milliseconds: 150),
                    ),
                    textStyle: style,
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
