# #178 分页预加载修复与真机复测

本轮以 `tianjinsa/Venera-Next` 的 `codex/agent-center-tab` / `a11a5834a426d26b6d6f3e6ba76e7d4521e3ab53` 为基线。上游只读参考 `v1.18.4-rc.2` / `c0c45979d453c2a8740c45f08e95997c90717629`，版本为 `1.18.4-rc.2+251`。没有整文件覆盖、合并 RC2 或改变应用版本。

## 已确认的路径与证据边界

1. 旧画廊只在帧后按导航当前页更新窗口。拖动已经开始、页面尚未越过中点时，不会推进到目标页的相邻窗口；RC2 会在构建传入页面时额外预取它的邻页。
2. 旧窗口只包含下一页和上一页。原下一页变成当前页时，其预加载任务被取消，并从 pending 图像缓存逐出。如果显示订阅尚未接上，原生读取／解码也可能被取消；如果已经接上，显示订阅仍然安全，但预加载的缓存完成监听被撤下。修复保留当前／目标页已启动的任务，直到完成或真正离开窗口。
3. 单个预解码名额覆盖读取、解码、帧后监听释放和实际原生清理。慢任务及过期任务清理会阻塞其他候选，方向改变也不会调整已排队任务的插入顺序。
4. `onPageChanged` 的整幅画廊 `setState` 会重新构造已挂载的 PhotoView 子树。原有页面键与控制器机制已经避免完全销毁图片，仍存在可消除的 Widget 重建。
5. 预加载和显示使用相等的 `ReaderImageProvider` 缓存键。诊断对象和当前显示页码不改变这个键；本轮没有发现缓存键失配。没有改动图片处理的页码契约、缩放尺寸或质量。

这些是可复现的调度、缓存交接和构建行为。**没有真机追踪证明它们单独解释用户报告的约 69 ms 显示等待，也没有证明所有 UI／光栅慢帧都来自图片。** 可用内存预算低于 64 MiB 或系统内存压力仍会按原策略停止主动预加载；新增诊断会明确记录许可及预算，便于区分该情况。

## 改动与资源边界

| 文件 | 行为与边界 |
| --- | --- |
| `lib/features/reader/gallery_view.dart` | 在依赖就绪、命令发出、逻辑页位置刚开始移动及页面选择时更新窗口；输入相同时不重复调度。正反向按逻辑页坐标处理，适用于 RTL／纵向。保留正在交接的解码；预取双向邻页及目标页，评论页保留回到末页的预热。长距离导航忽略控制器未接受的中间页。活动页通知只重置进入页的缩放，不重建整幅画廊。 |
| `lib/features/reader/image_precache.dart` | 分页显式使用两个名额，连续／瀑布流默认仍为一个；构造时在 Release 也硬限制为 1–2。最多四个已准入任务，未准入的多图候选只有 Provider 元数据，完成后自动补位。排队顺序跟随最新方向；重复窗口、已有缓存与进行中的任务复用。窗口内失败／不可缓存图片每轮只尝试一次，避免持续重解码。 |
| 同上，任务收尾 | 被取消的读取、codec 或原生帧仍占用名额，实际清理后才完成 `ImageWorkTask` 并补位；保持错误去重与原始堆栈。退出／内存压力取消本视图订阅与队列，其他显示消费者继续持有自己的流。 |
| `lib/foundation/reader_diagnostics.dart` | schema 2 保留原四列前缀并追加真实帧阶段时间；增加总耗时摘要、预加载排队／完成、窗口许可／预算和相对翻页事件。缓冲和导出长度仍有界，关闭采集时不读时钟。 |
| `image_cache_policy.dart`、`display_image_provider.dart`、`reader_image.dart`、`image_work.dart` | 已检查，保留现有预算、Provider 缓存键、显示转发、准入冻结、原生收尾与错误所有权实现。没有扩大缓存上限或删除一秒退出收缩。 |

