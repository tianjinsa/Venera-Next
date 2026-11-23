# Android/iOS 手机 UI 整改与验收

> 本文记录第一轮。半屏菜单、阅读器悬浮控件、搜索和卡片的后续变化以[手机交互第二轮](mobile_ui_round2_20261123.zh.md)为准。

**基线** `d75a8d88b07d4972aa7086f4ee2a9e2e072c7bbc`，**产品代码** `7d813c1dc3e998af351d48751a7905e5ee1d7036`，分支 `codex/agent-center-tab`。沿用仓库定义的手机 UI：Android/iOS、非 TV、宽度不超过 600 个逻辑像素。不靠屏幕宽度把 Windows 或 TV 当成手机。平板双栏、桌面和 TV 保留原分支，阅读器墨水屏保留其低动效路径。

版本不变：Flutter **3.47.9**、Dart 3.13.7，Prism UI **0.1.3** 固定 Git 提交 `8f5fc22ca1a6bccb064589494ca69cedb38edb50`。没有改 pubspec、锁文件、依赖源码、数据格式、服务端能力、工作流或发版设置。

## 已接入的界面及真实行为

| 入口 | 交付 | 实现/回归入口 |
|---|---|---|
| 主页面底栏 | 五个目的地使用原版 NavigationDock 和镜片，作为顶层叠放的子项，不再占 Column 的整块高度。正文画到屏幕底部，胶囊外不加背景或全宽拦截层。末项单独留白，Agent 固定输入区避开底栏；保留 IME、徽标与原生拖动取消。 | `components/navigation_bar.dart`、`mobile_dock_inset.dart`、`scroll.dart`、`features/agent/agent_page.dart`；`mobile_navigation_overlay_test.dart` |
| 全局／Agent 设置与返回 | 设置直接点击自己的带标签按钮；其它真正的多项入口仍开菜单。Android 主 Activity 明确禁用预测性返回，移除路由进度监听器和预测性 transition；普通返回仍走既有 Navigator/PopScope。iOS 保留原来的边缘手势，菜单子层仍先折叠。 | `AndroidManifest.xml`、`foundation/app_page_route.dart`、`components/navigation_bar.dart`、`features/agent/agent_page.dart`；`edge_back_gesture_test.dart`、`mobile_ui_test.dart` |
| “更多”、短选项 | 保留 Prism 的 PopupAnchor、PopupMenu、槽位快照、子菜单和整个按压识别器。该固定版本的普通叶子会等 `route.completed`；应用仅用其公开的 `keepsOpen` 同步提交入口，先 pop 当前菜单再调用原回调。手指掠过不执行，取消不提交，真正需要保持打开的项照旧；不等待收起结束才导航。对异步按钮只在可用/选中状态改变时刷新其内部按压控件，不重建整个顶栏。 | `components/mobile_ui.dart`、`mobile_choice.dart`、`adaptive_action_menu.dart`；`mobile_popup_commit_test.dart` |
| Agent 历史、展示、队列、模型 | 历史和展示跟现有模型选择一致用 `prism.showSheet`，默认 90% 高度；保留底部安全区，长列表使用一个主要滚动容器，滚到顶再拖手柄关闭。历史条目返回选中的会话，返回／下拉不换会话。队列、服务商模型发现也接入；设置列表、表单、保存按钮、聊天输入/发送复用 Prism。 | `features/agent/agent_mobile_sheet.dart`、`agent_{page,history_view,showcase_view,queue_view,model_picker,settings_widgets}.dart`；`agent_mobile_surfaces_test.dart` |
| 设置与选择器 | 普通 ≤6 项从当前值锚定展开、带选中勾；更多选项或明确要求搜索则开可滚动 Sheet。自定义层级文件夹走可搜索的业务选择页。共享 FormField 提供禁用、validate/reset/save；使用业务值而非翻译或列表序号保存；已打开的面板不把选择写给新接管的表单。覆盖阅读模式、来源选项、WebDAV 间隔、关键词、同步计划、Agent 设置及日志筛选。原有三档玻璃分段保留。 | `components/{mobile_choice,select,select_dialog}.dart`、`features/settings/{mobile_setting_row,setting_components,reader_mode}.dart`、`features/comic_source/comic_source_page.dart`；`mobile_choice_test.dart` |
| 历史、本地／网络收藏 | 依业务区分搜索、刷新等高频动作；列表/画廊、列数、阅读筛选及已有排序归入带当前状态的「更多」分层菜单。选择模式与有选中项时的批量操作分开；不提前显示删除等操作。在多选与搜索间切换保留查询文字，过期选择不能删除新数据。共用文件夹行、选择标记和间距，不改惰性网格、分页、模型或过滤语义。 | `features/{history,favorites,comic_widgets}`、`components/mobile_collection_ui.dart`；`mobile_collection_ui_test.dart` |
| 同类列表 | 本地漫画、图片收藏、稍后再看、追更接入同套快捷操作或更多分组。网络收藏保留来源给出的顺序及原有单项操作，不虚设服务端不支持的排序或批量删除。 | `local_comics_page.dart`、`image_favorites_page.dart`、`read_later.dart`、`follow_updates_page.dart` |
| 阅读器 | 顶底工具栏、亮度面板的开关、章节行和排序、章节评论及回复输入层改手机展示。点击仍进入原来的命令、面板与退出队列；保留隐藏工具栏停 tick、有效输入缓存，以及原有分页、缩放、图像解码、预加载、音量键及进度写入。 | `features/reader/{scaffold,chrome_action,top_bar,bottom_actions,brightness,chapters,chapter_comments}.dart`；`mobile_reader_chrome_test.dart` |
| 漫画详情、来源、通用按钮 | 阅读/下载、收藏动作、标签、封面操作和下载分集执行按钮接入；点击、长按、取消不互相替代。漫画源及仓库的更多菜单保留操作身份核验和卸载确认。共享按钮保留指定尺寸、忙碌禁用、辅助标签和锚点坐标；需要特殊命中方式的图标仍走原路径。手机全屏业务弹层的顶栏换为 Prism，保留原有保存／返回所有者和键盘避让。 | `features/comic_details`、`features/comic_source`、`components/{button,pop_up_widget}.dart`；`mobile_shared_button_test.dart` |

