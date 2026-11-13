# [Bug]: 从收藏封面进入漫画详情时，页面过场和封面衔接不一致

<!-- feedback-id: U06; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 在原版 1.18.4-rc.1 的收藏夹中，将点击收藏项设置为查看详情。
2. 点击漫画封面进入详情，再返回收藏。
3. 与同一应用内正常进入漫画详情的页面过场和封面衔接比较。

### 预期行为 / Expected behavior

详情使用收藏列表所属导航上下文，封面 Hero ID 正确传递，进入/返回有连续、正常的过场。

### 实际行为 / Actual behavior

报告者已在原版确认收藏详情过场/封面衔接不一致。此为本轮补充的原用户编号 2，已不再是“尚未在原版验证”的候选；复现频率未单独量化。

### 问题位置与操作方式 / Affected screen and input

Android 15，原版 1.18.4-rc.1；触摸点击收藏封面。设备型号由报告者提交时补填。

### 诊断提供方式 / Diagnostic source

界面类日志选填；下方提供源码/组件证据。

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/favorites/local_favorites_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/favorites/local_favorites_page.dart#L1262)

注意：这里已传递 `heroID`。`Navigator.of(navigatorKey.currentContext)` 会返回该 Navigator 本身；已排除“使用 key 上下文必定找到父 Navigator”的错误解释。用户确认了现象，尚不能把所有原因归结为 Navigator 错层。

### 日志无法取得的原因 / Why diagnostics are unavailable

界面/布局/导航报告按上游表单可不附日志；没有编造错误日志或设备性能数据。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/favorites/local_favorites_refresh_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/favorites/local_favorites_refresh_test.dart) 中详情导航/封面 Hero 回归，并在上述原设备检查入场、退场与快速往返。

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

#129 为“封面浮在界面上”，当前 open / awaiting-feedback。本报告不是自动认定二者同根因；提交时应说明此处是收藏详情过场问题，必要时作为该讨论的补充证据。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
