import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

const fadeTabDuration = Duration(milliseconds: 220);
const fadeTabCurve = Curves.easeInOut;

/// Plays [spring] over the first [seconds] of an animation, easing out the
/// remaining residual so the curve still ends exactly at 1.
class SpringCurve extends Curve {
  SpringCurve(SpringDescription spring, {required this.seconds})
    : _simulation = SpringSimulation(spring, 0, 1, 0);

  final double seconds;
  final SpringSimulation _simulation;

  late final double _residual = 1 - _simulation.x(seconds);

  @override
  double transformInternal(double t) =>
      _simulation.x(t * seconds) + _residual * t;
}

/// 让组件库感知外层是否要求减少动态效果。
///
/// 应用在墨水屏构建下把 [reduceMotion] 设为 true；未挂 scope 时回退到系统
/// 的无障碍设置，行为与 Material 的 disableAnimations 一致。
class PrismMotionScope extends InheritedWidget {
  const PrismMotionScope({
    super.key,
    required this.reduceMotion,
    required super.child,
  });

  final bool reduceMotion;

  static bool of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<PrismMotionScope>();
    if (scope != null) {
      return scope.reduceMotion;
    }
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  bool updateShouldNotify(PrismMotionScope oldWidget) =>
      oldWidget.reduceMotion != reduceMotion;
}

/// 组件库统一的动画时长入口。
abstract final class PrismMotion {
  static bool reduce(BuildContext context) => PrismMotionScope.of(context);

  static Duration duration(BuildContext context, Duration value) =>
      PrismMotionScope.of(context) ? Duration.zero : value;
}

Duration frameIntervalOf(BuildContext context) {
  final rate = View.maybeOf(context)?.display.refreshRate ?? 0;
  return rate > 0
      ? Duration(microseconds: Duration.microsecondsPerSecond ~/ rate)
      : Duration.zero;
}

/// Ends [simulation] at [end], where a controller would hold an overshoot.
class ArrivingSimulation extends Simulation {
  ArrivingSimulation(this.simulation, {required this.end})
    : _start = simulation.x(0),
      super(tolerance: simulation.tolerance);

  final Simulation simulation;
  final double end;
  final double _start;

  @override
  double x(double time) => simulation.x(time);

  @override
  double dx(double time) => simulation.dx(time);

  @override
  bool isDone(double time) =>
      simulation.isDone(time) ||
      (_start != end && (x(time) - end) * (_start - end) <= 0);
}

final dropletSpring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 165,
  ratio: 0.8,
);

/// Rises to 1 at [peak] and back, as iOS 27's droplets overshoot and swell.
double riseAndFall(double time, double peak, double sharpness) {
  if (time <= 0) {
    return 0;
  }
  final x = time / peak;
  return math.pow(x, sharpness) * math.exp(sharpness * (1 - x));
}
