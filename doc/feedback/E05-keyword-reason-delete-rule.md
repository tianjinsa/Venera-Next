# [Enhancement]: 希望从屏蔽原因进入规则编辑后，能直接删除误伤规则

<!-- feedback-id: E05; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 需求场景 / Use case

我在屏蔽原因里发现某个关键词误伤后，可以点编辑，但如果想删掉这条规则，还需要退出并回到管理列表重新寻找。

### 当前不便与对我的影响

我已经定位到了造成误伤的那条规则，却还得换页面再找一次。规则多时容易找错，也打断了检查误伤的过程。

### 建议方案 / Proposed solution

我希望原因文字区域可以直接进入该规则编辑，并在编辑窗口提供删除操作。删除成功后原因列表立即重新计算；失败时明确提示并允许重试。

### 验收标准 / Acceptance criteria

- 从原因直接定位到当前规则，并能在同一个编辑窗口删除。
- 只删除当前这条有效规则，不误删其他或已被替换的规则。
- 成功后隐藏数量和原因列表更新；失败时可以重试。
- 已有的匹配方式、大小写设置及管理列表删除能力继续保留。

### 我的使用环境

- 应用：1.18.4-rc.1（官方原版）
- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

界面、导航或交互 / UI, navigation or interaction

### 平台 / Platform

Android 手机／平板 / Android phone or tablet（我的使用平台；也欢迎其他平台提供同样体验）。

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 实现参考与已有讨论

<details>
<summary>已有实现参考与相关讨论（供维护者参考）</summary>

我希望补全这条操作路径，不是说原版完全没有编辑或删除规则的功能。

- [test/features/settings/keyword_rules_widget_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/keyword_rules_widget_test.dart)
- [test/features/settings/keyword_display_persistence_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/keyword_display_persistence_test.dart)

</details>

### 提交前确认 / Checklist

- [x] 我已检索相关建议，这一条聚焦一个使用需求。
- [x] 我希望改进的是应用本体的操作体验。
- [x] 我已检查正文，没有包含私人内容或凭据。
