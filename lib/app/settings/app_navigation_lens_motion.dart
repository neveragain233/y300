/// 沉浸式底栏透镜的跟随方式。
///
/// 只决定按下和拖动时透镜如何移动；点按入口、拖动松手按落点提交一次、
/// 取消回原项以及关闭滑动后仅点按的提交规则都不随该选项改变。
enum AppNavigationLensMotion {
  /// 按下即跟随：透镜先移动到按下的入口，再从按压点继续跟手。
  followPress,

  /// 从当前入口拖动：透镜停在当前选中项，按相对位移跟手。
  fromSelection;

  /// prism_ui `FloatingNavigationBar.dragFromSelection` 的投影。
  bool get dragFromSelection => this == AppNavigationLensMotion.fromSelection;
}
