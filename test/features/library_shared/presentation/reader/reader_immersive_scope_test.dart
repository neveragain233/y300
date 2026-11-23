import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/presentation/reader/reader.dart';

final class _FakeSystemUiController implements ReaderSystemUiController {
  bool immersive = false;
  int enterCount = 0;
  int restoreCount = 0;

  @override
  Future<void> enterImmersive() async {
    immersive = true;
    enterCount++;
  }

  @override
  Future<void> restore() async {
    immersive = false;
    restoreCount++;
  }
}

void main() {
  testWidgets('tracks enabled toggle, route cover, and holdWhenRouteCovered', (
    tester,
  ) async {
    final systemUi = _FakeSystemUiController();
    final enabled = ValueNotifier<bool>(true);
    final hold = ValueNotifier<bool>(false);
    addTearDown(enabled.dispose);
    addTearDown(hold.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerSystemUiControllerProvider.overrideWithValue(systemUi),
        ],
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: enabled,
            builder: (context, isEnabled, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: hold,
                builder: (context, isHold, _) {
                  return ReaderImmersiveScope(
                    enabled: isEnabled,
                    holdWhenRouteCovered: isHold,
                    child: const Scaffold(body: Text('reader')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    expect(systemUi.immersive, isTrue);

    enabled.value = false;
    await tester.pump();
    expect(systemUi.immersive, isFalse);

    enabled.value = true;
    await tester.pump();
    expect(systemUi.immersive, isTrue);

    final navigator = Navigator.of(tester.element(find.text('reader')));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('covered')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(systemUi.immersive, isFalse);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(systemUi.immersive, isTrue);

    // 模拟设置抽屉盖住路由但保持 holdWhenRouteCovered = true：仍维持沉浸且响应开关。
    hold.value = true;
    await tester.pump();
    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(find.text('reader')),
        builder: (_) => const SizedBox(height: 120, child: Text('settings')),
      ),
    );
    await tester.pumpAndSettle();
    expect(systemUi.immersive, isTrue);

    enabled.value = false;
    await tester.pump();
    expect(systemUi.immersive, isFalse);
  });

  testWidgets('nested reader disposal does not clobber outer reader', (
    tester,
  ) async {
    final systemUi = _FakeSystemUiController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerSystemUiControllerProvider.overrideWithValue(systemUi),
        ],
        child: const MaterialApp(
          home: ReaderImmersiveScope(
            enabled: true,
            child: Scaffold(body: Text('outer-reader')),
          ),
        ),
      ),
    );
    expect(systemUi.immersive, isTrue);

    final navigator = Navigator.of(tester.element(find.text('outer-reader')));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const ReaderImmersiveScope(
            enabled: true,
            child: Scaffold(body: Text('inner-reader')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(systemUi.immersive, isTrue);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(systemUi.immersive, isTrue);
  });
}
