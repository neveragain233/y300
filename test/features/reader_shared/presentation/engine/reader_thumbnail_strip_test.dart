import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/reader_shared/domain/continuous_image/continuous_image.dart';
import 'package:y300/features/reader_shared/presentation/services/reader_image_session_store.dart';
import 'package:y300/features/reader_shared/presentation/widgets/reader_thumbnail_strip.dart';

import '../../../../test_support/localized_test_app.dart';

void main() {
  Future<void> pumpStrip(
    WidgetTester tester, {
    required int currentIndex,
    int itemCount = 5,
    bool reversed = false,
    int? previewIndex,
    ValueChanged<int>? onPreview,
    ValueChanged<int>? onSubmit,
    VoidCallback? onCancel,
  }) async {
    final items = _items(itemCount);
    final store = ReaderImageSessionStore();
    store.startSession(readerOwnerId: _ownerId, generation: 1, items: items);
    addTearDown(store.dispose);
    await tester.pumpWidget(
      LocalizedTestApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: 400,
              child: ReaderThumbnailStrip(
                spec: ReaderThumbnailStripSpec(
                  ownerId: _ownerId,
                  items: items,
                  currentIndex: currentIndex,
                  previewIndex: previewIndex,
                  reversed: reversed,
                  enabled: true,
                  sessionBindingFor: (item) => store.bindingFor(item),
                  onPreview: onPreview ?? (_) {},
                  onSubmit: onSubmit ?? (_) {},
                  onCancel: onCancel ?? () {},
                ),
                imageBuilder: _fakeImage,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('centers and marks the current page without submitting', (
    tester,
  ) async {
    final previews = <int>[];
    final submits = <int>[];
    await pumpStrip(
      tester,
      currentIndex: 2,
      onPreview: previews.add,
      onSubmit: submits.add,
    );

    final listCenter = tester.getCenter(
      find.byKey(ReaderThumbnailStrip.listKey),
    );
    final currentCenter = tester.getCenter(
      find.byKey(ReaderThumbnailStrip.itemKey(2)),
    );
    expect((currentCenter.dx - listCenter.dx).abs(), lessThan(0.5));
    expect(
      tester
          .widget<Semantics>(find.byKey(ReaderThumbnailStrip.itemKey(2)))
          .properties
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<Semantics>(find.byKey(ReaderThumbnailStrip.itemKey(1)))
          .properties
          .selected,
      isFalse,
    );
    expect(find.text('3 / 5'), findsOneWidget);
    expect(previews, isEmpty);
    expect(submits, isEmpty);

    final previous = tester.getCenter(
      find.byKey(ReaderThumbnailStrip.itemKey(1)),
    );
    final next = tester.getCenter(find.byKey(ReaderThumbnailStrip.itemKey(3)));
    expect(previous.dx, lessThan(currentCenter.dx));
    expect(next.dx, greaterThan(currentCenter.dx));
  });

  testWidgets('tapping a thumbnail submits that page once', (tester) async {
    final previews = <int>[];
    final submits = <int>[];
    var cancels = 0;
    await pumpStrip(
      tester,
      currentIndex: 2,
      onPreview: previews.add,
      onSubmit: submits.add,
      onCancel: () => cancels++,
    );

    await tester.tap(find.byKey(ReaderThumbnailStrip.itemKey(4)));
    await tester.pump();

    expect(previews, isEmpty);
    expect(submits, [4]);
    expect(cancels, 0);
  });

  testWidgets('dragging previews the center candidate and submits on release', (
    tester,
  ) async {
    final previews = <int>[];
    final submits = <int>[];
    await pumpStrip(
      tester,
      currentIndex: 2,
      onPreview: previews.add,
      onSubmit: submits.add,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ReaderThumbnailStrip.listKey)),
    );
    await gesture.moveBy(const Offset(-128, 0));
    await tester.pump();

    expect(previews, isNotEmpty);
    expect(previews.last, 4);
    expect(submits, isEmpty);
    expect(find.byKey(ReaderThumbnailStrip.previewKey), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(submits, [4]);
  });

  testWidgets('cancelling a drag restores the confirmed page', (tester) async {
    final previews = <int>[];
    final submits = <int>[];
    var cancels = 0;
    await pumpStrip(
      tester,
      currentIndex: 2,
      onPreview: previews.add,
      onSubmit: submits.add,
      onCancel: () => cancels++,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ReaderThumbnailStrip.listKey)),
    );
    await gesture.moveBy(const Offset(-96, 0));
    await tester.pump();
    expect(previews, isNotEmpty);

    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(submits, isEmpty);
    expect(cancels, 1);
    expect(find.text('3 / 5'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(find.byKey(ReaderThumbnailStrip.itemKey(2)))
          .properties
          .selected,
      isTrue,
    );
  });

  testWidgets('reverses visual order in right-to-left reading', (tester) async {
    await pumpStrip(tester, currentIndex: 2, reversed: true);

    final current = tester.getCenter(
      find.byKey(ReaderThumbnailStrip.itemKey(2)),
    );
    final previous = tester.getCenter(
      find.byKey(ReaderThumbnailStrip.itemKey(1)),
    );
    final next = tester.getCenter(find.byKey(ReaderThumbnailStrip.itemKey(3)));
    expect(previous.dx, greaterThan(current.dx));
    expect(next.dx, lessThan(current.dx));
  });

  testWidgets('hides itself for empty and single-image sequences', (
    tester,
  ) async {
    for (final count in <int>[0, 1]) {
      await pumpStrip(tester, currentIndex: 0, itemCount: count);
      expect(find.byKey(ReaderThumbnailStrip.listKey), findsNothing);
      expect(find.byKey(ReaderThumbnailStrip.hiddenKey), findsOneWidget);
    }
  });
}

const String _ownerId = 'chapter';

List<ContinuousImageItem> _items(int count) {
  return List<ContinuousImageItem>.generate(
    count,
    (index) => ContinuousImageItem(
      ownerId: _ownerId,
      id: '$_ownerId:$index',
      url: 'https://img.test/$index.jpg',
      cacheKey: 'reader/$index',
      index: index,
      sourceKind: ContinuousImageSourceKind.comicPage,
      knownWidth: 200,
      knownHeight: 300,
    ),
  );
}

Widget _fakeImage(BuildContext context, ReaderThumbnailImageSpec spec) {
  return ColoredBox(
    key: ValueKey<String>(
      'fake-thumbnail-${spec.preview ? 'preview' : 'page'}-${spec.index}',
    ),
    color: spec.preview ? Colors.red : Colors.blue,
  );
}
