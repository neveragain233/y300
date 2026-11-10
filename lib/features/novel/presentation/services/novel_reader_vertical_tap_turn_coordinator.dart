import 'package:flutter/material.dart';

/// Direction of one vertical reader tap-turn request.
enum NovelReaderVerticalTurnDirection { backward, forward }

/// Owns tap-triggered vertical scroll animation and its single pending intent.
///
/// A tap starts an animation from the position that is current when the
/// animation actually starts. While one animation is running, at most one more
/// same-direction intent is retained; an opposite tap interrupts the running
/// animation so the reader immediately moves back. Drags, seeks, chapter or
/// mode switches and disposal retire the intent through [retire].
final class NovelReaderVerticalTapTurnCoordinator {
  NovelReaderVerticalTapTurnCoordinator({
    required ScrollController scrollController,
    this.duration = const Duration(milliseconds: 260),
    this.curve = Curves.easeOutCubic,
  }) : _scrollController = scrollController;

  final ScrollController _scrollController;
  final Duration duration;
  final Curve curve;

  _PendingTurn? _pending;
  NovelReaderVerticalTurnDirection? _runningDirection;
  bool _running = false;
  bool _disposed = false;
  int _generation = 0;

  void turn({
    required NovelReaderVerticalTurnDirection direction,
    required double step,
    required VoidCallback onCommitted,
    Duration? duration,
    Curve? curve,
  }) {
    if (_disposed || !step.isFinite || step <= 0) {
      return;
    }
    final pending = _PendingTurn(
      direction,
      step,
      onCommitted,
      duration ?? this.duration,
      curve ?? this.curve,
    );
    _pending = pending;
    if (_running) {
      if (direction != _runningDirection) {
        _interruptRunningAnimation();
      }
      return;
    }
    _pump();
  }

  /// Drops queued intent and invalidates the in-flight completion callback.
  ///
  /// The running animation is left to the caller (a drag replaces the scroll
  /// activity itself; seeks jump explicitly).
  void retire() {
    _generation++;
    _pending = null;
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    _pending = null;
  }

  void _pump() {
    _running = true;
    _run();
  }

  Future<void> _run() async {
    while (!_disposed) {
      final pending = _pending;
      if (pending == null) {
        break;
      }
      _pending = null;
      await _animate(pending);
    }
    if (_disposed) {
      return;
    }
    _running = false;
    _runningDirection = null;
  }

  Future<void> _animate(_PendingTurn pending) async {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    final start = position.pixels;
    final delta = pending.direction == NovelReaderVerticalTurnDirection.forward
        ? pending.step
        : -pending.step;
    final target = (start + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((target - start).abs() < 0.5) {
      // At the boundary the final callback is not a navigation.
      return;
    }
    final generation = ++_generation;
    _runningDirection = pending.direction;
    await _scrollController.animateTo(
      target,
      duration: pending.duration,
      curve: pending.curve,
    );
    if (_disposed ||
        generation != _generation ||
        !_scrollController.hasClients) {
      return;
    }
    // Layout compensation can move the offset without a completed turn; only a
    // request that actually advanced the reader confirms progress.
    if ((_scrollController.offset - start).abs() < 0.5) {
      return;
    }
    pending.onCommitted();
  }

  void _interruptRunningAnimation() {
    _generation++;
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    // jumpTo replaces the driven activity; the awaiting _animate call resumes
    // and the loop starts the reverse intent from the actual position.
    position.jumpTo(position.pixels);
  }
}

final class _PendingTurn {
  const _PendingTurn(
    this.direction,
    this.step,
    this.onCommitted,
    this.duration,
    this.curve,
  );

  final NovelReaderVerticalTurnDirection direction;
  final double step;
  final VoidCallback onCommitted;
  final Duration duration;
  final Curve curve;
}
