enum ThreadControlsSide { left, right }

final class ThreadControlsPreferences {
  const ThreadControlsPreferences({
    this.compact = false,
    this.side = ThreadControlsSide.right,
    this.showFavorite = true,
    this.navigationEnabled = true,
    this.singleNavigationButton = false,
    this.holdToFirstPost = false,
    this.hideOnScroll = false,
  });

  final bool compact;
  final ThreadControlsSide side;
  final bool showFavorite;
  final bool navigationEnabled;
  final bool singleNavigationButton;
  final bool holdToFirstPost;
  final bool hideOnScroll;

  ThreadControlsPreferences copyWith({
    bool? compact,
    ThreadControlsSide? side,
    bool? showFavorite,
    bool? navigationEnabled,
    bool? singleNavigationButton,
    bool? holdToFirstPost,
    bool? hideOnScroll,
  }) => ThreadControlsPreferences(
    compact: compact ?? this.compact,
    side: side ?? this.side,
    showFavorite: showFavorite ?? this.showFavorite,
    navigationEnabled: navigationEnabled ?? this.navigationEnabled,
    singleNavigationButton:
        singleNavigationButton ?? this.singleNavigationButton,
    holdToFirstPost: holdToFirstPost ?? this.holdToFirstPost,
    hideOnScroll: hideOnScroll ?? this.hideOnScroll,
  );
}
