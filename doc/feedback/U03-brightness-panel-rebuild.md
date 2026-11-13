# [Bug]: 夜间调光保存时快捷面板高度变化，预览又刷新整个阅读外壳

<!-- feedback-id: U03; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 进入阅读器，打开夜间调光快捷面板并启用调光。
2. 连续拖动滑条、松手，在较慢保存或大字号下比较面板高度。
3. 在组件夹具中延迟保存，并统计亮度遮罩和无关阅读子树的 build。

### 预期行为 / Expected behavior

预览只刷新亮度遮罩；保存状态保持固定占位；保存完成/预览释放后读取正确作用域的已提交值，不重置图像、缩放或进度。

### 实际行为 / Actual behavior

快捷面板动态插入 `settingsSaveStatus` 行；亮度预览监听调用外壳 `update`，亮度设置提交又发出 rebuildShell/rebuildReader。高度变化和重建路径可从源码确认，原设备闪烁幅度尚未量化。

### 问题位置与操作方式 / Affected screen and input

仅报告原版已有的调光；不要求加入 fork 的线条增强、夜览模式或其快捷菜单。

### 诊断提供方式 / Diagnostic source

界面类日志选填；下方提供源码/组件证据。

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/settings/reader_brightness.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/settings/reader_brightness.dart#L123)；[lib/components/settings_save_state.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/components/settings_save_state.dart#L283)；[lib/features/reader/scaffold.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/scaffold.dart#L139)；[lib/features/reader/settings_effects.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/settings_effects.dart#L85)

### 日志无法取得的原因 / Why diagnostics are unavailable

界面/布局/导航报告按上游表单可不附日志；没有编造错误日志或设备性能数据。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/reader/brightness_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/brightness_test.dart)、[test/features/reader/settings_effects_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/settings_effects_test.dart) 和阅读退出集成中的全局/设备/单漫画亮度回归。

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

已检索上游收藏、阅读和关键词相关讨论；本稿聚焦这一项独立行为。发布时可再核对新增讨论。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
