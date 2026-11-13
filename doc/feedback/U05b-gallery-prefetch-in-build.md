# [Reader]: 画廊在页面构建中重复执行同一位置的预取请求

<!-- feedback-id: U05b; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 02-reader-performance.yaml -->

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

1. 使用普通本地页面进入画廊阅读。
2. 保持内容、布局、当前页与预取数量不变，触发与图像内容无关的重建。
3. 统计 `_buildPhotoPage` 的 `cache(index)` 调用及实际重复工作。

### 预期行为 / Expected behavior

将预取移到帧后，按工作所有者、内容、布局、页码和预取数量合并；不丢掉必要的新预取，不重建 PhotoView 或丢弃解码画面。

### 实际行为 / Actual behavior

`_buildPhotoPage` 内直接调用 `cache(index)`；每次构建都进入预取路径。底层合并请求不等于调用、遍历及配置创建没有开销。

### 阅读环境 / Reading context

画廊重复构建；不声称当前主线每次翻页都销毁 PhotoView。

### 诊断提供方式 / Diagnostic source

无法取得（需说明原因并提供替代证据） / Unavailable (explain and provide alternatives)

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/reader/gallery_view.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/gallery_view.dart#L346)

### 日志无法取得的原因 / Why diagnostics are unavailable

当前排查在云端，没有连接原设备的原版阅读会话，无法从该会话导出手动阅读诊断；没有拿 Prime 的旧报告或其他用户报告冒充本项诊断。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/reader/gallery_page_continuity_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/gallery_page_continuity_test.dart)、[test/features/reader/gallery_rotation_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/gallery_rotation_test.dart)、[test/features/reader/image_precache_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/image_precache_test.dart)

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

#118 的 PhotoView 反复销毁/闪屏问题已修复并关闭；本报告只讨论仍存在的构建期预取路径。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
