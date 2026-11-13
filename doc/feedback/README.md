# 上游反馈稿与后续 PR 入口

整理日期：2026-11-13。目标仓库：[CyrilPeng/Venera-Next](https://github.com/CyrilPeng/Venera-Next)，源码复核基线 `482810df369d126e4011be31d64408e33aede76f`。本目录有 **12 份缺陷/组件问题稿、6 份功能建议稿**，另有本索引及交接文档；没有创建外部 Issue 或 PR。

每份稿件第一行可作为 Issue 标题，正文按对应 YAML 表单同名字段填写。GitHub 已关闭 blank issue，网页需要选择稿件所链接的表单，不能把整份 Markdown 直接塞进单一“复现步骤”字段。未来若用户授权通过 API/CLI 发布，可用标题加正文创建；本轮只写文件。

- **原候选 2/4** 指旧文档待原版确认表中的用户编号 2（U06 收藏详情过场）、4（U07 阅读首帧透明），不是 U02/U04。用户已在原版 **1.18.4-rc.1、Android 15、骁龙 7gen2+、12 GB 内存** 验证，两稿已写入；设备型号按用户要求提交时自行填。
- U01–U05 的旧证据保留；U05 按独立路径拆为 U05a/U05b。U08–U10 为本轮新增阅读问题。
- U11 如实限定为双导航器下的通用详情/卡片行为。当前原版不含 fork 的屏蔽原因封面入口；不要用该新增入口声称原版可复现，也不要把作者独立屏蔽或 Agent 一起移植。
- 各稿区分源代码、最小组件与原设备证据。阅读性能稿包含原设备诊断无法取得的具体范围及替代证据，未编造报告或截图；这不保证上游自动材料检查一定不再追问。
- 2026-11-13 检索相关主题并读取 #93/#112/#115/#118/#125/#129：前五项 closed，#129 open / awaiting-feedback；#125 仍有 investigating 标签。发布前仅核对增量讨论，不把旧关闭状态当作新缺陷已解决的证明。
- 后续开发按用户要求：**从上游另建一个工作分支，全部拟提交项集中一个 PR；Issue 则逐项独立**。详见 [PR 交接](upstream-pr-handoff.md)，不从 Agent 整分支提 PR、不整包 cherry-pick。

| 编号 | 可直接使用的稿件 | 证据/性质 |
| --- | --- | --- |
| U01 | [收藏夹选择“全部”仍逐本查历史，无关设置更新反复遍历大列表](U01-favorites-history-queries.md) | 上游源码确认；验证范围见正文 |
| U02 | [设置保存时移除原开关或选择器，导致控件宽度及文字布局变化](U02-settings-control-layout.md) | 上游源码确认；验证范围见正文 |
| U03 | [夜间调光保存时快捷面板高度变化，预览又刷新整个阅读外壳](U03-brightness-panel-rebuild.md) | 上游源码确认；验证范围见正文 |
| U04 | [阅读进度开启总数或紧凑显示后丢弃已保存的实际章节名称](U04-history-chapter-title.md) | 上游源码确认；验证范围见正文 |
| U05a | [跨章瀑布流在章节和页码未变时反复通知阅读外壳](U05a-waterfall-shell-updates.md) | 上游源码确认；验证范围见正文 |
| U05b | [画廊在页面构建中重复执行同一位置的预取请求](U05b-gallery-prefetch-in-build.md) | 上游源码确认；验证范围见正文 |
| U06 | [从收藏封面进入漫画详情时，页面过场和封面衔接不一致](U06-favorite-detail-transition.md) | 原版 1.18.4-rc.1 / Android 15 用户已确认 |
| U07 | [进入阅读器的初始过场透明，短暂露出上一页内容](U07-reader-transparent-entry.md) | 原版 1.18.4-rc.1 / Android 15 用户已确认 |
| U08 | [图片下载进度逐分块刷新 ComicImage，滑动时产生密集重建](U08-image-progress-rebuilds.md) | 上游源码确认；验证范围见正文 |
| U09 | [瀑布流上方图片加载为真实尺寸时，正在阅读的下方页面异常上移](U09-waterfall-image-size-anchor.md) | 上游源码确认；验证范围见正文 |
| U10 | [瀑布流前章预取晚到时跳回旧页，并丢失当前页面的局部偏移](U10-waterfall-prepend-stale-position.md) | 上游源码确认；验证范围见正文 |
| U11 | [详情位于根导航器时，标签或作者搜索错误进入下层主导航器](U11-detail-nested-navigation.md) | 双导航器组件条件已确认，原版原因封面入口不存在 |
| E01 | [用户主动收藏、导入和追更的列表可保持完整，关键词屏蔽主要用于发现与搜索](E01-selected-lists-keyword-scope.md) | 功能/交互建议 |
| E02 | [阅读返回可先完成退场，后台保存并保留可查看的错误状态](E02-reader-background-save.md) | 功能/交互建议 |
| E03 | [封面进度提供可选的固定尺寸紧凑图标，保留完整进度说明](E03-compact-cover-progress.md) | 功能/交互建议 |
| E04 | [关键词屏蔽原因窗口提供可选封面预览和详情入口](E04-keyword-reason-cover-preview.md) | 功能/交互建议 |
| E05 | [从关键词屏蔽原因编辑规则时，可以直接删除当前规则](E05-keyword-reason-delete-rule.md) | 功能/交互建议 |
| E06 | [关键词管理提供本地收藏只读扫描，用于检查可能的误伤](E06-scan-favorites-keyword-matches.md) | 功能/交互建议 |

迁移分支的保留约束见 [登记表](../agent/branch-change-register.md)，上游范围归因见 [候选清单](../agent/upstream-issue-candidates.md)。原版已经合入的菜单锁、白边裁剪、封面状态约束、大字号/选择器布局等不重复列为未解决问题。