解码缓存仍取可用内存的 1/16，限制 32–192 MiB，继续遵守 TV／继承的小预算；压力时最多 32 MiB 并停预加载。分页投机任务的瞬时读取／解码峰值可能比单任务增加一张图片，因此不能声称峰值内存完全不变。新增并发限于两个，成功后撤下监听并交由原 LRU 预算管理，不长期固定额外图像；真实 RSS／原生内存峰值仍需手机测量。

## 自动测试和可重复对照

新测试 `gallery_precache_test.dart` 在测试 ImageCache 中控制图片源完成时间，保留真实 Provider 键、原生解码生命周期、显示转发流、PhotoView 和 PageView 路径。

| 同一组检查 | 分支基线 | 修复实现 | RC2 参考实现 |
| --- | --- | --- | --- |
| 中点前启动下一窗口，LTR／RTL／纵向 | 0/3 通过 | 3/3 通过 | 未用该更早时机断言测试 RC2 |
| 目标转为当前页时保留 pending 缓存及任务，LTR／RTL／纵向 | 0/3 通过 | 3/3 通过 | 3/3 通过 |
| 选择时复用原 PhotoView Widget 和控制器，LTR／RTL／纵向 | 0/3 通过 | 3/3 通过 | 未作此断言 |

基线与 RC2 文件只导出到工作区临时目录供同组测试引用，未覆盖仓库代码。此表验证调度与对象复用，**不是 Android 帧耗时或显示等待的实测表**。

`image_precache_test.dart` 增加一个可控原生首帧，使用诊断注入时钟模拟 50 ms 等待：单名额时第二任务排队 50 ms；两个名额时第二任务在原任务完成前已开始，排队 0 ms。这只证明减少队首阻塞，未改变或加速解码器。

其他新增／扩展覆盖：两个活跃任务及四请求上限、重复窗口去重、多图窗口自动补位、快速换向的排队优先级、显示前的任务交接、取消后实际原生收尾才归还名额、两并发下内存压力保留可见消费者、实际手指拖动完成／取消、封面单页加双／三图布局、评论末页返回、长距离跳页、切章与退出无活动图片任务残留、可逆退出恢复预取、诊断批量帧时间与隐私／导出长度。

现有评论退出集成测试仍先断言立即返回，再等待后台保存错误。末页预取会增加真实文件／解码收尾，因此在模拟帧以外使用已有 `_pumpUntil` 等待真实 I/O；没有延长等待预算、跳过用例或放宽原有退出／错误断言。

本轮检查命令、计数与最终构建记录在下方补齐。环境最初的包解析缓存缺少当前分支已锁定的 `flutter_markdown_plus`；已执行 `flutter pub get --enforce-lockfile`，没有更新依赖版本或锁文件。

## 诊断 JSON 的对应关系

schema 2 的 `retainedFrameSamples.slowestColumns`：

```text
receivedAtUs, uiUs, rasterUs, totalSpanUs,
vsyncStartAtUs, buildStartAtUs, buildFinishAtUs,
rasterStartAtUs, rasterFinishAtUs
```

前四列与 schema 1 一致。后五列来自 `FrameTiming.timestampInMicroseconds`，减去采集开始的 `Timeline.now`。Flutter 原生引擎在 `DartVMInitializer` 中把 `fml::TimePoint` 设置为 `DartTimelineTicksSinceEpoch`，因此 Android 原生帧与图片／翻页事件使用同源单调时钟；不混用 wall time 或把回调接收时刻当作帧发生时刻。采集前已开始、随后批量送达的帧可为负值，仍计入原有帧摘要。

`uiUs` 是构建耗时，`rasterUs` 是光栅化耗时，`totalSpanUs` 是从 vsync 到光栅结束的跨度。超预算仍按 UI 或 raster 超过刷新预算判断，未用总跨度替换口径，未过滤真实慢帧。

