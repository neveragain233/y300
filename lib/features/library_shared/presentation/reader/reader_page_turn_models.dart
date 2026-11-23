import 'package:flutter/widgets.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_paged_turn_motion.dart';

/// 整页翻页动效（漫画与小说共用的通用整页过渡类型）。
enum ReaderPageEffect { slide, paper, fade, cover }

/// 翻页动效速度档位。
enum ReaderPageSpeed {
  relaxed(1.35),
  standard(1),
  brisk(0.7);

  const ReaderPageSpeed(this.durationScale);
  final double durationScale;
}

/// 共享整页翻页动效的时长、曲线与松手回弹倍率策略。
abstract final class ReaderPageMotion {
  static int baseMilliseconds(ReaderPageEffect effect) => switch (effect) {
    ReaderPageEffect.paper => 420,
    ReaderPageEffect.fade => 300,
    ReaderPageEffect.cover => 340,
    ReaderPageEffect.slide => 260,
  };

  static double snapDurationScale(
    ReaderPageEffect effect,
    ReaderPageSpeed speed,
  ) =>
      (effect == ReaderPageEffect.fade || effect == ReaderPageEffect.cover
          ? 1
          : baseMilliseconds(effect) / 260) *
      speed.durationScale;

  static Curve curve(ReaderPageEffect effect) => switch (effect) {
    ReaderPageEffect.fade || ReaderPageEffect.cover => Curves.linear,
    ReaderPageEffect.slide ||
    ReaderPageEffect.paper => ReaderPagedTurnMotion.animationCurve,
  };

  static Duration duration(ReaderPageEffect effect, ReaderPageSpeed speed) =>
      Duration(
        milliseconds: (baseMilliseconds(effect) * speed.durationScale).round(),
      );
}

/// 控制 `PageView` 松手吸合物理的时长倍率。
class ReaderPageScrollPhysics extends PageScrollPhysics {
  const ReaderPageScrollPhysics({required this.durationScale, super.parent});

  final double Function() durationScale;

  @override
  ReaderPageScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ReaderPageScrollPhysics(
        durationScale: durationScale,
        parent: buildParent(ancestor),
      );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final scale = durationScale();
    final simulation = super.createBallisticSimulation(position, velocity);
    return simulation == null ? null : _ScaledPageSimulation(simulation, scale);
  }
}

class _ScaledPageSimulation extends Simulation {
  _ScaledPageSimulation(this.source, this.scale)
    : super(tolerance: source.tolerance);

  final Simulation source;
  final double scale;

  @override
  double x(double time) => source.x(time / scale);

  @override
  double dx(double time) => source.dx(time / scale) / scale;

  @override
  bool isDone(double time) => source.isDone(time / scale);
}
