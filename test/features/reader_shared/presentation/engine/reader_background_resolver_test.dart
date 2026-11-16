import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:y300/features/reader_shared/domain/reader_preferences/reader_preferences.dart';
import 'package:y300/features/reader_shared/presentation/engine/reader_background_resolver.dart';

void main() {
  const themeSurface = Color(0xFFF5F5F5);

  Color resolve(
    ReaderBackgroundPreference background,
    ReaderModePreference mode, {
    Color? pagedCanvasColor,
  }) {
    return resolveReaderBackground(
      themeSurface: themeSurface,
      background: background,
      readerMode: mode,
      pagedCanvasColor: pagedCanvasColor,
    );
  }

  test('vertical mode always uses the saved background preference', () {
    const expected = <ReaderBackgroundPreference, Color>{
      ReaderBackgroundPreference.followTheme: themeSurface,
      ReaderBackgroundPreference.black: Colors.black,
      ReaderBackgroundPreference.white: Colors.white,
      ReaderBackgroundPreference.gray: Color(0xFF202124),
    };
    for (final entry in expected.entries) {
      expect(
        resolve(
          entry.key,
          ReaderModePreference.vertical,
          pagedCanvasColor: Colors.black,
        ),
        entry.value,
      );
    }
  });

  test('paged modes use the preference when no canvas color is fixed', () {
    const expected = <ReaderBackgroundPreference, Color>{
      ReaderBackgroundPreference.followTheme: themeSurface,
      ReaderBackgroundPreference.black: Colors.black,
      ReaderBackgroundPreference.white: Colors.white,
      ReaderBackgroundPreference.gray: Color(0xFF202124),
    };
    for (final entry in expected.entries) {
      expect(resolve(entry.key, ReaderModePreference.ltr), entry.value);
      expect(resolve(entry.key, ReaderModePreference.rtl), entry.value);
    }
  });

  test('paged modes use the fixed canvas color for every preference', () {
    for (final background in ReaderBackgroundPreference.values) {
      expect(
        resolve(
          background,
          ReaderModePreference.ltr,
          pagedCanvasColor: Colors.black,
        ),
        Colors.black,
      );
      expect(
        resolve(
          background,
          ReaderModePreference.rtl,
          pagedCanvasColor: Colors.black,
        ),
        Colors.black,
      );
    }
  });
}
