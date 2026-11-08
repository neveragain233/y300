/// Canonical identity rules for locally blocked threads.
abstract final class ThreadBlockIdentity {
  /// Returns the canonical thread id, or null when [raw] cannot identify a
  /// thread.
  ///
  /// Numeric ids are written without leading zeros so that rule text and
  /// parsed links converge on one key. Non-numeric ids stay as trimmed text;
  /// fixtures and future sources must still match exactly.
  static String? normalizeTid(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed > 0 ? parsed.toString() : null;
    }
    return value;
  }

  /// Whether [candidate] denotes the same thread as canonical [blockedTid].
  static bool matches(String? candidate, String blockedTid) {
    return normalizeTid(candidate) == blockedTid;
  }
}
