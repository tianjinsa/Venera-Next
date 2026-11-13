# 构建与开发

English version: [build.en.md](build.en.md)

本文面向准备从源码构建、测试或维护 VeneraNext 的开发者。安装和使用说明请阅读仓库根目录的 [README](../../README.md)。

## 环境要求

- Flutter `3.41.4`
- Dart `>=3.8.0 <4.0.0`
- JDK `17`，用于 Android 构建
- Rust 工具链；Android 构建需要安装对应 Android targets
- 目标平台原生构建环境，例如 Android SDK / NDK、Xcode、Visual Studio 或 Linux GTK/WebKit 依赖
- Windows 本地构建需要开启系统“开发者模式”；PDF 导入依赖的 `pdfrx` native assets 会在构建时创建符号链接

先检查 Flutter 环境：

```bash
flutter doctor -v
flutter --version
```

## 获取依赖

克隆仓库后，使用仓库锁文件获取依赖：

```bash
git clone https://github.com/CyrilPeng/venera-next.git
cd venera-next
flutter pub get --enforce-lockfile
```

不要在不了解依赖影响的情况下删除或重新生成 `pubspec.lock`。

Git fork 的来源、固定 commit 和升级要求见[依赖治理](dependencies.zh.md)。

### 关键依赖锁定

项目依赖 `rhttp 0.15.1`，必须保持 `flutter_rust_bridge 2.11.1`。版本不匹配时，构建可能成功，但应用启动后无法联网，并提示：

```text
flutter_rust_bridge has not been initialized
```

在 PowerShell 中可以检查锁定版本：

```powershell
Select-String pubspec.lock -Pattern "flutter_rust_bridge" -Context 0,6
```

结果应包含：

```yaml
version: "2.11.1"
```

## 质量检查

提交代码前至少运行：

```bash
python .github/scripts/check_structure_imports.py
flutter analyze --no-pub
flutter test --no-pub
git diff --check
```

CI 会使用 `flutter test --no-pub --coverage` 生成 `coverage/lcov.info`，在工作流摘要中显示行覆盖率，并上传报告产物。当前覆盖率用于建立可见基线，尚未设置统一硬阈值；涉及关键业务路径的改动仍必须增加针对性测试。

PR 还会运行 `依赖安全审查` 和 `PR 平台冒烟构建`。依赖审查会阻止引入高危或严重漏洞依赖；当改动涉及 Flutter 代码、原生平台目录、依赖、构建脚本或工作流时，平台工作流会执行 Android 手机版／TV 版 Debug 和 Windows Debug 构建，文档等不影响构建的改动会跳过这些平台任务。质量流程另运行真实 TV flavor 的导航、输入、低内存和更新回归。Dart 格式检查只针对本次修改的 Dart 文件执行，避免历史格式差异阻塞后续贡献。`main` 分支要求 PR 通过代码分析、依赖审查和平台冒烟构建门禁，并禁止直接强推或删除分支。

涉及发布版本时再运行：

```bash
python .github/scripts/release_version.py --check
```

## Android 构建

本地 release 签名文件放置在：

```text
android/keystore.jks
android/key.properties
```

`android/key.properties` 示例：

```properties
storePassword=你的 store 密码
keyPassword=你的 key 密码
keyAlias=你的 key alias
storeFile=../keystore.jks
```

构建 APK：

```bash
flutter pub get --enforce-lockfile
flutter build apk --release --flavor mobile
flutter build apk --release --flavor tv
```

构建产物分别位于 `build/app/outputs/apk/mobile/release/` 和 `build/app/outputs/apk/tv/release/`。Android 必须明确指定 `--flavor mobile` 或 `--flavor tv`；不设置全局 `default-flavor`，避免影响 iOS/macOS 的原有 Xcode scheme。GitHub Actions 开启 Android 时会同时构建两种。TV 的独立包名、版本码偏移、更新方式和发布校验见 [Android TV 分发说明](../distribution/android_tv.zh.md)。

签名文件和密码属于敏感信息，不应提交到仓库。

## 桌面端与 iOS 构建

在对应操作系统和原生工具链就绪后执行：

```bash
flutter pub get --enforce-lockfile
flutter build windows
flutter build linux
flutter build macos
```

iOS 可先执行无签名构建验证：

```bash
flutter pub get --enforce-lockfile
flutter build ios --release --no-codesign
```

Windows 安装器、便携包和 winget manifest 的维护方法见 [Windows 分发](../distribution/windows.zh.md)。

## GitHub Actions 与发布版本

仓库工作流负责持续集成、手动构建、tag 发布和分发元数据维护。发布版本号统一维护在 `release.json`：

```json
{
  "version": "1.2.3",
  "build": 123
}
```

准备发布时先更新 `release.json`，再同步并校验相关文件：

```bash
python .github/scripts/release_version.py --write
python .github/scripts/release_version.py --check --tag v1.2.3
```

`pubspec.yaml`、发布 tag 和 `CHANGELOG.md` 版本章节必须与 `release.json` 一致。`alt_store.json` 不是版本源；正式版 GitHub Release 成功后，工作流会根据发布资产更新它，RC 预发布不会更新 AltStore 源。

