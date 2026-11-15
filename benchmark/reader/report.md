# #178 真机分页性能实验记录

状态：基线与单变量实验准备中，**尚未完成实体长按验收，也未确认最终根因**。

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
