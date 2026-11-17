# #178 真机分页性能实验记录

当前进展（2026-11-17）：动画交接、隐藏工具栏通知、视口发布、同章节导航范围和章节收藏
状态缓存已分阶段保留。实体键已校准，12 个 120 Hz／192 MiB 的单方向主要对照窗口完成；
长按页数与 CPU 已接近 Prime，快速触摸仍单独验证手势解析热点。最终版本的实体体验复核
和未覆盖功能仍需如实记录。下文按轮次保留当时判断，不将早期“待校准”视为当前状态。

环境、源码与构建约束见 [environment.md](environment.md)，执行方式见 [README.md](README.md)。
所有原始采样与大型文件在忽略目录 `raw/`、`artifacts/`；没有上传或自动提交。

## 输入校准

- Android `input keyevent --duration 8000` 在两版均只有 DOWN/repeat 两个原生事件，
  `repeatCount=[0,1]`，间隔约 300 ms，不能作为实体长按。
- 实体长按后来已在用户配合下校准：271 个 DOWN、同一 downTime、连续 repeatCount，
  持续约 19.78 Hz。回放前 8 秒的 152 个 DOWN，保留真实事件偏移，详见后续校准记录。
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

### 第三轮：同一视口的重复发布

保留范围很小的视口通知合并：绑定仍立即更新；帧末仅发布最终所有者变化。
真实替换、卸载、首个挂载仍通知，晚到旧视口卸载不能清除当前所有者，dispose 后不发布。
自动模式／真实 Gallery／连续视图定向共 59 项通过，相关 Dart 分析通过。

| 场景 | 修改前 | 修改后 | Prime |
|---|---:|---:|---:|
| 校准长按 r1 UI P95 | 4.057 ms | 4.668 ms | 4.055 ms |
| 校准长按 r2 UI P95 | 4.556 ms | 4.470 ms | 4.285 ms |
| 校准长按 r1 CPU time | 6990 ms | 6793 ms | 5692 ms |
| 校准长按 r2 CPU time | 7478 ms | 6937 ms | 5134 ms |
| 缓存按键 UI P95 | 3.986 ms | 4.320／4.249 ms | 3.651 ms（前轮） |
| 缓存按键 CPU time | 2344 ms | 2046／2028 ms | 1875 ms（前轮） |

校准长按各轮均 152 个事件、77 次选页，120 Hz／192 MiB；两轮倒换前后顺序。
修改后 UI 总执行时间约 913–931 ms，修改前 1120–1165 ms，≥2 ms 帧约 270→156；
缓存窗口约 719→554–571 ms、187→100 帧。总工作减少，但 UI P95 没有改善，
不能写成“长尾已修复”。保留依据是稳定减少重复工作及缓存场景约 13% 的 CPU time。
各轮 PSS 有波动，结束约 132–157 MiB，没有增加缓存预算；Next 仍落后 Prime，
下一轮只检查按键导航是否需要重建未改变的整个阅读内容。完整统计见
[results/viewport-publication.json](results/viewport-publication.json)。

修改后的 Profile 有三轮因实际预算未达到 192 MiB 在输入前被校验拦截，均无有效对照。
后续允许记录实际预算的 Profile 仅作事件顺序诊断，不把它的耗时与 192 MiB Release
混比。缓存策略仍未改变。

实体键校准 `next-physical-volume-calibration-r3` 完成：271 个连续 DOWN、同一 downTime，
原生／Dart 数量一致，持续重复约 19.78 Hz；首个 repeat 的 eventTime 相隔 401 ms。
原计划按住 8 秒，但实际首末 eventTime 相隔约 14 秒，因此只使用实际记录计算频率，
不将提示时长当作持键时长。之前启动 ACK 超时及零输入窗口均排除。

自动输入截取该实体记录前 8 秒的 152 个 DOWN，保留各次 eventTime 偏移、连续
repeatCount 和同一 downTime。Next 与 Prime 均验证完整原生序列、Dart 接收和
注入时间一致，首键原生投递约 161–163 ms；通道接收 P95 分别 .429／.776 ms。
这组未见 Next 通道积压，不支持将 MethodChannel 本身归为根因。两版均选页 77 次，
Next／Prime UI P95 为 4.057／4.055 ms，CPU time 6990／5692 ms；Next 图片入口
152 次、Prime 76 次，是否取消后重读需进一步记录，不能当作已完成两倍解码的证据。
原生探针未记录实体 UP，回放验证范围限于阅读器消费的 DOWN 链路。

