# [Enhancement]: 用户主动收藏、导入和追更的列表可保持完整，关键词屏蔽主要用于发现与搜索

<!-- feedback-id: E01; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

本地漫画、收藏或数据 / Local comics, favorites or data

### 平台 / Platform

所有支持的平台 / All supported platforms（建议适用范围，不代表所有平台已完成实现/验收）

### 需求场景 / Use case

用户已经主动选择收藏/导入/稍后阅读/追更的漫画，仍可能因全局关键词规则在这些列表不可见；这容易与数据未保存混淆。发现/搜索的推荐过滤仍有价值。

### 建议方案 / Proposed solution

为用户主动管理的本地漫画、收藏、历史、稍后阅读与追更列表提供不应用关键词过滤的行为或独立控制，发现/搜索保持原过滤。搜索、已读筛选和多选只遵守用户当前条件，不删除、隐藏持久数据。

### 验收标准 / Acceptance criteria

- 命中屏蔽词的已收藏/导入漫画仍可在对应管理列表找到。
- 发现、搜索和分类仍按原规则过滤。
- 全选、反选、范围选择与当前搜索/阅读状态一致，修改屏蔽词不意外清空选择。
- 备份、同步及关键词匹配方式保持兼容。

### 截图或录屏 / Screenshots or video

本稿未附附件；可用普通测试数据验证上述完成条件。

### 实现参考与已有讨论

参考 [test/features/comic_widgets/keyword_filter_consumers_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_widgets/keyword_filter_consumers_test.dart)、[test/features/local_comics/local_archive_visibility_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/local_comics/local_archive_visibility_test.dart)。上游没有 fork 的作者独立屏蔽/Agent，不将它们带入此建议。#115 已按关键词实际命中关闭，本建议不是“导入丢数据”的缺陷报告。

源码核对基线：`482810df369d126e4011be31d64408e33aede76f`。这是功能/交互建议，不将现有设计冒称为已确认的数据损坏或崩溃。

### 提交前确认 / Checklist

- [x] 已检索相关建议，一稿聚焦一个目标。
- [x] 建议针对应用本体。
- [x] 文本未包含私人内容或凭据。
