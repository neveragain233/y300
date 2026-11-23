import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:y300/features/reader_shared/application/active_reader_session.dart';

class ActiveReaderHost extends ConsumerStatefulWidget {
  const ActiveReaderHost({
    super.key,
    required this.target,
    this.flush,
    required this.child,
  });
  final ActiveReaderTarget target;
  final Future<void> Function()? flush;
  final Widget child;

  @override
  ConsumerState<ActiveReaderHost> createState() => _ActiveReaderHostState();
}

class _ActiveReaderHostState extends ConsumerState<ActiveReaderHost>
    with WidgetsBindingObserver {
  late final sessions = ref.read(activeReaderSessionsProvider);
  bool active = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    final current = ModalRoute.isCurrentOf(context) ?? true;
    active =
        ref.watch(restoreReaderPreferenceProvider).value == true && current;
    (active ? sessions.activate(this, widget.target) : sessions.release(this))
        .ignore();
    return widget.child;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.inactive &&
        state != AppLifecycleState.detached) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != false) {
      widget.flush?.call().ignore();
    }
    if (active) sessions.activate(this, widget.target, refresh: true).ignore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != AppLifecycleState.detached &&
        lifecycle != AppLifecycleState.paused) {
      sessions.release(this).ignore();
    }
    super.dispose();
  }
}
