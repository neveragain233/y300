/// Device-local display policy for the current account's web blacklist.
final class BlacklistDisplayPreferences {
  const BlacklistDisplayPreferences({
    this.hideThreadsStartedByBlacklistedUsers = false,
  });

  /// Default matches the website: threads stay visible and their author's
  /// floors collapse inside the thread.
  static const defaults = BlacklistDisplayPreferences();

  /// Whether threads initiated by a blacklisted author disappear from lists.
  final bool hideThreadsStartedByBlacklistedUsers;

  BlacklistDisplayPreferences copyWith({
    bool? hideThreadsStartedByBlacklistedUsers,
  }) => BlacklistDisplayPreferences(
    hideThreadsStartedByBlacklistedUsers:
        hideThreadsStartedByBlacklistedUsers ??
        this.hideThreadsStartedByBlacklistedUsers,
  );
}
