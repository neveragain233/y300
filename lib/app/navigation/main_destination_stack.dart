import 'package:flutter/material.dart';
import 'package:y300/app/theme/app_layout_tokens.dart';

/// 切页只驱动显示层，保持各入口的页面实例和导航状态。
class MainDestinationStack extends StatefulWidget {
  const MainDestinationStack({
    super.key,
    required this.index,
    required this.children,
  });

  final int index;
  final List<Widget> children;

  @override
  State<MainDestinationStack> createState() => _MainDestinationStackState();
}

class _MainDestinationStackState extends State<MainDestinationStack>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppLayoutTokens.feedbackDuration,
    value: 1,
  );
  late final _opacity = _controller.drive(
    CurveTween(curve: const Cubic(0.23, 1, 0.32, 1)),
  );

  @override
  void didUpdateWidget(MainDestinationStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    key: const Key('main-destination-transition'),
    opacity: _opacity,
    child: IndexedStack(index: widget.index, children: widget.children),
  );
}
