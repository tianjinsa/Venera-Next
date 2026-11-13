# [Bug]: 阅读进度开启总数或紧凑显示后丢弃已保存的实际章节名称

<!-- feedback-id: U04; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 用普通测试历史记录保存 `chapter_title="Bonus chapter"`、章节编号、页码及总数。
2. 分别调用普通、`showTotals: true`、`compact: true` 的进度显示。
3. 比较列表/Tooltip 中是否还包含实际名称。

### 预期行为 / Expected behavior

已有实际章节名时各模式优先使用；旧记录无名称时回退编号，保留页总数、分组及无障碍信息，不增加详情请求。

### 实际行为 / Actual behavior

只有 `!showTotals && !compact` 才使用 `chapterTitle`；其他模式强制退回 `Chapter N`/`Ch. N`。此前同一记录的上游逻辑探针确认带总数时名称消失。

### 问题位置与操作方式 / Affected screen and input

历史/收藏/追更的阅读进度描述。这里只修名称条件遗漏；把“Page”改成“P”属于显示偏好，不作为缺陷修复的必要内容。

### 诊断提供方式 / Diagnostic source

界面类日志选填；下方提供源码/组件证据。

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/history/history_model.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/history/history_model.dart#L155)

### 日志无法取得的原因 / Why diagnostics are unavailable

界面/布局/导航报告按上游表单可不附日志；没有编造错误日志或设备性能数据。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/history/history_progress_description_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/history/history_progress_description_test.dart)、[test/features/comic_widgets/detailed_reading_progress_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_widgets/detailed_reading_progress_test.dart)

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

#93 已完成进度显示功能，本报告针对其后续名称显示条件遗漏，不重复请求新增同一功能。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
