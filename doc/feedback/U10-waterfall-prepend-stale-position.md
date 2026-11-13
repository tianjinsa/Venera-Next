# [Bug]: 瀑布流前一章加载晚到时，画面回跳并把半页位置顶回页首

<!-- feedback-id: U10; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题说明

我想反馈另一种瀑布流回跳：我已经继续往下读，前一章的内容这时才加载回来，画面却可能跳回较早的位置；原本停在半页，也会被对齐到页首。

我最初是在二次开发版本里反馈现象；这项的原版确认范围见后面的说明。

### 实际行为 / Actual behavior

触发条件是前一章的加载结果比我的滚动动作晚回来。程序仍按较早的页码恢复位置，而且没有保留半页偏移，可能出现回到旧页、半页变页首或滚动被打断。这个路径已通过组件和源码确认，不表示每次阅读都会触发。

### 对我的影响

我明明是在向下读，却被拉回前面，或者突然失去当前半页的位置，需要重新找刚才读到的内容。

### 预期行为 / Expected behavior

前一章晚到时保留我此刻真正看到的页面和半页位置，不使用之前的旧位置；拖动或惯性滚动期间不被强制跳页。

### 复现步骤 / Steps to reproduce

1. 在尚未修复的瀑布流中，从中间章节开始阅读。
2. 当前一章加载较慢时，继续向下读到当前章的后续页面，并停在半页位置。
3. 等前一章结果返回后，观察是否回到旧页、对齐页首或打断当前滚动。

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

跨章瀑布流、前一章列表晚返回。它与单张图片加载为真实尺寸导致的上移是两个独立触发条件。

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

原路径捕获请求开始时的 current，插入后 jumpTo(current + insertedCount)，默认 alignment=0。应检查最新可见项、局部偏移，以及换章/退出后的取消处理。

源码定位：

- [lib/features/reader/continuous_view.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/continuous_view.dart#L247)
- [lib/features/reader/waterfall_controller.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/waterfall_controller.dart#L152)

已有最小验证入口：

- [test/features/reader/waterfall_loading_stability_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/waterfall_loading_stability_test.dart)
- [test/features/reader/waterfall_controller_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/waterfall_controller_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已检索相关 Issue，并把不同问题分开说明。
- [x] 我反馈的是应用本体的问题。
- [x] 我已检查正文，没有包含账号、Cookie、Token、签名链接或私人内容。
