# #178 真机分页性能实验记录

状态：动画交接单变量实验已有设备收益，UI 长尾仍需继续优化；**尚未完成实体长按验收，也未达到最终验收目标**。

环境、源码与构建约束见 [environment.md](environment.md)，执行方式见 [README.md](README.md)。
所有原始采样与大型文件在忽略目录 `raw/`、`artifacts/`；没有上传或自动提交。

## 输入校准

- Android `input keyevent --duration 8000` 在两版均只有 DOWN/repeat 两个原生事件，
  `repeatCount=[0,1]`，间隔约 300 ms，不能作为实体长按。
- 实体长按已向用户请求校准；用户选择稍后进行，未擅自启动。
- 快速离散音量键是独立场景：单次 DOWN/UP 对、请求间隔 50 ms，实测中位间隔约
  53 ms。以下数值只适用于该场景，不能替代实体长按验收。
- 触摸点按过快会触发正常双击缩放；没有翻页的点按轮次不计作分页性能证据。

## 首轮 Release：100 次快速离散音量减键

两版均为 LTR、单页、512 张固定本地大图、120 Hz、192 MiB、相同起始页、
新进程及相同预热。100 个原生事件全部送达 Dart。采样名为
`prime-release-keysequence-r1`、`next-release-keysequence-r1`。

| 指标 | Prime | Next 修改前 |
|---|---:|---:|
| 实际前进页数 | 50 | 34 |
| 原生事件间隔 P50 | 53.246 ms | 52.942 ms |
| 原生到 Dart 接收 P95 | 1.032 ms | 0.241 ms |
| UI P50 / P95 / P99 / Max | 0.362 / 3.726 / 4.150 / 4.519 ms | 0.652 / 3.943 / 4.774 / 5.699 ms |
| Raster P95 | 1.696 ms | 1.748 ms |
| 产出帧数（不是呈现 FPS） | 409 | 656 |
| 动画 / 跳页调用 | 50 / 50 | 100 / 0 |
| 上段动画未完成时的新请求 | 50 | 99 |
| 连续请求重复同一目标 | 50 | 66 |
| 被替代动画的迟到完成 | 50 | 99 |
| 外壳 update 次数 | 100 | 101 |
| cache 调用 | 50 | 269 |
| Next 实际预取窗口替换 | — | 268 |
| 12 秒窗口内进程 CPU time | 3338 ms | 5909 ms |
| 结束 RSS | 202.4 MiB | 225.5 MiB |
| 结束图片缓存 | 192 MiB | 192 MiB |

这一轮支持“Next 在快速请求时不断替代动画、页面推进更少且 CPU 更多”的实验假设。
MethodChannel 在该轮没有表现为输入积压；通知次数也没有数量级差异。
仍需重复、反向、最小修改后的对照及实体长按确认，不能据一轮宣称修复成功。

## 第一轮修改：动画期间的新命令通过跳页交接

只在 `ReaderController.toPage` 启动动画前检查已有 `pendingPage`。空闲时保留正常
200 ms 动画；动画未完成的新合法命令立即交给原跳页路径，不丢弃事件。旧动画的
迟到完成仍由已有 generation 门禁隔离。实际视觉页的 EInk 刷新判断使用
`previousActivePage`，防止逻辑页先提交后吞掉视觉页变化。

设备上已测的 `next-handoff-release-keysequence-r1` / `reverse-r2` 只含控制器交接
修改；视觉刷新修正另有真实 PageView 回归，待下一版设备复测。两轮采样与原基线
使用相同观察器和设置。可审查的数值及原始文件／APK 摘要见
[results/handoff-release.json](results/handoff-release.json)。

| 指标（正向 100 次快速离散键） | Prime | Next 前 | Next 交接修改 |
|---|---:|---:|---:|
| 前进页数 | 50 | 34 | 50 |
| UI P50 / P95 / P99 / Max (ms) | .362 / 3.726 / 4.150 / 4.519 | .652 / 3.943 / 4.774 / 5.699 | .822 / 4.050 / 5.113 / 6.333 |
| Raster P95 (ms) | 1.696 | 1.748 | 1.768 |
| UI 超 8.33 ms | 0% | 0% | 0% |
| 动画／跳页 | 50 / 50 | 100 / 0 | 50 / 50 |
| update／预取窗口替换 | 100 / — | 101 / 268 | 100 / 200 |
| 进程 CPU time（12 秒） | 3338 ms | 5909 ms | 4710 ms |
| 结束 PSS / RSS | 139.7 / 202.4 MiB | 155.2 / 225.5 MiB | 151.8 / 224.0 MiB |
| 结束图片缓存 | 192 MiB | 192 MiB | 192 MiB |

