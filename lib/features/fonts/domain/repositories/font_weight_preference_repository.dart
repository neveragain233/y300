import '../models/imported_font.dart';

/// Optional capability for updating per-font variable weight preferences.
abstract interface class FontWeightPreferenceRepository {
  Future<ImportedFont> updateFontWeight(String fontId, double? customWeight);
}