`next-profile-viewport-cached-key-r1` 完整保存 Dart／GC Timeline，避免高密度 Embedder
流覆盖早期窗口。100 次离散键、50 次选页、零图片未命中期间，出现 200 次同一视口
卸载／挂载与 250 次 shellUpdate，其中 200 次来自绑定回调。ReaderImagesHost 每次
build 更换闭包，Gallery.didUpdateWidget 交接同一对象，ReaderState 再注册两个帧后
外壳刷新。这是正在进行的单变量实验，尚不能仅由次数判定性能收益。

该 Profile 有 200 个 UI ≥2 ms 帧；Perfetto 完整覆盖 UI 区间，Running P95 4.303 ms、
Runnable P95 .023 ms。CPU 样本主要落在框架 build／layout 和按钮动画，支持继续检查
同步 UI 工作。窗口内记录到 8 次 CollectNewGeneration，区间合计 24.957 ms，不能将
并发 Scavenge 工作线程时间再重复相加，也不把 Profile 的 GC 次数用于 Release 验收。

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


## 第四轮：同章节导航保留内容子树（2026-11-17）

对照与实验的数据、源码路径见 [Prime 渲染流程核对](prime-render-flow.md) 和
[完整统计](results/navigation-scope.json)。两轮各 100 次离散键／50 次选页、零读取解码、
120 Hz／192 MiB。UI P95 4.991→4.560 ms、4.614→4.008 ms；Prime 4.325／4.003 ms。
CPU time 大致持平，缓存驻留完全相同；不将 build 100→0 单独当作性能收益。
保留该导航范围修改；正常触摸、布局、章节和连续阅读仍走各自原路径。

r1 实验仍有一帧 10.447 ms，Perfetto 对齐后 Running 6.827 ms、Runnable .828 ms、
睡眠 2.792 ms，未归因具体 Dart 调用或 GC。r1/r2 的 CPU 频率不同，不跨轮拼接比较。
早期约 40°C 的数据和自动预算不足 192 MiB 的拦截窗口均排除主对照；不足预算不等于
32 MiB 压力降级。长按最终验收仍未完成。

新增 cached-budget-headroom 仅用于相同五张已解码驻留的隔离实验，校验上下限和零新载入，
从不修改预算；本轮六个有效窗口实际均为 192 MiB。控制器／自动模式 61 项、真实阅读器
六种方向／单双页与缓存压力共 8 项、相关 Dart 分析通过。


## 第五轮：章节收藏状态复用（2026-11-17）

独立于分页导航范围的修改。为测试漫画固定写入 1,000 条生成收藏（10 章），仍使用同一批
本地图片。原实现每次当前页查询调用 repository.find，读取／解析整部漫画。Release 的
50 次查询同步墙钟中位数约 1.29 ms、P95 约 1.44–1.54 ms。Profile 的有效窗口 1,220 个
CPU 样本中有 63 个位于 find 链路，其中 51 个包含 imageFavoritesComicFromRow；包含关系
不能相加。这证明重复读取／解析存在，不证明它独自造成此前外部记录的 12 ms UI P95。

修改只保留当前章节页码集合，连接、来源、漫画和章节身份均隔离；读取仍经原准入队列。
原生同步行更新只清缓存，不在 SQLite 内启动查询。连接重开、显式外部导入通知、收藏修改
和 dispose 均处理。移除查询转圈，未知状态仍禁用误操作，实际写入保留反馈。

| 指标 | 修改前 r2 / r3 / r4 | 修改后 r1 / r2 |
|---|---|---|
| 状态请求／SQL | 50 / 50（各轮） | 50 / 0（各轮） |
| CPU time | 2174 / 2214 / 2169 ms | 2081 / 2067 ms |
| UI P95 | 4.067 / 3.872 / 4.003 ms | 3.836 / 3.797 ms |
| UI P99 | 4.504 / 4.328 / 4.674 ms | 4.153 / 4.141 ms |

