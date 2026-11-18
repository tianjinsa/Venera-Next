# 连续翻页的 VSync 产帧节奏

同一段分页动画中，已定位到一种 16.7 ms 长间隔。Flutter 的分页 ticker 已经请求下一帧，
但处理该请求的原生任务要等主线程结束当前帧。请求到达 SurfaceFlinger 时，最近一次
VSync 已开始分发，阅读器收到再下一次的回调。只看已经产出的帧的 UI 或 Raster 耗时，
会漏掉中间没有进入 Flutter 帧管线的那一拍。

## 一次实际错过的回调

以下来自 `pclead-main-hold-reverse-before-1` 的 3.118 秒附近。
以中间那次 SurfaceFlinger app VSync 分发开始为零点。

| 事件 | 相对时间 ms |
| --- | ---: |
| 阅读器收到前一拍的 `AChoreographer` 回调 | −3.753 |
| Flutter ticker 请求下一帧 | −1.271 |
| SurfaceFlinger 开始分发中间那拍 | 0 |
| Flutter 的 `handleDrawFrame` 返回，含帧后回调 | +1.038 |
| 阅读器唤醒 SurfaceFlinger binder 线程 | +1.188 |
| SurfaceFlinger 执行该请求的 `requestNextVsync` | +1.245 |
| 阅读器收到下一可用的 `AChoreographer` 回调 | +8.578 |

这两个实际产出帧的 VSync 起点相隔 16.700 ms。前一帧 UI 为 4.244 ms。
上一拍的回调到达已经偏晚，剩给当前帧、帧后工作及原生请求传递的时间少于一个刷新周期。
这里的 UI 指标在提交场景时结束，因此不包含完整的帧后耗时。

11 个既有 120 Hz Release 长按窗口含 975 个大于 1.5 个刷新周期的产帧间隔，其中
18 个落在同一段命令动画内。18 个案例都能对齐首尾系统唤醒点、中间系统脉冲、
Flutter 的请求和 SurfaceFlinger binder 的唤醒来源。系统分发间隔约 8.35 ms，
中间一拍没有阅读器的原生回调。Dart 在中间分发开始前 1.005–7.694 ms 已经请求下一帧，
可归属的原生请求在分发开始后 0.008–1.456 ms 才进入 SurfaceFlinger。
14 次连 Dart 帧处理结束都晚于该分发点。前帧 UI 为 1.129–7.538 ms，
Raster 为 1.000–2.376 ms。逐项证据见 [脱敏数据](results/vsync-dispatch.json)。

这个对齐用的是 Android 的单调时钟和厂商 Trace 中的 app 唤醒时间。binder 归属来自
`sched_waking` 记录的阅读器主线程，不是给每次 JNI 调用赋予了独立 ID。零点是系统
分发开始的时间，和 binder 操作成功的精确截止时刻可能有少量差异。

## 为什么调整预加载会影响节奏

Next 67be06fc 的同步路径在 `animateToPage`、`jumpToPage` 和滚动位置回调中调用
`_preparePage → cache → ReaderPrecache.replace`。目标或方向变了，去重通过后会在
该调用栈构造图片 Provider、更新窗口、取消和补位。原生解码可以异步执行，
这些管理工作仍会占用主线程。其中滚动回调发生在 ticker 更新位置的调用栈内，
同步工作返回后 ticker 才能登记下一帧。
[Flutter ticker 源码](https://github.com/flutter/flutter/blob/ff37bef603469fb030f2b72995ab929ccfc227f0/packages/flutter/lib/src/scheduler/ticker.dart#L269-L301)

Prime 只在预定的帧后回调里处理邻页窗口，分页也通过同一套 PageView ticker。
当前试用修复在翻页意图出现时登记目标，并把预加载窗口的实际计算和提交留在帧后。
这兼顾下一页的解码提前量与输入／滚动调用栈的负担。帧后回调依然占主线程，
仍会影响 Flutter 引擎何时真正向系统订阅下一拍。引擎的 `Animator::RequestFrame` 会把
`AwaitVSync` 排到 UI 任务队列，Dart 接受请求和 Android 收到订阅之间因此有可变延迟。
[Flutter Animator 源码](https://github.com/flutter/flutter/blob/ff37bef603469fb030f2b72995ab929ccfc227f0/engine/src/flutter/shell/common/animator.cc#L239-L281)

这 18 个错过订阅的间隔内，前帧 build 开始到后一帧 build 开始均无预加载窗口重排。
因此可以确认漏拍发生在下一帧订阅交接，也能解释老同步路径为何可能放大压力。
还无法把历史日志中 16.7 ms 的中位数全部归给预加载，或认定上述 18 次都由同一段
应用代码耗时造成。旧 67be06fc 还有一轮零读图、零解码的缓存往返，最长 25.062 ms。
其间 SurfaceFlinger 仍约每 8.35 ms 分发，阅读器主线程出现超过 11 ms 的不可中断等待。
该轮有离散按下／松开和 IME 处理，不能直接外推为实体长按的触发源。

## 可直接控制的部分

动画进行时，优先缩短当前帧到原生下一帧订阅之间的工作。对于阅读器，首先让命令、位置
回调只登记必要状态，把预加载窗口合并后执行，并控制该帧后回调的同步开销。优化是否有效，
应看同一段动画内的位置更新和逾期订阅次数。长按时，Prime 与当前 Next 都在下一次 repeat
打断活动动画并正位跳页，此后自然停留到再下一次按键。静止时图片依然可以显示在每次刷新上，
无需为这段停留主动提交新画面。

真实章节的提前预加载解决了首显等待，动画内 P95 仍约 8.37 ms。部分静止帧增加，且
真实章节 CPU 结果尚不稳定。因此试用结论仅覆盖首显和已定位的调度机制。
[预加载前后对照](precache-lead.md)

## 使用已有 Trace 复算

需要含 `frameRequest`、`frameEnd` 的独立包 `capture.json` 和同轮 `trace.pftrace`。
脚本用 `animate → jump／匹配完成` 确定区间，不跨越静止和动画交接。缺少原生时间线字段
或进程归属证据的间隔标记为未知，不能计入已定位的订阅延迟。输出不包含图片、设备标识或
绝对时间戳，也不尝试计算屏幕掉帧率。

```powershell
python benchmark/reader/analyze_vsync_dispatch.py benchmark/reader/raw/pclead-main-hold-reverse-before-1 --processor D:/.tool/codex-temp/reader-adb-perf/trace_processor_shell.exe --out benchmark/reader/raw/vsync-dispatch.json
```
