# [Enhancement]: 希望封面阅读进度可以切换为小图标，减少对封面的遮挡

<!-- feedback-id: E03; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

界面、导航或交互 / UI, navigation or interaction

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 需求场景 / Use case

我希望封面上的阅读进度能选用更紧凑的小图标。完整进度文字有用，但在小封面上会挡住一部分画面，我更想先快速看出当前页和总页数。

我在浏览很多小封面时，既想认出漫画，也想知道读到哪里。较大的进度文字块会与封面争位置，只关闭进度又不方便继续阅读。

我的使用环境：

- 应用：1.18.4-rc.1（官方原版）
- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 建议方案 / Proposed solution

我希望保留现有详细显示，再增加一个可选的固定小图标：当前页左上、总页数右下，各自分行；读完显示勾。长按提示、鼠标提示或无障碍说明里仍保留完整章节和进度。

<details>
<summary>已有实现参考与相关讨论（供维护者参考）</summary>

这是显示偏好建议，不是要求移除 #93 的详细进度，也不重复报告已经修过的大字号布局问题。

- [test/features/comic_widgets/reading_progress_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_widgets/reading_progress_test.dart)
- [test/features/comic_widgets/reading_status_layout_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_widgets/reading_status_layout_test.dart)

</details>

### 验收标准 / Acceptance criteria

- 我可以在现有详细显示和紧凑图标之间选择。
- 3/30、162/233、1001/1200 在窄封面和大字号下仍能区分，不重叠溢出。
- 没有总页数时正常显示，读完时有明确完成标记。
- 完整进度仍可查看，图标不会盖到封面之外的标题。

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