- `precacheQueueWait`：准入后等待解码名额的经过时间。
- `precacheWait`：开始 resolve 到取得首帧的经过时间；取消／失败以 `success=false` 标记，不伪装成命中。
- `precacheWindow`：是否允许预加载、候选图像数、并发上限及当时缓存预算。
- `pageTurn`：`requested`／`selected`、相对方向与距离；不记录作品、章节标识或具体来源页 ID。
- `cacheLookup`／`displayWait` 与预加载阶段使用同一匿名图片编号。通过帧的真实构建／光栅区间分析重叠，而不是通过 `receivedAtUs` 的批次聚集推定周期性卡顿。

只记录数字、布尔值和固定枚举，不包含图片地址／缓存键、漫画标题／内容、脚本、账号或错误正文。报告仍只在内存中手动采集及复制，不自动上传。

## Android 复测

1. 安装本次准确提交对应的 **mobile / arm64-v8a Release APK**；保持原设备 120 Hz、同一漫画、预加载张数、单／多页布局和关闭自定义图片处理。版本号未变，应以构建清单的源码 SHA 区分包。
2. 分别采集正常正向、反向阅读，保持相近翻页频率；另采快速连续翻页、翻页中改变方向、半页拖动完成／取消、RTL、双／多图布局和章节／评论边界。每段单独开启诊断，避免混合场景掩盖 P95。
3. 比较 `displayWait` 中位数／P95、`precacheWait` 完成是否先于显示、排队时间、cacheLookup 的 pending／keepAlive 命中、重复读取／首次解码数，以及缓存最大预算／已用字节与进程内存峰值。
4. 同时比较 UI 和 raster 中位数／P95／最大值与超预算比例，继续按 120 Hz 约 8.33 ms 的既有阈值，不把异步图片等待当作 UI 阻塞。
5. 离开阅读器并重新进入，测试真实内存压力下可见图片保持、预加载停载及后台保存完成。不要为压低等待而修改缓存大小或禁用动画。

若仍有 #178：回传上述分段 schema 2 JSON、确切构建 SHA、预加载张数及布局，保留慢帧附近 `imageEvents`。若预加载已在显示前完成而 UI／raster 仍慢，需要同一操作的 Android Profile／Perfetto 时间线，定位主线程构建／布局／同步字节工作、GC 或光栅／纹理上传；图片完成时间重叠只能作为线索，不能单独判定因果。

## 本轮实际验证与构建

2026-11-15，在 Flutter 3.41.4 / Dart 3.11.1 的云端 Linux 环境：

- 最终有界定向回归：`flutter test --no-pub --concurrency=2 --reporter expanded`，显式选择 23 个阅读器／图片生命周期文件，**443 通过，23 按原有平台／条件跳过，0 失败**，用时约 2 分 11 秒。包含 `gallery_*`、`image_precache*`、cache policy、display／scroll-aware、gesture lifecycle、reader controller／exit／reading session、auto reading、diagnostics dialog，以及 foundation 的 diagnostics／ImageWork／ReaderImageProvider／provider release／base provider／shutdown；不是仓库全量结果。
- 修改直接涉及的核心子集五文件 **61 项通过**；评论退出失败路径修正真实 I/O 等待后单项通过，并已包含在最终 443 项通过中。
- `flutter analyze --no-pub`：全仓库静态分析 **No issues found**。
- `dart format --output=none --set-exit-if-changed`：本轮 Dart 文件无格式差异。
- `python3 .github/scripts/check_structure_imports.py`、`check_architecture_dependencies.py`、`release_version.py --check`、`git diff --check`：通过。锁定依赖解析通过，`pubspec.yaml`／`pubspec.lock` 未改动。
- 基线同组九项全部复现失败、修复通过；RC2 的三项交接对照通过。合成首帧实验验证单／双名额排队 50／0 ms，不能替代真机数据。

Android 构建将在本轮源码提交推送后通过现有 `build.yml` 派发，保留默认质量门禁；准确源码 SHA、运行链接和最终结果随后记录。没有 Android 真机帧率／显示等待结果。