`代码分析` 工作流会运行版本与结构检查、Python 脚本测试、修改文件的 Dart 格式检查、`flutter analyze`、完整 Dart 测试及覆盖率汇总。`依赖安全审查` 会检查 PR 新增或升级的依赖，`PR 平台冒烟构建` 会按改动范围验证 Android 和 Windows 编译。`完整构建` 在开始多平台构建前会复用同一质量工作流；手动平台构建和 tag 发布则共同复用 `.github/workflows/build.yml`，避免两套构建定义产生差异。

CI 先执行一次 `flutter pub get --enforce-lockfile`，后续分析、测试与构建使用 `--no-pub`；Windows 打包脚本内部也遵循这一顺序，独立运行时仍会获取锁定依赖。Rust 初始化在原工具链上补齐组件和目标，安装或可执行文件校验失败时直接报错，不卸载重装或重置环境；通过 `RUSTUP_TOOLCHAIN` 避免宿主任务自动安装仓库中其他平台的 targets。Cargokit 同时识别已经安装的固定版本及 Windows 换行，避免各 ABI 再次请求安装相同工具链或目标。

共享的 `.github/actions/cache-rust` 按运行系统、架构、构建配置、Rust 工具链、锁文件和相关编译环境缓存 Cargo 依赖；Android 还区分 Gradle／NDK 配置与 Cargokit 脚本。Linux、Windows 和 Android 使用各自实际的 Cargokit 编译目录，Apple 应用仅复用下载缓存，不缓存 Xcode 产物或 Rustup 包装器。鸿蒙使用其独立的 API 26 交叉编译缓存。缓存不跳过项目自身 Rust 编译、测试、ABI 校验或发布来源校验，首次运行仍需填充缓存。

依赖安全工作流使用 runner 的宿主 stable 工具链，单独缓存固定版本、构建选项和运行平台下的 `cargo-audit` 可执行文件，在扫描前保存工具缓存，扫描发现漏洞也不会使工具缓存丢失。每次仍更新公告数据库并扫描完整锁文件，不缓存或复用审计通过结果。

普通原生库、带 ASan／UBSan 的原生库和 Android Provider 测试 APK 分别服务于不同测试，不能合并删除。Linux Flutter 测试仅编译 Rhttp 动态库，不额外生成未使用的静态库；Android 手机版和 TV 版继续在独立矩阵任务中构建。Linux 的 DEB、RPM、AppImage 与 Arch 打包已经共用一次 Flutter release 构建，不会逐格式重新编译应用。

Android release 工作流需要以下仓库 Secrets：

- `ANDROID_KEYSTORE`：keystore 文件的 Base64 内容
- `ANDROID_KEY_PROPERTIES`：`key.properties` 文本内容

发布后的 AltStore 更新会复用固定分支 `automation/update-altstore` 并创建 PR。仓库需要配置可向当前仓库推送分支并创建 PR 的 `ALTSTORE_PR_TOKEN`；未单独配置时会复用 `WINGET_PKGS_TOKEN`。令牌缺失或 PR 创建失败会使任务明确失败，不再产生只有分支、没有 PR 的成功记录。

Issue 分类与格式检查默认运行，不需要 AI API：`.github/scripts/issue_policy.py` 校验新表单、按类型要求诊断并维护分类／补充信息标签。新建、编辑、重新打开及评论变化会复查，同一提示评论更新；机器人事件、PR、已关闭和旧格式报告跳过。首次需要时自动创建分类标签，保留已有同名标签的颜色和说明。用户采集步骤见[Issue 提交说明](../user/issue_reporting.zh.md)。

可选 AI 摘要默认关闭，仅对格式检查通过的新建／编辑报告运行。确认 `API_URL`、`API_KEY` 可用后，将仓库变量 `ENABLE_AI_ISSUE_CHECK` 设为 `true`；`ISSUE_CHECK_MODEL` 可覆盖模型。格式和 AI 各自按 Issue 串行更新，机器人事件在作业入口跳过，不占用用户事件的待运行位置；AI 耗时不阻塞后续格式复查。AI 更新单独标记的评论，读取已有正文及报告者／维护者补充，失败不影响固定规则；只给维护者建议，不自动关闭。Issue 正文不插入 shell 命令，附件不由自动检查下载。

不要把 Secrets、签名文件或实际密码写入代码、日志和文档示例。

## 构建问题排查

### 构建成功但应用无法联网

优先确认 `flutter_rust_bridge` 仍为 `2.11.1`，并确认依赖是通过当前仓库的 `pubspec.lock` 获取。不要通过盲目升级依赖解决初始化错误。

### 提示 `flutter_rust_bridge has not been initialized`

通常是依赖版本漂移。恢复仓库中的 `pubspec.lock`，确认 Flutter 版本符合要求，再运行：

```bash
flutter pub get --enforce-lockfile
```

### 提示 `Unable to satisfy pubspec.yaml using pubspec.lock`

通常是 Flutter/Dart 版本或包源环境不匹配。先核对本页要求的 Flutter 版本和 `flutter doctor -v` 输出，不要直接删除锁文件。

### Gradle 下载过慢

可以在本地临时切换 Gradle wrapper 镜像或配置网络代理，但环境相关地址不应提交到仓库。提交前应确认 `gradle-wrapper.properties` 没有混入本地镜像改动。