## 残留盘点（不是“全应用零 Material”声明）

逐个核对了 `lib/` 内原生下拉和底部弹层调用点，再沿调用者区分手机入口与非手机回退。不能用全局出现多少次 `Material` 判断是否已经迁移。

- **所有 4 个 Dropdown 构造点均有手机替代路径**：`data_sync_schedule_fields.dart`（同步计划），`webdav_settings.dart`（更新间隔），`keyword_blocking.dart`（匹配模式），`comic_source_page.dart`（来源表单）。剩余构造器只用于非紧凑手机样式的既有分支。Agent 选项、阅读模式和自定义 Select 原先不一定叫 Dropdown，也已另行接入。
- **所有 5 个 `showModalBottomSheet` 调用点均为回退**：Agent 的历史、展示（同文件两处）、队列、模型页头、设置选项。手机常规历史/展示不再走 Material 高抽屉。长选择、来源自定义文件夹和有业务结果的 JS 选择器使用的不是无返回值的装饰性面板，仍保留原生结果和关闭的所有权。
- **有意不替换核心行为**：阅读器实际页码/亮度拖动仍保留原滑杆的页码读屏、键盘及取消/提交语义；所锁 Prism Slider 的默认语义是百分比、取消也走 `onChangeEnd`，不能逐个换名。章节分组 Tab、受管理的设置/评论侧栏、阅读表面及原生图片处理、文件选择、权限、系统分享等不重写。
- **本轮尚未逐项统一的 UI**：搜索建议/标签与来源脚本编辑器、同步/导入/导出的复杂确认、图片收藏的日期和数值筛选、关联收藏的同步参数弹框，以及部分设置帮助、独立筛选/批量操作对话框仍有 Material 或既有自定义组件。卡片长按的定位式上下文菜单保留已有路由身份、取消与清理策略。Agent 的破坏性二次确认、消息富文本、模型选择内的一些控件也不是全量替换对象。不要把提交理解成这些页面都经真机视觉验收。
- **系统／桌面边界**：外层 Material/Scaffold 还承担主题、Ime、语义与路由宿主；宽屏、桌面、TV 的回退控件应保留。不在每张卡上加玻璃，不重画 Prism 的弹簧、按压或拖尾。

