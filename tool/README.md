# Android 安装包构建

固定入口为 `python3 tool/build_apk.py`，在仓库根目录运行。需要 Python 3.9 以上、已配置的 Flutter（与 CI 一致的 3.47.7）、Android SDK，以及带 `aapt`、`apksigner`、`zipalign` 的 build-tools。签名配置放在 `android/key.properties`，该文件不进入版本控制；缺少时 Gradle 回落到调试签名，`flutter run` 和本地构建仍可继续。

脚本读取两份工程配置作为唯一来源：`android/app/build.gradle.kts` 的 `applicationId` 是应用标识，`pubspec.yaml` 的 `version: <版本名>+<内部版本号>` 是显示版本与 versionCode。应用标识默认取 Gradle 配置里的字面量；本机如果要在 `android/local.properties` 写入 `y300.applicationId`，脚本按覆盖后的标识校验，这条覆盖只用于继续覆盖安装既有自用版本，不进入版本控制。构建命令固定为发布模式、`lib/main.dart`、`android-arm64` 和 `--no-pub`，不修改 pubspec，不安装应用，不启动模拟器：

```bash
python3 tool/build_apk.py
```

产物为 `build/app/outputs/flutter-apk/y300-v<版本名>-android-arm64-v8a.apk`，与 Gradle 的 `archivesName` 保持一致；同一版本重建会覆盖上一份产物。构建完成后核对应用标识与 Gradle 一致、不可调试、只有 arm64-v8a、不含调试内核、ZIP 与全部原生库加载段按 16KB 对齐，并记录签名证书与 SHA-256。已有上一份安装包时要求签名证书一致，否则覆盖升级会失败。

校验通过后才发布并更新 `build/apk-builds/latest.json`，随后删除 `build/` 下其它 `.apk` 及校验和、签名伴随文件，包括 Gradle 的重复产物。清理不跟随目录链接，不进入 Git 对象库。构建请求、日志、badging、签名与对齐证据、清理清单保存在 `build/apk-builds/<时间戳>/`；`build/` 整体被忽略，不进入提交。

无需重新构建时可以只整理已有安装包：

```bash
python3 tool/build_apk.py --keep-latest
```

该模式按 versionCode 选出最新安装包，重新校验后执行相同清理。

## 图标资源

桌面与启动图标沿 `dart run tool/generate_app_icons.dart` 统一生成，再运行 `dart run flutter_native_splash:create`。原图保持 `assets/app_icon_source.png`，标志覆盖率、着色及布局在 `tool/app_icons/icon_artwork.dart`。自适应前景不预裁桌面轮廓；旧版本单独生成圆形及圆角方形回退。浅色使用黄底红标，深色使用暗底浅红标；系统亮度限定符同时作用于背景、前景与旧版本回退。安卓12及以上启动前景保持透明与出血，由系统统一裁切；旧版本启动图只有一层圆角底板。

安卓13及以上普通和圆形入口声明同一原生单色图层，浅色与夜间均提供自适应入口，避免夜间回退位图优先命中；桌面自定义颜色或系统动态取色由桌面控制。`assets/app_icon_monochrome.png` 与多密度原生单色资源共用透明覆盖率。对应回归为 `flutter test test/tool/app_icon_artwork_test.dart`。

纯构建工具改动通过 Python 回归检查：

```bash
python3 -m unittest discover -s tool/tests
```
