/// 液态玻璃档位。关闭时使用主题实色，标准档提供背景模糊与边缘高光，
/// 增强档在同一外壳上叠加更强的边缘光学和选中透镜。
enum AppGlassLevel {
  off,
  standard,
  enhanced;

  bool get enabled => this != AppGlassLevel.off;
}
