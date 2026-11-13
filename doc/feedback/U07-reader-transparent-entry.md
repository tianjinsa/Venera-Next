# [Bug]: 进入阅读器的初始过场透明，短暂露出上一页内容

<!-- feedback-id: U07; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题类型 / Issue type

界面、导航与交互 / UI and interaction

### 应用版本 / App version

1.18.4-rc.1（官方原版，报告者已确认复现）；源码复核 482810df369d126e4011be31d64408e33aede76f

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 设备与系统 / Device and OS

骁龙 7gen2+，12 GB 内存，Android 15。设备型号由报告者提交时手动填写。

### 复现步骤 / Steps to reproduce

1. 在原版 1.18.4-rc.1 的漫画详情点击阅读/继续阅读。
2. 观察阅读路由刚开始入场、内容仍在加载时的最初画面。
3. 比较详情页背景和阅读器表面是否从第一帧连续绘制。

### 预期行为 / Expected behavior

阅读器和阅读加载页从路由过场第一帧绘制主题表面背景，内容尚未准备好也保持不透明。

### 实际行为 / Actual behavior

报告者已在原版确认阅读入场初期透明、露出上级页面的现象。这是原用户编号 4 的原版确认，不等于已证明所有平台或所有转场都必现。

### 问题位置与操作方式 / Affected screen and input

Android 15，原版 1.18.4-rc.1。设备型号由报告者提交时补填；问题在进入阅读器时，不是 fork 后台保存改造造成的退场画面清空。

### 诊断提供方式 / Diagnostic source

界面类日志选填；下方提供源码/组件证据。

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/reader/reader_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/reader_page.dart#L1910)；[lib/features/reader/loading.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/loading.dart#L55)

原版加载页和 Reader 顶层没有 fork 为此加入的首帧主题背景；转场仍与 AppPageRoute/平台有关，不泛化为全平台实测。

### 日志无法取得的原因 / Why diagnostics are unavailable

界面/布局/导航报告按上游表单可不附日志；没有编造错误日志或设备性能数据。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/reader/reader_exit_integration_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/reader_exit_integration_test.dart) 的加载/首帧背景与过场回归；Android 原设备再核验首个可见过场帧。

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

已检索上游收藏、阅读和关键词相关讨论；本稿聚焦这一项独立行为。发布时可再核对新增讨论。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
