# [Bug]: 设置保存时移除原开关或选择器，导致控件宽度及文字布局变化

<!-- feedback-id: U02; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 在窄屏、大字号设置页选择标题接近换行边界的开关/选择器。
2. 点击保存，在写入较慢时观察右侧控件和左侧文字。
3. 最小组件复现可阻塞 `AppDataOperations` 的写入准入，点击后检查保存前后的 Element 和文字矩形。

### 预期行为 / Expected behavior

保存期间保留原控件 Element 和布局尺寸，可禁用输入或叠加状态；失败可重试，持久化与退出等待仍有效。

### 实际行为 / Actual behavior

保存期间原 Switch/选择器被 18×18 进度圈替换，控件卸载、占位宽度改变。此前直接取上游组件的探针确认保存期间 Switch 不再存在；文字能否恰好换行取决于可用宽度和字号。

### 问题位置与操作方式 / Affected screen and input

设置列表右侧交互控件；原版源码仍有 `trailing: saving ? _savingIndicator : Switch(...)` 及选择器的对应分支。

### 诊断提供方式 / Diagnostic source

界面类日志选填；下方提供源码/组件证据。

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/settings/setting_components.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/settings/setting_components.dart#L170)；同文件选择器保存分支约 404、540 行。

### 日志无法取得的原因 / Why diagnostics are unavailable

界面/布局/导航报告按上游表单可不附日志；没有编造错误日志或设备性能数据。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/settings/setting_persistence_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/setting_persistence_test.dart) 的原 Element、标题矩形、失败/重试及真实落盘断言。

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

已检索上游收藏、阅读和关键词相关讨论；本稿聚焦这一项独立行为。发布时可再核对新增讨论。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
