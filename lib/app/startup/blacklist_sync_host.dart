import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/blacklist/application/blacklist_sync_controller.dart';
import 'package:y300/features/blacklist/data/providers/blacklist_providers.dart';

/// Starts a stale web-blacklist refresh when the cookie-backed account appears
/// or changes.
///
/// It listens to the local session snapshot rather than the authentication
/// controller so ordinary app builds do not start a session request. The sync
/// itself still requires the verified session owner.
class BlacklistSyncHost extends ConsumerStatefulWidget {
  const BlacklistSyncHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BlacklistSyncHost> createState() => _BlacklistSyncHostState();
}

class _BlacklistSyncHostState extends ConsumerState<BlacklistSyncHost> {
  BlacklistSessionIdentity? _lastIdentity;
  bool _initialScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialScheduled) {
      return;
    }
    _initialScheduled = true;
    final identity = ref.read(blacklistSessionUidProvider);
    _lastIdentity = identity;
    if (identity != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_sync());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BlacklistSessionIdentity?>(blacklistSessionUidProvider, (
      previous,
      next,
    ) {
      if (next == null || next == previous) {
        return;
      }
      _lastIdentity = next;
      unawaited(_sync());
    });
    return widget.child;
  }

  Future<void> _sync() async {
    if (_lastIdentity == null) {
      return;
    }
    await ref.read(blacklistSyncControllerProvider.notifier).syncIfStale();
  }
}
