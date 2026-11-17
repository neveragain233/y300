import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/thread/presentation/widgets/thread_detail_widgets.dart';
import 'package:y300/l10n/app_localizations.dart';
import 'package:y300/shared/widgets/native_pagination_bar.dart';

import '../../../../test_support/localized_test_app.dart';

const _previousKey = Key('thread-detail-previous-page-button');
const _nextKey = Key('thread-detail-load-more-button');
const _pageLabelKey = Key('thread-detail-page-label');

void main() {
  testWidgets('renders page actions with the shared forum button', (
    tester,
  ) async {
    var previousTaps = 0;
    var nextTaps = 0;
    await _pump(
      tester,
      onLoadPreviousPage: () => previousTaps++,
      onLoadNextPage: () => nextTaps++,
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadLoadMoreSection)),
    );
    expect(find.byType(NativePaginationButton), findsNWidgets(2));
    expect(find.text(l10n.threadDetailPreviousPage), findsOneWidget);
    expect(find.text(l10n.threadDetailNextPage), findsOneWidget);
    expect(find.byKey(_pageLabelKey), findsOneWidget);
    expect(tester.getSize(find.byKey(_previousKey)).height, 34);
    expect(tester.getSize(find.byKey(_nextKey)).height, 34);

    await tester.tap(find.byKey(_previousKey));
    await tester.tap(find.byKey(_nextKey));
    expect(previousTaps, 1);
    expect(nextTaps, 1);
  });

  testWidgets('disables both page actions at the boundaries', (tester) async {
    await _pump(tester, canLoadPrevious: false, hasMore: false);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ThreadLoadMoreSection)),
    );
    expect(_button(tester, _previousKey).onPressed, isNull);
    expect(_button(tester, _nextKey).onPressed, isNull);
    expect(find.text(l10n.threadDetailNoMore), findsOneWidget);
  });

  testWidgets('keeps the load failure above the page actions', (tester) async {
    await _pump(tester, failure: '页面加载失败');

    expect(find.text('页面加载失败'), findsOneWidget);
    expect(find.byKey(_previousKey), findsOneWidget);
    expect(find.byKey(_nextKey), findsOneWidget);
  });
}

NativePaginationButton _button(WidgetTester tester, Key key) =>
    tester.widget<NativePaginationButton>(find.byKey(key));

Future<void> _pump(
  WidgetTester tester, {
  bool canLoadPrevious = true,
  bool hasMore = true,
  VoidCallback? onLoadPreviousPage,
  VoidCallback? onLoadNextPage,
  String? failure,
}) => tester.pumpWidget(
  LocalizedTestApp(
    home: Scaffold(
      body: Center(
        child: ThreadLoadMoreSection(
          hasMore: hasMore,
          isLoadingMore: false,
          currentPage: 2,
          lastPage: 4,
          canLoadPrevious: canLoadPrevious,
          onLoadPreviousPage: onLoadPreviousPage ?? () {},
          onLoadNextPage: onLoadNextPage ?? () {},
          onLoadPageNumber: (_) {},
          failure: failure,
        ),
      ),
    ),
  ),
);
