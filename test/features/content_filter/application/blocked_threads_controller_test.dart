import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/core/preferences/preference_key.dart';
import 'package:y300/core/preferences/preference_keys.dart';
import 'package:y300/core/preferences/preferences_providers.dart';
import 'package:y300/core/preferences/preferences_store.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/data/codecs/blocked_thread_snapshot_codec.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';

void main() {
  group('BlockedThreadsController', () {
    test('publishes rules only after the snapshot is written', () async {
      final repository = _MemoryRepository();
      final container = _container(repository);
      addTearDown(container.dispose);

      final result = await container
          .read(blockedThreadsControllerProvider.notifier)
          .block(tid: '0009', subject: '  标题  ');

      expect(result.isCreated, isTrue);
      expect(result.entry!.tid, '9');
      expect(result.entry!.subject, '标题');
      expect(repository.saved, hasLength(1));
      expect(container.read(blockedThreadIdsProvider), <String>{'9'});
    });

    test('failed writes leave the previous rules untouched', () async {
      final repository = _MemoryRepository(failWrites: true);
      final container = _container(repository);
      addTearDown(container.dispose);
      await container.read(blockedThreadsControllerProvider.future);

      final result = await container
          .read(blockedThreadsControllerProvider.notifier)
          .block(tid: '10', subject: '标题');

      expect(result.status, BlockedThreadBlockStatus.failed);
      expect(container.read(blockedThreadIdsProvider), isEmpty);
      expect(repository.saved, isEmpty);
    });

    test('undo only reverts the revision it was created from', () async {
      final repository = _MemoryRepository();
      var clock = 1000;
      final container = _container(
        repository,
        clock: () => DateTime.fromMillisecondsSinceEpoch(clock++),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        blockedThreadsControllerProvider.notifier,
      );

      final first = await controller.block(tid: '11', subject: '标题');
      await controller.undo(first.entry!);
      expect(container.read(blockedThreadIdsProvider), isEmpty);

      final second = await controller.block(tid: '11', subject: '新标题');
      await controller.undo(first.entry!);
      expect(container.read(blockedThreadIdsProvider), <String>{
        '11',
      }, reason: 'A stale undo must not reverse a later decision.');

      await controller.undo(second.entry!);
      expect(container.read(blockedThreadIdsProvider), isEmpty);
    });

    test('serializes mutations in submission order', () async {
      final repository = _MemoryRepository();
      final container = _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(
        blockedThreadsControllerProvider.notifier,
      );

      final results = await Future.wait([
        controller.block(tid: '21', subject: 'A'),
        controller.block(tid: '22', subject: 'B'),
      ]);

      expect(results.every((result) => result.isCreated), isTrue);
      expect(repository.saved.map((rules) => rules.length), <int>[1, 2]);
      expect(container.read(blockedThreadIdsProvider), <String>{'21', '22'});
    });

    test(
      'blocking an already blocked thread does not create an undo',
      () async {
        final repository = _MemoryRepository();
        final container = _container(repository);
        addTearDown(container.dispose);
        final controller = container.read(
          blockedThreadsControllerProvider.notifier,
        );

        await controller.block(tid: '31', subject: '标题');
        final again = await controller.block(tid: '31', subject: '另一标题');

        expect(again.status, BlockedThreadBlockStatus.alreadyBlocked);
        expect(again.entry!.subject, '标题');
      },
    );
  });
}

ProviderContainer _container(
  _MemoryRepository repository, {
  DateTime Function()? clock,
}) {
  return ProviderContainer.test(
    overrides: [
      preferencesStoreProvider.overrideWithValue(repository),
      if (clock != null) blockedThreadClockProvider.overrideWithValue(clock),
    ],
  );
}

final class _MemoryRepository implements PreferencesStore {
  _MemoryRepository({this.failWrites = false});

  final bool failWrites;
  final Map<String, Object> _values = <String, Object>{};
  final List<List<BlockedThread>> saved = <List<BlockedThread>>[];

  List<BlockedThread> get rules => BlockedThreadSnapshotCodec.decode(
    _values[PreferenceKeys.contentFilterBlockedThreadsV1.name] as String?,
  );

  @override
  Future<T?> read<T extends Object>(PreferenceKey<T> key) async {
    final value = _values[key.name];
    return value is T ? value : null;
  }

  @override
  Future<bool> contains<T extends Object>(PreferenceKey<T> key) async =>
      _values.containsKey(key.name);

  @override
  Future<void> write<T extends Object>(PreferenceKey<T> key, T value) async {
    if (failWrites) {
      throw StateError('fixture write failure');
    }
    _values[key.name] = value;
    if (key.name == PreferenceKeys.contentFilterBlockedThreadsV1.name &&
        value is String) {
      saved.add(BlockedThreadSnapshotCodec.decode(value));
    }
  }

  @override
  Future<void> remove<T extends Object>(PreferenceKey<T> key) async {
    _values.remove(key.name);
  }
}
