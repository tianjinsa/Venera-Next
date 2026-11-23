# 手机界面第三轮：哪些入口、哪些面板

基线 `387b8923c83076a8d632b8fca4b9429403990715`（开工时 fork 与本地一致）。产品 `cc1be155aa32ce20e4f880c8bb2410850a0f77aa`；含最终无障碍回归用例的源码为 `984ca59a514cbb43edfc61dba18d12e4b3c0facd`。保留 Flutter 3.47.9 和 [Prism 的锁定提交](https://github.com/chen08209/prism_ui/tree/8f5fc22ca1a6bccb064589494ca69cedb38edb50)。手机表示 Android/iOS 窄屏既有作用域，不包括 TV；阅读器保留墨水屏门禁。本轮不调整阅读图片加载、帧调度、数据格式或构建工作流。

## 从哪里进入，就从哪里动

| 入口 | 行为及维护位置 |
|---|---|
| 全局搜索栏、顶栏搜索、详情标签和已存搜索快捷方式 | 以**所点控件**在所属 Navigator 中的可见矩形为源。源在原位交出图标，残滴和离开的主面共享一个轮廓，拉出连接、分离，再扩展为完整页面。玻璃关时使用相同形状的实色材质；返回反向收拢，减少动态效果即时切换。页面按最终尺寸布局，输入焦点和回传值仍归路由。见 `mobile_search_route.dart`、`search_entry.dart`。 |
| 来源作者的特殊页面 | 来源的 `onClickTag` 返回什么，仍打开什么。现有 API 的 `search` 和作者/画师名下的 `category` 都使用点击标签或快捷条目作锚点；后者保留 `categoryKey/category/options/param`，没有翻译成普通关键字。非作者分类继续普通导航；没有伪造第三种来源 API。见 `page_jump_target.dart`、`comic_details/actions.dart`。 |
| 收藏页第二行的局部搜索 | 旧实现只在编辑/多选时才把整个滚动树包进 Focus 和快捷键组件，点击时销毁重建了原来的动画控制器。现在这些祖先与漫画网格保持身份，用同一工具栏从实际图标展开/收回。在 IME 调整空间和切换选择模式时业务页仍持有文字/焦点；显式关闭按原意结束搜索复用已载入数据，不仅为关搜索就重新读大型收藏夹。见 `local_favorites_page.dart`、`mobile_collection_ui.dart`。 |
| 收藏夹侧栏 | 点「当前目录 ›」而不是独立菜单按钮。适用于未选择、本地层级及网络收藏入口。方向固定为**物理左侧浮出、名称右侧箭头**，内容仍按应用文字方向。浮层有遮罩、合适的边角、安全区/键盘避让、返回/取消和独立拖动把手；切换目录仍由原业务回调完成。同一目录或取消不换当前搜索；并非为旧的桌面侧栏翻转整页方向。宽屏保留原布局。见 `mobile_side_sheet.dart`、`favorites_page.dart`、`favorite_folder_path.dart`。 |

侧栏不只是把旧列表放进新外壳：`FavoritesFolderSidebar → FavoriteFolderBrowser` 的手机左侧模式使用专用 `MobileFolderSheetHeader/Section/Row`。本地全部、父目录、子目录和网络目录均为新材质及 Prism ListRow；选中勾选与数量各有空间，数量在窄屏／大字时挪到标题下。点目录选择，点独立箭头只展开/折叠；本地「更多」从真实锚点打开建夹／排序，网络设置和关闭是独立新按钮。长名称保留完整无障碍名字，过期数据目标不会写入。其他业务选择器与桌面列表不被一起替换。

## 对照 FlClash 的设置与原生控件

- [网络设置中的 TunStackItem](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/views/config/network.dart) 通过 [ListItem.options](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/ui/list_item.dart) 显示当前值与上下双箭头。Venera 手机设置采用这个结构：卡组边缘与组内分隔、标题/说明、可整行点击的开关/导航、行末无边框当前值。点击行或值从同一控件弹出有界列表；当前项有勾，长列表靠触摸滚动，点遮罩/返回不保存。使用实际锁定 Prism 的 PopupMenu、PopupValueText、Card、ListRow、ItemPositionProvider、形状与排版。**不直接引入整份 `prism_ui/list.dart`**：它会连带引入本 Flutter 版本没有的 `ScrollCacheExtent`。共用代码在 `lib/components/mobile_{setting_row,choice}.dart`，设置仍由其原来的异步保存者提交。
- 全局和单本阅读模式、发现配置、快捷收藏设置（完整目录路径和 None）、动态来源表单、代理/同步及常规 Agent 设置用值锚点。玻璃强度等本来是分段/滑杆的控件不强改成下拉。**设置的值选择**不因项目多于 7 个就变成底部面板。商品/内容类业务过滤、分层收藏目标选择、聊天模型管理、从服务加载/重试的模型目录和编辑任务不等于普通设置枚举；保留各自交互。
- [真实更多按钮](https://github.com/chen08209/FlClash/blob/afe7136002271fd64f098b154e7fff40be721eb8/lib/ui/scaffold/scaffold_actions.dart) 使用 PopupAnchor；[Prism 的弹出渲染](https://github.com/chen08209/prism_ui/blob/8f5fc22ca1a6bccb064589494ca69cedb38edb50/lib/popup.dart) 有离开源的主面和残滴。搜索用公开 `gooPairOutline`、`LiquidGlassGoo` 与 `LiquidGlassPane` 表达这个过程；**扩为整个搜索页和物理左侧移动的目录弹层是 Venera 适配，并不是 FlClash 原有的同名业务**。Prism 自带的 [SideSheet](https://github.com/chen08209/prism_ui/blob/8f5fc22ca1a6bccb064589494ca69cedb38edb50/lib/side_sheet.dart) 固定在物理右边且有 360 宽度下限，未假设有左向参数。
- 多个快捷按钮依序分成**每组最多两个**，不是限制快捷按钮总数；奇数余项和「更多」独立。窄屏不足以同时放置全部动作时可以横向滚动快捷区，不裁掉命令或遮住返回/更多。非首页主栏的搜索和设置一组，首页不重复显示搜索。阅读器返回与诊断在左边同组，锁与设置在右边，设置位于末端；评论等原功能仍能直接操作，空隙不铺整条玻璃。阅读器自身不更改翻页策略。
- 新内容卡/列表和共用手机设置组的底色从**实际页面背景**向黑色压暗，而非用另一套 seed 重建更亮的卡色；文字/封面不被遮罩压暗，选中项仍有轮廓，玻璃开/关/极致保留。纯黑页没有更暗的颜色，靠边缘分隔。未把这一规则全局套到弹出菜单、图片或桌面主题。

## 排序、屏蔽原因与业务状态

- 详情顺/逆序原来把写入指示器插到分段控件旁，某些宽度会临时换行再跳回。现在写入状态占固定高度，控件和网格均不挪位；单元按「组＋来源章节 ID」识别并映射新位置。仅转展示顺序，不改变来源编号、已读标记、选中的组、各组展开状态或外层滚动位置；支持组间重名 ID。保留立即预览、失败重试和原保存/退出所有权。见 `comic_details/chapters.dart`。
- 关键词屏蔽原因属于查看/诊断，**手机使用底部半屏面板，可上拖扩大并滚动**。入口和原因条目使用新行组件；点封面仍开详情，点原因仍编辑对应规则，返回顺序不变。仍使用原过滤器、批量扫描及保存作用域，未将关键词屏蔽套到收藏列表。非手机保留原对话框。

## 实际验证与边界

1. 锁定 Flutter/Prism 的隔离夹具 **80/80 通过**，覆盖菜单前后位置及取消、32 项设置的末项、分组行/开关、两团液面中间像素、搜索回程与中断、真实阅读器顶栏的 320 竖屏及 RTL 横屏、深/浅色正文对比、真实文件夹标题与左侧弹层的坐标/手势/焦点、238 像素宽及 2.6 倍字号下两种文字方向的目录行与选择/展开等。没有替换被检查的控件，省去了整包平台初始化；这些数字不是 APK 或手机验收。
2. 另用可控数据宿主挂载**实际章节、屏蔽原因、收藏侧栏组件**，**3/3 通过**：348 像素宽、写入挂起期间表头/偏移/键控元素与原章节序号不变；390×800 原因面板从 0.5 到 0.9、收回/关闭、封面和原因分流、根路由及保存作用域保留。实际收藏页侧栏在正式左弹层中渲染时不再含旧的 ListTile/Chip/CloseButton，验证新行、父/子与网络目录选择、展开不选中，以及本地「更多」的建夹/排序各调用一次。用例在可控本地/网络目录、保存、编辑器、图像端口上运行；没有运行真实存储、外网或原生窗口。
3. 与 `387b892` 在相同 **68/166** 个可用锁定依赖下做离线分析差分：没有新增诊断。导入边界、架构依赖、Git 差异检查通过。**完整依赖未解析，不能将此称为完整 `flutter analyze` 通过。** 本轮未推送、未派发 CI，未构建手机包或测 Android/iOS 实际帧时间。
4. 完整项目中已加入真实 `FavoritesPage`（501 项根目录与子目录、多个动画中间帧、IME、更多按钮与滚动对象身份）、本书阅读设置、来源作者目标、未选/网络收藏夹入口、ReaderScaffold 等回归；这些依赖完整 App 的测试**未在本次离线环境执行**。在依赖完整的环境，可运行：

```sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub test/features/favorites/local_favorites_refresh_test.dart test/features/comic_details/author_navigation_round3_test.dart test/features/comic_details/tag_navigation_test.dart test/features/comic_details/chapter_order_persistence_test.dart test/features/settings/setting_persistence_test.dart test/features/settings/keyword_rules_widget_test.dart test/features/reader/mobile_reader_chrome_test.dart test/features/reader/reader_menu_lock_test.dart test/agent/agent_page_test.dart
```

真机优先验证：锁定同一收藏目录时局部搜索与 IME 是否同时平滑；点目录名打开而不是点搜索；从实际提供作者分类的来源进入/返回；系统返回、RTL、深色/浅色、玻璃三档及大字。观察到问题时区分业务跳转、宿主生命周期与渲染材质，不能按宿主测试结果宣称真机体验或性能完全一致。
