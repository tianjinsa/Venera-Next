# [Reader]: 跨章瀑布流在章节和页码未变时反复通知阅读外壳

<!-- feedback-id: U05a; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 02-reader-performance.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=02-reader-performance.yaml)

### 问题类型 / Issue type

阅读卡顿、慢加载或内存异常 / Reader performance

### 应用版本 / App version

源码对照：CyrilPeng/Venera-Next main@482810df369d126e4011be31d64408e33aede76f（版本元数据 1.18.4-rc.1+250）。组件复现运行于 fork 对应实现，不冒称官方安装包整体验证。

### 平台 / Platform

其他（请说明） / Other (please specify)：源码层核对；最小组件验证为 Linux 云端，不能据此声明各发行平台均实测。

### 设备与系统 / Device and OS

组件环境为 Linux、仓库锁定 Flutter 3.41.4；本项原版设备型号、系统/刷新率未单独采集。

### 复现步骤 / Steps to reproduce

1. 使用已缓存的普通本地图片，选择跨章瀑布流。
2. 在一张足够长的页面内缓慢滚动，保持同章同页。
3. 统计 `onPositionChanged` 中向外壳发送的 `onUpdate`，比较普通连续模式。

### 预期行为 / Expected behavior

同章节同页只处理视口、预取等必要工作；位置真正变化时才通知外壳，保留跨章选择、自动阅读与进度保存。

### 实际行为 / Actual behavior

跨章分支每次位置检查均 `_setReaderLocation(imageRef)` 并 `widget.onUpdate()`；普通连续分支会先比较页码。反复通知路径已由上游源码确认，但不能据此认定它是全部设备卡顿的唯一原因。

### 阅读环境 / Reading context

跨章瀑布流，本地普通已缓存 PNG/JPEG 即可，不需要特定作品或源；原设备刷新率/图片尺寸未记录，本报告没有设备帧率结论。

### 诊断提供方式 / Diagnostic source

无法取得（需说明原因并提供替代证据） / Unavailable (explain and provide alternatives)

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/reader/continuous_view.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/continuous_view.dart#L554)

### 日志无法取得的原因 / Why diagnostics are unavailable

当前排查在云端，没有连接原设备的原版阅读会话，无法从该会话导出手动阅读诊断；没有拿 Prime 的旧报告或其他用户报告冒充本项诊断。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/reader/continuous_owner_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/continuous_owner_test.dart)、[test/features/reader/reader_exit_integration_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/reader_exit_integration_test.dart)

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

#125 当前 closed 且仍带 investigating 标签，不能仅凭症状相似认为本路径解决了其全部问题。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
