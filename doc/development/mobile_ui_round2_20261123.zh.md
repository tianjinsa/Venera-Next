# 手机交互第二轮：设置、搜索、阅读器和书库

**从哪里接续：** 开始前核对了 fork 远端和本地 `codex/agent-center-tab`，两者都是 `36e67fec59906ab0289ac5a8cac459a5044cd11c`。本轮产品代码截至 `b9f41bb8a5b0b1ccb8143bf11fc61af3cd8ab6e0`，含最后一项真实设置页用例的验证版本是 `cae2296bf77acf6a718fb98d6b5496b1dce2302e`。不修改依赖、锁文件、数据格式、CI 或发版配置。新样式只用于既有 Android/iOS 窄屏作用域（宽度 ≤ 600，排除 TV）；阅读器另外排除墨水屏模式。本文补充而不覆盖[第一轮记录](mobile_ui_remediation_20261123.zh.md)。

## 哪里改变了

| 操作 | 现在的行为与实现 |
|---|---|
| 选择设置 | 普通设置不再因为小于 450 就把选项放到标题下面。全局/漫画阅读模式、可选择的收藏夹、Agent、代理、同步及来源表单共用标题与值分栏的布局；标题可换行，值按钮靠末端，长值显示省略，可打开查看完整选项。说明和校验信息仍可占用整行。玻璃强度是三档分段控件而非下拉，保留宽行。见 `mobile_choice.dart`、`setting_components.dart`、`reader_mode.dart`。 |
| 快捷和多选 | 一颗快捷胶囊最多两个动作。「更多」不跟随胶囊按压；正常态的「多选／管理对话」从「更多」进入，仍支持原有长按。进入选择后可直接取消、全选或执行适用于当前选区的操作，危险操作沿用原确认。只有一项普通命令时不为它额外开菜单；多选入口是用户指定的例外。Agent 设置仍直接进入；聊天的更多项保留新建和展示，展示计数保留在锚点上。不为网络收藏等没有多选／本地搜索的页面虚构能力。 |
| 阅读器 | 顶栏不再画整块底色，底部也不再铺背景；标题用文字阴影保持可读，玻璃只在控件上，组外空隙不吞本应落在画面上的点击。收藏当前图、调整画面组成快捷组，旋转、自动阅读、章节、保存和分享仍按能力可达。页面进度、前后页、菜单锁、亮度预览及持久化沿用旧命令。画面调整从底部进入共用面板，复用原亮度、线条增强和夜间颜色等实际设置；切换漫画时只退役这张面板，不弹出压在上面的别的页面。原有完整设置、章节和评论的业务侧栏不是这一类底部菜单。未改 Gallery、音量键、图片加载、预缓存和数据库路径。 |
| 大底部菜单 | 统一用 `mobileLargeSheetRoute`（可按确切路由撤回）或 `showMobileLargeSheet`（直接调用）。默认占可用高度的 50%，左右各留约 8 个逻辑像素，上拉到 90% 高度时是满宽；**宽度随手指进度连续变化**，不是松手才切样式。列表首先扩张面板，再交给主要滚动容器；下拉可回到较小档或关闭。处理底部安全区和键盘，无数据或筛选剩一项也可拉开。应用于 Agent 历史／展示／队列／模型、长/可搜选项、层级收藏夹、图片收藏筛选、搜索结果筛选和阅读画面调整。不改变短菜单的锚点或用一个弹框替代整页设置。 |
| 全局搜索 | 主标签中原来的首页搜索栏，或其它根标签的顶栏搜索按钮，均以自己在当前 Navigator 内的真实矩形为起点，圆角玻璃展开到整个页面；两种入口不必在同一标签重复显示。详情的标签／作者进入来源提供的**搜索目标**时从点击处展开并保留原来源、文字及选项；原本是分类或其它目标的标签不强行改成搜索。返回时往入口收回，减少动态效果走即时路由。进入全局搜索后再请求输入焦点；直接打开结果页不强行弹键盘。输入框使用 Prism TextField 保留长 URL。Android 不重新开启预测性返回，iOS 保留原边缘返回。 |
| 局部搜索 | 本地收藏、历史、本地漫画和图片收藏中，按搜索图标展开为**真正的 Prism SearchField**。用同一个控制器正／反向改变同一外形，中途反向从当前宽度继续；真实字段按最终宽度布局，不在动画的每一帧重新排版列表。查询由业务页持有；临时进出选择模式不清空，显式关闭按各页原约定退出／清除。Prism 0.1.3 的 SearchField 内部限制为 256 个字符，本地列表沿用原件，不把这一限制加到全局搜索。 |
| 回到顶部 | 首页和来源发现页各使用正在显示列表的滚动控制器。向下滚超过 240 个逻辑像素显示向上箭头；发现页回到顶部之后，该位置恢复刷新。按钮避开悬浮 Dock 已包含安全区的实际空间，没显示 Dock 时只用系统边距。减少动态效果直接到顶部。 |
| 卡片与列表 | 七类首页摘要、发现分组标题、通用漫画行与画廊卡片、收藏夹文件夹行共用 `MobileContentSurface`／`MobileContentRow`。玻璃开启时使用 Prism 的卡片色阶、连续角和静态色泽/边缘，关闭时用实色。**不是每张图片后面都开模糊或 shader**；滚动列表没有新增每项的背景采样。按压、长按、缩略图、惰性创建、选择和分页保持原所有者。特殊业务编辑器及非手机界面不等于全应用换肤。 |

