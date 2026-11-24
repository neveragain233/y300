/// Variable-weight (`fvar` `wght`) axis bounds for an imported font.
final class FontWeightAxis {
  const FontWeightAxis({
    required this.min,
    required this.defaultValue,
    required this.max,
  }) : assert(1 <= min && min <= defaultValue && defaultValue <= max),
       assert(max <= 1000 && min < max);

  static const double step = 10;
  static const double relativeBoldDelta = 250;

  final double min;
  final double defaultValue;
  final double max;

  static bool isValidRange(double min, double defaultValue, double max) =>
      min.isFinite &&
      defaultValue.isFinite &&
      max.isFinite &&
      1 <= min &&
      min <= defaultValue &&
      defaultValue <= max &&
      max <= 1000 &&
      min < max;

  double clamp(double value) {
    if (!value.isFinite) return defaultValue;
    return value.clamp(min, max).toDouble();
  }

  double snap(double value) {
    if (!value.isFinite) return defaultValue;
    return clamp((value / step).roundToDouble() * step);
  }

  double relativeBold(double baseWeight) =>
      clamp(baseWeight + relativeBoldDelta);

  @override
  bool operator ==(Object other) =>
      other is FontWeightAxis &&
      min == other.min &&
      defaultValue == other.defaultValue &&
      max == other.max;

  @override
  int get hashCode => Object.hash(min, defaultValue, max);
}

/// A durable, device-local font entry. Paths remain relative to its repository.
final class ImportedFont {
  const ImportedFont({
    required this.id,
    required this.displayName,
    required this.storageFileName,
    required this.byteLength,
    this.weightAxis,
    this.customWeight,
    this.weightAxisScanned = false,
  });

  final String id;
  final String displayName;
  final String storageFileName;
  final int byteLength;
  final FontWeightAxis? weightAxis;
  final double? customWeight;

  /// Whether this entry has already been scanned for `fvar` `wght` metadata.
  final bool weightAxisScanned;

  bool get isVariableWeight => weightAxis != null;

  double? get effectiveWeight {
    final axis = weightAxis;
    if (axis == null) return null;
    final custom = customWeight;
    return custom == null ? axis.defaultValue : axis.clamp(custom);
  }

  ImportedFont copyWith({
    String? id,
    String? displayName,
    String? storageFileName,
    int? byteLength,
    FontWeightAxis? weightAxis,
    bool clearWeightAxis = false,
    double? customWeight,
    bool clearCustomWeight = false,
    bool? weightAxisScanned,
  }) {
    return ImportedFont(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      storageFileName: storageFileName ?? this.storageFileName,
      byteLength: byteLength ?? this.byteLength,
      weightAxis: clearWeightAxis ? null : (weightAxis ?? this.weightAxis),
      customWeight: clearCustomWeight
          ? null
          : (customWeight ?? this.customWeight),
      weightAxisScanned: weightAxisScanned ?? this.weightAxisScanned,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImportedFont &&
      id == other.id &&
      displayName == other.displayName &&
      storageFileName == other.storageFileName &&
      byteLength == other.byteLength &&
      weightAxis == other.weightAxis &&
      customWeight == other.customWeight;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    storageFileName,
    byteLength,
    weightAxis,
    customWeight,
  );
}
