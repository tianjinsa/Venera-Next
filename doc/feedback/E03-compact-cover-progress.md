# [Enhancement]: 封面进度提供可选的固定尺寸紧凑图标，保留完整进度说明

<!-- feedback-id: E03; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

界面、导航或交互 / UI, navigation or interaction

### 平台 / Platform

所有支持的平台 / All supported platforms（建议适用范围，不代表所有平台已完成实现/验收）

### 需求场景 / Use case

用户希望小封面少被完整进度文本遮挡，同时仍能快速看到当前页和总页数。上游详细进度本身是已有需求，不应被直接移除。

### 建议方案 / Proposed solution

增加可选紧凑进度图标：固定小尺寸，当前页左上、总页数右下并各占独立行；多位数按需缩小，完成时显示勾。完整章节和进度继续放入 Tooltip/无障碍标签，保留现有详细模式。

### 验收标准 / Acceptance criteria

- 3/30、162/233、1001/1200 在普通/大字号、窄网格中无重叠溢出。
- 缺总数居中、完成时显示勾。
- 完整章节名和进度对辅助技术仍可读。
- 图标限制在封面范围内，不覆盖标题；既有详细显示可继续选择。

### 截图或录屏 / Screenshots or video

本稿未附附件；可用普通测试数据验证上述完成条件。

### 实现参考与已有讨论

参考 [test/features/comic_widgets/reading_progress_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_widgets/reading_progress_test.dart)、[test/features/comic_widgets/reading_status_layout_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_widgets/reading_status_layout_test.dart)。#93 已交付详细进度，本建议为显示偏好，不重复报告已修复的 #158 大字号溢出。

源码核对基线：`482810df369d126e4011be31d64408e33aede76f`。这是功能/交互建议，不将现有设计冒称为已确认的数据损坏或崩溃。

### 提交前确认 / Checklist

- [x] 已检索相关建议，一稿聚焦一个目标。
- [x] 建议针对应用本体。
- [x] 文本未包含私人内容或凭据。