顺序为前、前、后、后、前，均为 100 个完整事件／50 次实际选页、五张解码驻留／120 MiB，
192 MiB 上限、零新增图片读解码、120 Hz。两组主要运行频率约 2.16–2.23 GHz，不靠更高
频率或预算换取结果。完整温度、PSS／RSS、Raster 和调度统计见
[收藏实验数据](results/favorite-status-cache.json)。保留小幅且稳定的收益，继续主线长按验收。

最初 r1 被五图驻留隔离校验拒绝（实际六张），原始记录保留并排除；后续使用默认严格
192 MiB 流程，分析脚本额外核验所有有效轮次前后驻留完全相同，未修改缓存策略。
相关 49 项通过，新增 9 项修正测试夹具初始化后通过，Dart 分析通过。


收藏修改后的 Profile 同样保存完整 CPU／GC Timeline：50 次状态请求、0 次 SQL，
_isCollected 链路仅 2 个 CPU 样本，不再出现 find／收藏 JSON 解析样本；对照为 63 个，
其中解析 51 个。CollectNewGeneration 事件对照 14 次、修改后 10 次，仅作 Profile
诊断，不把工作线程 Scavenge 重复相加，也不据此推算 Release GC 或功耗。
最后将六个相关测试文件一起复测，58 项全部通过。

## 第六轮：手势有效性检查只解析一次实时设置（2026-11-17）

`createGestureRequest.targetCurrent` 原先连续四次访问 `preferences`、两次访问
`pageLayout`，重复执行同一同步校验所需的设置归一化。早期 CPU Profile 已定位该调用链；
本轮只把每次校验内的读取存为局部变量，结构／内容／章节／视口／设置有效性检查仍在。
没有跨回调保留设置快照。新增真实 Reader 回归确认四项设置不经 build 直接修改时，
旧请求立即失效，恢复设置重新有效，翻页后旧请求失效。

Release 顺序前—后—后—前，均 20 次同向拖动、160→179、18 次在上段滚动中重新按下。
拖动 80 ms，UP 后间隔 125 ms，实际 DOWN 周期约 205 ms，不能与早期 125 ms 的
DOWN 周期混淆。虽以自然预算诊断方式采样，四轮实际预算前后都严格为 192 MiB，
驻留均从四张／96 MiB 到八张／192 MiB，sourceLoad／imageMiss 均 19，完整输入无遗漏。

| 指标 | 前 1 | 后 2 | 后 3 | 前 4 |
|---|---:|---:|---:|---:|
| UI P95 ms | 1.092 | .963 | 1.087 | 1.191 |
| UI P99 ms | 3.001 | 2.470 | 3.288 | 3.387 |
| UI Max ms | 3.332 | 3.115 | 3.739 | 3.658 |
| 进程 CPU time ms | 2590 | 2595 | 2890 | 2992 |
| UI／平台线程 Running ms | 1082 | 982 | 1192 | 1239 |
| 结束 dumpsys PSS KiB | 165291 | 167193 | 163239 | 170461 |

相邻配对的 UI P95 下降约 12% 和 9%；CPU time 第一对大致持平，第二对下降约 3%，
不能声称总 CPU 稳定大降。电池温度 37.5→37.8°C；线程运行加权频率分别约
2.188／1.623／1.859／1.857 GHz，保留频率干扰，不跨窗口直接推算周期或功耗。
缓存／内存没有观察到持续增加。Max 并非每轮更优。具体分布、松手后阶段与调度证据见
[Release 统计](results/gesture-settings.json)。

另有同参数 Profile 前后各一轮，均 20 DOWN、160→179、192 MiB。有效窗口 CPU 样本
1113／1232；targetCurrent 包含样本 46→38、preferences 17→10、ReaderSettings.resolve
19→9。采样统计存在误差、包含栈重叠，不能求和为耗时。CollectNewGeneration 均 3 次，
对应 Scavenge 工作线程标记均 6 个，不重复累计为 9 次 GC，也不用于 Release 的 GC 结论。
原始 CPU／Timeline 在本地 `gesture-settings-profile-{before,after}-vm`；摘要见
[Profile 统计](results/gesture-settings-profile.json)。

保留这项小改动。新增实时设置真实 Reader 用例 1 项、三个手势相关文件 30 项及相关
Dart 分析通过；没有把局部收益归为长按全部根因。预加载仍按 Next 原目标准备策略执行。
