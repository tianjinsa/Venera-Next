# 源仓库问题归因与反馈入口

2026-11-13 复核源仓库 `CyrilPeng/Venera-Next/main@482810df369d126e4011be31d64408e33aede76f`。本文件是精简索引，详细步骤/证据/上游 YAML 表单字段已分别写入 [doc/feedback](../feedback/README.md)。**尚未创建外部 Issue/PR。**

## 新会话直接入口

- [独立反馈稿索引](../feedback/README.md)：12 份缺陷/组件问题，6 份功能建议。
- [集中 PR 交接](../feedback/upstream-pr-handoff.md)：基线、用户原版验证、实现/回归映射、一个新分支/一个 PR 的方案、已验证和中断范围。
- [分支保留登记](branch-change-register.md) / [迁移记录](migration.md)：保留二次开发功能，不等同于所有项目都适合回移上游。

用户本轮所称“2/4”对应旧待原版验证表中的 **用户编号 2（U06 收藏详情过场）/4（U07 阅读初帧透明）**。用户已确认原版 **1.18.4-rc.1、Android 15、骁龙 7gen2+、12 GB 内存** 存在这两项，设备型号由用户提交时手动填。不得再写成“尚未原版复现”，也不要混为 U02/U04。

## 缺陷与有明确条件的组件问题

| 编号 | 问题及证据范围 | 反馈稿 |
| --- | --- | --- |
| U01 | 收藏夹选择“全部”仍逐本查历史，无关设置更新反复遍历大列表；源码及组件/逻辑路径；不代称原版设备帧率实测 | [U01](../feedback/U01-favorites-history-queries.md) |
| U02 | 设置保存时移除原开关或选择器，导致控件宽度及文字布局变化；源码及组件/逻辑路径；不代称原版设备帧率实测 | [U02](../feedback/U02-settings-control-layout.md) |
| U03 | 夜间调光保存时快捷面板高度变化，预览又刷新整个阅读外壳；源码及组件/逻辑路径；不代称原版设备帧率实测 | [U03](../feedback/U03-brightness-panel-rebuild.md) |
| U04 | 阅读进度开启总数或紧凑显示后丢弃已保存的实际章节名称；源码及组件/逻辑路径；不代称原版设备帧率实测 | [U04](../feedback/U04-history-chapter-title.md) |
| U05a | 跨章瀑布流在章节和页码未变时反复通知阅读外壳；源码及组件/逻辑路径；不代称原版设备帧率实测 | [U05a](../feedback/U05a-waterfall-shell-updates.md) |
| U05b | 画廊在页面构建中重复执行同一位置的预取请求；源码及组件/逻辑路径；不代称原版设备帧率实测 | [U05b](../feedback/U05b-gallery-prefetch-in-build.md) |
| U06 | 从收藏封面进入漫画详情时，页面过场和封面衔接不一致；原版用户已确认 | [U06](../feedback/U06-favorite-detail-transition.md) |
| U07 | 进入阅读器的初始过场透明，短暂露出上一页内容；原版用户已确认 | [U07](../feedback/U07-reader-transparent-entry.md) |
| U08 | 图片下载进度逐分块刷新 ComicImage，滑动时产生密集重建；源码及组件/逻辑路径；不代称原版设备帧率实测 | [U08](../feedback/U08-image-progress-rebuilds.md) |
| U09 | 瀑布流上方图片加载为真实尺寸时，正在阅读的下方页面异常上移；源码及组件/逻辑路径；不代称原版设备帧率实测 | [U09](../feedback/U09-waterfall-image-size-anchor.md) |
| U10 | 瀑布流前章预取晚到时跳回旧页，并丢失当前页面的局部偏移；源码及组件/逻辑路径；不代称原版设备帧率实测 | [U10](../feedback/U10-waterfall-prepend-stale-position.md) |
| U11 | 详情位于根导航器时，标签或作者搜索错误进入下层主导航器；双导航器组件条件；原版没有原因封面新增入口 | [U11](../feedback/U11-detail-nested-navigation.md) |

U05 保留原编号并拆为 U05a（瀑布流重复外壳通知）、U05b（画廊构建期预取）。U08–U10 是本轮新增的分块进度、图片尺寸及前章晚到路径，分别报告，不混称同一个已证实的卡顿根因。

## 交互/功能建议

- [E01：用户主动收藏、导入和追更的列表可保持完整，关键词屏蔽主要用于发现与搜索](../feedback/E01-selected-lists-keyword-scope.md)。
- [E02：阅读返回可先完成退场，后台保存并保留可查看的错误状态](../feedback/E02-reader-background-save.md)。
- [E03：封面进度提供可选的固定尺寸紧凑图标，保留完整进度说明](../feedback/E03-compact-cover-progress.md)。
- [E04：关键词屏蔽原因窗口提供可选封面预览和详情入口](../feedback/E04-keyword-reason-cover-preview.md)。
- [E05：从关键词屏蔽原因编辑规则时，可以直接删除当前规则](../feedback/E05-keyword-reason-delete-rule.md)。
- [E06：关键词管理提供本地收藏只读扫描，用于检查可能的误伤](../feedback/E06-scan-favorites-keyword-matches.md)。

这些是原版现有设计的调整/功能扩展，不是已证实的数据损坏。上游没有 Agent、作者独立屏蔽、fork 的线条增强/夜览和每日统计，不将对应适配当作源仓库缺陷。

## 已排除的错误归因与历史证据

- `Navigator.of(navigatorKey.currentContext)` 能返回该 Navigator 本身，旧探针已排除“必然进入父 Navigator”的说法。U06 用户确认现象，根因仍需由实际路由/Hero 证据支持。U11 则是明确双导航器条件下，标签动作主动硬编码另一个全局导航器的问题，不能混为一谈。
- 上游已传递收藏详情 heroID，且已修复导航控制器生命周期的一条已确认路径；不声称 heroID 完全缺失或 #129 已彻底解决。
- #118 的 PhotoView 反复销毁路径已修复。当前 main 的稳定 PhotoView key 应保留，U05b 只报告构建期重复预取。
- 上游 `218f102` 起已修封面状态范围、大字号与 Select 布局；`482810d` 又加入菜单锁、白边裁剪、收藏交互等。未经新证据不重复列为未修复缺陷。
- 2026-11-13 检索相关主题并读取 #93/#112/#115/#118/#125/#129：前五项 closed；#129 open/awaiting-feedback；#125 虽 closed 仍带 investigating 标签。状态仅描述该日读取，不替代本报告的范围判断。
- 初始 2026-11-10 的 5 项探针基于 `218f102` 对照及 fork 未变基础设施：证实 1200 次不必要历史查找、已知章节名丢失、保存期间 Switch 卸载，以及 fork 保留 Switch；导航探针用于排除错误归因。未宣称运行完整纯净主线整包。
- 本轮图片尺寸/进度/导航复现用可控夹具，详细实际输出与限制已写入各稿及交接。Prime 的旧真机性能报告不能当作当前 Next 的帧率数据。

发布时使用稿件所链接的上游表单，一项一个 Issue；未来全部拟提交项按用户要求集中一个上游 PR。测试默认在 GitHub Actions，Cloud 不重新执行长测试或重新整理全部历史日志。
