import 'package:flutter/widgets.dart';
import 'package:prism_ui/liquid_glass.dart';
import 'package:y300/app/settings/app_glass_level.dart';

/// 应用级液态玻璃来源环境，挂在 Navigator 之上，让普通路由、根页菜单、
/// 模态面板和分栏详情读取同一份背景捕获。
///
/// 关闭档与高对比模式不启用捕获；标准、增强档只映射既有质量档，
/// 不改变玻璃外观。整棵树只应存在一个启用宿主，避免嵌套重复捕获。
class AppGlassEnvironment extends StatelessWidget {
  const AppGlassEnvironment({
    super.key,
    required this.glassLevel,
    required this.child,
  });

  final AppGlassLevel glassLevel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = glassLevel.enabled && !MediaQuery.highContrastOf(context);
    final quality = glassLevel == AppGlassLevel.enhanced
        ? LiquidGlassQuality.ultra
        : LiquidGlassQuality.standard;
    return LiquidGlassScope(
      enabled: enabled,
      quality: quality,
      child: LiquidGlassHost(enabled: enabled, child: child),
    );
  }
}
