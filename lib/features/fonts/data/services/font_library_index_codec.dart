import 'dart:convert';

import 'package:y300/features/fonts/domain/models/font_library_failure.dart';
import 'package:y300/features/fonts/domain/models/imported_font.dart';
import 'package:y300/features/fonts/domain/services/font_file_validator.dart';

/// The index contains metadata only. Private paths are derived from font IDs.
final class FontLibraryIndexCodec {
  const FontLibraryIndexCodec();

  static const version = 1;
  static const maxIndexBytes = 1024 * 1024;
  static const maxEntries = 4096;

  static final _fontIdPattern = RegExp(r'^[0-9a-f]{64}$');

  List<ImportedFont> decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
    }
    final storedVersion = decoded['version'];
    if (storedVersion is! int || storedVersion < 1) {
      throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
    }
    if (storedVersion != version) {
      throw const FontLibraryException(
        FontLibraryFailure.unsupportedLibraryVersion,
      );
    }
    final entries = decoded['fonts'];
    if (entries is! List || entries.length > maxEntries) {
      throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
    }
    final seenIds = <String>{};
    final fonts = <ImportedFont>[];
    for (final entry in entries) {
      if (entry is! Map<String, dynamic>) {
        throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
      }
      final id = entry['id'];
      final name = entry['displayName'];
      final fileName = entry['storageFileName'];
      final byteLength = entry['byteLength'];
      if (id is! String ||
          !_fontIdPattern.hasMatch(id) ||
          !seenIds.add(id) ||
          name is! String ||
          name.trim().isEmpty ||
          name.length > 256 ||
          fileName is! String ||
          (fileName != '$id.ttf' && fileName != '$id.otf') ||
          byteLength is! int ||
          byteLength <= 0 ||
          byteLength > FontFileValidator.maxFontBytes) {
        throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
      }
      final (weightAxis, weightAxisScanned) = _decodeWeightAxis(entry);
      final customWeight = _decodeCustomWeight(entry, weightAxis);
      fonts.add(
        ImportedFont(
          id: id,
          displayName: name,
          storageFileName: fileName,
          byteLength: byteLength,
          weightAxis: weightAxis,
          customWeight: customWeight,
          weightAxisScanned: weightAxisScanned,
        ),
      );
    }
    return List<ImportedFont>.unmodifiable(fonts);
  }

  String encode(List<ImportedFont> fonts) {
    final source = jsonEncode(<String, Object>{
      'version': version,
      'fonts': <Map<String, Object?>>[
        for (final font in fonts)
          <String, Object?>{
            'id': font.id,
            'displayName': font.displayName,
            'storageFileName': font.storageFileName,
            'byteLength': font.byteLength,
            if (font.weightAxis != null)
              'weightAxis': <String, Object>{
                'min': font.weightAxis!.min,
                'default': font.weightAxis!.defaultValue,
                'max': font.weightAxis!.max,
              }
            else if (font.weightAxisScanned)
              'weightAxis': null,
            if (font.customWeight != null && font.weightAxis != null)
              'customWeight': font.customWeight!,
          },
      ],
    });
    // Treat writes with the same rules as restart reads, before touching disk.
    decode(source);
    if (utf8.encode(source).length > maxIndexBytes) {
      throw const FontLibraryException(FontLibraryFailure.storage);
    }
    return source;
  }

  static (FontWeightAxis?, bool) _decodeWeightAxis(Map<String, dynamic> entry) {
    if (!entry.containsKey('weightAxis')) {
      return (null, false);
    }
    final raw = entry['weightAxis'];
    if (raw == null) {
      return (null, true);
    }
    if (raw is! Map<String, dynamic>) {
      throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
    }
    final min = raw['min'];
    final defaultValue = raw['default'];
    final max = raw['max'];
    if (min is! num ||
        defaultValue is! num ||
        max is! num ||
        !FontWeightAxis.isValidRange(
          min.toDouble(),
          defaultValue.toDouble(),
          max.toDouble(),
        )) {
      throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
    }
    return (
      FontWeightAxis(
        min: min.toDouble(),
        defaultValue: defaultValue.toDouble(),
        max: max.toDouble(),
      ),
      true,
    );
  }

  static double? _decodeCustomWeight(
    Map<String, dynamic> entry,
    FontWeightAxis? axis,
  ) {
    if (!entry.containsKey('customWeight')) {
      return null;
    }
    final raw = entry['customWeight'];
    if (raw == null) {
      return null;
    }
    if (raw is! num || !raw.isFinite || axis == null) {
      throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
    }
    final value = raw.toDouble();
    if (value < axis.min || value > axis.max) {
      throw const FontLibraryException(FontLibraryFailure.corruptLibrary);
    }
    return value;
  }
}
