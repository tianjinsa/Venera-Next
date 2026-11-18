补充一下[上次说的真机调查](https://github.com/CyrilPeng/Venera-Next/issues/178#issuecomment-6920747961)。我用个人 Next 试用分支在原来的 Android 120 Hz 手机重新做了普通手动翻页和长按音量键连翻，两种场景的实际观感都已正常。长按连翻的 UI 耗时仍有差距，我会继续追踪这一部分。

### 1. 从 `6fc50094` 起保留的优化

| 改动 | 验证结果 | 代码 |
| --- | --- | --- |
| 同一帧内合并视口交接通知，只在最终视口所有者变化时刷新外壳 | 缓存按键的 CPU time 从 2344 ms 降至 2046／2028 ms。这个样本的 UI P95 从 3.986 ms 变为 4.320／4.249 ms | [`6fc50094`](https://github.com/tianjinsa/Venera-Next/commit/6fc5009489be912893d538567b856b8282fdea8d) |
| 同章节翻页只通知页码、外壳和输入有效性，保留 Gallery 内容 | 两轮零新增读图／解码的 UI P95 分别从 4.991、4.614 ms 降到 4.560、4.008 ms，进程 CPU 大致持平 | [`b76652d6`](https://github.com/tianjinsa/Venera-Next/commit/b76652d66651015858890ace74eb1b721682e0bf) |
| 复用当前章节的图片收藏页码集合，取消翻页状态查询时的转圈 | 50 次选页产生的 50 次重复 SQLite 查询与收藏解析降到 0，实测 CPU time 约降 5%。实际收藏写入、外部变更和数据库重开都会使缓存失效 | [`509fc5a1`](https://github.com/tianjinsa/Venera-Next/commit/509fc5a145700bed7ae969a5a6ab0bdf37b8f28f) |
| 手势有效性校验每次只解析一次实时设置和布局 | 两组同向连续拖动的 UI P95 分别约降 12% 和 9%。测试包含上一段回弹结束前再次拖动，进程 CPU 没有同幅下降 | [`67be06fc`](https://github.com/tianjinsa/Venera-Next/commit/67be06fc235c1498fe33b41d6fad660b12f94089) |

以上几项各有独立对照。音量键测试也先用实体键校准，再回放同一组 152 个事件。Prime 和 Next 均完整收到这组原生和 Dart 事件，本轮 Next 的输入时序未见明显积压。 [完整 ADB 实验记录](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/benchmark/reader/report.md)

### 2. 预加载与 VSync

仅等到 `onPageChanged` 再安排邻页预加载，会少掉一段解码提前量。试用版改为在翻页命令或滚动意图出现时登记目标，同帧合并后才真正构造并提交窗口。这样不用在每次位置回调里同步重建队列，也能在页面越过选页阈值前准备图片。普通触摸和单次按键保留原有动画，连续输入沿用现有的正位跳页交接。 [预加载提交 `cc52be63`](https://github.com/tianjinsa/Venera-Next/commit/cc52be63856a9d62a215aa84c8364c5813b05720)

同一批真实章节原图、120 Hz、Release、192 MiB、相同校准输入的对照中，第 1–50 页首次显示查询时已解码的图片由 **40/49 提高到 49/49**。首显等待 P95 从 **5.962 ms 降到 0.045／0.048 ms**，同一段动画内的产帧 VSync 间隔 P95 约为 **8.37 ms**。真实章节的 CPU 与温度尚缺更多重复对照。 [首显 A/B 及资源数据](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/benchmark/reader/precache-lead.md)

Perfetto 还定位到了一种动画内约 16.7 ms 的长间隔。在 11 个 Release 长按窗口中，有 18 个同动画间隔可以对齐到下一帧订阅。Dart 已在中间一拍开始前请求下一帧，原生订阅到达 SurfaceFlinger 时这一拍已经在分发。即使已产出的那帧 UI 在 8.33 ms 预算内，也可能错过下一拍。这些案例确认了订阅交接发生的位置，各案例具体占用主线程的工作仍需帧内栈来判断。 [VSync 对齐过程](https://github.com/tianjinsa/Venera-Next/blob/cc52be63856a9d62a215aa84c8364c5813b05720/benchmark/reader/vsync-dispatch.md)

### 3. 最新试用版复测

四份日志均来自 Android Release、约 120 Hz 横向分页。Prime 是我已经优化过的参考分支。各次采样的时长、起始缓存和操作节奏有差异，下面的值用于说明目前的表现。

| 指标 | Prime 手动 | Next 试用手动 | Prime 音量连翻 | Next 试用音量连翻 |
| --- | ---: | ---: | ---: | ---: |
| UI P95 | 5.157 ms | 1.120 ms | 1.018 ms | 5.338 ms |
| Raster P95 | 7.372 ms | 1.871 ms | 2.704 ms | 2.328 ms |
| UI 或 Raster 单项超过约 8.33 ms | 20/446 | 0/1108 | 14/1155 | 6/497 |

Next 这份音量连翻日志里，保留的回弹阶段产帧 VSync 间隔中位数为 8.353 ms，P95 为 8.378 ms，首显等待 P95 为 0.040 ms。连续翻页中图片已能及时显示，UI 仍有发生在跳页后和动画选页附近的慢帧。帧耗时与间隔基于 Flutter 产出的帧，实际屏幕呈现需要同条件的系统帧数据。

之后我又修了一处正位跳页的重复进度通知。两轮 Release Trace 每轮 75 次跳页，都能找到 75 次逻辑页已经更新后的同页回报。去重后的组件测试每次交接只发一次进度通知，实际选页、预加载和墨水屏刷新继续正常处理。合入后的帧耗时还要在手机上复测。

缓存这边同时修了压力后的恢复。收到系统通知时先立即降到最多 32 MiB 并暂停主动预解码，回前台仍按原冷却时间计算。冷却后如果新读数有足够余量，32 MiB 也能沿方向预解码下一张。组件测试已验证翻到前命中缓存且复用同一次读取，手机上的加载背景、首显等待和内存占用还需要单独测量。

我建议 #178 先保持开放。接下来重点是拿同一输入定位选页附近的 UI 长尾，并在手机上复核低预算试用体验。 [试用分支完整差异](https://github.com/tianjinsa/Venera-Next/compare/a5e5edf26725a9b83003506a6d6c91826ff46aa5...cc52be63856a9d62a215aa84c8364c5813b05720)
