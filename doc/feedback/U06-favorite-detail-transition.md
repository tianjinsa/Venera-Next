# [Bug]: 从收藏打开漫画详情时，页面和封面转场不连贯

<!-- feedback-id: U06; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题说明

我在原版 1.18.4-rc.1 中确认，从收藏封面进入漫画详情时，页面过场和封面衔接与正常详情入口不一致，切换显得不连贯。

### 实际行为 / Actual behavior

点击收藏封面后，漫画详情可以打开，但收藏页与详情页之间的页面过场、封面衔接不够自然。与应用内其他正常进入详情的情况相比，能看出切换体验不一致。

### 对我的影响

打开和返回详情时，我看到的画面衔接比较突兀，难以跟随刚才点击的那本漫画。希望收藏入口也有一致、连续的页面切换体验。

### 预期行为 / Expected behavior

从收藏打开详情、返回收藏时，页面切换和封面衔接保持连续，与正常详情入口一致。

### 复现步骤 / Steps to reproduce

1. 使用原版 1.18.4-rc.1，把点击收藏项的操作设置为“查看详情”。
2. 进入收藏夹，点击一本漫画的封面打开详情，再返回收藏。
3. 与应用内其他正常详情入口的页面过场、封面衔接比较。

### 应用版本 / App version

1.18.4-rc.1（我使用的官方原版）。

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 设备与系统 / Device and OS

- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 问题位置与操作方式 / Affected screen and input

我已在原版 Android 设备确认此现象；触摸点击收藏封面。复现频率没有单独统计。

### 问题类型 / Issue type

界面、导航与交互 / UI and interaction

### 诊断提供方式 / Diagnostic source

我暂未附设备日志，提供下方源码和已有验证线索。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

### 日志无法取得的原因 / Why diagnostics are unavailable

这项是界面/交互反馈，我暂未附运行日志。

### 替代证据 / Alternative evidence

<details>
<summary>源码定位与最小验证（供维护者参考）</summary>

源码已经传递 heroID。不能仅凭使用 navigatorKey.currentContext 就断定找错父导航器；目前确认的是现象，具体转场原因仍需结合实际路由/Hero 行为定位。

源码定位：

- [lib/features/favorites/local_favorites_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/favorites/local_favorites_page.dart#L1262)

已有最小验证入口：

- [test/features/favorites/local_favorites_refresh_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/favorites/local_favorites_refresh_test.dart)

我查到 #129 讨论“封面浮在界面上”。我的反馈重点是收藏进入详情的过场和封面衔接，暂不确定是否与该问题同一个原因。

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已检索相关 Issue，并把不同问题分开说明。
- [x] 我反馈的是应用本体的问题。
- [x] 我已检查正文，没有包含账号、Cookie、Token、签名链接或私人内容。
