# [Bug]: 开启进度总数或紧凑显示后，“番外”等实际章节名变回章节编号

<!-- feedback-id: U04; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 阅读带实际章节名的章节，例如“序章”或“番外”，留下历史进度。
2. 在列表中查看普通进度，再开启总数或切换紧凑显示。
3. 比较同一条进度是否始终保留实际章节名。

### 预期行为 / Expected behavior

有实际章节名时，各种显示方式都优先保留；旧记录没有名称时再显示编号。页数、总数和分组信息应继续可用，不必额外联网查询。

### 实际行为 / Actual behavior

同一条已经保存实际章节名称的阅读记录，在普通显示中能看到名称，开启进度总数或紧凑显示后却退回章节编号。例如已保存章节名“番外”的记录，普通描述保留“番外”，带总数或紧凑显示时却只显示 Chapter N / Ch. N。

我通常按“序章”“番外”等名称辨认读到的位置。只剩编号后，我不容易判断上次读到哪部分，还需要重新打开漫画确认。

### 问题位置与操作方式 / Affected screen and input

收藏、历史、追更等列表的阅读进度描述；“番外”是便于说明的示例名称。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

### 替代证据 / Alternative evidence

<details>
<summary>源码定位与最小验证（供维护者参考）</summary>

已有逻辑验证确认，名称只在 !showTotals && !compact 时使用。本条关注已知名称丢失，不要求把原版 Page 文案改成 P。

源码定位：

- [lib/features/history/history_model.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/history/history_model.dart#L155)

已有最小验证入口：

- [test/features/history/history_progress_description_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/history/history_progress_description_test.dart)
- [test/features/comic_widgets/detailed_reading_progress_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_widgets/detailed_reading_progress_test.dart)

我查到 #93 已提供章节进度显示；这里反馈的是其中实际章节名在部分显示方式下丢失的问题。

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
