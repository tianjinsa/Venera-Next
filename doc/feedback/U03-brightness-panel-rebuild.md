# [Bug]: 阅读器调光滑条保存时面板高度变化，影响连续调节

<!-- feedback-id: U03; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 进入阅读器，打开夜间调光快捷面板并启用调光。
2. 拖动滑条，松手保存，然后继续调整。
3. 观察保存开始、结束时面板高度和滑条位置是否变化；可在大字号或较慢保存时比较。

### 预期行为 / Expected behavior

面板高度和滑条位置保持稳定；预览只更新亮度遮罩，保存结束后显示正确的亮度，不重置阅读位置或缩放。

### 实际行为 / Actual behavior

在夜间调光面板拖动滑条并松手保存时，面板会增加一行保存状态，内容向下挪动；保存结束后又收回这一行，面板高度和内容位置再次变化。亮度预览还会刷新整个阅读外壳，而不只是调光遮罩。

我细调亮度时需要反复确认滑条位置，面板的上下变化会打断连续调节；额外刷新也可能影响调节的顺畅程度。

### 问题位置与操作方式 / Affected screen and input

阅读器已有的夜间调光快捷面板。本条不要求新增线条增强或夜览功能。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

### 替代证据 / Alternative evidence

<details>
<summary>源码定位与最小验证（供维护者参考）</summary>

源码可确认保存状态行动态插入，以及预览监听触发外壳更新的路径；现有组件验证用于检查布局和刷新行为。

源码定位：

- [lib/features/settings/reader_brightness.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/settings/reader_brightness.dart#L123)
- [lib/components/settings_save_state.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/components/settings_save_state.dart#L283)
- [lib/features/reader/scaffold.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/scaffold.dart#L139)
- [lib/features/reader/settings_effects.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/settings_effects.dart#L85)

已有最小验证入口：

- [test/features/reader/brightness_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/brightness_test.dart)
- [test/features/reader/settings_effects_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/settings_effects_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
