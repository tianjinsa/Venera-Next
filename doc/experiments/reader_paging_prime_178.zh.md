# #178：对照 Prime 减少分页渲染工作

本轮是 [预加载续修](reader_paged_preload_178.zh.md) 后的第二轮修复。Next 基线为 `16f54ee482b100853c47bfbab0ce14100d6b7a6e`；只读参考 `tianjinsa/venera-prime/codex/agent-center-tab` 的 `2e287566c6fad11b0085bbdf4a528e507021ec61`，以及其锁定的 PhotoView `a1255d1b5945aad4b7323303ec2ecdf0c90ffc4c`。只获取 Git 对象和相关文件快照，没有合并 Prime 或覆盖 Next 文件。应用版本与身份保持不变。

## 结论与证据边界

已确认 **Next 每次翻页产生额外的设置解析、隐藏表单／工具栏重建和隐藏控件动画**。它们在正常及 32 MiB 缓存下都存在；上一轮提前预加载不能消除这些 UI 工作。已针对这些实际路径修改代码。

不能据此断言已解释全部真机卡顿。用户提供的 192 MiB 样本显示 `displayWait` 中位数已到 0.019 ms，仍有 2.87% 超预算帧；最近 32 MiB 样本的正／反向显示等待为 64.480／57.723 ms，超预算为 4.38%／3.07%。这些样本的预算不同，不能把差异都归因于代码。旧 Prime 的流畅度反馈是真实回归线索，但目前没有同条件的数值报告，不虚构其 FPS 或性能提升比例。

## 逐项源码对照

| 路径 | Prime | Next 基线及本轮处理 |
| --- | --- | --- |
| 分页容器 | `PhotoViewGallery.builder` 内部同样使用 `PageView.builder` | 不能把容器名称作为根因；保留当前稳定页面键、PhotoView、图片流和控制器所有权 |
| 点击翻页动画 | 200 ms、`Curves.ease` | 相同；不改时长、手势速度或滚动物理参数 |
| 布局字段 | 按字段读取当前作用域 | `imagesPerPage`／封面单页等每次读取都构造整套 `ReaderSettings`，归一化全部字段。改为同一类型化 preference 的单字段读取，保留全局→设备→漫画优先级、非法值修复和 TV 单页约束；不引入容易过期的全局设置缓存 |
| 翻页外壳 | 原有自绘进度条没有值变化动画，亮度面板也较简单 | Next 的 Material Slider、收藏加载动画在菜单移出屏幕后仍可运行；隐藏亮度表单和标题工具栏每页重新构建。使用 `TickerMode` 停止隐藏控件自身 tick，缓存输入未变的面板、标题和动作 Widget；进度／页码仍实时更新 |
| 设置／功能变化 | 旧的耦合结构 | 保留 Next 的作用域、收藏查询、调光预览、自动阅读、语义与焦点。主题／语言／可访问性依赖、内容／ImageWork、动作状态变化使对应缓存失效；实时设置监听继续工作，不缓存存储结果 |
| PhotoView 本地补丁 | 旧 fork 基线 | Next 的尺寸监听克隆释放、控制器和旧手势清理是必要安全修复。`value` setter 已对相等变换去重，额外 no-op reset 判断无收益，核对后未保留；没有撤回生命周期补丁 |
| Provider／ImageWork | 较早的生命周期设计 | 未发现本轮缓存键失配证据，保留显示／预取共享结果、实际原生清理后归还名额和退出等待 |
| 缓存与预加载 | 可用内存的 1/16，32–192 MiB；低于 64 MiB／压力时停主动预取 | 同类约束继续保留；不扩大预算、不增加并发、不移除压力或退出定时器。上一轮分页两并发、四任务准入和双向窗口交接保留 |

隐藏控件仍保留状态，缓存每个外壳只持有固定数量的 Widget，没有新增解码图片持有者。菜单出入的 `AnimatedPositioned` 在 `TickerMode` 外，正常翻页动画也不在该禁用区域内。

## 本地对照测量

在真实 Reader 集成夹具中，先预热 12 张 100×150 本地 PNG，关闭菜单，使用相同的 18 次页选择序列 `2..10,9..1`。分别在 192 MiB 和真实调用 `handleMemoryPressure()` 后的 32 MiB 下运行。通过 `debugOnRebuildDirtyWidget` 计数；临时对设置工厂的调用计数在测量后移除。基线只临时恢复本分支自己的相关改动文件用于同组测量，结束后恢复修复；没有用 Prime 文件代替 Next。

| 18 次选择的工作量 | Next 基线，192／32 MiB | 本轮，192／32 MiB |
| --- | ---: | ---: |
| 整套 ReaderSettings 解析 | 468／468 | 90／90 |
| 全部 Widget build 调用 | 13,392／13,392 | 3,354／3,354 |
| 隐藏亮度面板 build | 18／18 | 0／0 |
| 标题栏 build | 18／18 | 0／0 |
| Slider build（含隐藏亮度滑块） | 54／54 | 18／18 |
| 最后一次 pump 后待处理 tick | 3／3 | 1／1；清理和稳定后为 0 |

