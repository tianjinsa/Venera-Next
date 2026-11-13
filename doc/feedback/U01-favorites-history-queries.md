# [Bug]: 收藏夹选择“全部”仍逐本查历史，无关设置更新反复遍历大列表

<!-- feedback-id: U01; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 准备包含 1200 条普通测试记录的本地收藏夹，阅读状态选“全部”。
2. 不启用额外的已读筛选，进入该收藏夹。
3. 在 `HistoryManager.find` 增加计数，检查一次默认过滤；再修改与收藏内容无关的阅读设置，检查重新计算次数。

### 预期行为 / Expected behavior

“全部”直接复用输入，不逐项读取历史；已读筛选按输入及历史状态缓存；无关设置不重算完整列表，搜索、选择和真实历史更新仍正确。

### 实际行为 / Actual behavior

“全部”分支仍为每条记录先调用 `find`。此前对上游逻辑的 1200 项探针得到 1200 次历史查找。可见列表/选择协调及通用网格还会响应无关设置重新过滤、复制及生成身份映射。调用次数不等于 SQLite 实际查询次数，本报告不虚构卡顿秒数。

### 问题位置与操作方式 / Affected screen and input

收藏默认展示与列表刷新；属于应用侧可避免的主线程工作，不涉及源站速度或私人数据。

### 诊断提供方式 / Diagnostic source

界面类日志选填；下方提供源码/组件证据。

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/favorites/local_favorites_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/favorites/local_favorites_page.dart#L238)；[lib/features/favorites/local_favorites_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/favorites/local_favorites_page.dart#L158)；[lib/features/comic_widgets/comic_list.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/comic_widgets/comic_list.dart#L67)

旧探针记录：`input=1200; read_filter=all; HistoryManager.find calls=1200`。这是调用计数，非数据库查询计数或设备帧率。

### 日志无法取得的原因 / Why diagnostics are unavailable

界面/布局/导航报告按上游表单可不附日志；没有编造错误日志或设备性能数据。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/favorites/local_favorites_refresh_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/favorites/local_favorites_refresh_test.dart) 中的 1200 项计数、无关设置及选择回归。

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

与 #152 的多选入口需求不同；与 #115 的关键词匹配结果不同。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
