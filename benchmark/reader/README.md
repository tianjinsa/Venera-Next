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

当前状态：已提交动画交接与隐藏收藏通知修复，完成实体键校准，继续调查按键导航的重复工作。
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

## 实体音量键校准与匹配输入

已在本设备完成实体音量减键校准：连续 271 个 DOWN，repeatCount 为 0…270、
共用一个 downTime；原生及 Dart 各收到 271 个，持续重复约 19.78 Hz。
首个重复的 eventTime 间隔为 401 ms；原生接收间隔约 242 ms，是因为首键本身
约 163 ms 后才到 Activity。两种时间分别保存，不把通道耗时与原生投递延迟混为一谈。
实际首末 DOWN 的 eventTime 跨度约 14 秒，提示原计划的 8 秒不能充当实测时长。

客户端不显示内部 `notify()` 提示，声音也未可靠传达。手工采样必须拆开准备和结束，
准备命令返回 `SAMPLER ARMED` 后，在可见聊天及表层命令中明确提示按住／松开：

```powershell
python benchmark/reader/manual_session.py arm --variant next --name physical-hold
# 这里在聊天中提示按住，再执行可见的 8 秒计时；用户按住后不再运行准备步骤。
Write-Output '现在按住音量减键'; Start-Sleep -Seconds 8; Write-Output '现在松开音量减键'
python benchmark/reader/manual_session.py finish --variant next --name physical-hold
```

重启手机可能使单调时钟回退；ACK 按时间戳是否改变判断，不能要求大于旧进程时间。
连续同名命令也必须等待各自的新 ACK，避免把前一次定位当成本次完成。

自动对照保留实体记录前 8 秒的 eventTime 偏移，发送连续递增 repeatCount 的 DOWN
及一个 UP，保留相同 downTime。它不同于反复发送单次 `input keyevent`：

```powershell
./benchmark/reader/build_input.ps1 -Keys
python benchmark/reader/adb_benchmark.py --variant next capture --name calibrated-forward --input calibrated-hold --seconds 12 --perfetto
```

两版首轮均核验 152 个 DOWN、完整 repeatCount、同一个 downTime，且接收事件时间与
注入记录一致；首键原生投递也同为约 161–162 ms。校准摘要见
[results/physical-volume-calibration.json](results/physical-volume-calibration.json)。
后续每轮自动拒绝不匹配的原生序列。原生探针只记录 DOWN，没有测量实体 UP 的时刻；
模拟输入验证的是阅读器实际消费的 DOWN 链路，最终仍需实体键复核体验。


## 缓存驻留隔离与视口观察

`--cached-budget-headroom` 只允许 keysequence / alternate / warm-radius=1，
要求前后相同五张图片、120 MiB、无 pending 和任何 sourceLoad/imageMiss，实际预算至少
128 MiB；它不改变自动预算，不适用于冷加载或一般长按。默认严格 192 MiB 校验保持不变。

`analyze_viewport.py` 区分控制器整数页驻留时间、产出帧结束时位置；均非屏幕呈现。
`analyze_cpu_schedule.py` 对齐实际采样窗口，报告 UI 线程 CPU 放置与运行时间加权频率，
不修改频率或亲和性。Prime／官方测试／本分支执行路径见 prime-render-flow.md。

## 收藏状态数据集

Next 导出支持 `prepare.py --favorite-pages 1000`：在独立测试包内，为固定生成漫画写入
10 章各 100 条收藏，不访问网络或用户漫画。默认 0，仅移除这条生成漫画的测试收藏。
真实入口的包路径检查始终保留。`favoriteStatus` 计进入原队列的请求，`favoriteSql` /
`favoriteSqlEnd` 计同步数据库读取加解析；其间隔为墙钟耗时，不直接当作 CPU time。
`analyze_favorite_status.py` 拒绝页数、输入、读取／解码、驻留集合或预算不同的对照。

## SurfaceView 实际呈现时间戳

`surface_capture.py` 接受与 capture 相同的输入参数，先新启独立测试包，再每 .5 秒
读取其唯一 BLAST SurfaceView 的 127 行循环记录，不清空统计、不更改设备设置。
只与同样启用该采样器的窗口比较。`analyze_presentation.py` 按原生单调时钟校准筛选
ROI、去重重叠记录、排除未触发的 fence，并报告采样开销／环覆盖风险。

三列为 desiredPresent、actualPresent、frameReady，定义见
[AOSP FrameTracker::dumpStats](https://android.googlesource.com/platform/frameworks/native/+/refs/heads/main/services/surfaceflinger/FrameTracker.cpp)。
实际呈现间隔包含跳页后的正常静止与空闲，不能直接换算为屏幕掉帧数；这项记录补充
当前 Perfetto 未提供应用 Surface FrameTimeline 的限制。没有可用映射时，掉帧计数保持未知。
