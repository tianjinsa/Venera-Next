# [Bug]: 瀑布流前一章加载晚到时，画面回跳并把半页位置顶回页首

<!-- feedback-id: U10; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 在原版 1.18.4-rc.1 的瀑布流中，从中间章节开始阅读。
2. 当前一章加载较慢时，继续向下读到当前章的后续页面，并停在半页位置。
3. 等前一章结果返回后，观察是否回到旧页、对齐页首或打断当前滚动。

### 预期行为 / Expected behavior

前一章晚到时保留我此刻真正看到的页面和半页位置，不使用之前的旧位置；拖动或惯性滚动期间不被强制跳页。

### 实际行为 / Actual behavior

我已经在瀑布流中继续往下读，前一章内容这时才加载回来，画面却可能跳回较早的位置；原本停在半页，也可能被对齐到页首或打断滚动。

我明明在向下读，却被拉回前面或突然失去半页位置，需要重新找刚才读到的内容。这与上方单张图片加载后使内容上移的触发条件不同。

### 问题位置与操作方式 / Affected screen and input

跨章瀑布流、前一章列表晚返回。它与单张图片加载为真实尺寸导致的上移是两个独立触发条件。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

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

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
