# [Enhancement]: 希望已收藏、导入和追更的漫画保持可见，关键词主要过滤发现和搜索

<!-- feedback-id: E01; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 需求场景 / Use case

我希望自己主动收藏、导入或加入追更的漫画能一直在对应列表里找到。现在只要名字等信息命中全局关键词，这些我已经选过的漫画仍可能被隐藏。

### 当前不便与对我的影响

从我的角度看，就是收藏过或导入过的漫画又找不到了，容易误以为没有保存成功。我需要临时关掉规则或来回检查，才能区分是被隐藏还是确实没存下来。

### 建议方案 / Proposed solution

我希望发现、搜索和推荐结果继续按关键词过滤；收藏、本地、历史、稍后阅读和追更这些由我主动管理的列表，能保持完整或提供独立开关。列表内的搜索、阅读状态筛选和多选仍按我的当前选择工作。

### 验收标准 / Acceptance criteria

- 命中关键词的已收藏/导入漫画仍能在对应管理列表找到。
- 发现、搜索和分类继续遵守屏蔽规则。
- 修改屏蔽词不会意外改变我已选中的收藏项。
- 不会删除、移动漫画或改变已有备份、同步与规则选项。

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

这是对过滤范围的交互建议。#115 的关键词命中行为已有结论，我希望补充的是已选内容的可见性控制，不把它说成导入丢失数据。

- [test/features/comic_widgets/keyword_filter_consumers_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_widgets/keyword_filter_consumers_test.dart)
- [test/features/local_comics/local_archive_visibility_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/local_comics/local_archive_visibility_test.dart)

</details>

### 提交前确认 / Checklist

- [x] 我已检索相关建议，这一条聚焦一个使用需求。
- [x] 我希望改进的是应用本体的操作体验。
- [x] 我已检查正文，没有包含私人内容或凭据。
