原先明显影响阅读的分页停顿和连翻不连贯，在我这轮真机复测中已经解决。我用个人 Next 试用版在原来的 Android 120 Hz 手机上测了普通手动翻页和实体音量键长按，两种场景的实际观感都已恢复流畅。下面是可以直接适配到上游的改动。 [已验证的试用版 `cc52be63`](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/lib/features/reader/gallery_view.dart)

### 1. 把预加载移出页面构建，在翻页意图出现时排队

我核对了 PR #185 的 `348c4bdd`。`GalleryModeState._buildPhotoPage()` 的单图和多图分支仍会调用 `cache(index)`。构建相邻页时，这条路径可能同步创建 Provider、提交预加载，跟翻页抢 UI 线程。直接把触发点移到 `onPageChanged` 又会等到动画越过选页阈值，下一张图常来不及解码，所以会看到加载背景。 [上游 `_buildPhotoPage`](https://github.com/CyrilPeng/Venera-Next/blob/348c4bdddb6d2d432841a0355b7e1e9b30b775a0/lib/features/reader/gallery_view.dart#L371-L431)

1. 去掉 `_buildPhotoPage()` 中两处 `cache(index)`。在 `animateToPage()`、`toPage()` 和触摸滚动监听中调用 `_notePageRequest(target, direction)`，记录最新目标和方向。同一目标与方向重复上报时直接复用。
2. `_schedulePrecache()` 每帧只登记一个 `addPostFrameCallback`。回调才执行 `cache(navigation.state.pendingPage ?? requested)`。这样动画经过中间页时，预加载仍优先使用已接受的命令目标。实际 `onPageChanged` 用于校正窗口。
3. 窗口替换时优先准备目标和移动方向上的邻页，保留当前页、目标页已经开始的解码订阅。分页最多两个并行预解码、四个准入任务，取消后的原生清理仍占名额。上游可以参考试用版的 `ReaderImagePrecache.replace()` 和队列实现来适配。

