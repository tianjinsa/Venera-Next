# [Bug]: 详情位于根导航器时，标签或作者搜索错误进入下层主导航器

<!-- feedback-id: U11; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题类型 / Issue type

界面、导航与交互 / UI and interaction

### 应用版本 / App version

源码对照：CyrilPeng/Venera-Next main@482810df369d126e4011be31d64408e33aede76f（版本元数据 1.18.4-rc.1+250）。组件复现运行于 fork 对应实现，不冒称官方安装包整体验证。

### 平台 / Platform

其他（请说明） / Other (please specify)：源码层核对；最小组件验证为 Linux 云端，不能据此声明各发行平台均实测。

### 设备与系统 / Device and OS

组件环境为 Linux、仓库锁定 Flutter 3.41.4；本项原版设备型号、系统/刷新率未单独采集。

### 复现步骤 / Steps to reproduce

1. 在组件夹具中建立根 Navigator 和页面内主 Navigator，主导航器保留列表。
2. 将漫画详情放到根 Navigator，提供可返回 search 目标的标签/作者动作。
3. 点击标签或作者，记录两层 Navigator 的新路由。
4. 退出详情，检查搜索是否错误留在下层列表。

### 预期行为 / Expected behavior

标签/作者搜索与后续漫画卡片使用当前页面所属导航器；搜索→详情→原页面的返回顺序正确，保留查询、来源、选项和 Hero。

### 实际行为 / Actual behavior

`ComicPageActions.onTapTag` 忽略详情自己的 context，硬编码 `appNavigation.mainNavigatorKey`。组件双导航器路径中，搜索被推到下层而被详情遮住；普通 ComicTile 默认打开详情也依赖全局主导航器。

### 问题位置与操作方式 / Affected screen and input

限定条件：详情位于根导航器。用户本轮是在 fork 的“屏蔽原因封面”入口观察到问题，但原版没有这个新增入口，不能把该入口写成原版操作步骤。本稿报告上游通用详情动作在双导航器下的组件级问题，不宣称原版该菜单存在。

### 诊断提供方式 / Diagnostic source

界面类日志选填；下方提供源码/组件证据。

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/comic_details/actions.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/comic_details/actions.dart#L387)；[lib/features/comic_widgets/comic_tile.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/comic_widgets/comic_tile.dart#L221)

通过原 `onTapTag` 方法的双导航器夹具核验推入的 Navigator 及 SearchResultPage 参数；不依赖特定第三方源。

### 日志无法取得的原因 / Why diagnostics are unavailable

界面/布局/导航报告按上游表单可不附日志；没有编造错误日志或设备性能数据。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/comic_details/tag_navigation_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/comic_details/tag_navigation_test.dart) 的普通/根导航器、标签/作者、推荐卡片及返回链路。上游回移时把测试入口改为根路由夹具，不能依赖上游没有的原因封面/作者规则功能。

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

已检索上游收藏、阅读和关键词相关讨论；本稿聚焦这一项独立行为。发布时可再核对新增讨论。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