反向两轮均从 300 到 250：Prime UI P95 3.770 ms、CPU 3306 ms；Next 交接修改
4.047 ms、4544 ms。原生中位间隔分别约 53.23 / 53.44 ms，均接收完整 100 个事件。
修改前 Next 的反向严格基线尚缺，不能把这两轮写成完整的反向前后对照。

保留交接修改：正向推进页数增加约 47%，CPU time 减少约 20%，未增加缓存预算。
**UI P95 没有改善，CPU 仍比 Prime 高约 41%**，所以交接异常只是已确认的一部分
回归；继续调查真实拖动打断松手动画、重复预取和 UI 热点，不宣称解决全部卡顿。
这一组固定图片没有复现用户原先 8.33 ms 以上的 UI 长尾。

功能验证：控制器、音量控制器／通道、真实 Gallery 连续性共 53 项通过，含正反向
100 连续命令、迟到完成、LTR／RTL／纵向和单／双页交接；相关 Dart 分析通过。
额外手势／预取／压力回归 35 项通过。退出集成 184 项通过、8 项失败；对未修改
`97217db9` 的独立源码导出复测也是同名 184 通过、8 失败（Windows 文件占用及
保存提示／时序断言），保留两份日志，不将此轮写成退出回归全通过。

## 连续触摸测试的时序约束

用户澄清实际操作为：**上一段松手动画尚未结束便开始下一次拖动**。
自动输入次数或短间隔本身不能证明覆盖该场景。下一轮在原始 PointerDataPacket
进入 GestureBinding 前记录 PageController 的页位置和 `isScrolling`；以单指
新 DOWN 时前一段仍滚动的次数核验，另计多指缩放，不用 pendingPage 代替触摸动画状态。
同时对两版记录图片缓存未命中与源读取入口次数，避免由 cache() 调用数直接推断解码量。

## 固定触摸序列复现与 UI 帧定位

两版使用相同的 shell 注入器：每次 80 ms、4 ms 路径采样、相邻 DOWN 间隔
125 ms，20 次拖动。两轮倒换顺序，均确认 20 个 DOWN、18 次在前段滚动中重新
拖动；实际原生 DOWN 中位间隔均约 125 ms。注入实际时间与最大迟到单独留存，
不假设 Dart 收到的 MOVE 数量相同。数据见
[results/fixed-touch-baseline.json](results/fixed-touch-baseline.json)。

| 轮次 | Prime UI P95 | Next 交接修复后 UI P95 | Prime / Next CPU time |
|---|---:|---:|---:|
| 固定快速拖动 r1 | .802 ms | 2.996 ms | 1973 / 1846 ms |
| 固定快速拖动 r2 | .801 ms | 3.219 ms | 1869 / 2077 ms |

Prime 两轮均前进 18 页，Next 分别 17／18 页，均有 17 个不同图片键未命中；
这组没有复现 UI 超 8.33 ms，却稳定重现了 Next 的 UI P95 差距。
Next 每轮 34／35 帧 UI ≥2 ms，Prime 均为 18 帧；其中松手后 UI P95 分别
2.795／2.996 ms 对 .662／.732 ms。

`analyze_frames.py` 对齐实际 buildStart／buildFinish 与 Perfetto：所有这些帧的
线程状态覆盖完整，Next ≥2 ms 帧的 Runnable P95 仅 .025／.108 ms，主要时间处于
Running，而非睡眠或调度等待。该结论限于这些窗口，不排除其他场景的调度问题。

另外的零解码命中对照 `next-observed-key-cached-r1` /
`prime-observed-key-cached-r1` 均完整接收 100 个快速离散键、实际选页 50 次，
`imageMiss=sourceLoad=0`；Next CPU 2348 ms、455 帧，Prime 1875 ms、399 帧。
Next 的 200 次窗口替换没有造成此轮重复读取／解码，不能由 cache() 计数直接归因。
固定往返拖动中 Next 仍有 1 次未命中，不列为完全缓存命中的严格对照；500 ms
间隔的普通拖动仍有部分 Prime 动画被下一次拖动打断，后续用更长间隔另验。

Widget build Profile `next-widget-profile-fast-r1-vm` 与 Prime 对照表明：选页后
Next 阅读外壳在相邻两帧重建，连带隐藏底栏及多个 Material 按钮；Prime 接近每页
一次。高密度 Widget Timeline 的环形缓冲只保留了后段窗口，分析仅针对有效窗口，
不把其含额外标记的耗时用于性能验收。

