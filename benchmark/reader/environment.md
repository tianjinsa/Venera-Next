# 环境记录（2026-11-16）

| 项目 | 记录 |
|---|---|
| 设备 | 23049RAD8C / marble，ARM64 |
| Android | 15 / API 35 |
| 显示 | 1080×2400；系统支持 60/90/120 Hz；准备阶段 active render 为 120.00001 Hz |
| 热状态 | 准备阶段 Thermal Status 0；电池温度 35.9°C；各次采样前后另存原始状态 |
| Next 起点 | `97217db9f0c40549b15acef528abc339eb1998d4` |
| Prime 参考 | `2e287566c6fad11b0085bbdf4a528e507021ec61`（远端指定分支） |
| Flutter | 两版均使用 3.41.4，framework `ff37bef603469fb030f2b72995ab929ccfc227f0` |
| Engine | `e4b8dca3f1b4ede4c30371002441c88c12187ed6` |
| Dart | 3.11.1 |
| Android 构建 | Gradle 8.14、AGP 8.12.3、JDK 21；NDK 28.0.13004108、CMake 3.22.1；ARM64 |
| SDK | compile/target 36；platform-tools 37.0.1；build-tools 36.0.0，另复用/补齐插件所需平台 |
| Perfetto | 设备 v46.0；主机 Trace Processor v59.1 |

这些是工具准备证据，不代表阅读器采样时也始终处于 120 Hz。每轮仍需核对
Flutter display.refreshRate、dumpsys display、FrameTimeline 和热状态。
两版均使用同一 Flutter/引擎构建，避免把引擎差异混入本轮对照；设备原有安装的
源码 SHA 无法仅从版本号推断，因此不冒充准确构建基线。

原 SDK 的部分目录是失效链接。本轮从 Google 官方仓库清单校验散列后恢复
platform-tools、command-line tools、SDK 平台及 build-tools；既有 NDK/CMake 保留。
宿主缺少 Windows symlink 权限，通过子进程 `FLUTTER_WINDOWS=false` 只准备 Android。
历史 Gradle user home 中有强制开发包名的配置，采样使用独立 user home，仅复用
下载缓存与显式固定的 NDK/CMake，不修改历史配置。安装前 aapt 检查曾正确拦截
错误包名，未覆盖设备上的正式或开发应用。

APK、实际导出源码散列、完整观察器补丁及逐轮构建日志保存在忽略目录。
最终采用的 APK 必须由 `stamp.py` 封存，并与对应采样记录关联。
