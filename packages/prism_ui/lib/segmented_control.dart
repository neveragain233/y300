import 'package:flutter/widgets.dart';
import 'package:prism_ui/card_surface.dart';
import 'package:prism_ui/context.dart';
import 'package:prism_ui/press_surface.dart';
import 'package:prism_ui/shape.dart';
import 'package:prism_ui/surface.dart';
import 'package:prism_ui/typography.dart';

class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.segmentKeyBuilder,
  });

  static const double _height = 44;
  static const double _inset = 4;

  final List<(T, String)> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final Key? Function(T value)? segmentKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final count = segments.length;
    final index = segments.indexWhere((segment) => segment.$1 == value);
    final control = Container(
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: AppShape.full,
      ),
      child: Stack(
        children: [
          if (index >= 0)
            AnimatedAlign(
              duration: context.motionDuration(
                const Duration(milliseconds: 250),
              ),
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional(
                count == 1 ? 0 : index * 2 / (count - 1) - 1,
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colorScheme.primary,
                    shape: AppShape.full,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final (option, label) in segments)
                Expanded(
                  child: PressSurface(
                    key: segmentKeyBuilder?.call(option),
                    fill: const Color(0x00000000),
                    shape: AppShape.full,
                    look: option == value ? PressLook.none : PressLook.ink,
                    ringStandsOff: option == value,
                    selected: option == value,
                    childFills: true,
                    // A null onPressed would unfocus the selected segment.
                    onPressed: !enabled
                        ? null
                        : option == value
                        ? () {}
                        : () => onChanged(option),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: context.motionDuration(
                          const Duration(milliseconds: 200),
                        ),
                        style: AppTextStyle.subheadline
                            .of(context, emphasized: option == value)
                            .copyWith(
                              color: option == value
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                            ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    if (enabled) {
      return control;
    }
    return IgnorePointer(child: Opacity(opacity: 0.45, child: control));
  }
}