[触摸意图和帧后调度](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/lib/features/reader/gallery_view.dart#L250-L327) · [动画和跳页入口](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/lib/features/reader/gallery_view.dart#L718-L746) · [窗口与保留策略](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/lib/features/reader/gallery_view.dart#L329-L403) · [预解码队列](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/lib/features/reader/image_precache.dart#L15-L126)

在同一批本地原图、Release、120 Hz、192 MiB 缓存上限和同一组校准音量键输入下，前 50 页首次查询时已解码的图片由 **40/49 提高到 49/49**，首显等待 P95 从 **5.962 ms 降到 0.045／0.048 ms**，同一段动画内的产帧 VSync 间隔 P95 约 **8.37 ms**。

Perfetto 也解释了为什么要控制这段同步工作。在 18 个同一动画内的长间隔里，Dart 已经请求下一帧，但实际原生订阅进入 SurfaceFlinger 时中间一拍已经开始分发。即使前一帧的 UI 耗时低于 8.33 ms，订阅晚到仍可能出现约 16.7 ms 的产帧间隔。帧后窗口也应只处理最新一份。 [首显真机对照](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/benchmark/reader/precache-lead.md) · [VSync 订阅时序](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/benchmark/reader/vsync-dispatch.md)

### 2. 选页时只更新活动图和阅读器外壳

PR #185 的 `PageView.onPageChanged` 末尾仍调用整个 Gallery 的 `setState()`。这会在翻页动画中重新走页面构建。我的改法是用 `ValueNotifier<int>` 发布实际活动页，让 `_GalleryPhotoPageState` 监听活动页，只在自己成为新活动页时重置缩放。实际选页依旧处理墨水屏和章节边界。 [上游选页回调](https://github.com/CyrilPeng/Venera-Next/blob/348c4bdddb6d2d432841a0355b7e1e9b30b775a0/lib/features/reader/gallery_view.dart#L319-L365) · [试用版选页](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/lib/features/reader/gallery_view.dart#L483-L538) · [活动页监听](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/lib/features/reader/gallery_view.dart#L930-L960)

同章节的分页命令和动画完成通知，从 `ReaderController.toPage()` 走 `onPageNavigationChanged`。在 `ReaderState._onPageNavigationChanged()` 更新输入有效性和外壳，并保留会话关闭检查、屏幕常亮和过期布局取消逻辑。章节、布局、设置或连续阅读依旧走原来的 `update()`。两轮零新增读图／解码对照的 UI P95 分别从 **4.991、4.614 ms 降到 4.560、4.008 ms**。 [控制器回调](https://github.com/tianjinsa/Venera-Next/blob/b76652d66651015858890ace74eb1b721682e0bf/lib/features/reader/reader_controller.dart#L259-L303) · [外壳更新实现](https://github.com/tianjinsa/Venera-Next/blob/b76652d66651015858890ace74eb1b721682e0bf/lib/features/reader/reader_page.dart#L888-L908)

这里还能顺手去掉一次重复进度通知。正位跳页已经设置了逻辑页，Gallery 收到同一页的回报，只在 `page != i` 时执行 `navigation.reportPage(i)`。后面的活动页、预加载和墨水屏通知照常执行。这个重复在两轮 Release Trace 中每轮出现 75 次，修复后的组件测试每次交接只更新一次进度。

PR #185 已实现上一段动画未结束时的新请求通过跳页交接，也已包含我从 `6fc50094` 做的同帧视口通知合并。移植时沿用这两处。 [现有动画交接](https://github.com/CyrilPeng/Venera-Next/blob/348c4bdddb6d2d432841a0355b7e1e9b30b775a0/lib/features/reader/reader_controller.dart#L254-L294) · [现有视口通知](https://github.com/CyrilPeng/Venera-Next/blob/348c4bdddb6d2d432841a0355b7e1e9b30b775a0/lib/features/reader/reader_page.dart#L203-L217)

### 3. 两个可独立移植的开销点

- 图片收藏在 `lib/features/history/image_favorites.dart` 的 `_isCollected()` 缓存当前章节页码集合。按数据库连接代次、来源、漫画和章节定位，收藏写入和外部变更使集合失效。底栏在 `bottom_actions.dart` 只对实际写入显示转圈。真机 50 次翻页的重复 SQLite 查询从 50 次降到 0。 [`509fc5a1` 与测试](https://github.com/tianjinsa/Venera-Next/commit/509fc5a145700bed7ae969a5a6ab0bdf37b8f28f)
- `ReaderState.createGestureRequest()` 内的 `targetCurrent()` 每次校验各取一次实时 `preferences` 和 `pageLayout`，然后比较所需字段。两组连续触摸拖动均包含动画未结束时再次拖动，UI P95 约下降 9–12%。 [`67be06fc` 的校验实现](https://github.com/tianjinsa/Venera-Next/blob/67be06fc235c1498fe33b41d6fad660b12f94089/lib/features/reader/reader_page.dart#L319-L377)

### 复测入口

建议先适配前两节，用同一本地章节在 Android Release 120 Hz 测普通触摸、动画未结束时再次拖动，以及实体音量键正反向长按。重点看下一页在首次显示查询前是否已解码、动画内 VSync 间隔和进程 CPU／内存。已有测试覆盖了 LTR、RTL、纵向分页、同帧多次导航和中间页。我的试用版连翻首显等待 P95 已到 0.040 ms，保留的回弹阶段 VSync P95 为 8.378 ms，连翻仍有少量较慢的 UI 帧。 [Gallery 回归用例](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/test/features/reader/gallery_precache_test.dart#L129-L216) · [固定输入真机实验](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/benchmark/reader/report.md)

低预算出现逐页黑底时，还可以独立处理 `ReaderImageCachePolicy.handleMemoryPressure()` 和 Gallery 缓存窗口。我的后续版本在压力到来时立即降到最多 32 MiB 并暂停主动预解码，冷却 30 秒后用前台新读数判断。仍处于 32 MiB 档且可用内存达到 640 MiB 时，沿移动方向预解码一张。这部分已验证组件缓存命中，手机上的内存峰值和首显收益仍待测。
