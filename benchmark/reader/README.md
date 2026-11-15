# Android 分页阅读器 A/B 实验

工作起点：Next `97217db9f0c40549b15acef528abc339eb1998d4`。
本轮用户明确要求独立分支 `codex/reader-page-turn-adb-perf`，覆盖通常的固定开发分支约定。
Prime 只读参考为远端 `codex/agent-center-tab`：
`2e287566c6fad11b0085bbdf4a528e507021ec61`。
本地 Prime 当前检出其他分支，不能用当前工作树冒充这个基线。

原始设备记录、图片、截图、CPU/Timeline/Perfetto 和 APK 放在被忽略的
`raw/`、`artifacts/`；提交前必须另行检查隐私。汇总报告不含书名、地址、设备序列号。

FrameTiming 的时间戳属于实际帧阶段；接收批次的时间不是帧时间。
UI/Raster 超预算、Flutter 产帧间隔与 SurfaceFlinger 实际呈现分别统计。
Profile 用于定位；性能验收必须复测 Release，并同时记录资源和热状态。

当前状态：已完成多轮设备基线并提交动画交接修复，继续调查隐藏工具栏的重复工作。
详细数据和未完成验收范围见 [report.md](report.md)。

## 运行方式

`prepare.py` 从准确 SHA 导出独立源码，在副本中加入相同观察器和本地图片入口。
它拒绝覆盖现有导出目录，Prime 原工作树保持只读。两版均使用普通 Flutter
引擎绑定、真实阅读器与原有音量键通道，不使用测试绑定持续产帧。

```powershell
python benchmark/reader/prepare.py --repo D:/code/Venera-Next --ref <SHA> --variant next --out benchmark/reader/artifacts/next-before
./benchmark/reader/build.ps1 -Source benchmark/reader/artifacts/next-before
python benchmark/reader/adb_benchmark.py --variant next install <APK>
python benchmark/reader/adb_benchmark.py --variant next launch
python benchmark/reader/adb_benchmark.py --variant next capture --name next-calibrate --seconds 12 --input duration --hold-ms 8000 --perfetto
python benchmark/reader/summarize.py benchmark/reader/raw/next-calibrate/capture.json
```

构建脚本支持 `-Mode profile` 与 `-AnalyzeOnly`，工具路径可以传参。
只在子进程禁用 Windows 桌面插件生成，避免要求修改宿主 Developer Mode。
Next 导出副本打开 universal 输出以兼容 Flutter 默认 ARM64 NDK filter；这仅改变打包。
保留锁文件校验与 Release 插件注册流程。签名仅使用忽略目录内专用测试密钥。
安装脚本用 aapt 核验 `.readerbenchmark` 包名，拒绝覆盖正式包。

夹具为 512 个不同文件键的相同 2048×3072 PNG。首次启动在采样前复制，后续复用。
文件缓存预热与 Flutter 已解码缓存命中要区分，不能把本地文件直接称为已解码命中。
固定 LTR、单页、200 毫秒动画、预加载设置；其他方向／布局需另行配置与回归。

图片由导出脚本生成无损 RGB PNG 并作为资产打包，手机只在首次准备时复制。
普通对照每轮只结束独立测试包进程并重新启动，不清除数据，统一初始解码窗口；
采样入口核验 512 页、120 Hz、192 MiB。`--reuse-process` 仅用于明确标记的缓存
窗口／压力实验，避免将切后台后的 32 MiB 状态混入普通基线。

`duration` 是 ADB 输入候选。必须先对照实体按键的原生 `repeatCount`、`downTime`
和间隔；若不等价，用 `--input manual` 自动采样并手动按键。
`taps`／`swipes` 明确作为触摸场景，不能替代长按音量键证据。
`keysequence` 是单次 DOWN/UP 对的固定间隔连续输入，保留 `repeatCount=0`；
它用于连续合法单次键与动画交接实验，不能冒充实体长按。以测得事件间隔为准，
不把请求的 50 ms 自动当作实际 20 Hz。过快点按可能触发双击缩放，须核对真实页码。
原生事件与 Dart 接收通过八次时钟往返校准对齐，报告最短往返的不确定度。
CPU 使用进程累计 CPU 时间差；不把异步等待或整段动画时长当 CPU 执行。

`vm_trace.dart` 使用 Profile 的 VM Service 导出 CPU 样本、Timeline 与堆概况；
Release 的验收不用这些 Profile 开销。Perfetto 另外采集调度／频率、SurfaceFlinger
FrameTimeline、GPU 内存和设备支持的电源轨。原始 Trace 不自动上传或提交。

测量语义检查：`python -m unittest discover -s benchmark/reader -p test_measurement.py`。

Profile 启动需传 `enable-dart-profiling=true`，`profile_capture.py` 会负责启动、
转发 VM 端口、等待明确就绪事件、保存 CPU/Timeline 并释放端口。Profile 与 Release
在导出副本中统一 ARM64 versionCode，切换不卸载、不清数据。
`stamp.py` 保存源码差异、资产与 APK 散列；后续采样还核验设备实际安装包的 SHA-256。

## 动画结束前再次拖动

原始 PointerDataPacket 进入 GestureBinding 前记录 DOWN 时的页位置、滚动状态及
已有指针数。`newDragWhileScrolling` 仅计无其他指针且上一段仍滚动的新 DOWN，
用于核验用户实际的“松手动画结束前再次拖动”，不把短输入间隔自动当作已覆盖。
两版在入口安装相同 PageController 观察器；高频位置只缓冲数值，不追加 Profile instant。

Android `input swipe` 的 MOVE 数量随执行速度变化。严格触摸对照可用独立 shell
注入器，按绝对时间发送同样的 DOWN／MOVE／UP 路径，保存计划和实际时间：

```powershell
./benchmark/reader/build_input.ps1
python benchmark/reader/adb_benchmark.py --variant next capture --name next-fixed-fast --input swipes --touch-driver fixed --touch-step-ms 4 --swipe-ms 80 --interval .045 --count 20 --perfetto
python benchmark/reader/analyze_frames.py benchmark/reader/raw/next-fixed-fast
```

注入器以 shell UID 调用系统输入接口，只创建带内容散列的新测试 dex，不改系统设置
或应用数据。固定路径适配本轮 1080×2400 设备；每轮核验注入迟到、原生 DOWN 间隔、
Dart 收到的指针及实际选页数。Flutter MOVE 计数另报，不假定与注入数相等。

`--alternate --warm-radius 1` 提供小窗口往返预热场景（音量键每两次反向，拖动每次
反向）。是否完全命中缓存以 `imageMiss`／`sourceLoad` 为准，不能只根据预热参数认定。
采样前后均核验预算和刷新率；任何变化都保留原始文件但排除普通 A/B。

`profile_capture.py --widget-builds` 启用 Flutter 自带 Widget build Timeline，仅用于
识别调用路径，不能用其耗时作为 Release 改善；大量标记可能覆盖环形缓冲早期记录。
`analyze_frames.py` 将真实 UI 帧区间与 Perfetto 线程状态对齐，分开报告拖动中和
松手后阶段；松手后标签本身不保证动画仍活跃，也不代表屏幕实际掉帧。
