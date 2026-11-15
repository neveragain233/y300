import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/domain/models/library_models.dart';
import 'package:y300/features/library_shared/domain/services/recent_reading.dart';

void main() {
  test('resolver picks the newest reading across both sources', () async {
    final resolver = RecentReadingResolver(
      sources: <RecentReadingSource>[
        _FixedSource(
          RecentReadingTarget(
            moduleKey: LibraryModuleKey.comic,
            workId: 'comic:1',
            episodeId: 'e1',
            readAt: DateTime(2026, 5, 1),
          ),
        ),
        _FixedSource(
          RecentReadingTarget(
            moduleKey: LibraryModuleKey.novel,
            workId: 'novel:1',
            episodeId: 'e9',
            readAt: DateTime(2026, 6, 1),
          ),
        ),
      ],
    );

    final target = await resolver.resolve();

    expect(target?.moduleKey, LibraryModuleKey.novel);
    expect(target?.workId, 'novel:1');
  });

  test(
    'resolver ignores missing sources and breaks ties deterministically',
    () async {
      final readAt = DateTime(2026, 6, 1);
      final resolver = RecentReadingResolver(
        sources: <RecentReadingSource>[
          _FixedSource(
            RecentReadingTarget(
              moduleKey: LibraryModuleKey.novel,
              workId: 'novel:2',
              episodeId: 'e1',
              readAt: readAt,
            ),
          ),
          const _FixedSource(null),
          _FixedSource(
            RecentReadingTarget(
              moduleKey: LibraryModuleKey.comic,
              workId: 'comic:1',
              episodeId: 'e1',
              readAt: readAt,
            ),
          ),
        ],
      );

      final target = await resolver.resolve();

      expect(target?.moduleKey, LibraryModuleKey.comic);
    },
  );
}

class _FixedSource implements RecentReadingSource {
  const _FixedSource(this.target);

  final RecentReadingTarget? target;

  @override
  Future<RecentReadingTarget?> loadMostRecentReading() async => target;
}
