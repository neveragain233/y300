import 'dart:ui' show FontVariation;

import 'font_identity.dart';
import 'imported_font.dart';

/// Published only after the requested font has finished loading.
final class ResolvedFont {
  const ResolvedFont({
    required this.id,
    required this.fontFamily,
    this.weightAxis,
    this.customWeight,
  });

  static const system = ResolvedFont(id: FontIdentity.system, fontFamily: null);

  final String id;
  final String? fontFamily;
  final FontWeightAxis? weightAxis;
  final double? customWeight;

  bool get isSystem => id == FontIdentity.system;

  bool get isVariableWeight => weightAxis != null;

  double? get effectiveWeight {
    final axis = weightAxis;
    if (axis == null) return null;
    final custom = customWeight;
    return custom == null ? axis.defaultValue : axis.clamp(custom);
  }

  List<FontVariation>? get fontVariations {
    final axis = weightAxis;
    final custom = customWeight;
    if (axis == null || custom == null) return null;
    return List<FontVariation>.unmodifiable(<FontVariation>[
      FontVariation('wght', axis.clamp(custom)),
    ]);
  }

  List<FontVariation>? get boldFontVariations {
    final axis = weightAxis;
    final custom = customWeight;
    if (axis == null || custom == null) return null;
    return List<FontVariation>.unmodifiable(<FontVariation>[
      FontVariation('wght', axis.relativeBold(axis.clamp(custom))),
    ]);
  }

  /// Consumers use content identity, rather than a user-editable display name.
  String get cacheKey {
    final axis = weightAxis;
    final custom = customWeight;
    if (axis == null || custom == null) {
      return id;
    }
    return '$id@wght=${axis.clamp(custom).toStringAsFixed(1)}';
  }

  @override
  bool operator ==(Object other) =>
      other is ResolvedFont &&
      id == other.id &&
      fontFamily == other.fontFamily &&
      weightAxis == other.weightAxis &&
      customWeight == other.customWeight;

  @override
  int get hashCode => Object.hash(id, fontFamily, weightAxis, customWeight);
}
