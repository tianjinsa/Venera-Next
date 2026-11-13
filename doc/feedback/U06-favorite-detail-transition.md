# [Bug]: 从收藏打开漫画详情时，页面和封面转场不连贯

<!-- feedback-id: U06; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题类型 / Issue type

界面、导航与交互 / UI and interaction

### 应用版本 / App version

1.18.4-rc.1（官方原版）。

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 设备与系统 / Device and OS

- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 复现步骤 / Steps to reproduce

1. 使用原版 1.18.4-rc.1，把点击收藏项的操作设置为“查看详情”。
2. 进入收藏夹，点击一本漫画的封面打开详情，再返回收藏。
3. 与应用内其他正常详情入口的页面过场、封面衔接比较。

### 预期行为 / Expected behavior

从收藏打开详情、返回收藏时，页面切换和封面衔接保持连续，与正常详情入口一致。

### 实际行为 / Actual behavior

我在原版 1.18.4-rc.1 中确认，从收藏封面进入漫画详情时，详情可以打开，但收藏页与详情页之间的页面过场、封面衔接与应用内其他正常详情入口不一致，切换显得不连贯。

打开和返回详情时，画面衔接比较突兀，我难以跟随刚才点击的那本漫画，影响连续浏览收藏的体验。

### 问题位置与操作方式 / Affected screen and input

我已在原版 Android 设备确认此现象；触摸点击收藏封面。复现频率没有单独统计。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

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

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
