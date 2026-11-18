# Y300

<div align="center">
  <strong>面向 Yamibo / 百合会内容浏览与阅读场景的第三方 Flutter 客户端</strong>
</div>

<p align="center">
  <img alt="License: GPL v3" src="https://img.shields.io/badge/License-GPLv3-blue.svg">
  <img alt="Development status" src="https://img.shields.io/badge/status-active%20development-orange">
</p>

Y300 将论坛浏览、收藏同步、漫画管理和小说阅读整合在一个 Android 客户端中

本仓库是 [QAQadws/y300](https://github.com/QAQadws/y300) 的 fork，保留上游的论坛协议、书架与阅读器主体，在此基础上维护界面焕新（prism_ui 组件与外观设置）、应用级分类书架、阅读配色、筛选与黑名单拆页等改动。安装包使用独立应用标识 `com.adws.y300.fork`，与上游 `com.adws.y300` 签名互不影响，两者可以同时安装。上游的更新与发布说明以[上游仓库](https://github.com/QAQadws/y300)为准。

## 功能

- 浏览论坛、版块、帖子，支持登录、搜索、收藏、回复和发帖
- 同步论坛收藏，并整理为漫画或小说书架
- 漫画支持纵向、LTR、RTL 阅读，记录进度并提供章节下载
- 小说支持滚动与分页阅读、主题排版、简繁转换和书签
- 本地保存书架、历史、阅读状态、偏好设置与下载内容
- 支持缓存管理、深色模式和应用内更新

## 下载

本 fork 的 Android 安装包通过本仓库 Releases 发布，也可以按下面的构建说明自行打包。上游版本见 [上游 Releases](https://github.com/QAQadws/y300/releases)。本仓库的产物名称固定为：

```text
y300-v<version>-android-arm64-v8a.apk
```

目前仅提供适用于 `arm64-v8a` Android 设备的安装包。项目主体基于 Flutter，具备迁移至 iOS 的基础，但通知、应用更新等平台相关能力仍需适配。请只安装本仓库发布或自行构建的 APK

## 本地开发

环境要求：Flutter 3.47.7（自带 Dart 3.13.5，与 CI 一致）、JDK 17 和 Android SDK。Dart 使用该 Flutter SDK 自带版本；具体 SDK 兼容范围以 [`pubspec.yaml`](./pubspec.yaml) 为准。

```bash
git clone https://github.com/neveragain233/y300.git
cd y300
flutter pub get
flutter run
```

检查与构建：

```bash
dart format <本次修改的Dart文件>
flutter test
flutter analyze
python3 tool/build_apk.py
```

`tool/build_apk.py` 是安装包的唯一入口：固定发布模式、`android-arm64` 与生产入口，应用标识取自 `android/app/build.gradle.kts`、版本取自 `pubspec.yaml`，校验签名、架构和 16KB 对齐后输出 `build/app/outputs/flutter-apk/y300-v<version>-android-arm64-v8a.apk`。规则和校验项见 [tool/README.md](./tool/README.md)。

公开分发前请在 `android/key.properties` 配置自己的 release keystore，不要提交签名文件、密码、账号凭据或包含认证信息的日志；没有该文件时 Gradle 回落到调试签名，本地构建仍可继续。

`doc/`、`AGENTS.local.md` 和 `.local/` 是维护者本机资料，已被忽略规则排除，克隆后不存在属于正常情况；`docs/` 是被上游忽略的历史文档目录。公开贡献只需要 `lib/`、`packages/`、`test/`、`tool/` 与根目录配置。

## CI

面向 `main` 的 PR、`main` push 和手动运行会触发 `.github/workflows/ci.yml`。一个 Job 使用 Flutter 3.47.7 和 Ubuntu 24.04，执行 App 与协议包的静态分析和全部测试；依赖来源沿用现有锁文件的镜像配置。测试样本随仓库提交，不依赖本地 `docs/html` 或签名资料。

原有 `Android arm64 release` 手动 APK 构建入口保持独立，同样固定 Flutter 3.47.7。CI 只执行检查，GitHub 与 Gitee Release 由维护者手动创建。

## 设计参考

Y300 的部分 UI 设计与交互参考自 [kodjodevf/mangayomi](https://github.com/kodjodevf/mangayomi)

界面组件基于 vendored 的 [prism_ui](https://github.com/chen08209/prism_ui)（GPL-3.0-only），其改编来源与各自的许可声明见 [`packages/prism_ui/NOTICE`](./packages/prism_ui/NOTICE)

小说阅读器的段落接续、渐隐和覆盖翻页动效参考了 [Wenku8_Flutter](https://github.com/mikufoxxx/Wenku8_Flutter) 的阅读器实现。Y300 根据自身的 HTML 分页和阅读器结构实现并调整了这些效果

参考代码及其原始版权和许可声明见 Wenku8_Flutter 的 [NOTICE](https://github.com/mikufoxxx/Wenku8_Flutter/blob/master/NOTICE) 和 [LICENSE](https://github.com/mikufoxxx/Wenku8_Flutter/blob/master/LICENSE)。Wenku8_Flutter 的 Flutter 组合版本按 GNU GPL v3 分发；Y300 源代码按 GPL-3.0-only 授权

## 免责声明

Y300 不是 Yamibo / 百合会官方客户端。论坛帖子、漫画、小说、图片及其他内容归原作者或相应权利人所有。使用时请尊重原作者，并遵守 Yamibo 的相关规则

## 许可证

Copyright (c) 2026 QAQadws and contributors

本项目源代码依据 [GNU General Public License v3.0](./LICENSE) 授权，许可证标识为 `GPL-3.0-only`。第三方名称、商标、内容和用户数据不属于本项目源代码许可证的授权范围
