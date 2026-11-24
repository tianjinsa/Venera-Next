# 手机界面第四轮：从实际操作改，保留业务契约

`codex/agent-center-tab` 基线 `2124abbdd29a257ac27dd2ee4e7e2e7258dfc702`（开工时实时 fork 与本地一致），产品与测试定稿 `be66d9a2d513083d09554b7e70706c33a360174b`。保留 Flutter 3.47.9、Dart 3.13.7 和 [Prism 8f5fc22](https://github.com/chen08209/prism_ui/tree/8f5fc22ca1a6bccb064589494ca69cedb38edb50)。只调整 Android/iOS 的手机界面；非手机、TV 与既有设备限制保留。

## 操作与实现位置

| 改动 | 实现及约束 |
| --- | --- |
| 收藏目录的左侧面板 | 点当前目录名，从物理左侧以可用安全区的 40% 宽、86% 高打开。右侧把手的横向拖动让宽度与高度同步增长，最大态仍保留系统安全区和最小外边距。向左先收窄，再继续拖才关闭；保留障碍层点击、返回键、缩放无障碍动作和减少动效。窄态名称使用整行，数量挪到下方，点展开箭头不会误选目录；扩宽、IME 和滚动不会换搜索框。`mobile_side_sheet.dart`、`favorite_folder_browser.dart`、`mobile_folder_sheet_widgets.dart`。 |
| 搜索从触点生长 | 从首页搜索栏、顶栏搜索、搜索框提交、实际详情／分类标签、已存作者和标签以及搜索历史的真实可见控件直接展开。点击位置只偏置液态肩部，首帧矩形是触发控件本身。使用锁定 Prism 的公共 `gooPairOutline`，内部实色 alpha 为 255，完成几何扩展后保留不透明底色并渐显目标页，关闭时反向收回，不先移动／分离。实体键和无障碍激活用控件中心，减少动效不播放。`mobile_search_route.dart`、`mobile_global_search_bar.dart`、`page_jump_target.dart`。 |
| 搜索页控件 | 使用实际 Prism 搜索输入、绑定来源选项的胶囊、聚合开关、设置行／长列表锚定筛选、新材质建议与历史、收藏作者／标签及聚合来源标题。独立更多按钮、长按、鼠标右键和普通点击各保留用途；自动补全仍只编辑查询，链接和漫画直达保持原目标，结果页的原位重新查询不额外推入路由。源插件返回专用分类或普通搜索时保留 source key、类别、参数等。`lib/features/search/`。 |
| 关键词表单 | 屏蔽原因面板不改为选择菜单；点原因打开实际关键词表单的手机版。使用 Prism FormSheet、输入、动作按钮和共用选择／开关行，编辑、测试匹配、重复与空白验证和原保存/失败路径均保留。减少动效时以无动画文本显示当前选项，规避锁定 Prism 在零时长下的布局问题。`keyword_blocking.dart`、`mobile_choice.dart`。 |
| 调节画面 | 保留底部拖动层和图像渲染入口；夜间调暗开关／强度换为手机 Prism 组件。亮度、线条增强和夜览强度使用行内草稿，拖动只更新局部预览／重绘滤镜，显示读数不重排滑轨；手势被取消或只拖面板时不保存，结束调节后按原设备／全局／本书作用域保存一次。没有更改翻页机制、图片请求和画廊状态。`reader/brightness.dart`、`reader/reader_appearance.dart` 与两个 `settings/reader_*.dart`。 |

## 复测与限制

1. **89 项锁定版 Flutter／Prism 的定向控件回归通过**。包括 40%/86% 的真实面板、拖动中间值、最大值、撤销／返回、RTL 和大字号目录；搜索真实锚点、形状连续、扩展面采样不透明、目标淡入、反向和减少动效；搜索行的单击、长按、次键与独立菜单；调整画面从 95% 到 100% 滑轨不位移、垂直拖面板与取消不写入、横拖释放仅保存一次。主要测试在 `test/components/mobile_{side_sheet_round3,folder_sheet_widgets_round3,search_route,search_morph_round3}_test.dart`、`test/features/search/mobile_search_widgets_test.dart` 及 `test/features/reader/brightness_test.dart`。
2. **1 项实际屏蔽原因 → 新表单的整段交互通过**，在可控内存存储／平台端口下验证键盘、空白、重复、取消、标准值菜单和一次改名写入。真实 Flutter 用例入口 `test/features/settings/keyword_rules_widget_test.dart`，隔离夹具省去完整 App 的存储和初始化。这 90 项不包含完整 App 的收藏数据库、来源载入或三级设置持久化回归；更多入口在 `test/features/favorites/local_favorites_refresh_test.dart`、`test/features/comic_details/author_navigation_round3_test.dart` 和 `test/features/settings/reader_settings_persistence_test.dart`。实际颜色滤镜与绘制身份回归见 `test/prime_migration/reader_color_effects_test.dart`。
3. 同源离线分析有 **68/166** 个可用锁定依赖，35 个改动 Dart 文件里 8 条基线诊断均已存在，**没有新增**；结构导入、架构分类、简繁翻译覆盖与 Git 差异检查通过。

完整锁定依赖拉取受限，不宣称完整 `flutter analyze`、全量测试、已推送、已出 APK 或已经用真机量得帧率。真机优先观察：横向拉目录同时输入/滚动、实际特殊来源标签往返与键盘、深浅色/玻璃/减少动效、打开画面面板并连续拖亮度和颜色滑块。观察到底层 jank 时应区分弹层布局、绘制与图片加载，不由局部组件测试推断设备性能。
