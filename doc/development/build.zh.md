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

CI 会使用 `flutter test --coverage` 生成 `coverage/lcov.info`，在工作流摘要中显示行覆盖率，并上传报告产物。当前覆盖率用于建立可见基线，尚未设置统一硬阈值；涉及关键业务路径的改动仍必须增加针对性测试。

PR 还会运行 `依赖安全审查` 和 `PR 平台冒烟构建`。依赖审查会阻止引入高危或严重漏洞依赖；平台工作流按改动选择 Android、Windows、Linux、macOS 或 iOS 冒烟构建；Android 手机／TV 在同一 runner 上顺序验证 ARM64，文档等不影响构建的改动跳过平台任务。质量流程另运行真实 TV flavor 的导航、输入、低内存和更新回归。Dart 格式检查只针对本次修改的 Dart 文件执行，避免历史格式差异阻塞后续贡献。`main` 分支要求 PR 通过代码分析、依赖审查和平台冒烟构建门禁，并禁止直接强推或删除分支。

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

构建产物分别位于 `build/app/outputs/apk/mobile/release/` 和 `build/app/outputs/apk/tv/release/`。Android 必须明确指定 `--flavor mobile` 或 `--flavor tv`；不设置全局 `default-flavor`，避免影响 iOS/macOS 的原有 Xcode scheme。GitHub Actions 勾选 Android 后固定构建手机和 TV 的全部架构，不再提供 flavor／架构选项。TV 的独立包名、版本码偏移、更新方式和发布校验见 [Android TV 分发说明](../distribution/android_tv.zh.md)。

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

### 桌面与 iOS 的 CI 用时控制

Windows 打包前只清理 `runner/Release` 中的旧安装文件，保留 CMake／MSBuild 编译中间文件。`windows/build.py` 使用 `--no-pub`，请先运行上面的锁文件依赖命令；便携 ZIP 从 Release 目录直接生成，不再复制完整应用。CI 缓存固定版本的 Inno Setup，并检查恢复后的编译器是否存在。ISCC 启动器的文件版本固定为 `0.0.0.0`，不用于判定编译引擎版本。

macOS 与 iOS 在同一 Apple job 按选择顺序构建，共用一次 Flutter／Xcode／Rust 准备和 CocoaPods 下载缓存。Flutter SDK 使用 runner 的本机架构；macOS release 仍为通用二进制，iOS 单独构建时只安装 iOS Rust target。DMG 优先使用 APFS 克隆暂存应用，不支持时回退为普通复制；DMG、IPA 分别上传，iOS 原生版本和内嵌版本校验保留。

Linux x64／ARM64 使用仅包含所选架构的矩阵。APT 只安装缺失依赖，并复用镜像中已有的 CMake／Clang 等工具；C/C++ 编译使用按架构隔离的 ccache，Rust 缓存继续独立保留。DEB、RPM、AppImage 和 Arch 包从一次 Flutter 编译的同一 bundle 生成。AppImage 工具恢复后仍校验 SHA-256；Arch 打包镜像只安装 fakeroot，不安装编译器或应用运行依赖，GTK/WebKit 仍写入包的依赖元数据。打包和 AppImage 冒烟容器使用 BuildKit 缓存；跳过测试时 ARM64 不启动 Docker。

发行包优先使用较快的压缩配置：Windows ZIP／IPA 使用低级别 Deflate，Inno 使用 LZMA2 fast，DMG 使用低级别 zlib，DEB 使用 xz level 1，RPM／Arch／AppImage 使用 zstd level 3。包体可能略大，安装布局、CPU 架构和签名／来源要求不变；上传已经压缩的安装包时关闭二次压缩。同分支、同平台范围的重复构建会取消旧任务，不同平台范围互不取消。缓存首次建立需要额外时间，实际收益以后续运行的累计 runner 用时和缓存命中统计为准。

Rust 编译缓存也会在失败后尝试保存，但使用独立的 `partial` 键。重试优先恢复相同输入的编译进度，成功后再写入完整缓存键；缓存服务异常不改变构建结果。

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

`代码分析` 先执行轻量版本／结构／架构检查，再根据完整 PR diff 或 push 的全部提交选择测试。纯文档和分发元数据不启动 Flutter、模拟器或 Apple runner；Dart 改动保留完整 Flutter 测试和覆盖率，平台原生检查按受影响目录执行。未知输入、无法读取 diff、手动构建及 tag 发布保守地使用完整范围。`依赖安全审查` 会检查 PR 新增或升级的依赖；`PR 平台冒烟构建` 按受影响平台编译，Android 手机／TV 共用一个 runner，冒烟只编译 ARM64。`完整构建` 在开始多平台构建前复用同一质量工作流。

