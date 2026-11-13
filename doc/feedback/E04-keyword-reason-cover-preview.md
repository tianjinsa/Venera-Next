# [Enhancement]: 希望查看关键词屏蔽原因时，可以按需看封面并打开漫画详情

<!-- feedback-id: E04; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

界面、导航或交互 / UI, navigation or interaction

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 需求场景 / Use case

我查看被关键词隐藏的漫画时，只有标题和命中原因，有时很难判断是不是我想找的那一本。我希望在这个窗口里能按需看看封面，再决定是否调整规则。

只看文字不容易认出漫画，我需要离开原因窗口再去找这本漫画，确认封面后又回来修改规则，操作比较绕。

我的使用环境：

- 应用：1.18.4-rc.1（官方原版）
- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 建议方案 / Proposed solution

我希望增加一个可选的封面预览或“查看封面”操作。点封面打开漫画详情，点原因文字编辑规则；从详情返回后保留刚才的原因列表，不必重新找。

<details>
<summary>已有实现参考与相关讨论（供维护者参考）</summary>

原版写明了 Images stay hidden，我理解这是现有设计。因此我提的是可选预览功能，不把未显示封面当成原有按钮坏了。

- [lib/features/comic_widgets/keyword_hidden_notice.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/comic_widgets/keyword_hidden_notice.dart#L102)
- [test/features/settings/keyword_rules_widget_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/keyword_rules_widget_test.dart)

</details>

### 验收标准 / Acceptance criteria

- 我明确选择查看时才加载预览，原来的不显示图片行为仍可保留。
- 点封面进入对应漫画，不误触规则编辑。
- 详情里的标签、作者和后续封面跳转位置正确。
- 返回后仍是刚才的原因列表，方便继续检查和调整规则。

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