## 和真实 FlClash 的对应关系

固定参考 FlClash 的提交 `afe7136002271fd64f098b154e7fff40be721eb8`。Venera 继续使用 Flutter **3.47.9** 和 [Prism 0.1.3 的锁定提交](https://github.com/chen08209/prism_ui/tree/8f5fc22ca1a6bccb064589494ca69cedb38edb50)。没有把 FlClash 的整套业务脚手架或另一个版本的组件库搬进来。

- [FlClash 选项行](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/ui/list_item.dart)把选择器锚在末端；[_SelectionButtons 和 overflow](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/ui/scaffold/scaffold_actions.dart)至多把两个按钮放进同一组。本项目保留选项值、校验和状态写入的原所有者。
- [Dashboard connections table](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/views/dashboard/widgets/connections_table.dart)将 Sheet 的实际滚动控制器交给列表；[类型化的嵌套 Sheet](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/ui/nested_sheet.dart)传回结果。本项目直接使用锁定版 [SnapSheetRoute](https://github.com/chen08209/prism_ui/blob/8f5fc22ca1a6bccb064589494ca69cedb38edb50/lib/snap_sheet.dart) 的 `detents: [.5, .9], fitsContent: false`；缩放、宽度、弹簧和手势交接是库的实现，不是另写宽度动画。
- [FlClash 访问控制](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/views/access.dart)启用顶栏搜索；[scaffold_search.dart](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/ui/scaffold/scaffold_search.dart)测量入口，分阶段显示输入和旁侧操作。局部搜索用该策略组合库的 GooSurface 和 SearchField。**按钮／标签扩到整页是 Venera 路由的适配**，并不声称 FlClash 有相同业务路由。没有为追求外观而引入 Prism OpenContainer 的整页拖动关闭。
- [DashboardCard](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/views/dashboard/widgets/card.dart)与[配置列表](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/views/profiles/profiles.dart)区分浮在画面上的操作与滚动中的内容层。内容卡沿用这种分层；不要据此宣称不同设备上的折射像素完全相同。

## 已验证与未验证

- 在上述锁定 Flutter/Prism 上，隔离夹具 **58/58 通过**：其中 53 项来自仓库控件/返回手势测试，另 5 项为交叉检查（几何、真实组件宿主与滚动）。包含 244/350 父宽 × 1.0/2.5 字号、半屏到中途再到满宽的实际坐标、IME 选项回传、按确切路由移除、两种源矩形往返、局部搜索按压与快速反向、Dock 命中及在位列表行等。夹具复用产品 UI、替换 App 全局数据等宿主，不是 58 项整包 App 验收。
- **离线差分，不是完整 analyze 通过。** 同一 SDK、同一批可获得的 68/166 个锁定依赖分别分析 `36e67fe` 和 `cae2296`；本次 66 个变更 Dart 文件中有 20 个缺依赖相关的既有错误，**没有新增诊断**。依赖未完整解析。导入与架构依赖检查通过，新文件仅登记为 UI，没有新放行的业务边界。Git 差异检查通过。
- 本轮没有推送、运行 Actions、编译手机包、运行需要完整依赖的 App 级测试或连接 Android/iOS 真机；没有测帧时间，不据控件测试声称已改善阅读帧率。
- 完整环境建议先 `flutter pub get --enforce-lockfile`，再运行 `flutter analyze --no-pub` 和以下与改动相符的 App 级用例。设备验收用同一已缓存漫画/同一 120 Hz 手机、相近温度，分开看手动翻页和长按音量翻页的 VSync 间隔、P95 和最大值。玻璃档位、深浅色／大字、屏幕旋转和键盘下拉都要在 Android 与 iOS 分开看。

```sh
flutter test --no-pub test/features/settings/setting_persistence_test.dart test/features/reader/mobile_reader_chrome_test.dart test/features/reader/mobile_reader_picture_sheet_test.dart test/features/favorites/local_favorites_refresh_test.dart test/features/image_favorites/time_filter_widget_test.dart test/features/comic_details/tag_navigation_test.dart test/features/search/mobile_search_option_test.dart test/agent/agent_mobile_surfaces_test.dart
```