开发工作在 `codex/agent-center-tab` 分支进行。手动 `构建` 通过平台开关控制范围；勾选 Android 就生成手机和 TV 的 ARM32、ARM64、x86_64 与通用包，共 8 个 APK 和两份 manifest，不再提供 Android 版本或架构选择。两种 Android 安装包顺序构建，共用 Flutter、Gradle 和原生 Rust 编译目录，每种通过独立签名／内容校验后立即暂存，统一上传为 `android_build`。Android 单平台质量检查不占用 Apple runner。完整构建／标签构建采用相同的全量 Android 产物要求。

Rust 缓存覆盖下载源码及实际 Cargo 输出目录，按操作系统、主机架构、目标平台／profile、锁文件、工具链、构建配置和 Rust 源码区分；源码变化可恢复同配置的依赖缓存，由 Cargo 判定重新编译。准备脚本保留可用工具链，只安装缺失工具链或 targets。Gradle 启用任务缓存。Android runner 至少保留 20 GiB 空间；空间足够时不清理，只有 GitHub 托管 runner 空间不足时才按需删除无关工具，不删除整个 `/opt/hostedtoolcache`、Android SDK 或 Flutter。

手动运行 `构建`、`完整构建` 或 `HarmonyOS Release HAP` 时，可勾选 `skip_tests` 跳过测试，默认不勾选。该选项会传递至复用工作流，跳过 Python、Dart、Swift、Rust 测试、Android Provider 回归、Windows 原生／启动测试、Linux AppImage 冒烟测试及鸿蒙主机测试；静态分析、版本／依赖检查、编译和产物完整性／签名校验仍然执行。PR 和主分支 CI 默认运行受影响范围的测试；tag 自动发布默认运行完整测试。

Android release 工作流需要以下仓库 Secrets：

- `ANDROID_KEYSTORE`：keystore 文件的 Base64 内容
- `ANDROID_KEY_PROPERTIES`：`key.properties` 文本内容

`ANDROID_KEY_PROPERTIES` 可以直接使用以下格式，无需修改 `storeFile`：

```properties
storeFile=keystore.jks
storePassword=<ANDROID_KEYSTORE_PASSWORD>
keyAlias=<ANDROID_KEY_ALIAS>
keyPassword=<ANDROID_KEY_PASSWORD>
```

工作流仅在 Android 构建步骤中读取 Secrets，将证书和属性文件写入 `$RUNNER_TEMP/android-signing/`，目录权限为 `700`、文件权限为 `600`。Gradle 通过 `ANDROID_KEYSTORE_FILE` 和 `ANDROID_KEY_PROPERTIES_FILE` 读取临时文件，CI 中以临时证书的绝对路径覆盖 `storeFile`；无需在仓库中放置 `android/app/keystore.jks`。缺少 Secrets 或 Base64 无效时直接失败；无论构建成功或失败都会执行清理步骤，签名文件不作为产物上传。本地构建未设置这些环境变量时，仍读取 `android/key.properties` 及其中的 `storeFile`。

JDK 在编译前读取配置 keystore 中指定别名的公开证书，使用与 Gradle 完全相同的 Java Properties 转义规则解析属性。预期 SHA-256 经 `ANDROID_EXPECTED_SIGNER_SHA256` 传给 APK 校验，并通过复用工作流输出传给发布门禁；每个 APK 和 manifest 必须匹配这份独立身份，CI 不允许缺失或格式无效的指纹。keystore 密码或别名有误会在耗时编译前失败。fork 可使用自己的证书，但与上游证书不同的 APK 不能直接覆盖上游安装包；后续升级应沿用同一 keystore。

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

## 仅运行 GitHub Actions 质量与回归测试

Cloud Codex 可以在云环境按本次修改运行有界定向测试，全量测试使用 fork 工作分支的手动构建工作流，不在本地自动启动全量或重型构建。选择 `tests_only=true` 可强制完整质量门禁且不构建安装包；此时 `skip_tests` 不会跳过测试。普通构建中 `tests_only` 默认 false，已有平台/签名行为保持。

```sh
gh workflow run build.yml --repo tianjinsa/Venera-Next \
  --ref codex/agent-center-tab -f tests_only=true -f skip_tests=false \
  -f build_android=false -f build_windows=false -f build_macos=false \
  -f build_ios=false -f build_linux_x64=false -f build_linux_arm64=false
```

提交推送后再触发，并核对 run 的 head SHA、所需 job 和最终结果；派发成功不代表通过。此入口不会创建 Release。