剩余 Slider 是需要更新页码的进度条。剩余一次 tick 可能包含当前帧的合法工作，不能全部归为隐藏动画。该对照的宿主 Debug pump 计时包含测试框架开销，**不是 Android UI 帧耗时、GPU 耗时、图片解码基准或呈现 FPS**。100×150 夹具用于隔离构建工作，不能替代下面的大图设备测试。

`reader_exit_integration_test.dart` 新增两档预算回归，断言页面更新不重建隐藏面板和标题、隐藏进度条的 tick 被禁用，稳定后无残留动画；还原压力策略与缓存限制，避免污染其他用例。导出用例在选择新页后使用已有真实 I/O 轮询辅助方法等待 native decode，再执行 fake-time settle；保留翻页后仍保存原始字节的断言，不放宽超时。

## 32 MiB 从哪里来

Android 已锁定的 `flutter_memory_info 0.0.3` 返回 `ActivityManager.MemoryInfo.availMem`，单位为字节。预算公式未变：`clamp(availableBytes ~/ 16, 32 MiB, 192 MiB)`。32 MiB 可以来自可用内存偏低（约 512 MiB 及以下）、Android 压力通知，或继承上个会话的预算且本次查询无结果／失败。单看 `globalImageCache.maximumBytes=32 MiB` 不能确定来源。普通 TV 上限为 64 MiB，本身不等同于压力 32 MiB。

新诊断保留最近的固定枚举与数值：`readerCacheBudgetAtStart`／`readerCacheBudgetLatest` 包含 `reason`、`memoryQuery`、`availableBytes`（若取得）、`ceilingBytes`（若存在）、`limitBytes`、`pressureEvents`、`underPressure` 和 `precacheAllowed`。采集开始前发生的压力也可见；停止后的报告固定为停止时证据。采集中变动另有 `cacheBudget` 事件。失败只记录 `failed`，不记录平台异常正文。继承而查询失败时仍须承认上一预算原因未知。

32 MiB 下停止主动预取能够解释再次出现的图片异步等待，但不能单独解释动画掉帧：旧 Prime 同样有低于 64 MiB 的阈值。两档预算都减少了 UI 构建工作，低内存策略未被绕过。大图首次解码／纹理上传及总 RSS 的影响仍需真机记录。

## 帧节奏与诊断兼容性

继续使用 schema 2，原 `slowest` 九列、全局摘要和 UI 或 raster 超预算的判断不变，未过滤慢帧。追加全局 `uiOverBudget`／`rasterOverBudget` 便于分别定位。

新增 `scrollFrameSamples`：只在手动采集中监听最外层 PageView 通知，记录去重后的 `drag`／`settle`／`idle` 边界（最多 96 条），忽略嵌套评论滚动；关闭采集不读时钟、不更新 UI。使用真实 `vsyncStart` 排序，分别报告每段拖动和回弹中的 UI／raster 摘要、连续超预算**样本**长度、相邻产出帧的 vsync 间隔及最大的 12 个间隔。跨手势、空闲和阶段边界的间隔只从这项辅助统计排除，原有全局统计仍保留全部样本。截断数明确导出。

这些是已产出 Flutter 帧的时间，不是 SurfaceFlinger 最终呈现时间。通知边界也不是精确输入到显示延迟。不能用采样数÷总时长当作 FPS，不能用批量接收时间推测每秒真实卡顿；未移除任何一秒定时器。

## 设备性能脚本

新增 `integration_test/reader_performance_test.dart` 和 `test_driver/reader_performance_test.dart`，参考 Prime 原测试设计并适配 Next 的真实 Reader、FavoritesScope／HistoryScope、退出和数据队列。生成相同的 **32 张 2048×3072 PNG**，完整记录正反向、1200／3200／6200 ms 空闲后翻页、短拖动取消／换向、系统通道 `memoryPressure`、两档方向和四次重入。记录 RSS、缓存字节／限制、live／pending、活动图片源任务及分段诊断。

数据和库位于独立临时目录，不读取原有用户库；成功退出后断言无活动图片加载和 pending 缓存。正常阶段使用设备实际预算，**不会强行设置 192 MiB**；压力阶段通过系统消息模拟，不实际耗尽 RAM。若正常阶段本身是 32 MiB，报告保留该事实与原因，不能冒充正常大缓存对照。RSS 是进程占用，不等于所有原生／GPU内存，更不只包含 ImageCache。

在有 Android SDK、原生构建依赖和已连接手机的电脑执行：

```sh
flutter pub get --enforce-lockfile
flutter drive --profile --flavor mobile -d DEVICE_ID \
  --driver test_driver/reader_performance_test.dart \
  --target integration_test/reader_performance_test.dart
```

