/// Shared geometry for grid-mode shelf covers.
///
/// Keeping these values together prevents the cover chrome and grid layout
/// from drifting apart when the shelf density is adjusted.
abstract final class ShelfGridGeometry {
  static const double contentPadding = 8;
  static const double itemSpacing = 4;

  static const double selectionCornerRadius = 8;
  static const double coverCornerRadius = 7;
  static const double selectionPadding = 2;
  static const double selectionBorderWidth = 2;

  /// 密度偏好保持不变，宽窗口追加列数，窄窗口保证封面可点按。
  static int columnCount(double width, int preferredColumns) {
    final available = width - contentPadding * 2 + itemSpacing;
    final minimum = width >= 600 ? (available / 184).ceil().clamp(1, 20) : 1;
    final maximum = (available / 52).floor().clamp(1, 20);
    return preferredColumns.clamp(minimum, 20).clamp(1, maximum);
  }
}
