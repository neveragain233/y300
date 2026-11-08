/// A local rule that hides one forum thread from native forum surfaces.
///
/// Rules are device-local and available to signed-out visitors. The [subject]
/// is only a display snapshot for the management page; matching always uses
/// the canonical [tid].
final class BlockedThread {
  const BlockedThread({
    required this.tid,
    required this.subject,
    required this.blockedAt,
  });

  /// Canonical thread id used for rule matching.
  final String tid;

  /// Title captured when the rule was created, for recognition only.
  final String subject;

  /// Time the current rule was written.
  final DateTime blockedAt;

  /// Whether both entries describe the same rule revision.
  ///
  /// An undo request only applies while this still holds, so a later decision
  /// for the same thread is never reversed by an older gesture.
  bool isSameRule(BlockedThread other) =>
      tid == other.tid &&
      subject == other.subject &&
      blockedAt.isAtSameMomentAs(other.blockedAt);

  @override
  bool operator ==(Object other) => other is BlockedThread && isSameRule(other);

  @override
  int get hashCode => Object.hash(tid, subject, blockedAt);
}
