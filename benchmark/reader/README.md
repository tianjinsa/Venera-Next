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

当前状态：工具链恢复和实机基线准备中，尚无性能修复或验收结论。

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

夹具为 512 个不同文件键的相同 2048×3072 PNG。首次启动在采样前生成，后续复用。
文件缓存预热与 Flutter 已解码缓存命中要区分，不能把本地文件直接称为已解码命中。
固定 LTR、单页、200 毫秒动画、预加载设置；其他方向／布局需另行配置与回归。

`duration` 是 ADB 输入候选。必须先对照实体按键的原生 `repeatCount`、`downTime`
和间隔；若不等价，用 `--input manual` 自动采样并手动按键。
`taps`／`swipes` 明确作为触摸场景，不能替代长按音量键证据。
原生事件与 Dart 接收通过八次时钟往返校准对齐，报告最短往返的不确定度。
CPU 使用进程累计 CPU 时间差；不把异步等待或整段动画时长当 CPU 执行。

`vm_trace.dart` 使用 Profile 的 VM Service 导出 CPU 样本、Timeline 与堆概况；
Release 的验收不用这些 Profile 开销。Perfetto 另外采集调度／频率、SurfaceFlinger
FrameTimeline、GPU 内存和设备支持的电源轨。原始 Trace 不自动上传或提交。

测量语义检查：`python -m unittest discover -s benchmark/reader -p test_measurement.py`。