对应路径是 `ReaderScaffold.buildBottom` 绑定当前页收藏查询，
`ReaderImageFavoriteController._read` 完成后调用 `onChanged`，再刷新整个外壳。
正在进行的下一项单变量实验仅限制隐藏菜单的完成通知重建；保留状态读取供快捷
收藏，保留失效通知重新绑定，以及菜单打开后的实时结果。尚待 Release 对照决定保留。

## 第二轮修改：收藏结果不重建隐藏外壳

保留上述单变量修改。`ReaderScaffold` 的收藏 `onChanged` 仅在菜单可见或状态失效
需重新绑定时更新外壳。后台查询仍照常完成，供手势快捷收藏使用；没有改读写队列、
任务所有权或缓存。功能测试直接验证隐藏控件保持原 Widget、关闭菜单仍可快捷收藏、
失效时重新查询，以及菜单可见时新结果显示。该回归在未修改源码上失败，修改后通过；
与既有外壳／收藏控制器／收藏手势共 25 项通过，Dart 分析通过。

| 同为 20 次固定快速拖动 | 仅交接修复，复测 r3 | 加上通知修复 r2 | 加上通知修复 r3 |
|---|---:|---:|---:|
| 实际选页次数 | 17 | 17 | 18 |
| UI P95 | 2.929 ms | 1.224 ms | 1.142 ms |
| 松手后 UI P95 | 2.825 ms | .542 ms | 0.941 ms |
| UI ≥2 ms 帧 | 35 | 17 | 18 |
| 进程 CPU time | 2022 ms | 1905 ms | 1931 ms |
| 结束 PSS | 151.9 MiB | 149.6 MiB | 159.6 MiB |
| 电池温度前／后 | 35.4 / 35.4°C | 35.4 / 35.4°C | 35.4 / 35.4°C |

两轮修改后均核实 20 个 DOWN、18 次打断上一段滚动，17 个图片键未命中，120 Hz、
192 MiB。对照与修改后的 PSS／RSS 有波动，没有增加预算或新增长期资源；不同轮次
CPU 分布重叠，不宣称稳定的整体 CPU 增益。图片完全命中的往返触摸也复现了
每选页约两帧到一帧的变化，保留实际选页数不同的限制，不把总 CPU 差异都归为收益。

这一修改**未解决缓存音量键场景**：100 个完整事件、50 次选页、零解码／读取下，
UI P95 3.810→3.844 ms，CPU 2348→2334 ms，产出帧 455→458，基本不变。
继续跟踪按键期间的外壳／视口通知，不把触摸改善当成长按验收。
完整数据与源补丁摘要见
[results/hidden-favorite-notification.json](results/hidden-favorite-notification.json)。

首次候选输入进程被系统终止（`Killed`），应用仍存活、无输入，保留失败文件并排除。
重试和后续原生固定序列正常；原因尚未归因，不把该失败算作应用性能回归或改善。

## Profile 与 Perfetto

- Next 已保存有效 CPU 样本与 Timeline：`next-profile-swipe-fast-r2-vm`、
  `next-profile-keysequence-r1-vm`。仅按对应 capture 的实际时间窗口分析样本，
  不把异步等待时间当执行时间。当前有效窗口未观察到 GC 时间线事件。
- 快速拖动中的设置归一化热点位于 `createGestureRequest.targetCurrent` →
  `ReaderState.preferences` → `ReaderSettings.resolve`，后续作为独立触摸热点调查。
- 调度 Trace 可见主线程／raster CPU 与 Runnable 等待。FrameTimeline 只记录到
  SurfaceFlinger 与 SystemUI，未包含测试应用 Surface，因而不报应用实际掉帧率。
- 初轮 Trace 有两个负时间戳记录被丢弃及空电源轨包，保留健康检查结果，不把它们
  隐瞒为完整 GPU／功耗证据；当前设备未提供可用电源轨数据。

## 已发现的测量干扰

Next 切后台返回后曾保持 32 MiB，预加载状态与 192 MiB 基线不同。
`next-swipe-normal-r1`、`next-swipe-fast-r1` 的 32 MiB 结果单独保留，
不能直接与 Prime 192 MiB 轮次比较。普通对照现在每轮重启独立测试进程、保留数据，
并强制核验预算和刷新率；缓存策略尚未修改。该问题按原任务 P2 独立处理。
