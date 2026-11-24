/// Adding one authenticated forum user to the account's web blacklist.
library;

import '../network/forum_request.dart';
import 'data_command_contract.dart';

/// Adds one target to the current account's blacklist.
///
/// The real blacklist form posts the target's exact server username to
/// `home.php?mod=spacecp&ac=friend&op=blacklist`; the stable id is retained
/// for local reconciliation and receipt verification.
final class ForumBlacklistAddSubmission {
  /// Creates an add-blacklist request.
  const ForumBlacklistAddSubmission({
    required this.userId,
    required this.username,
    this.cancellation,
  });

  /// Stable positive forum user id of the target.
  final String userId;

  /// Exact server username submitted by the add form.
  final String username;

  /// Cancels local waiting; cannot roll back an already accepted command.
  final ForumRequestCancellation? cancellation;
}

/// Proven server effect: the target exists in the account's blacklist.
final class ForumBlacklistAddReceipt {
  /// Creates a receipt for the confirmed blacklist member.
  const ForumBlacklistAddReceipt({
    required this.userId,
    required this.username,
  });

  /// Confirmed target user id.
  final String userId;

  /// Exact username as returned by the blacklist listing.
  final String username;
}

/// Applies the forum account's blacklist write through the shared session.
abstract interface class ForumBlacklistCommand {
  /// Returns applied only after the account's blacklist lists the target.
  Future<DataCommandResult<ForumBlacklistAddReceipt>> execute(
    ForumBlacklistAddSubmission submission,
  );
}

/// Removes one target from the current account's blacklist.
final class ForumBlacklistRemoveSubmission {
  /// Creates a remove-blacklist request.
  const ForumBlacklistRemoveSubmission({
    required this.userId,
    this.cancellation,
  });

  /// Stable positive forum user id of the target.
  final String userId;

  /// Cancels local waiting; cannot roll back an already accepted command.
  final ForumRequestCancellation? cancellation;
}

/// Proven server effect: the target is absent from the account's blacklist.
final class ForumBlacklistRemoveReceipt {
  /// Creates a receipt for the confirmed removal.
  const ForumBlacklistRemoveReceipt({required this.userId});

  /// Confirmed removed user id.
  final String userId;
}

/// Removes one member from the forum account's web blacklist.
abstract interface class ForumBlacklistRemoveCommand {
  /// Returns applied only after a complete blacklist read omits the target.
  Future<DataCommandResult<ForumBlacklistRemoveReceipt>> execute(
    ForumBlacklistRemoveSubmission submission,
  );
}
