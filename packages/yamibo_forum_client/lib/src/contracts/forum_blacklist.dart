import '../network/forum_request.dart';
import 'data_read_contract.dart';

/// Read request for the authenticated account's web blacklist.
final class ForumBlacklistQuery {
  /// Creates a complete-list read request.
  const ForumBlacklistQuery({this.cancellation});

  /// Cancels an obsolete account read.
  final ForumRequestCancellation? cancellation;
}

/// One blacklisted forum user.
final class ForumBlacklistEntry {
  /// Creates a validated identity.
  const ForumBlacklistEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
  });

  /// Stable positive forum user ID.
  final String userId;

  /// Exact server username.
  final String username;

  /// Validated HTTP(S) avatar URL, when supplied by the source.
  final String? avatarUrl;
}

/// The complete blacklist as read across its pages.
final class ForumBlacklistData {
  /// Creates a complete-list result.
  const ForumBlacklistData({required this.entries, required this.pagesRead});

  /// Blacklisted users in source order.
  final List<ForumBlacklistEntry> entries;

  /// Number of accepted pages, for diagnostics and bounded-read evidence.
  final int pagesRead;
}

/// Capabilities available from a blacklist source.
enum ForumBlacklistCapability {
  /// Stable user IDs and exact usernames.
  identity,

  /// Server-supplied avatar references.
  avatar,

  /// The source validates and returns the complete list, not one page.
  completeList,
}

/// Declared blacklist source capabilities.
final class ForumBlacklistSourceCapabilities {
  /// Creates a capability set.
  const ForumBlacklistSourceCapabilities({required this.values});

  /// Per-capability support.
  final DataCapabilitySet<ForumBlacklistCapability> values;

  /// Converts declared capabilities to a successful read's capabilities.
  ForumBlacklistReadCapabilities toReadCapabilities() =>
      ForumBlacklistReadCapabilities(values: values);
}

/// Capabilities proven for a successful blacklist read.
final class ForumBlacklistReadCapabilities {
  /// Creates a capability set.
  const ForumBlacklistReadCapabilities({required this.values});

  /// Per-capability support.
  final DataCapabilitySet<ForumBlacklistCapability> values;

  /// Whether the requested capability is supported.
  bool supports(ForumBlacklistCapability capability) =>
      values.supports(capability);
}

/// Loads the current account's web blacklist without modifying it.
abstract interface class ForumBlacklistRepository {
  /// Source-declared capabilities.
  ForumBlacklistSourceCapabilities get capabilities;

  /// Loads and validates the complete list belonging to the current session.
  Future<DataReadResult<ForumBlacklistData, ForumBlacklistReadCapabilities>>
  load(ForumBlacklistQuery query);
}
