# 自用安装包构建

固定入口为 `python3 tool/build_personal_apk.py`，在仓库根目录运行。后续任务复用此入口，构建规则和校验在这里维护，不再向任务笔记目录新增打包实现。需要 Python 3.9 以上、已配置的 Flutter 和安卓 SDK、既有自用签名配置及已获取的项目依赖。代理执行此命令时申请在沙箱外运行，因为它会调用 Flutter 并使用 SDK 缓存。

脚本复用原试装构建流程：发布模式、`lib/main.dart`、`android-arm64`、`--no-pub`。使用同一次开始构建的北京时间生成 `app-debug-dev-MMddHHmm.apk` 和 `v<基础版本>-MMddHHmmdev`；内部版本号高于基础版本、现存试装包和上次预留编号。同一分钟重复交付直接报错，不覆盖已有包。命令不修改 `pubspec.yaml`，不安装应用、不启动模拟器。

最新试装反馈修正计划已启用2.0系列，`pubspec.yaml` 基础版本为 `2.0.0`，脚本统一拼接字面前缀 `v`，试装版本名为 `v2.0.0-MMddHHmmdev`。内部版本号接续现有记录递增，文件命名沿用。版本规则只在本入口维护。

构建完成后核对版本、固定包名、固定签名证书、不可调试标志、单一架构、预编译产物及 ZIP／全部原生库加载段的16KB对齐。校验通过才发布并更新最新包指针，然后删除仓库内其他 `.apk` 文件及其校验和、签名伴随文件，包含预览包和 Gradle 重复产物。构建或校验失败保留上一交付包，构建任务使用共享文件锁避免相互覆盖。

无需重建时运行 `python3 tool/build_personal_apk.py --keep-latest`。脚本从现有规范命名的试装包中按内部版本号选取最新包，重新校验后执行相同清理。目录符号链接和 Git 内部目录不进入清理范围。

构建日志、验证证据、清理清单及 `latest.json` 位于 `.local/agent-notes/<完整分支名>/build-apk/`。该目录留在本地。安装包位于 `build/app/outputs/flutter-apk/`，只保留最新一份。签名密钥继续使用现有安卓构建配置，脚本只固定公开的证书指纹。

工具回归检查运行 `python3 -m unittest discover -s tool/tests`，覆盖版本递增、越界清理保护、链接隔离、验证失败保留旧包和同一分钟覆盖保护。


## 图标资源

桌面与启动图标沿 `dart run tool/generate_app_icons.dart` 统一生成，再运行 `dart run flutter_native_splash:create`。原图保持 `assets/app_icon_source.png`，标志覆盖率、着色及布局在 `tool/app_icons/icon_artwork.dart`。自适应前景不预裁桌面轮廓；旧版本单独生成圆形及圆角方形回退。浅色使用黄底红标，深色使用暗底浅红标；系统亮度限定符同时作用于背景、前景与旧版本回退。安卓12及以上启动前景保持透明与出血，由系统统一裁切；旧版本启动图只有一层圆角底板。

安卓13及以上普通和圆形入口声明同一原生单色图层，浅色与夜间均提供自适应入口，避免夜间回退位图优先命中；桌面自定义颜色或系统动态取色由桌面控制。`assets/app_icon_monochrome.png` 与多密度原生单色资源共用透明覆盖率。未来三套应用主题联动沿同一几何接入，边界见 `doc/图标与启动屏适配.md`。对应回归为 `flutter test test/tool/app_icon_artwork_test.dart`。
