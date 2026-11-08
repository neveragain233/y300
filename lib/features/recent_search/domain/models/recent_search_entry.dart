/// One recent search keyword and when it was last used.
final class RecentSearchEntry {
  const RecentSearchEntry({required this.keyword, required this.usedAt});

  final String keyword;
  final DateTime usedAt;

  @override
  bool operator ==(Object other) =>
      other is RecentSearchEntry &&
      other.keyword == keyword &&
      other.usedAt.isAtSameMomentAs(usedAt);

  @override
  int get hashCode => Object.hash(keyword, usedAt);
}
