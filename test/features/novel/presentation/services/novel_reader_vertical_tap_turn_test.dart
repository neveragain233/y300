import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/novel/presentation/services/novel_reader_vertical_tap_turn_coordinator.dart';

void main() {
  testWidgets('turns by the requested step and commits once', (tester) async {
    final scrollController = ScrollController();
    final coordinator = NovelReaderVerticalTapTurnCoordinator(
      scrollController: scrollController,
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(() {
      coordinator.dispose();
      scrollController.dispose();
    });
    await tester.pumpWidget(_host(scrollController));
    var commits = 0;

    coordinator.turn(
      direction: NovelReaderVerticalTurnDirection.forward,
      step: 300,
      onCommitted: () => commits += 1,
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(300, 0.01));
    expect(commits, 1);

    coordinator.turn(
      direction: NovelReaderVerticalTurnDirection.backward,
      step: 300,
      onCommitted: () => commits += 1,
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(0, 0.01));
    expect(commits, 2);
  });

  testWidgets('retains one same-direction intent and steps from position', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final coordinator = NovelReaderVerticalTapTurnCoordinator(
      scrollController: scrollController,
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(() {
      coordinator.dispose();
      scrollController.dispose();
    });
    await tester.pumpWidget(_host(scrollController));
    var commits = 0;

    coordinator.turn(
      direction: NovelReaderVerticalTurnDirection.forward,
      step: 300,
      onCommitted: () => commits += 1,
    );
    coordinator.turn(
      direction: NovelReaderVerticalTurnDirection.forward,
      step: 300,
      onCommitted: () => commits += 1,
    );
    coordinator.turn(
      direction: NovelReaderVerticalTurnDirection.forward,
      step: 300,
      onCommitted: () => commits += 1,
    );
    await tester.pumpAndSettle();

    // The third tap is coalesced into the single pending intent.
    expect(scrollController.offset, closeTo(600, 0.01));
    expect(commits, 2);
  });

  testWidgets('opposite tap interrupts the running animation', (tester) async {
    final scrollController = ScrollController();
    final coordinator = NovelReaderVerticalTapTurnCoordinator(
      scrollController: scrollController,
      duration: const Duration(milliseconds: 300),
    );
    addTearDown(() {
      coordinator.dispose();
      scrollController.dispose();
    });
    await tester.pumpWidget(_host(scrollController));
    var commits = 0;

    coordinator.turn(
      direction: NovelReaderVerticalTurnDirection.forward,
      step: 300,
      onCommitted: () => commits += 1,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    coordinator.turn(
      direction: NovelReaderVerticalTurnDirection.backward,
      step: 300,
      onCommitted: () => commits += 1,
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(0, 0.01));
    expect(commits, 1);
  });

  testWidgets('retire drops the intent and the late completion', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final coordinator = NovelReaderVerticalTapTurnCoordinator(
      scrollController: scrollController,
      duration: const Duration(milliseconds: 200),
    );
    addTearDown(() {
      coordinator.dispose();
      scrollController.dispose();
    });
    await tester.pumpWidget(_host(scrollController));
    var commits = 0;

    coordinator.turn(
      direction: NovelReaderVerticalTurnDirection.forward,
      step: 300,
      onCommitted: () => commits += 1,
    );
    await tester.pump(const Duration(milliseconds: 40));
    coordinator.retire();
    await tester.pumpAndSettle();

    expect(commits, 0);
  });

  testWidgets('a tap at the boundary does not commit', (tester) async {
    final scrollController = ScrollController();
    final coordinator = NovelReaderVerticalTapTurnCoordinator(
      scrollController: scrollController,
      duration: const Duration(milliseconds: 100),
    );
    addTearDown(() {
      coordinator.dispose();
      scrollController.dispose();
    });
    await tester.pumpWidget(_host(scrollController));
    var commits = 0;

    coordinator.turn(
      direction: NovelReaderVerticalTurnDirection.backward,
      step: 300,
      onCommitted: () => commits += 1,
    );
    await tester.pumpAndSettle();

    expect(scrollController.offset, 0);
    expect(commits, 0);
  });
}

Widget _host(ScrollController controller) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 600,
        child: ListView(
          controller: controller,
          children: const [SizedBox(height: 3000)],
        ),
      ),
    ),
  );
}
