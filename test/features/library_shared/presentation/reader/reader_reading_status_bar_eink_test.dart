import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/library_shared/presentation/reader/reader_reading_status_bar.dart';

const _barKey = Key('shared-reader-persistent-status-bar');
const _surfaceKey = Key('shared-reader-persistent-status-eink');
const _leftKey = Key('shared-reader-persistent-status-eink-left');
const _progressKey = Key('shared-reader-persistent-status-eink-progress');
const _timeKey = Key('shared-reader-persistent-status-eink-time');

void main() {
  test('title defaults to empty and participates in equality', () {
    const plain = ReaderReadingStatus(
      leading: '第 1 / 3 章',
      trailing: '第 1 / 9 页',
      semanticsLabel: '第 1 / 3 章，第 1 / 9 页',
    );
    const titled = ReaderReadingStatus(
      leading: '第 1 / 3 章',
      trailing: '第 1 / 9 页',
      semanticsLabel: '第 1 / 3 章，第 1 / 9 页',
      title: '第一章',
    );

    expect(plain.title, isEmpty);
    expect(titled, isNot(plain));
    expect(titled.hashCode, isNot(plain.hashCode));
  });

  testWidgets(
    'e-ink light surface uses 24dp, palette tokens and three segments',
    (tester) async {
      await _pumpBar(
        tester,
        width: 600,
        status: const ReaderReadingStatus(
          leading: '第 3 / 12 章',
          title: '第三章 标题',
          trailing: '第 1 / 5 页',
          semanticsLabel: '第 3 / 12 章，第 1 / 5 页',
        ),
        now: DateTime(2026, 1, 2, 13, 4),
      );

      expect(tester.getSize(find.byKey(_surfaceKey)).height, 24);
      final surface = tester.widget<Container>(find.byKey(_surfaceKey));
      final decoration = surface.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFFFFFFF));
      final border = decoration.border! as Border;
      expect(border.top.width, 1);
      expect(border.top.color, const Color(0xFFCCCCCC));

      final left = tester.widget<Text>(find.byKey(_leftKey));
      expect(left.data, '第 3 / 12 章 · 第三章 标题');
      expect(left.style?.color, const Color(0xFF444444));
      expect(left.style?.fontSize, 11);
      expect(left.style?.height, 1.1);
      expect(tester.getTopLeft(find.byKey(_leftKey)).dx, 14);

      final progress = tester.widget<Text>(find.byKey(_progressKey));
      expect(progress.data, '第 1 / 5 页');
      expect(progress.style?.fontWeight, FontWeight.w600);
      expect(tester.getTopRight(find.byKey(_timeKey)).dx, closeTo(600 - 14, 1));
      expect(
        tester.getTopRight(find.byKey(_progressKey)).dx,
        lessThanOrEqualTo(tester.getTopLeft(find.byKey(_timeKey)).dx),
      );

      final context = tester.element(find.byKey(_barKey));
      expect(
        tester.getSize(find.byKey(_barKey)).height,
        closeTo(24 + ReaderReadingStatusBarLayout.bottomInset(context), 0.01),
      );
      expect(
        ReaderReadingStatusBarLayout.contentHeightForVariant(
          context,
          ReaderReadingStatusBarVariant.eInk,
        ),
        24,
      );
      expect(
        ReaderReadingStatusBarLayout.dockClearanceForVariant(
          context,
          ReaderReadingStatusBarVariant.eInk,
        ),
        closeTo(
          24 +
              ReaderReadingStatusBarLayout.bottomInset(context) -
              MediaQuery.paddingOf(context).bottom +
              8,
          0.01,
        ),
      );
    },
  );

  testWidgets('e-ink dark palette derives from the background brightness', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      background: Colors.black,
      status: const ReaderReadingStatus(
        leading: '第 3 / 12 章',
        title: '第三章',
        trailing: '第 1 / 5 页',
        semanticsLabel: '第 3 / 12 章，第 1 / 5 页',
      ),
    );

    final surface = tester.widget<Container>(find.byKey(_surfaceKey));
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF141414));
    final border = decoration.border! as Border;
    expect(border.top.color, const Color(0xFF333333));
    expect(
      tester.widget<Text>(find.byKey(_leftKey)).style?.color,
      const Color(0xFFE0E0E0),
    );
  });

  testWidgets('e-ink time follows MaterialLocalizations and the 24-hour flag', (
    tester,
  ) async {
    final now = DateTime(2026, 1, 2, 13, 4);
    await _pumpBar(tester, status: _status, now: now);
    final twelveHour = _expectedTime(tester, now, alwaysUse24HourFormat: false);
    expect(tester.widget<Text>(find.byKey(_timeKey)).data, twelveHour);

    await _pumpBar(
      tester,
      status: _status,
      now: now,
      alwaysUse24HourFormat: true,
    );
    final twentyFourHour = _expectedTime(
      tester,
      now,
      alwaysUse24HourFormat: true,
    );
    expect(tester.widget<Text>(find.byKey(_timeKey)).data, twentyFourHour);
  });

  testWidgets('e-ink drops title, then time, and keeps progress at 280dp 2x', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      width: 280,
      textScaler: const TextScaler.linear(2),
      status: const ReaderReadingStatus(
        leading: '第 371 / 451 章',
        title: '第三章 某个很长的章节标题',
        trailing: '第 1 / 12 页',
        semanticsLabel: '第 371 / 451 章，第 1 / 12 页',
      ),
      now: DateTime(2026, 1, 2, 13, 4),
    );

    expect(tester.widget<Text>(find.byKey(_leftKey)).data, '第 371 / 451 章');
    expect(find.byKey(_timeKey), findsNothing);
    final progress = tester.widget<Text>(find.byKey(_progressKey));
    expect(progress.data, '第 1 / 12 页');
    expect(progress.overflow, TextOverflow.ellipsis);
    expect(
      tester
          .renderObject<RenderParagraph>(find.byKey(_progressKey))
          .didExceedMaxLines,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('e-ink drops the title before the time', (tester) async {
    await _pumpBar(
      tester,
      width: 280,
      textScaler: const TextScaler.linear(2),
      status: const ReaderReadingStatus(
        leading: '1',
        title: 'T',
        trailing: '1',
        semanticsLabel: '1，1',
      ),
      now: DateTime(2026, 1, 2, 13, 4),
    );

    expect(tester.widget<Text>(find.byKey(_leftKey)).data, '1');
    expect(find.byKey(_timeKey), findsOneWidget);
    expect(find.byKey(_progressKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('e-ink semantics merges the visible segments', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pumpBar(
        tester,
        width: 600,
        status: const ReaderReadingStatus(
          leading: '第 3 / 12 章',
          title: '第三章 标题',
          trailing: '第 1 / 5 页',
          semanticsLabel: 'unused',
        ),
        now: DateTime(2026, 1, 2, 13, 4),
      );

      final expectedTime = _expectedTime(
        tester,
        DateTime(2026, 1, 2, 13, 4),
        alwaysUse24HourFormat: false,
      );
      final node = tester.getSemantics(find.byKey(_barKey));
      expect(node.label, '第 3 / 12 章 · 第三章 标题，第 1 / 5 页，$expectedTime');
    } finally {
      handle.dispose();
    }
  });
}

const _status = ReaderReadingStatus(
  leading: '第 3 / 12 章',
  title: '第三章 标题',
  trailing: '第 1 / 5 页',
  semanticsLabel: '第 3 / 12 章，第 1 / 5 页',
);

String _expectedTime(
  WidgetTester tester,
  DateTime now, {
  required bool alwaysUse24HourFormat,
}) {
  final context = tester.element(find.byKey(_barKey));
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(now),
    alwaysUse24HourFormat: alwaysUse24HourFormat,
  );
}

Future<void> _pumpBar(
  WidgetTester tester, {
  required ReaderReadingStatus status,
  Color background = Colors.white,
  double width = 400,
  TextScaler textScaler = TextScaler.noScaling,
  bool alwaysUse24HourFormat = false,
  DateTime? now,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: textScaler,
            alwaysUse24HourFormat: alwaysUse24HourFormat,
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            systemGestureInsets: EdgeInsets.zero,
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ReaderReadingStatusBar(
                status: status,
                background: background,
                foreground: Colors.black,
                variant: ReaderReadingStatusBarVariant.eInk,
                now: now,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
