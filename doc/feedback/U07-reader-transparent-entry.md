# [Bug]: 点击阅读后，入场最初透明，短暂露出漫画详情页

<!-- feedback-id: U07; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 使用原版 1.18.4-rc.1，打开一本漫画的详情页。
2. 点击“阅读”或“继续阅读”。
3. 观察阅读器刚开始入场、内容尚未完全出现时，是否会短暂透出详情页。

### 预期行为 / Expected behavior

进入阅读器时就显示不透明的阅读背景或加载画面，随后再出现图片，不短暂透出上一级页面。

### 实际行为 / Actual behavior

我在原版 1.18.4-rc.1 中确认，点击阅读或继续阅读后，阅读页面入场的最初一段会短暂透明，透出上一级漫画详情页；随后才显示阅读背景或内容。

详情页和阅读器画面会在切换中短暂混在一起，让我感觉页面没有切换完整，阅读开始时有明显的不连贯感。

### 问题位置与操作方式 / Affected screen and input

我已在原版 Android 设备确认此现象；发生在进入阅读器时。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

### 替代证据 / Alternative evidence

<details>
<summary>源码定位与最小验证（供维护者参考）</summary>

Reader 与阅读加载入口的顶层背景需要一起检查。转场还受 AppPageRoute 和平台影响；没有据此宣称所有平台都必现。

源码定位：

- [lib/features/reader/reader_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/reader_page.dart#L1910)
- [lib/features/reader/loading.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/loading.dart#L55)

已有最小验证入口：

- [test/features/reader/reader_exit_integration_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/reader_exit_integration_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