可复查的检索入口（限定产品源码，不扫 Flutter 或依赖库）：

```sh
rg -n 'showModalBottomSheet|DropdownButton(FormField)?<' lib
rg -n 'MobileUi.enabledOf|MobilePopupAnchor|MobileChoice|MobileMenuButton|prism\.showSheet' lib/components lib/features
rg -n 'PredictiveBack|enableOnBackInvokedCallback' android lib
```

## 这次实际验证了什么

- 产品提交 `7d813c1`：`git diff --check`、仓库导入边界、架构依赖边界通过（新增 7 个展示层文件登记为 UI，没有放宽允许的业务依赖）。Android 主 Activity 的 XML 和 Dart 路由入口已核对。
- **隔离组件回归：32/32 通过**。实际使用以上 Flutter/Prism，包含菜单提交与取消、当前值锚定和表单/失效目标、书库行、底栏真实几何及单击设置、共享按钮切换忙碌/禁用、原有边缘手势（12 项），以及真实 Agent Sheet 包装层的一项滚动/下拉用例。夹具复用产品控件/测试，将应用存储、翻译等宿主输入替换为最小测试实现；它没有启动完整 Venera，会话数据库和 Reader 设备集成不在该数字里。不要从此推导出真机动画流畅或性能提升。
- **离线差分分析：不是完整 analyze 通过。** 相同 SDK、Prism 和实际可获得的 75/166 个锁定依赖分别分析基线和产品代码；75 个变更 Dart 文件中余下 45 项诊断均与基线相同（缺失依赖），没有新增错误、警告或提示。此过程曾发现并修正实际接线错误。
- 完整应用 `flutter pub get --enforce-lockfile` 因环境无法完成 pub.dev 的锁定依赖解析而未完成，另一次限时 180 秒的尝试超时。没有篡改依赖或用跳过项冒充通过。**未跑完整 Flutter 静态分析、App 级组件全集、Android/iOS 构建或真机。** 本地补齐 SDK 和依赖后，建议首先运行：

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub test/components/mobile_ui_test.dart test/components/mobile_navigation_overlay_test.dart test/components/mobile_popup_commit_test.dart test/components/mobile_choice_test.dart test/components/mobile_collection_ui_test.dart test/components/mobile_shared_button_test.dart test/foundation/edge_back_gesture_test.dart test/agent/agent_mobile_surfaces_test.dart test/agent/agent_page_test.dart test/features/reader/mobile_reader_chrome_test.dart
```

## 设备验收顺序

1. Android 和 iOS 各选一个有底部安全区的设备。首页与收藏中滚动对比胶囊两侧和下方的运动内容；滚到最后一项仍能完全看见/点到。按住镜片跨几个标签，先取消、再松手选中；Agent 输入区开合键盘、转横屏再恢复。
2. 在手机窄屏分别点击全局设置与 Agent 设置，一次打开。用「更多 → 显示/排序 → 选项」，分别试轻点、滑选、移出后松手、按住取消；改变发生在松手当下。Android 返回先退子菜单、再关主菜单、再退页面；系统后退不应跟随手指预演页面。iOS 边缘手势取消不退页。
3. Agent 历史/展示造出能滚过一屏的数据；列表中部可正常滚动，回到顶部下拖关闭；打开后返回不切会话，选中某条只切一次。切换深浅色、放大系统字号，检查底部系统区域、按钮标签和选项勾选。
4. 用已有的大收藏反复搜索、进入/退出多选、切换文件夹，本地/网络分别检查「更多」的项及受支持操作；不要为测试删除真实收藏。用同一本已缓存漫画，在冷却好的 120 Hz 手机上复测横向手动和长按音量连续翻页，按相同来源、方向、缓存、温度对比 VSync/长尾。此处是验收步骤，不是测量结果。
