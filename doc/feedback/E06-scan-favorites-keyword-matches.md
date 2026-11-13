# [Enhancement]: 关键词管理提供本地收藏只读扫描，用于检查可能的误伤

<!-- feedback-id: E06; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

本地漫画、收藏或数据 / Local comics, favorites or data

### 平台 / Platform

所有支持的平台 / All supported platforms（建议适用范围，不代表所有平台已完成实现/验收）

### 需求场景 / Use case

收藏管理列表保持完整时，仍希望能检查现有关键词对已收藏漫画会产生哪些匹配，便于调整规则，而不是重新开启收藏隐藏。

### 建议方案 / Proposed solution

关键词设置加入显式“扫描本地收藏”入口，只读遍历现有收藏并显示命中项及原因，复用规则编辑/删除；可与可选封面预览配套。大列表分批让出界面，旧结果不得覆盖新窗口/新规则。

### 验收标准 / Acceptance criteria

- 扫描不删除/移动收藏、不改收藏时间或开启收藏屏蔽。
- 显示实际命中字段和规则，修改后按当前规则重新计算。
- 快速退出、重复扫描或更换规则时旧异步结果不覆盖新状态。
- 来源离线及同 ID 不同类型身份保持，扫描不额外请求每本漫画详情。

### 截图或录屏 / Screenshots or video

本稿未附附件；可用普通测试数据验证上述完成条件。

### 实现参考与已有讨论

参考 fork 的 `lib/features/settings/keyword_blocking.dart`、`keyword_hidden_notice.dart` 及 [test/features/settings/keyword_rules_widget_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/keyword_rules_widget_test.dart)。上游回移时不带作者独立屏蔽或 Agent 数据。

源码核对基线：`482810df369d126e4011be31d64408e33aede76f`。这是功能/交互建议，不将现有设计冒称为已确认的数据损坏或崩溃。

### 提交前确认 / Checklist

- [x] 已检索相关建议，一稿聚焦一个目标。
- [x] 建议针对应用本体。
- [x] 文本未包含私人内容或凭据。
