import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Narrow platform boundary for the reader's immersive system-bar state.
///
/// Keeping this behind an interface lets widget tests observe entry/exit
/// without sending platform messages, and keeps the page free of direct
/// `SystemChrome` calls.
abstract interface class ReaderSystemUiController {
  Future<void> enterImmersive();

  Future<void> restore();
}

final class PlatformReaderSystemUiController
    implements ReaderSystemUiController {
  bool _immersive = false;

  @override
  Future<void> enterImmersive() async {
    if (_immersive) return;
    _immersive = true;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Future<void> restore() async {
    if (!_immersive) return;
    _immersive = false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Target SDK 35+ is edge-to-edge, so this is the app's normal mode.
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }
}

final readerSystemUiControllerProvider = Provider<ReaderSystemUiController>(
  (ref) => PlatformReaderSystemUiController(),
);
