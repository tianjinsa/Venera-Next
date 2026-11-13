# [Enhancement]: 关键词屏蔽原因窗口提供可选封面预览和详情入口

<!-- feedback-id: E04; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

界面、导航或交互 / UI, navigation or interaction

### 平台 / Platform

所有支持的平台 / All supported platforms（建议适用范围，不代表所有平台已完成实现/验收）

### 需求场景 / Use case

只读标题和命中原因有时难以判断是否误伤；希望在主动查看原因时按需查看封面并进入详情。原版明确选择不显示图片，这是交互扩展而非原有功能故障。

### 建议方案 / Proposed solution

原因窗口提供可选封面预览；封面单独点击打开该漫画详情，原因文字继续编辑规则。返回详情后保留原原因列表，导航沿用当前窗口上下文。默认行为保留原有设计意图，由明确开关/操作启用预览。

### 验收标准 / Acceptance criteria

- 预览只在用户明确开启/查看时加载对应封面。
- 封面进入正确 ID、来源、标题与封面的详情，不触发编辑规则。
- 详情标签/作者及后续封面走正确导航器，返回仍保留原因列表。
- 不增加作者独立规则、Agent 或图源私有实现。

### 截图或录屏 / Screenshots or video

本稿未附附件；可用普通测试数据验证上述完成条件。

### 实现参考与已有讨论

现有设计：[lib/features/comic_widgets/keyword_hidden_notice.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/comic_widgets/keyword_hidden_notice.dart#L102) 的 `Images stay hidden.`。参考 fork 的 `keyword_rules_widget_test.dart`；与 U11 的双导航器健壮性配套，不能倒称原版已有原因封面按钮。

源码核对基线：`482810df369d126e4011be31d64408e33aede76f`。这是功能/交互建议，不将现有设计冒称为已确认的数据损坏或崩溃。

### 提交前确认 / Checklist

- [x] 已检索相关建议，一稿聚焦一个目标。
- [x] 建议针对应用本体。
- [x] 文本未包含私人内容或凭据。
