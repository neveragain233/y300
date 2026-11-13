import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/thread/data/providers/thread_controls_preferences_providers.dart';
import 'package:y300/features/thread/data/repositories/shared_preferences_thread_controls_repository.dart';
import 'package:y300/features/thread/domain/models/thread_controls_preferences.dart';
import 'package:y300/features/thread/domain/repositories/thread_controls_preferences_repository.dart';
import 'package:y300/features/thread/presentation/thread_controls_preferences_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final provider = threadControlsPreferencesControllerProvider;
  test('default controls are full, dual and visible while scrolling', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final value = await container.read(provider.future);
    expect(value.hideOnScroll, isFalse);
    expect(value.compact, isFalse);
    expect(value.singleNavigationButton, isFalse);
    expect(value.navigationEnabled, isTrue);
    expect(value.showFavorite, isTrue);
  });
  test('legacy side is read without enabling scroll hiding', () async {
    SharedPreferences.setMockInitialValues({
      PreferenceKeys.threadQuickScrollDockSide.name: 'left',
    });
    final repository = SharedPreferencesThreadControlsRepository(
      SharedPreferencesStore(),
    );
    final value = await repository.load();
    expect(value.side, ThreadControlsSide.left);
    expect(value.hideOnScroll, isFalse);
  });
  test('all options survive a new provider container', () async {
    final first = ProviderContainer();
    await first.read(provider.future);
    await first
        .read(provider.notifier)
        .savePreferences(
          const ThreadControlsPreferences(
            compact: true,
            side: ThreadControlsSide.left,
            showFavorite: false,
            singleNavigationButton: true,
            holdToFirstPost: true,
            hideOnScroll: true,
          ),
        );
    first.dispose();
    final second = ProviderContainer();
    addTearDown(second.dispose);
    final restored = await second.read(provider.future);
    expect(restored.compact, isTrue);
    expect(restored.side, ThreadControlsSide.left);
    expect(restored.showFavorite, isFalse);
    expect(restored.singleNavigationButton, isTrue);
    expect(restored.holdToFirstPost, isTrue);
    expect(restored.hideOnScroll, isTrue);
  });
  for (final raw in [
    'broken',
    '{"schemaVersion":99,"hideOnScroll":true}',
    '{"schemaVersion":1,"hideOnScroll":"yes"}',
  ]) {
    test('unsupported snapshot $raw keeps hiding disabled', () async {
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.threadControlsV1.name: raw,
      });
      final repository = SharedPreferencesThreadControlsRepository(
        SharedPreferencesStore(),
      );
      expect((await repository.load()).hideOnScroll, isFalse);
    });
  }
  test('queued writes preserve the latest complete selection', () async {
    final gate = Completer<void>();
    final repository = _Repository()..gate = gate.future;
    final container = ProviderContainer(
      overrides: [
        threadControlsPreferencesRepositoryProvider.overrideWithValue(
          repository,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(provider.future);
    final controller = container.read(provider.notifier);
    final first = controller.savePreferences(
      const ThreadControlsPreferences(compact: true),
    );
    final next = controller.savePreferences(
      const ThreadControlsPreferences(compact: true, hideOnScroll: true),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.writes, hasLength(1));
    expect(container.read(provider).requireValue.hideOnScroll, isTrue);
    gate.complete();
    await first;
    await next;
    expect(repository.writes, hasLength(2));
    expect(repository.saved.hideOnScroll, isTrue);
  });
  test(
    'failed write restores the cached snapshot and the current choice',
    () async {
      final repository = _Repository()..failOnce = true;
      final container = ProviderContainer(
        overrides: [
          threadControlsPreferencesRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(provider.future);
      expect(
        await container
            .read(provider.notifier)
            .savePreferences(
              const ThreadControlsPreferences(hideOnScroll: true),
            ),
        isFalse,
      );
      expect(container.read(provider).requireValue.hideOnScroll, isFalse);
      expect(repository.saved.hideOnScroll, isFalse);
    },
  );
}

class _Repository implements ThreadControlsPreferencesRepository {
  ThreadControlsPreferences saved = const ThreadControlsPreferences();
  final writes = <ThreadControlsPreferences>[];
  Future<void>? gate;
  bool failOnce = false;
  @override
  Future<ThreadControlsPreferences> load() async => saved;
  @override
  Future<void> save(ThreadControlsPreferences value) async {
    writes.add(value);
    saved = value;
    if (failOnce) {
      failOnce = false;
      throw StateError('write failed');
    }
    await gate;
  }
}
