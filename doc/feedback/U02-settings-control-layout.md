# [Bug]: 设置保存时开关变成转圈，文字和控件位置随之跳动

<!-- feedback-id: U02; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 打开设置页，选择一个开关或选择器。
2. 修改选项，观察保存期间的右侧控件。
3. 在大字号或较窄屏幕下，比较保存前后的标题换行和控件位置；保存较慢时更容易看清。

### 预期行为 / Expected behavior

保存时保持原控件、状态和占位宽度，可以暂时禁用操作或叠加小提示；保存失败时仍能看到错误并重试。

### 实际行为 / Actual behavior

修改开关或选择器后，保存期间原控件会被较小的进度圈替换，保存完成才恢复。我暂时看不到刚选择的状态；在窄屏、大字号或标题接近换行边界时，右侧占位宽度变化还可能让左侧文字重新换行，文字和控件位置跟着跳动。

这种一闪一跳会干扰我连续调整设置，也不方便确认刚才的选择是否保留。

### 问题位置与操作方式 / Affected screen and input

设置列表的开关/选择器；窄屏、大字号、较慢保存时更容易受到影响。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

### 替代证据 / Alternative evidence

<details>
<summary>源码定位与最小验证（供维护者参考）</summary>

已有组件验证确认保存期间 Switch 被移除。源码使用 saving 分支把控件替换为较小的进度圈；是否恰好触发文字换行取决于布局宽度和字号。

源码定位：

- [lib/features/settings/setting_components.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/settings/setting_components.dart#L170)

已有最小验证入口：

- [test/features/settings/setting_persistence_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/setting_persistence_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
