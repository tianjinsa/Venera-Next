# 源仓库 main 问题归因与 Issue 候选

核对时间：2026-11-10。源仓库：[`CyrilPeng/Venera-Next`](https://github.com/CyrilPeng/Venera-Next)。本文是待选草稿，**未创建 Issue**。

## 对照范围与证据边界

- 最新源仓库 main：`218f1028108be376613e6130e096bb675c3d19e4`；fork/迁移基线：`5eccbc7fa3361c2385d670ba9c54161bcb3cf95b`，两者之间只有一个上游提交。
- 本分支修复：`d28e4bd`；长期保留要求见[分支登记表](branch-change-register.md)。本分支的改进包含原有行为调整和新功能，并非全部都是源仓库缺陷。
- 以下已确认项经过最新 main 源码核对。另取上游设置组件、进度模型和收藏筛选逻辑进行小范围组件/逻辑探针，共 5 项通过：确认 1200 次不必要历史查找、章节名丢失、保存期间卸载 Switch；同时验证本分支保留 Switch。导航探针用来排除错误归因，见后文。
- 探针复用当前分支未变的数据/设置基础设施，不等于运行完整纯净 upstream 应用；没有在原设备对最新 main 测量帧率。性能 Issue 应按[上游采集说明](../user/issue_reporting.zh.md)附阅读诊断及版本/设备信息。章节标题、控件替换等纯界面问题可提供截图或组件复现。

## 优先候选：main 已存在的具体问题

### U01：收藏「全部」模式仍逐本查历史，大收藏与无关设置刷新放大主线程工作

对应用户编号：1、部分 3/11。

建议标题：`[性能] 收藏夹“全部”仍逐项读取历史，无关设置通知会重新遍历大列表`

复现步骤：

1. 使用包含 1000 项以上的收藏夹，阅读状态选择「全部」，不启用封面阅读状态。
2. 切换收藏夹并返回；然后改变无关阅读设置，观察收藏列表刷新。
3. 使用计数器统计 `filterComics` 中的 `HistoryManager.find`，并采集实际设备性能诊断。

实际：上游 `filterComics` 在检查筛选模式之前，对每一项执行 `find`。1200 项「全部」逻辑探针得到 **1200 次历史查找**；它并不需要这些结果。缓存未命中的旧记录还可能读取 SQLite，不能把调用次数直接等同为数据库查询次数。

另外 `_visibleComics` 每次应用规则并复制列表；收藏页任意设置通知会重建及协调选择，通用网格在 widget/设置/历史更新时重新遍历并重建过滤结果和 Hero 映射，放大工作量。

预期：「全部」无需逐本历史查询；已读筛选可缓存并按历史变化失效；无关设置及仅阅读状态更新不重新计算关键词和身份映射。

源码证据：

- [收藏筛选，无 All 快速返回](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/favorites/local_favorites_page.dart#L238-L249)。
- [可见列表与所有设置通知](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/favorites/local_favorites_page.dart#L158-L176)。
- [通用网格重滤及通知](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/comic_widgets/comic_list.dart#L67-L113)。

本分支验证入口：`test/features/favorites/local_favorites_refresh_test.dart`，真实 1200 项收藏验证默认展示零逐项历史查询，同时覆盖选择、无关设置和导航。该结果证明减少工作，不是原设备卡顿时间的测量。

### U02：设置保存时以进度圈替换开关/选择器，控件卸载并可能引起文字换行抖动

对应用户编号：11。

建议标题：`[界面] 设置保存期间替换原控件，导致布局宽度变化和文字闪动`

复现步骤：

1. 在窄屏/大字号下进入阅读设置，选择文字接近换行边界的开关项。
2. 调整开关；在存储较慢时观察其右侧控件与左侧文本。
3. 组件复现可暂时阻塞 `AppDataOperations` 的写入准入，再点击开关，检查原 `Switch` 是否还存在。

实际：上游 `saving ? _savingIndicator : Switch(...)` 导致保存期间 Switch 消失；逻辑/组件探针确认。选择器也有对应替换分支。不同宽度的控件和进度圈可能改变文本可用宽度及换行。

预期：保存期间保留原控件 Element 和布局尺寸，可叠加小保存状态或禁用输入；持久化错误/重试及退出等待继续有效。

源码证据：[Switch 的保存分支](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/settings/setting_components.dart#L164-L172)。

本分支验证入口：`test/features/settings/setting_persistence_test.dart` 同时断言待保存时原 Element 和标题矩形不变，以及完成后真实写盘；不只是检查最终布尔值。

### U03：夜间调光快捷面板保存时高度变化，亮度预览刷新整个阅读外壳

对应用户编号：10 的滑条闪烁部分、部分 11。不涉及本分支新增线条增强/夜览功能。

建议标题：`[界面/性能] 阅读器调光滑条保存时面板跳动，并触发大范围重建`

复现步骤：

1. 阅读器点按屏幕，打开夜间调光快捷面板，启用调光。
2. 连续拖动滑条并松手，在较慢存储或大字号下观察面板高度和布局。
3. 通过 widget build 计数或性能诊断，检查调光是否触发与亮度无关的阅读子树刷新。

实际：快捷面板加入 `settingsSaveStatus`，保存期间动态插入带 padding 的进度圈，前后高度不同；亮度预览监听直接调用外壳 `update`，持久化的亮度设置又同时发出 rebuildShell/rebuildReader。

预期：亮度预览只刷新遮罩；保存状态不改变快捷面板布局；图像/缩放状态不受调光重建干扰。

源码证据：

- [快捷面板保存状态](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/settings/reader_brightness.dart#L123-L140)。
- [动态状态行](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/components/settings_save_state.dart#L283-L304)。
- [预览监听刷新外壳](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/reader/scaffold.dart#L133-L135)、[亮度设置效果](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/reader/settings_effects.dart#L85-L94)。

本分支验证入口：`test/features/reader/brightness_test.dart`、`settings_effects_test.dart`、`test/features/settings/reader_settings_persistence_test.dart`。真机闪烁程度需补录，代码上的高度变化及重建路径已确认。

### U04：进度开启总数或紧凑显示时丢弃已保存的实际章节名

对应用户编号：7。

建议标题：`[界面] 阅读进度已有章节名，但显示总数或紧凑模式仍退回“第 N 话”`

复现步骤：

1. 阅读章节名为「番外」「序章」或其他非固定编号的章节，并产生历史记录。
2. 确认记录已有 `chapter_title`。
3. 在带总数的列表/紧凑进度显示中查看该漫画，与普通 description 比较。

实际：只有 `!showTotals && !compact` 使用 `chapterTitle`，否则强制使用 Chapter N；逻辑探针确认同一条带 `Bonus chapter` 的记录，默认描述保留标题，`showTotals: true` 丢弃标题。

预期：已知章节名优先使用，缺失时才退回编号；无需再次请求源详情。`P页数` 属于显示格式建议，可以和实际名称缺陷分开讨论。

源码证据：[章节名条件与页码拼接](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/history/history_model.dart#L155-L172)。

本分支验证入口：`test/features/history/history_progress_description_test.dart`、`test/features/comic_widgets/detailed_reading_progress_test.dart`。相关历史功能建议 [#93](https://github.com/CyrilPeng/Venera-Next/issues/93) 已关闭，提交时应明确这是显示条件遗漏，不是再次请求新增进度功能。

### U05：瀑布流同页滚动重复通知外壳；画廊在构建期间重复请求预取

对应用户编号：12、部分 3。建议按模式分别采集，必要时拆为两个性能 Issue。

建议标题：`[性能] 瀑布流页码未变仍反复通知阅读器外壳`；画廊候选标题为 `[性能] 画廊构建回调重复执行同位置预取`。

复现步骤：准备已经缓存的本地页面，在跨章瀑布流同一页内缓慢滚动，统计 `onUpdate`；画廊则在位置/内容/布局未变的重复构建中统计 `cache(index)`，同时采集阅读诊断。

实际：跨章分支没有普通连续模式的页码变化判断，每次位置检查均 `_setReaderLocation` 和 `onUpdate`；画廊 `_buildPhotoPage` 直接调用 `cache(index)`。这证明重复工作路径存在，尚不能单独证明它们就是用户全部卡顿的唯一原因。

预期：同页同章节不通知位置变化；预取合并相同内容/布局/页码的请求并放到构建帧之后，保持原图像生命周期。

源码证据：[瀑布流通知](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/reader/continuous_view.dart#L545-L554)、[画廊构建中的预取](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/reader/gallery_view.dart#L342-L347)。

本分支回归：`test/features/reader/continuous_owner_test.dart`、`gallery_page_continuity_test.dart`、`gallery_rotation_test.dart`、`reader_exit_integration_test.dart`。

相关 [#118](https://github.com/CyrilPeng/Venera-Next/issues/118) 的 PhotoView 反复销毁路径已经修复并由报告者确认；最新 main 也有稳定 `_GalleryPhotoPage` key，**不能再次写成当前主线仍在每次翻页销毁 PhotoView**。[#125](https://github.com/CyrilPeng/Venera-Next/issues/125) 涉及 WebDAV/首滑问题与解码/QuickJS 路径，不能仅凭相似症状认定同一根因。

## 需要纯净 main 设备复现的候选

| 用户编号 | 候选及当前证据 | 提交前补充 |
| --- | --- | --- |
| 2 | 收藏详情动画/Hero 不一致。本分支改用页面自身上下文；上游使用 mainNavigatorKey 上下文。但 Flutter 的 `Navigator.of(navigatorKey.currentContext)` 会返回该 Navigator 本身，探针已排除「必定找错父 Navigator」的假设 | 纯净 main 在实际嵌套导航结构中录屏、检查源/目标路由与 Hero controller，不能只凭换了 context 就归因 |
| 4 | 阅读入场最初透明。上游 Reader/ReaderWithLoading 没有本分支加入的首帧背景；具体过场效果还受 AppPageRoute/平台转场影响 | 同版本主题、平台与过场录屏，尤其 Android；不能泛称所有平台可复现 |

上游最新 `218f102` 已调整封面进度范围及大字号布局。旧版本「进度文字越出封面/挤压标题」不能未经复测当作最新 main 未修复缺陷。

## main 已有行为，可作为交互或功能建议

| 用户编号 | 建议 | 归因及相关历史 |
| --- | --- | --- |
| 0 | 将关键词屏蔽限定在发现/搜索等场景，用户收藏、历史、稍后再看、追更保持完整 | main 确实会屏蔽这些列表，但 [#115](https://github.com/CyrilPeng/Venera-Next/issues/115) 已确认 `bl` 命中 `black` 并按规则行为关闭；应提过滤作用范围建议，不能写成导入丢数据。Agent 不在 main |
| 5 | 阅读返回改为后台保存，提供右下角小状态与可查看/手动关闭的持久错误 | main `ReaderExitGuard` 先 await prepare 再 pop，并显示 Saving 对话框；这是异步保存阻塞导航，并非已证实同步磁盘 I/O。[等待路径](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/reader/exit_guard.dart#L119-L138)、[提示](https://github.com/CyrilPeng/Venera-Next/blob/218f1028108be376613e6130e096bb675c3d19e4/lib/features/reader/exit_guard.dart#L217-L239)。后台化需保留最终退出等待与错误处理 |
| 6 | 提供紧凑封面进度图标，完整内容留在 Tooltip/无障碍标签 | 详细进度本是 [#93](https://github.com/CyrilPeng/Venera-Next/issues/93) 的功能方向；紧凑模式是显示偏好，不宜直接称功能错误 |
| 8.1 | 屏蔽原因中提供可选封面预览 | main 原因窗口明确写有 `Images stay hidden.`，属于现有设计，可提预览建议 |
| 8.2/8.4 | 原因区域可点击进入编辑，编辑弹窗直接删除规则 | main 原因编辑弹窗没有删除，管理列表另有删除；这是操作路径补全及交互改进 |
| 9 | 关键词管理新增只读扫描本地收藏，发现可能误伤的规则 | 新功能；应明确不会因此在收藏页启用屏蔽，也不修改/删除收藏 |

## 不作为 main 缺陷的本分支内容

- 用户 8.3 的作者规则样式/编辑适配：作者独立屏蔽是迁移功能，当前 main 没有这组实现。
- 用户 10 的线条增强、夜览位置和快捷菜单整合：这两组图像设置是迁移功能；只有原有调光面板的布局/刷新问题归入 U03。
- Agent 各列表、对话、工具和退出适配：main 没有 Agent。
- 本次后台退出实现调试中发现的窗口重复 FlutterError：由新增后台保存路径暴露并在本分支修复，不倒推为原 main 缺陷。
- 后续发现的阅读返回画面提前清空：本分支后台收尾先关闭控制器，而阅读视图在退场完成前显示空白；已保留原挂载视图至路由释放。它属于后台保存改造的回归，不据此认定 main 同样缺少返回动画。

## 提交 Issue 时的使用方式

建议先提交 U01、U02、U04 这三项证据最直接的问题；U03 可附调光录屏；U05 先补纯净 main 阅读诊断。每个 Issue 保持单一问题，使用源仓库对应的[分类表单](https://github.com/CyrilPeng/Venera-Next/issues/new/choose)，写明版本、平台、最小复现、实际/预期及未验证范围。

核对时 #93、#110、#112、#115、#118、#125 的 GitHub 状态均为 closed。关联报告只用于追溯，不声称它们仍开放或本次修复已经复现/解决其全部原始症状。
