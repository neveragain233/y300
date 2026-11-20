import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/app/layout/app_window_layout.dart';

void main() {
  test('navigation and list-detail have independent width budgets', () {
    final medium = AppWindowLayout(size: const Size(760, 900));
    expect(medium.useNavigationRail, isTrue);
    expect(medium.split, isNull);
    final wide = AppWindowLayout(size: const Size(1100, 900));
    expect(wide.split!.list.width, greaterThanOrEqualTo(320));
    expect(wide.split!.detail.width, greaterThanOrEqualTo(480));
    expect(AppWindowLayout(size: const Size(1100, 300)).split, isNull);
  });

  test('e-ink mode uses the 600dp rail threshold', () {
    expect(
      AppWindowLayout(size: const Size(700, 900)).useNavigationRail,
      isFalse,
    );
    expect(
      AppWindowLayout(
        size: const Size(700, 900),
        eInkMode: true,
      ).useNavigationRail,
      isTrue,
    );
  });

  test('hinge is excluded and translated into the local host', () {
    final window = AppWindowLayout(
      size: const Size(1000, 900),
      globalOrigin: const Offset(80, 0),
      displayFeatures: const [
        DisplayFeature(
          bounds: Rect.fromLTWH(480, 0, 24, 900),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ],
    );
    expect(window.split!.list, const Rect.fromLTWH(0, 0, 400, 900));
    expect(window.split!.detail, const Rect.fromLTWH(424, 0, 576, 900));
  });

  test(
    'flat fold is continuous; tabletop keeps reading above auxiliary pane',
    () {
      const flat = DisplayFeature(
        bounds: Rect.fromLTWH(0, 450, 1000, 0),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureFlat,
      );
      const tabletop = DisplayFeature(
        bounds: Rect.fromLTWH(0, 450, 1000, 0),
        type: DisplayFeatureType.fold,
        state: DisplayFeatureState.postureHalfOpened,
      );
      expect(
        AppWindowLayout(
          size: const Size(1000, 900),
          displayFeatures: [flat],
        ).regions,
        hasLength(1),
      );
      final split = AppWindowLayout(
        size: const Size(1000, 900),
        displayFeatures: [tabletop],
      ).split!;
      expect(split.detail.bottom, 450);
      expect(split.list.top, 450);
    },
  );
}
