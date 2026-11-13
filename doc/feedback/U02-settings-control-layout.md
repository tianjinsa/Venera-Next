# [Bug]: 设置保存时开关变成转圈，文字和控件位置随之跳动

<!-- feedback-id: U02; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题说明

我想反馈设置页保存时的布局变化：点击开关或选择器后，原控件会先被小转圈替换，保存结束再出现。右侧占用宽度改变时，左侧文字也可能重新换行。

我目前提供的是源码核对和已有的最小验证结果，尚未为这一项单独补充原版手机复测。

### 实际行为 / Actual behavior

保存期间，刚才操作的开关/选择器暂时看不见，只剩进度圈；保存完成后控件恢复。在窄屏、大字号或标题接近换行边界时，文字和右侧控件的位置可能跟着变化。

### 对我的影响

保存时我无法继续看见刚选的开关状态；文字或控件的位置变化也会干扰连续操作，让设置界面显得一闪一跳。

### 预期行为 / Expected behavior

保存时保持原控件、状态和占位宽度，可以暂时禁用操作或叠加小提示；保存失败时仍能看到错误并重试。

### 复现步骤 / Steps to reproduce

1. 打开设置页，选择一个开关或选择器。
2. 修改选项，观察保存期间的右侧控件。
3. 在大字号或较窄屏幕下，比较保存前后的标题换行和控件位置；保存较慢时更容易看清。

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

设置列表的开关/选择器；窄屏、大字号、较慢保存时更容易受到影响。

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

已有组件验证确认保存期间 Switch 被移除。源码使用 saving 分支把控件替换为较小的进度圈；是否恰好触发文字换行取决于布局宽度和字号。

源码定位：

- [lib/features/settings/setting_components.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/settings/setting_components.dart#L170)

已有最小验证入口：

- [test/features/settings/setting_persistence_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/setting_persistence_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已检索相关 Issue，并把不同问题分开说明。
- [x] 我反馈的是应用本体的问题。
- [x] 我已检查正文，没有包含账号、Cookie、Token、签名链接或私人内容。
