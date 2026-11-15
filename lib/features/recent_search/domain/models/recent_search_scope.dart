/// Business ranges that keep separate recent-search keywords.
enum RecentSearchNamespace {
  forum,
  comicShelf,
  novelShelf,
  favoriteShelf,
  bookshelfShelf,
  history,
  accountDirectory,
  workChapters,
}

/// A stable local range for one recent-search list.
final class RecentSearchScope {
  const RecentSearchScope._(this.namespace, this.ownerKey);

  final RecentSearchNamespace namespace;

  /// User, work or module identity; null for shared ranges.
  final String? ownerKey;

  static const forum = RecentSearchScope._(RecentSearchNamespace.forum, null);
  static const comicShelf = RecentSearchScope._(
    RecentSearchNamespace.comicShelf,
    null,
  );
  static const novelShelf = RecentSearchScope._(
    RecentSearchNamespace.novelShelf,
    null,
  );
  static const favoriteShelf = RecentSearchScope._(
    RecentSearchNamespace.favoriteShelf,
    null,
  );
  static const bookshelfShelf = RecentSearchScope._(
    RecentSearchNamespace.bookshelfShelf,
    null,
  );
  static const history = RecentSearchScope._(
    RecentSearchNamespace.history,
    null,
  );

  static RecentSearchScope? accountDirectory(String? uid) {
    return _owned(RecentSearchNamespace.accountDirectory, uid);
  }

  static RecentSearchScope? workChapters(String? workId) {
    return _owned(RecentSearchNamespace.workChapters, workId);
  }

  static RecentSearchScope? _owned(
    RecentSearchNamespace namespace,
    String? ownerKey,
  ) {
    final value = ownerKey?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return RecentSearchScope._(namespace, value);
  }

  /// Encoded snapshot key. Owner keys are the app's stable identities.
  String get key => switch (namespace) {
    RecentSearchNamespace.forum => 'forum',
    RecentSearchNamespace.comicShelf => 'shelf:comic',
    RecentSearchNamespace.novelShelf => 'shelf:novel',
    RecentSearchNamespace.favoriteShelf => 'shelf:favorite',
    RecentSearchNamespace.bookshelfShelf => 'shelf:bookshelf',
    RecentSearchNamespace.history => 'history',
    RecentSearchNamespace.accountDirectory => 'account:$ownerKey',
    RecentSearchNamespace.workChapters => 'work:$ownerKey:chapters',
  };

  @override
  bool operator ==(Object other) =>
      other is RecentSearchScope && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'RecentSearchScope($key)';
}
