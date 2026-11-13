# [Bug]: 瀑布流前章预取晚到时跳回旧页，并丢失当前页面的局部偏移

<!-- feedback-id: U10; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题类型 / Issue type

界面、导航与交互 / UI and interaction

### 应用版本 / App version

源码对照：CyrilPeng/Venera-Next main@482810df369d126e4011be31d64408e33aede76f（版本元数据 1.18.4-rc.1+250）。组件复现运行于 fork 对应实现，不冒称官方安装包整体验证。

### 平台 / Platform

其他（请说明） / Other (please specify)：源码层核对；最小组件验证为 Linux 云端，不能据此声明各发行平台均实测。

### 设备与系统 / Device and OS

组件环境为 Linux、仓库锁定 Flutter 3.41.4；本项原版设备型号、系统/刷新率未单独采集。

### 复现步骤 / Steps to reproduce

1. 从第二章附近进入瀑布流，延迟上一章的图片列表响应。
2. 等待期间向下滚动到本章后续页面，停在页面中部。
3. 释放上一章响应，观察当前页和局部偏移；再让响应在拖动/惯性滚动中到达。

### 预期行为 / Expected behavior

待滚动停止后再插入，按插入时最新可见页及 leading edge 保持位置；换章/退出取消等待与旧结果，不遗留监听。

### 实际行为 / Actual behavior

前章响应完成后使用请求开始时捕获的 `current`，执行 `jumpTo(index: current + insertedCount)`；alignment 默认为 0，既可能回到旧页，也会把页面中部强制对齐顶部。jumpTo 还会终止正在进行的滚动。

### 问题位置与操作方式 / Affected screen and input

跨章瀑布流、上一章列表晚返回；与图片解码后的尺寸变化是两条独立路径，本稿单独报告章节插入。

### 诊断提供方式 / Diagnostic source

界面类日志选填；下方提供源码/组件证据。

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/reader/continuous_view.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/continuous_view.dart#L247)；[lib/features/reader/waterfall_controller.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/waterfall_controller.dart#L152)

### 日志无法取得的原因 / Why diagnostics are unavailable

界面/布局/导航报告按上游表单可不附日志；没有编造错误日志或设备性能数据。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/reader/waterfall_loading_stability_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/waterfall_loading_stability_test.dart) 的晚到前章/活跃拖动，以及 [test/features/reader/waterfall_controller_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/waterfall_controller_test.dart) 的取消和旧结果门禁。

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

已检索上游收藏、阅读和关键词相关讨论；本稿聚焦这一项独立行为。发布时可再核对新增讨论。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
