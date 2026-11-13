# [Enhancement]: 希望关键词管理能只读扫描收藏，方便检查哪些漫画会被误伤

<!-- feedback-id: E06; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 需求场景 / Use case

我希望在关键词设置里有一个主动“扫描本地收藏”的入口，列出哪些收藏会被当前规则命中，让我能集中检查和调整误伤。

### 当前不便与对我的影响

现在为了判断一个关键词影响了哪些收藏，我需要在规则列表和收藏页面之间来回查。规则或收藏多时，很难一次弄清楚匹配范围。

### 建议方案 / Proposed solution

我希望扫描只显示命中漫画和具体原因，并能编辑或删除规则；扫描本身不隐藏、删除或移动收藏。大列表扫描时界面仍可操作，关掉窗口后不要又弹出旧结果。

### 验收标准 / Acceptance criteria

- 我能看到命中的漫画、字段和具体规则，调整规则后结果更新。
- 扫描不改变收藏内容、位置、时间，也不重新开启收藏隐藏。
- 反复扫描、修改规则或退出窗口时，旧结果不会覆盖新状态。
- 不同来源的漫画不会混淆，不为扫描逐本联网请求详情。

### 我的使用环境

- 应用：1.18.4-rc.1（官方原版）
- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

本地漫画、收藏或数据 / Local comics, favorites or data

### 平台 / Platform

Android 手机／平板 / Android phone or tablet（我的使用平台；也欢迎其他平台提供同样体验）。

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 实现参考与已有讨论

<details>
<summary>已有实现参考与相关讨论（供维护者参考）</summary>

这是一个明确触发的只读检查入口，可以与封面预览配合，不要求在收藏列表重新应用屏蔽。

- [test/features/settings/keyword_rules_widget_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/settings/keyword_rules_widget_test.dart)

</details>

### 提交前确认 / Checklist

- [x] 我已检索相关建议，这一条聚焦一个使用需求。
- [x] 我希望改进的是应用本体的操作体验。
- [x] 我已检查正文，没有包含私人内容或凭据。