输出 `build/reader-paging/reader_performance.json`。RTL 加 `--dart-define=READER_RTL=true`；双／三页加 `--dart-define=READER_IMAGES_PER_PAGE=2` 或 `3`；显示时钟／电量加 `--dart-define=READER_STATUS_INFO=true` 单独采集。每次运行后先另存结果。保持手机实际 120 Hz、屏幕方向／尺寸、系统温度、手势脚本一致。SDK `watchPerformance` 附加报告沿用 Flutter 自己的统计；120 Hz 超预算比较以本应用诊断的 `displayRefreshHz`／`frameBudgetUs` 为准。

旧 Prime 可运行其原脚本 `--dart-define=READER_IDLE_PROBE=true` 对照相同尺寸、空闲间隔和压力响应；原脚本未单列正常／压力反向和取消手势，不能直接拿不等价阶段作数值 A/B。严格比较应在旧版测试脚本应用同一手势顺序、张数和设置，并记录它自己的准确构建 SHA，保持两套生产实现独立。

普通验收仍安装本轮准确 SHA 的 **mobile／arm64 Release APK**，在同一漫画分别记录正向、反向、快速／换向、半页取消、RTL、双／多页及章节／评论边界。先确认报告中的预算原因，再比较同预算下的 `displayWait`、UI／raster 长尾和连续慢样本。正常与压力结果分开；不要通过手动扩大预算或关闭动画达标。

## 尚有卡顿时的下一份证据

1. 回传本轮准确源码 SHA、分段 JSON、实际刷新率、布局与预算原因；标出更明显的是手指拖动还是松手后的回弹。
2. 在 Profile 下用 DevTools Performance 录相同 5–10 次翻页，检查慢 UI 帧的 build／layout／paint、GC、同步数据工作；脚本的 `Reader normal_forward` 等 TimelineTask 可用于定位阶段。必要时另开一次跟踪 Widget build／layout，跟踪开销不混入性能对比。
3. 若 Flutter UI 不慢但画面跳动，采集同一操作的 Android Perfetto（Android System Trace 的 Frame timeline、Graphics、View、Input、Scheduling 以及设备支持的 GPU 轨道）。结合应用和 SurfaceFlinger 的 FrameTimeline／实际呈现 deadline、主／光栅线程和输入事件判断纹理上传、合成或输入到呈现延迟。标记手指松开附近的具体帧，不从异步图片等待推断阻塞。

目前没有证据证明剩余问题是 GPU、某个一秒定时器、PageScrollPhysics 或某个 PhotoView 生命周期补丁；这些均保留为需要同一操作追踪的假设。

## 本轮验证

- 最终 32 个相关测试文件：`flutter test --no-pub --concurrency=2 --reporter expanded`，**498 通过、23 按原条件跳过、0 失败**，约 1 分 59 秒。覆盖预加载、压力、缓存复用、手势／旋转／多页、外壳、设置、PhotoView／ImageWork 与退出。不是仓库全量测试。
- 初次回归发现新手势用例的首个移动过大，已改为与现有用例一致的小步起拖；两个旧 Provider 用例仅等一次帧就假定原生解码完成，改用原有 `_frameUntil`，保留所有缓存／读取次数断言。修正子集 40 项通过，并包含在最终 498 项内。
- 结构、架构依赖、版本同步、依赖来源／本地许可证清单及 `git diff --check` 通过。初次 `flutter analyze --no-pub` 的问题已修改；按用户立即推送要求，不再启动本地验证，最终全仓静态分析由本次 Actions 门禁执行，尚不声明通过。
- 用户禁止云端编译构建之前尝试的 Android／Linux bundle 分别被缺少 Android SDK／clang++ 阻止，没有生成可安装包；用户发出限制后不再执行本地应用编译／打包。设备性能脚本未在手机上运行。
- 按用户最新要求提交推送后使用 `build.yml`，**`skip_tests=true`**，只选择 Android。不会额外启动全量测试工作流，也不轮询构建；Actions 尚未完成不能记为通过。

云端没有 Android 手机，不能声明手机帧率、实际呈现节奏、纹理上传或输入延迟已达标。

## Android Release 构建失败补修

用户回传 `d0db79cc` / [43713176724](https://github.com/tianjinsa/Venera-Next/actions/runs/43713176724) 的 Android job Java 编译失败。新增 `integration_test` 是开发依赖，Gradle 在 Release 正确排除它；但构建脚本的 `--no-pub` 让 Flutter 3.41.4 同时跳过 Release 注册文件的重新生成，前置 `pub get` 留下的注册文件仍引用该插件。这是构建路径回归，与本轮分页渲染修改无关。

补修只移除手机／TV Release 命令的 `--no-pub`，由 Flutter 自己重新生成正确的注册文件，保留工作流前置 `flutter pub get --enforce-lockfile`、性能测试、原生缓存和签名／产物门禁。不修改 SDK 或生成的 Java 文件，不将测试插件放进生产依赖。现有 Python 回归覆盖两种 flavor；云端不编译，推送后重新触发跳过测试的 Actions 构建，结果等待用户通知。

验证：`python3 -m unittest discover -s .github/scripts/tests -p test_ci_optimization.py -k AndroidBuildTests`，3 项通过；`git diff --check` 通过。未在云端编译 Android，实际构建交给 Actions。
