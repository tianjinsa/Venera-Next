# [Enhancement]: 从关键词屏蔽原因编辑规则时，可以直接删除当前规则

<!-- feedback-id: E05; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

界面、导航或交互 / UI, navigation or interaction

### 平台 / Platform

所有支持的平台 / All supported platforms（建议适用范围，不代表所有平台已完成实现/验收）

### 需求场景 / Use case

原版原因窗口已有 Edit rule，但进入编辑后不能直接删除；发现误伤时还需回管理列表重新定位同一规则。

### 建议方案 / Proposed solution

原因文字区域可进入当前规则编辑，并在编辑窗口提供删除当前规则的明确操作。删除与编辑共用现有排队保存、错误重试和过期规则校验。

### 验收标准 / Acceptance criteria

- 只删除当前仍有效的那条规则，不误删已被其他窗口替换的规则。
- 完成删除后原因列表重新计算，匹配统计更新。
- 保存失败保留错误/重试；窗口关闭后已接受的持久化仍完成。
- 管理列表原有删除、匹配方式和大小写选项保持有效。

### 截图或录屏 / Screenshots or video

本稿未附附件；可用普通测试数据验证上述完成条件。

### 实现参考与已有讨论

参考 [test/features/settings/keyword_rules_widget_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/keyword_rules_widget_test.dart)、[test/features/settings/keyword_display_persistence_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/keyword_display_persistence_test.dart)。仅补全操作路径，不声称原版完全没有编辑或管理列表删除能力。

源码核对基线：`482810df369d126e4011be31d64408e33aede76f`。这是功能/交互建议，不将现有设计冒称为已确认的数据损坏或崩溃。

### 提交前确认 / Checklist

- [x] 已检索相关建议，一稿聚焦一个目标。
- [x] 建议针对应用本体。
- [x] 文本未包含私人内容或凭据。
