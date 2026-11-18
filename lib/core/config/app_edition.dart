/// 构建变体标识。
///
/// `full` 是手机端全量包；`eink` 是墨水屏裁剪包，由构建命令传入
/// `--dart-define=Y300_EINK=true` 打开。两者共用同一份源码与版本号，
/// 只有编译期常量不同，因此关闭的表现层不会被另一变体带到运行时。
abstract final class AppEdition {
  static const bool isEInk = bool.fromEnvironment('Y300_EINK');
}
