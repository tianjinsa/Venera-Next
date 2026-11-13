# [Bug]: 详情页点击标签或作者没有反应，退出后搜索页才出现在上一层

<!-- feedback-id: U11; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题说明

我在二次开发版本的屏蔽原因窗口里点封面进入详情后，点击标签或作者看起来没有反应。退出详情才发现，搜索页其实打开了，却被放在上一层页面里。

### 实际行为 / Actual behavior

点击后，当前详情页没有切到搜索；返回后，上级页面却出现了刚才点的标签或作者搜索。这会让“点击没有生效”和“回到原页面”的反馈都变得不一致。

### 对我的影响

我无法在当前详情里直接查看同标签或同作者的漫画，还可能以为没点中而重复点击。返回时也不是预期的原因列表，而是意外出现的搜索页。

### 预期行为 / Expected behavior

点击标签或作者后立即进入对应搜索；返回时依次回到详情和原来的原因列表。搜索结果或推荐封面继续在当前页面打开，不出现藏在下层的页面。

### 复现步骤 / Steps to reproduce

1. 在二次开发版本里，打开关键词屏蔽原因窗口。
2. 点击其中的封面进入漫画详情。
3. 点击详情里的一个标签或作者，观察当前页是否进入搜索。
4. 退出详情，检查搜索是否错误地出现在上级页面。

### 应用版本 / App version

发现现象的二次开发版本：`【二次开发版本及构建号】`。

我用于对照的官方原版：1.18.4-rc.1；这不代表本条已经在原版手机上单独复测。

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 设备与系统 / Device and OS

- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 问题位置与操作方式 / Affected screen and input

我的实际入口是二次开发版本新增的原因封面，原版目前没有这个入口。我想反馈的是通用详情动作在两层导航下打开搜索位置不对；原版对应条件的最小验证方式放在后面供维护者参考。

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

上游 onTapTag 固定使用 mainNavigatorKey，普通卡片也默认使用全局主导航器。维护者可建立根/主两个 Navigator，把详情放到根层，调用原标签/作者动作，记录搜索被推入哪一层；这不依赖原版已有原因封面功能。

源码定位：

- [lib/features/comic_details/actions.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/comic_details/actions.dart#L387)
- [lib/features/comic_widgets/comic_tile.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/comic_widgets/comic_tile.dart#L221)

已有最小验证入口：

- [test/features/comic_details/tag_navigation_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_details/tag_navigation_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已检索相关 Issue，并把不同问题分开说明。
- [x] 我反馈的是应用本体的问题。
- [x] 我已检查正文，没有包含账号、Cookie、Token、签名链接或私人内容。
