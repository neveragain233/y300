import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/content_filter/application/blocked_threads_controller.dart';
import 'package:y300/features/content_filter/data/providers/content_filter_providers.dart';
import 'package:y300/features/content_filter/domain/models/blocked_thread.dart';
import 'package:y300/features/content_filter/domain/repositories/blocked_thread_repository.dart';

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
      blockedThreadRepositoryProvider.overrideWithValue(repository),
      if (clock != null) blockedThreadClockProvider.overrideWithValue(clock),
    ],
  );
}

final class _MemoryRepository implements BlockedThreadRepository {
  _MemoryRepository({this.failWrites = false});

  final bool failWrites;
  List<BlockedThread> rules = const <BlockedThread>[];
  final List<List<BlockedThread>> saved = <List<BlockedThread>>[];

  @override
  Future<List<BlockedThread>> load() async => rules;

  @override
  Future<void> save(List<BlockedThread> threads) async {
    if (failWrites) {
      throw StateError('fixture write failure');
    }
    rules = threads;
    saved.add(threads);
  }
}
