# 二次开发分支功能、修复与合并保留登记表

本文是 `codex/agent-center-tab` 的长期维护契约，用于防止合并上游时丢失已经交付的功能、修复和性能优化。合并成功或文件没有冲突，均不表示这些行为仍然存在。

本文与[迁移与验证记录](migration.md)共同维护：本文记录必须保留的行为、实现入口及回归检查，迁移记录保留适配背景和每轮实际验证结果。[旧 Prime 分支盘点](agent-branch-maintenance.md)仅用于历史追溯，不能作为覆盖 Next 代码的依据。面向源仓库的归因另见[上游 Issue 候选](upstream-issue-candidates.md)。

## 维护基线与状态

- 工作分支：`codex/agent-center-tab`；`main` 仅用于 fork 同步，开发改动不提交或合入 `main`。
- Next 迁移基线：`5eccbc7fa3361c2385d670ba9c54161bcb3cf95b`。
- Prime 参考：`2e287566c6fad11b0085bbdf4a528e507021ec61`，只迁移行为，沿用 Next 架构、类型化设置、存储与退出队列。
- Agent 初次迁移：`89338dd`；构建维护：`00bdd61`、`49fbc67`、`1262aea`、`001a9cf`、`cefb7a3`、`af00d83`；本轮阅读/收藏/设置修复：`d28e4bd`。
- 2026-11-13 从开发 HEAD `6a1fe07b20882f5d8e39f1144bab736ea0a5d619` 整合源仓库 `CyrilPeng/Venera-Next/main` 的 `482810df369d126e4011be31d64408e33aede76f`，共同祖先为 `5eccbc7`；此前 `218f102` 仅审查，现随本次四个上游提交一并整合。
- 下列 A、O、R、C、M 项均为「保留中」。原编号稳定，不因换文件或上游重构删除记录。上游等价实现可以替代本分支实现，但应登记替代提交和实际验证，状态改为「上游等价覆盖」。
- 路径均相对仓库根目录。表内测试是核对入口，不表示每个测试都只验证该条行为；具体已运行范围见文末。

## Agent 功能（A01–A16）

这些功能来自 `89338dd`，源仓库当前没有 Agent；合并时不能因为上游缺少对应功能而删除入口、配置、工具或测试。

| 编号 | 必须保留的行为 | 实现与回归入口 |
| --- | --- | --- |
| A01 | 手机/宽屏独立 Agent 入口；旧启动索引 0/1/2/3 映射为 0/1/3/4，Agent 惰性初始化 | `lib/app_shell/main_page.dart`、`lib/features/agent/agent_integration.dart`；`test/agent/agent_page_test.dart` |
| A02 | 切换页面后继续运行；运行、待确认、未读提示；应用最终退出先停止任务并等待持久化 | `lib/features/agent/agent_session.dart`、`lib/main.dart`；`test/agent/agent_session_test.dart`、`test/app_runtime/application_host_test.dart` |
| A03 | Chat Completions、Responses、Messages；流式/非流式、思考、工具续接、取消 | `lib/features/agent/agent_protocol.dart`、`agent_http_adapter.dart`；`test/agent/agent_protocol_test.dart`、`agent_protocols_test.dart`、`agent_http_adapter_test.dart` |
| A04 | 模型编辑/复制、服务商模型发现、分页搜索、图片能力、请求补丁 | `lib/features/agent/agent_model_settings.dart`、`agent_model_discovery.dart`；`test/agent/agent_model_editor_test.dart`、`agent_model_discovery_test.dart`、`agent_model_picker_test.dart` |
| A05 | 多轮任务、停止/重试/重新生成/编辑重发；运行中插入与 FIFO 队列各自保留 | `lib/features/agent/agent_controller.dart`、`agent_queue_view.dart`；`test/agent/agent_controller_test.dart`、`agent_message_queue_test.dart`、`agent_chat_interaction_test.dart` |
| A06 | 依据实际用量压缩上下文，保留原历史及成对工具调用/结果 | `lib/features/agent/agent_context.dart`、`agent_wire.dart`；`test/agent/agent_context_controller_test.dart` |
| A07 | 图片/纯文本附件的校验、预览、持久化、清理；Android 原生相册和取消恢复；文件选择令牌正确释放 | `lib/features/agent/agent_images.dart`、`agent_files.dart`、`agent_file_picker.dart`；`test/agent/agent_image_picker_test.dart`、`agent_images_resources_test.dart`、`agent_text_files_test.dart` |
| A08 | `comic_read_cover(covers)` 批量 1–10 张封面、逐项结果、跨协议多图历史，兼容旧单图调用 | `lib/features/agent/agent_tools_cover.dart`；`test/agent/agent_cover_test.dart` |
| A09 | 会话搜索、切换、重命名、多选删除，资源用量与附件清理 | `lib/features/agent/agent_store.dart`；`test/agent/agent_session_test.dart`、`agent_images_history_page_test.dart`、`agent_text_files_page_test.dart` |
| A10 | 漫画管理工具覆盖源、搜索、分类、榜单、评论、收藏、稍后再看、追更、历史、本地、下载、屏蔽、统计和导航；分页和逐项回执 | `lib/features/agent/agent_app_bridge.dart` 及 `agent_tools*.dart`；`test/agent/agent_more_tools_test.dart`、`agent_storage_tools_test.dart` |
| A11 | 源日志、分页代码读取/搜索、精确编辑、限额备份和还原；替换走 Next 事务/回滚，安装更新走来源服务 | `lib/features/agent/agent_tools_code.dart`、`agent_app_bridge.dart`、`agent_source_backups.dart`；`test/agent/agent_more_tools_test.dart` |
| A12 | Bing、Google、Tavily、DeepSeek 独立配置且默认关闭；验证码/限流如实失败；来源去重 | `lib/features/agent/agent_web_search.dart`、`agent_search_browser.dart`；`test/agent/agent_web_search_test.dart`、`agent_web_search_settings_test.dart` |
| A13 | Responses/Messages 的原生联网、思考和引用续接；按协议真实能力提供功能 | `lib/features/agent/agent_protocol.dart`；`test/agent/agent_native_search_test.dart`、`agent_protocols_test.dart` |
| A14 | 长流式内容懒渲染、折叠、Markdown 拖动；输入区避让键盘；用户离开底部后不强制跟随 | `lib/features/agent/` 对话和输入组件；`test/agent/agent_long_content_test.dart`、`agent_markdown_scroll_test.dart`、`agent_floating_composer_test.dart` |
| A15 | 展示懒加载、元数据复用、局部查询、批量通知；完成持久化后才报告写入成功 | `lib/features/agent/agent_app_bridge.dart` 及 Next 数据管理器；`test/agent/agent_showcase_performance_test.dart`、`agent_storage_tools_test.dart` |
| A16 | `read_web(pages)` 批量 1–5 页，提取 Markdown、分页、缓存、取消及响应限额；不执行网页脚本或下载图片 | `lib/features/agent/agent_web_reader.dart`、`agent_web_readability.dart`；`test/agent/agent_web_reader_test.dart`、`agent_web_readability_test.dart` |

表内省略目录的 Agent 实现文件位于 `lib/features/agent/`，Agent 测试位于 `test/agent/`。

Agent 数据边界也属于功能契约：配置、密钥、会话、附件和源备份保存在本机独立 `agent/` 目录，常规备份/WebDAV 不自动包含；进程内后台运行不承诺杀进程后继续。稍后再看复用 Next 收藏夹，离线 `Unknown:<type>` 保留数值身份；批量操作等待 Next 队列，保留收藏层级、原收藏时间、撤销快照及源替换事务。具体适配见[迁移记录](migration.md#对-next-数据服务的适配)。

## 迁移保留的性能与数据约束（O01–O10）

| 编号 | 必须保留的行为 | 实现与回归入口 |
| --- | --- | --- |
| O01 | 历史首批 60 条后台分页，稳定时间/ID/类型游标，整库搜索、跨页选择/删除，过期查询结果丢弃 | `lib/features/history/history_paging.dart`、`history_pager.dart`、`history_page.dart`；`test/prime_migration/history_pagination_test.dart`、`history_pager_test.dart`、`history_page_test.dart` |
| O02 | 封面按卡片尺寸解码；有效封面不补查详情；无效封面去重、限并发及失败冷却；过滤/更新保持图片状态；无关键盘/标签变化复用配置 | `lib/features/history/history_image_provider.dart`、`lib/components/image.dart`；`test/prime_migration/history_page_test.dart`、`test/network/image_config_ownership_test.dart` |
| O03 | 缩略图最多 6 并发，同 key 合并、失败冷却 30 秒；消费者全部取消时撤销排队；保留流式进度和原生清理 | `lib/network/thumbnail_request_queue.dart`；`test/prime_migration/thumbnail_request_queue_test.dart`、`test/network/shared_image_requests_test.dart` |
| O04 | 作者独立规则，作者名称及 author/artist 标签精确匹配；不可变快照兼容原地规则修改；继续保留 Next 的关键词匹配方式及大小写选项 | `lib/features/comic_widgets/comic_blocking.dart`；`test/prime_migration/comic_blocking_test.dart`、`test/foundation/keyword_rules_test.dart` |
| O05 | 收藏、历史、本地漫画、稍后再看、追更和 Agent 展示不按关键词/作者隐藏；发现/搜索继续过滤；独立扫描收藏用于调规则 | R00、R08、R09；`test/features/comic_widgets/keyword_filter_consumers_test.dart`、`test/agent/agent_showcase_filtering_test.dart` |
| O06 | 无关键盘/阅读设置不重查全列表；收藏默认展示不逐本查历史，已读筛选缓存；查询/搜索/选择所有权及追更 generation 门禁保留 | R01；`lib/foundation/context.dart`、`lib/features/favorites/local_favorites_page.dart`；`test/features/favorites/local_favorites_refresh_test.dart`、`favorite_updates_service_test.dart` |
| O07 | 阅读图像缓存取可用内存 1/16 并限 32–192 MiB；内存压力下最多 32 MiB 且取消主动预解码及排队订阅，可见图片不受取消影响；每视图预解码串行、最多四个请求，原生收尾后才交接下一项；退出 1 秒后收缩，重入取消旧收缩；TV 及继承的较小上限保留 | `lib/features/reader/image_cache_policy.dart`、`image_precache.dart`；`test/features/reader/image_cache_policy_test.dart`、`image_precache_test.dart`、`image_precache_pressure_test.dart` |
| O08 | 最后进度、前台时长准确提交；控制器/计时器/监听清理、旧回调门禁和任务所有权有效；返回后由原会话后台收尾 | R05、R12；`lib/features/reader/reading_session.dart`；`test/features/reader/reader_exit_integration_test.dart`、`reading_session_test.dart` |
| O09 | 线条增强及强度、暗色/暖色/红色夜览；黑线不变浅、纸白不提亮；评论可跳过增强而保留夜览；实时调整不重置缩放/进度 | `lib/foundation/reader_preferences.dart`、`lib/features/settings/reader_appearance.dart`；`test/prime_migration/reader_color_effects_test.dart`、`test/features/settings/reader_settings_persistence_test.dart` |
| O10 | 历史后台读取与保存互不阻塞；WAL 快照、恢复前等待读取；主键 `(id, type)` 保留 Next 全部扩展列及每日时长事务；Pica 跨库导入临时 DELETE 后恢复 WAL，失败保留数据 | `lib/features/history/`、Next 导入/恢复队列；`test/prime_migration/history_pagination_test.dart`、`test/features/history/history_repository_test.dart`、`agent_statistics_test.dart` |

省略目录的历史文件位于 `lib/features/history/`；同一测试单元内省略目录的文件沿用该单元第一个测试的目录。

## 本轮用户问题与修复契约（R00–R12）

编号对应用户原始 0–12。它们包含主线已有问题、交互改进以及迁移功能适配，来源不影响本分支的保留要求。性能契约以可测的查询、构建与任务行为表达，不把组件测试写成真机帧率保证。

| 编号 | 必须保留的行为 | 实现与回归入口 |
| --- | --- | --- |
| R00 | 用户已选定内容的列表不做关键词/作者屏蔽；全选、反选、范围选择遵守当前搜索/阅读状态，不被规则变化清空；发现/搜索保持屏蔽 | `lib/features/favorites/local_favorites_page.dart`、`lib/features/comic_widgets/comic_list.dart`、历史/本地/追更/Agent 消费者；`test/features/comic_widgets/keyword_filter_consumers_test.dart`、`test/features/local_comics/local_archive_visibility_test.dart`、`test/agent/agent_showcase_filtering_test.dart` |
| R01 | 收藏「全部」直接复用输入列表，不逐本调用历史；已读筛选按列表及状态缓存并在历史变化后失效，身份使用 `comic.type`；网格缓存身份索引和 Hero ID，无关设置不全量重滤 | `lib/features/favorites/local_favorites_page.dart`、`lib/features/comic_widgets/comic_list.dart`；`test/features/favorites/local_favorites_refresh_test.dart` 的 1200 项、选择与刷新回归 |
| R02 | 收藏点击详情和直接阅读使用列表所在导航上下文，传递正确 Hero ID，保持封面衔接；不因全量列表重算拖慢过场 | `lib/features/favorites/local_favorites_page.dart`；`test/features/favorites/local_favorites_refresh_test.dart` 的详情导航/Hero 回归；实际设备动画仍需复测 |
| R03 | 大收藏进入/退出阅读依赖 R01/R02/R05/R12 的组合约束；不能恢复「等全部保存结束才返回」或无关通知重滤收藏 | 收藏页、`reader_page.dart`、`exit_guard.dart`；`test/features/favorites/local_favorites_refresh_test.dart`、`test/features/reader/reader_exit_integration_test.dart` |
| R04 | 阅读器及阅读加载页从过场第一帧绘制主题表面背景，页面尚未加载完成也不透明露出上一页 | `lib/features/reader/reader_page.dart`、`loading.dart`；`test/features/reader/reader_exit_integration_test.dart`，并手工检查设备入场动画 |
| R05 | 返回时先冻结进度并移交任务，使用正常退场动画返回详情；后台收尾期间保留已挂载的阅读视图与解码画面，动画结束才随路由释放，不因控制器关闭提前清空；根覆盖层右下角显示动态保存图标；失败变红色感叹号且不自动消失，查看详情后才能手动关闭，新错误不随旧错误一起清除；应用最终退出仍等待真实任务完成 | `lib/components/background_save.dart`、`lib/features/reader/exit_guard.dart`、`reader_page.dart`、`images.dart`；`test/components/background_save_test.dart`、`test/features/reader/reader_exit_integration_test.dart` 的三种阅读模式退场/慢保存回归、`platform_effects_test.dart` |
| R06 | 封面进度使用固定 24×24 小图标；当前页左上、总页数右下，各占独立行并按可用空间缩小，多位数及大字号不能重叠或溢出；缺总数居中、完成时显示勾，完整进度通过 Tooltip/无障碍标签保留 | `lib/features/comic_widgets/comic_tile.dart`；`test/features/comic_widgets/reading_progress_test.dart` 的 3/30、162/233、1001/1200 文字矩形与回退/完成回归、`detailed_reading_progress_test.dart` |
| R07 | 有保存的实际章节名时优先显示，包含总数/紧凑模式同样生效；格式为 `实际章节名 - P页数`，可选页总数；旧数据无名称时正常回退，无额外元数据请求 | `lib/features/history/history_model.dart`；`test/features/history/history_progress_description_test.dart`、`test/features/comic_widgets/detailed_reading_progress_test.dart` |
| R08 | 被屏蔽项原因可查看封面；点击封面进入对应漫画详情，传递原 ID、来源、封面和标题，返回后保留原因列表；作者/关键词共用可点击文字原因区域，进入编辑后均可删除，封面点击不触发规则编辑；发现列表和收藏扫描结果行为一致；从原因窗口进入的详情中，标签和作者搜索使用详情所在导航器，推荐/搜索结果卡片继续沿用所在导航器，返回顺序为搜索→详情→原因窗口，不向下层页面暗中推入搜索；异步分批计算，过期弹窗/规则不能覆盖新状态 | `lib/features/comic_widgets/keyword_hidden_notice.dart`、`comic_tile.dart`、`lib/features/settings/keyword_blocking.dart`、`lib/features/settings/author_blocking.dart`；`test/features/settings/keyword_rules_widget_test.dart` 的封面导航/规则编辑分离回归、`keyword_display_persistence_test.dart`、`test/features/comic_details/tag_navigation_test.dart` |
| R09 | 关键词管理独立扫描本地收藏以检查误伤；扫描只读，不隐藏/删除收藏；原页面查询结束后再打开结果，窗口及 generation 门禁有效 | `lib/features/settings/keyword_blocking.dart`、`lib/features/comic_widgets/keyword_hidden_notice.dart`；`test/features/settings/keyword_rules_widget_test.dart` |
| R10 | 线条增强、夜览和调光位于阅读设置前部，并在「调节画面」快捷菜单共同提供；共享组件遵守全局/设备/单漫画作用域；亮度预览只刷新遮罩，结束后由真实宿主显式提供当前作用域的已提交值，独立外壳遵循传入快照；面板已卸载的晚到保存同样更新遮罩，不等待翻页；保存状态不反复改变菜单高度 | `lib/features/settings/reader_appearance.dart`、`lib/features/settings/reader_brightness.dart`、`lib/features/reader/scaffold.dart`、`shell_host.dart`、`settings_effects.dart`；`test/features/settings/reader_settings_persistence_test.dart`、`test/features/reader/brightness_test.dart`、`settings_effects_test.dart`、`shell_presentation_test.dart`、`reader_exit_integration_test.dart` 的快捷/侧栏三种作用域及面板卸载回归 |
| R11 | 开关/选择器保存期间保留原 Element 和占位宽度；只按相关字段订阅，作用域变化才重建设置表单；持久化失败/重试、窗口退出等待仍有效 | `lib/features/settings/setting_components.dart`、`lib/features/settings/setting_field.dart`；`test/features/settings/setting_persistence_test.dart` 的原 Element/文字矩形断言、`reader_settings_persistence_test.dart`、`test/components/settings_save_host_test.dart` |
| R12 | 瀑布流同章节同页滚动不反复通知外壳；图片分块进度按 100 毫秒合并，连续图像使用双线性采样；异步解码改变前方尺寸时在布局内补偿可见锚点，不产生中间跳帧或取消拖动；前章晚到先等待滚动停止，再保留最新可见页及局部偏移，换章/退出取消等待；画廊预取按内容/布局/页码合并并放到帧后，保留 PhotoView、缩放及已有图像生命周期 | `lib/features/reader/continuous_view.dart`、`gallery_view.dart`；`test/features/reader/continuous_owner_test.dart`、`waterfall_loading_stability_test.dart`、`comic_image_progress_test.dart`、`waterfall_controller_test.dart`、`gallery_page_continuity_test.dart`、`gallery_rotation_test.dart`、`reader_exit_integration_test.dart`；滚动锚点实现在 `continuous_scroll.dart` |

表内省略目录的阅读实现文件位于 `lib/features/reader/`，`comic_tile.dart` 位于 `lib/features/comic_widgets/`。来源及上游归因详见[候选表](upstream-issue-candidates.md)，不得把 R02 的导航调整直接写成已证实的上游 Navigator 缺陷。

## 本分支构建与分发更新（C01–C06）

这些变化同样位于二次开发分支，不能在合并工作流时遗漏。使用说明见[构建文档](../development/build.zh.md)。

| 编号 | 保留行为与来源提交 | 实现与验证入口 |
| --- | --- | --- |
| C01 | 独立 `tests.yml` 固定完整质量门禁，不经过构建、无打包／签名或跳过测试输入；替代旧 `build.yml tests_only`。构建保留默认关闭的 `skip_tests` 与平台开关，所选平台统一等待一次公共质量检查；按平台选择范围，发布调用通过 `quality_checked` 复用通过结果。跳过测试仍保留静态检查、编译、签名及产物校验（原 `00bdd61`，本轮分离入口） | `.github/workflows/tests.yml`、`build.yml`、`analyze.yml`、`main.yml`、`harmonyos-release.yml`、`tool/harmonyos/ci_full_app.py`；`test_workflow_entrypoints.py`、`test_android_signing.py`、`tool/harmonyos/test_full_app.py` |
| C02 | Android 签名从 fork Secrets 写入 runner 临时目录，受限权限且结束清理；按配置的 keystore/alias 取得预期公开证书，所有 APK/发布校验匹配该身份，不硬编码上游证书或信任 APK 自报身份（`00bdd61`、`af00d83`） | `android/app/build.gradle`、`.github/scripts/AndroidSigningIdentity.java`、`android_tv_build.py`、工作流；`test_android_signing.py`、`test_android_signing_identity.py`、`test_android_tv_build.py` |
| C03 | Android 选择后固定构建手机/TV 全部 8 个 APK 和两份清单；两种 flavor 顺序复用编译；单 ABI 拆包不与 Flutter/NDK 过滤互斥，PR ARM64 冒烟使用正确拆包参数（`49fbc67`、`1262aea`、`001a9cf`） | `.github/scripts/build_android.py`、`android_tv_build.py`、`android/app/build.gradle`；`test_android_tv_build.py`、`test_ci_optimization.py` |
| C04 | PR 按变更范围选择重型检查和平台冒烟；同平台旧构建取消、跨平台保留，所选平台组合透传独立质量并发键；独立全量测试与构建不互相取消。各 runner 按 CPU／内存配置测试及编译并发，关键步骤记录资源和耗时；资源脚本变更触发全部范围。Rust 使用已有工具链与真实编译缓存，分离恢复/保存，失败缓存显式保存，磁盘仅低空间时清理（`49fbc67`、`001a9cf`、`cefb7a3`） | `.github/scripts/ci_scope.py`、`ci_resources.py`、`prepare_rust_toolchain.py`、`prepare_android_space.py`、`.github/actions/ci-resources/`、`rust-cache/`、`rust-cache-save/`；`test_ci_resources.py`、`test_workflow_entrypoints.py`、`test_ci_optimization.py`、`test_desktop_ci.py` |
| C05 | Windows 保留中间文件、流式 ZIP/正确 Inno Setup 启动器及缓存；macOS/iOS 共用准备、按需 Rust targets/CocoaPods 缓存（`001a9cf`、`cefb7a3`） | `windows/build.py`、`windows/build.iss`、`windows/build_arm64.iss`、`.github/scripts/prepare_apple_build.py`、工作流；`test_windows_build.py`、`test_windows_installer.py`、`test_desktop_ci.py`、`test_apple_rustup_wrapper.py` |
| C06 | Linux x64/ARM64 共用矩阵、C/C++ 缓存、依赖检测及可复用打包/冒烟容器；Arch 预编译打包不额外安装编译器/GTK/WebKit；兼容的快速压缩，上传避免重复压缩（`001a9cf`） | `.github/scripts/prepare_linux_build.py`、`build_linux_packages.py`、`build_arch_package.py`、相关 Dockerfile、`debian/build.py`；`test_linux_packages.py`、`test_arch_package.py`、`test_debian_package.py`、`test_desktop_ci.py` |

表内省略目录的构建脚本位于 `.github/scripts/`，测试位于 `.github/scripts/tests/`，工作流位于 `.github/workflows/`。不因优化 runner 用时移除完整发布所需的全部平台、双 flavor、签名及产物门禁。

## 分支维护与启动入口（M01–M02）

| 编号 | 必须保留的维护行为 | 入口与验证 |
| --- | --- | --- |
| M01 | 维护方式以可发现 Skill 存入分支，由根 `AGENTS.md` / `agent.md` 直接引用；后续修改/合并完整核对登记表并同步真实验证，不以文档存在替代行为验证 | `.agents/skills/venera-agent-branch-maintenance/SKILL.md`；核对 frontmatter、相对链接、全部保留编号与根入口 |
| M02 | 云环境启动/恢复先核验 `/workspace/Venera-Next` 与完整分支名 `codex/agent-center-tab`，错误分支干净时安全切换，存在修改时保留现场；首轮编辑/提交/推送均复核；复用工具链与代理身份；全量测试等待结束后才一次性读取摘要，不轮询日志 | `.agents/skills/venera-cloud-startup/SKILL.md`；核对启动命令、分支错误/脏工作树策略、身份与 Actions 验证约定；外部云环境配置由用户手动粘贴，仓库提交不代表配置已部署 |

## 上游合并时的明确冲突点

审查 `218f102` 时发现以下上游新行为，后续整合应同时保留，不使用「本分支已改过」作为丢弃理由：

| 区域 | 上游新增行为 | 本分支同时需要保留 |
| --- | --- | --- |
| `lib/features/comic_widgets/comic_tile.dart` | 进度约束在封面范围内；大字号/窄宽下标题和描述适配 | R06 的小图标、R07 实际章节名和 Tooltip/无障碍信息；不要用整文件选择覆盖任一方 |
| `lib/components/select.dart` | Flexible/LimitedBox 约束及手机/桌面触控尺寸适配 | R11 的原控件及占位宽度、异步保存错误/重试；上游布局更新应接入现有保存包装 |
| 详情动作、阅读底栏、文件交互 | HarmonyOS 能力入口禁用/提示与平台能力门禁 | Agent/收藏/阅读器新增入口继续遵守相同平台能力；不要重新放开未支持的平台操作 |
| 收藏/历史/阅读状态 | 上游后续可能重构存储或完善总数、章节、阅读时长 | O10 的复合主键和全部 Next 字段、A10 的事务/撤销、R05 的后台任务生命周期 |

以上交集已在 2026-11-13 的上游整合中逐段处理；历史审查结论不代表未经测试的设备效果。

## 每次合并与功能变更的执行顺序

1. 确认工作分支和工作树状态，记录当前开发 HEAD、上次整合的上游提交及本次目标提交。只 fetch/审查上游不会改变本表的整合状态。
2. 阅读本文与迁移记录，按 A01–A16、O01–O10、R00–R12、C01–C06、M01–M02 逐项判断本次差异是否影响行为。保留 Next 原有的新功能、数据列及平台门禁。
3. 逐段处理冲突。不要用整文件 `ours/theirs`、删除测试或恢复旧 Prime 文件来消除冲突。文件搬迁时同步实现与测试入口。
4. 上游已经等价修复时可以合并实现，但先运行相关契约测试，再登记「上游等价覆盖：提交 + 行为 + 测试结果」。不静默删除本地修复或其记录。
5. 执行 `CONTRIBUTING.md` 要求及受影响的定向检查。完整测试输出写日志，直接等待进程结束后一次性查看摘要，不轮询 6000 多项的过程日志或进程状态。记录通过/跳过/失败/中止及未做的平台验证，不能将「全量 + 修后定向通过」改写成「最终全量全绿」。
6. 同步本文、迁移记录及 `CHANGELOG.md`，再提交推送开发分支。常规维护不修改应用身份、版本或历史 Release，不把改动合入 `main`。

新增条目记录：稳定编号、用户可见行为/数据约束、来源与提交、实现位置、回归入口、冲突注意点、实际验证范围。删除功能需明确记录产品决定和替代行为；不能仅因上游没有该功能而删除。

## 最近验证与维护记录

### 2026-11-13：按 runner 资源配置并发与测量

- 用户明确恢复工作流资源优化；保留原测试耗时分析基线，夹具／文件拆分继续暂缓。新增无依赖资源脚本及 composite action，质量、构建、PR 平台和 HarmonyOS 入口共享 CPU／内存预算；Linux 支持亲和性及标准 cgroup 限额，macOS／Windows 读取系统内存。
- Flutter 全量／TV 与 PR Windows 定向测试显式并发；消除原生编译固定两任务限制，共用 Cargo、CMake、CTest、Swift、Gradle 预算。Android flavors、Apple 平台及 Rustup 安装仍顺序／互斥；HarmonyOS 本地无预算时保留原默认值，冻结旧源码不修改。
- 关键步骤记录墙钟耗时与退出码，POSIX 附已退出子进程 CPU 及最大单进程 RSS，明确不当作进程树总内存或满载保证。命令失败保留非零退出码；现有 Gradle 参数通过安全多行格式保留，不输出参数内容。
- 本轮定向脚本回归与实际 Actions 验证见[迁移记录](migration.md#工作流计算资源调整2026-11-13)；全量仍仅在 Actions，按用户约定派发后至少 20 分钟再查询，不频繁轮询。

### 2026-11-13：独立全量测试入口与构建依赖优化

- 新增 `tests.yml`，Actions 显示为「全量测试」，仅手动派发、无输入，直接以 `platforms=all / skip_tests=false` 运行现有 `analyze.yml`；手动事件不按最后一次文档提交缩减检查，不包含构建／签名／发布任务。
- 删除构建入口 `tests_only`，保留原平台选项和 `skip_tests=false` 默认。所选平台统一等待一次公共质量检查：失败不继续打包，已验证的发布调用保留跳过重复检查的路径；按平台族控制无关检查，不同平台组合独立质量并发键，原有签名、清单和平台特有测试保持。
- 根规则、两份 Skill、中英文构建指南同步新入口。新工作流契约 7 项与既有构建／签名／发布兼容 63 项定向回归通过；使用校验过 SHA-256 的官方 `actionlint 1.7.7` 验证定义及发布调用，无问题。版本、结构／架构和差异检查通过，未构建平台范围见迁移记录。不因入口重构重跑已通过的阅读器全量。
- 阅读器最终源码 `a5222bcab780c58e4ea3097c1f0c8a3a51eb4b80` 的 [Actions 43401061170](https://github.com/tianjinsa/Venera-Next/actions/runs/43401061170) 最终 success；所有质量任务通过，安装包任务按原测试专用模式跳过。后续仅文档与工作流改动不冒充该 SHA 的新全量结果。

### 2026-11-13：图片完成卡顿反馈稿与 CI 等待

- 新增 [U12](../feedback/U12-reader-image-completion-stutter.md)，按上游阅读性能模板与用户第一人称直接说明问题、影响和模式差异；不展开 Prime 修复历史，简述同步字节工作并链接当前仓库 `a5222bca`。实际构建／来源、阅读环境和手机诊断未提供的部分保留待填项，不编造原版或真机验收。
- 当前 12 份缺陷／组件稿、6 份建议，共 18 份；索引、候选和未来单一 PR 映射同步，U11 仍撤出。未创建外部 Issue 或 PR。
- 按用户要求停止每分钟的本地 CI watcher，远端全量继续验证 `a5222bca`；先等运行满 20 分钟再查看，未完至少间隔 10 分钟，两份 Skill 同步。本轮只修改文档并核对模板、链接、计数和差异，不重启测试或构建。

### 2026-11-13：阅读首帧预热与内存压力调度

- 开发基点 `8bb1b343`，实际分支 `codex/agent-center-tab`。核对 Prime `2f55f730` / `3bd8de94` 与历史设备记录，确认 O07 缓存机制已迁入；原记录没有证明低内存是唯一根因，不能将旧设备结果当作 Next 当前验收。
- 连续／瀑布流继续预下载远端字节，并仅在可见图片就绪、未建议延迟加载时预解码下一张，本地图片同样覆盖；预热与显示共用 provider 构造、尺寸预算和缓存键。高速滚动不新增投机解码，换页／换所有者／退出撤下旧订阅。
- 画廊与连续视图共用有界串行预解码，最多四个请求；读取、codec 和首帧的实际收尾完成后才启动下一项，排队项在准入前不解析图片。内存压力或较小缓存预算通过只读许可通知及时取消预加载，保留其他可见消费者及 Next 的任务／错误所有权。
- 首帧就绪通过独立通知进入已有帧后视口更新门禁；缓存尺寸未变化时也继续预热，后续动图帧不重复触发。回归入口为 `comic_image_progress_test.dart` 的同尺寸重载与重复帧。
- 下载完成阶段另有确定的同步分配：普通 `List<int>` 累积图片字节，并在缓存写入准入时再次复制为整型列表。改为 `BytesBuilder` 与 `Uint8List` 独立快照，保留排队后调用方修改输入的隔离、分块进度及源回调／清理协议；回归入口为 `cache_manager_test.dart`、`images_test.dart`、`image_config_ownership_test.dart`。
- 用户进一步澄清非全量测试可以在云环境运行，只有全量放在 Actions；两份 Skill、根约定及中英文构建指南同步。已通过本地调度／首帧／压力回归 28 项、缓冲／缓存／网络所有权回归 83 项；全量仍以准确 SHA 的 Actions 为准。不将宿主测试时长称为设备帧率／GPU 完成证据，实际链接和结论见迁移记录。
- 连续／瀑布流、画廊、裁剪和退出兼容另 234 项通过、23 项按原条件跳过。新增 `tool/reader_byte_buffer_probe.dart` 及[同步字节准备对照](../experiments/webdav_reader_performance.zh.md#2026-11-13-agent-分支续修)，只验证该阶段的字节与宿主耗时，不代表 Android 帧率／峰值内存或全部卡顿已消除。

### 2026-11-13：按模板归并正文并补齐原版现象

- 用户最新确认：上游清单内保留的缺陷都在最新原版 1.18.4-rc.1 存在，覆盖早期只记录 U06/U07 原版确认的旧范围；公开稿移除二次开发版本及尚未原版复测的表述。此前已撤出的原 U11 仍只作分支回归记录。
- 17 份稿件按对应上游 YAML 的字段名称与顺序排列；缺陷的问题说明、现象与影响并入“实际行为”，建议的当前不便并入“需求场景”，去掉额外自建小节。设备型号继续为 `【设备型号】`。
- U01 补齐进入大收藏夹、从其漫画详情返回、点搜索唤起输入法三个卡顿场景。MediaQuery 全量订阅与整表重复计算作为排查线索，不声称已记录键盘动画每一帧都重建整页。
- 维护索引、候选与交接同步；仅文档修改，核对模板字段/顺序/选择项、原版表述、占位符、分类、链接与差异，不启动本地测试或新 CI。

### 2026-11-13：撤回原 U11 的上游缺陷归类

- 按用户明确更正，标签导航问题只确认发生在 agent 新增的关键词屏蔽原因封面详情入口，责任涉及上游代码、新功能代码或适配关系，尚未确定。双导航器夹具不能代替原版已有入口的证据。
- 原 U11 稿移为[分支回归记录](keyword-reason-detail-navigation.md)，从上游 Issue 清单与独立缺陷 PR 范围移出；当前公开稿为 11 份缺陷/组件稿与 6 份建议，共 17 份。E04 保留为新功能建议，导航适配按该功能的正确性需求评估。
- R08 的分支修复、功能与回归继续保留；索引、候选、交接及更新日志同步。本次仅文档变更，核对分类、计数、相对链接和差异，不启动测试或新 CI。

### 2026-11-13：反馈稿改为本人视角并补全现象与影响

- 当时按用户更正重写 18 份公开稿（其中原 U11 后续已撤出）：第一人称并补充问题/实际现象/影响。该轮增加的额外小节已在最新模板修订中撤掉，字段顺序以模板为准。
- 当时全稿使用 `【设备型号】` 并保留 Android 15、骁龙 7gen2+、12 GB 环境。该轮未知二次开发构建占位符已在用户确认全部保留缺陷均存在于原版后删除；U11 后续撤出上游范围。
- 同步反馈索引、候选索引及 PR 交接写法，避免下次又写回第三人称排查记录。本次只修改文档，做模板字段、占位符、链接和差异的轻量静态核对，不启动本地或重复 CI 测试。


### 2026-11-13：反馈交接与 Actions 默认测试

- 用户要求默认在 GitHub Actions 测试；更新两份 Skill、根入口及构建文档。`build.yml tests_only=true` 复用完整质量门禁并强制不跳测试，全部安装包 job 关闭，普通构建默认行为保留。
- 本地全量在环境恢复后已无 runner、无完成摘要：日志最后为 2271 通过、52 跳过，另有源事务崩溃恢复 `settingsPartial` 用例 30 秒超时。不记为通过，不武断判断 OOM；不再启动 Cloud 测试，后续以准确 SHA 的 Actions 为准。
- 当时新增 18 份独立反馈及[集中 PR 交接](../feedback/README.md)，保留 U01–U05，拆分 U05a/b，补 U06–U11 和 E01–E06；原 U11 后续已移至分支回归记录，当前上游清单为 17 份。用户原版确认的编号 2/4 对应 U06/U07，环境为 1.18.4-rc.1、Android 15、骁龙 7gen2+、12 GB，机型由用户手填。
- 文档静态核对覆盖上游模板必填标题、18 稿计数、相对链接和 tests_only 的各安装包门禁。没有创建外部 Issue/PR；未来从上游另建一条分支集中一个 PR，不能整合整个 Agent 分支。


### 2026-11-13：阅读加载跳动及原因详情标签导航

- 来源：用户反馈及 Prime `2e28756` 的 `lib/pages/reader/comic_image.dart` / `images.dart` 行为。补入遗漏的 100 毫秒进度合并和连续阅读双线性采样；保留 Next 的图像任务、取消、白边裁剪、TV 预算与既有缓存政策，不用 Prime 整文件覆盖。
- R12 新复现：上方占位图从 300 高变为 200 高时，下方正在阅读的图片上移 100 像素。滚动代理仅记录当前已解码阅读页的几何，初次加载的占位项不覆盖历史/显式跳页目标，在 Flutter 尺寸协调阶段补偿实际尺寸差，保留拖动/惯性活动并在首个绘制帧生效；支持横向和反向，明确翻页/换章时失效旧锚点。
- R12 前章预取修复：请求开始时的页码会过期，原实现还丢弃局部偏移。现在待滚动结束后插入，基于插入时的可见项及 leading edge 恢复；取消/旧 generation 不插入。
- R08 导航修复：agent 新增原因封面入口的详情在根导航器，而 `ComicPageActions.onTapTag` 硬编码主导航器；改用当前详情上下文，标签/作者的查询、来源与选项保持；普通卡片也使用所在页面上下文，支持从搜索结果/推荐继续进入详情，普通列表详情兼容。这说明新增入口下的失配机制，不确定上游与新增功能的责任归属。
- 新增回归入口：`comic_image_progress_test.dart`、`waterfall_loading_stability_test.dart`、`test/features/comic_details/tag_navigation_test.dart`。真实验证及未验证范围见迁移记录本轮章节。

### 2026-11-13：整合上游 `482810d`

- 仅在 `codex/agent-center-tab` 合并上游四个提交，未修改 fork 的 `main`。保留上游 `1.18.4-rc.1+250` 版本推进、菜单锁、白边裁剪、收藏多选快捷操作、鸿蒙能力门禁及发布恢复流程；未创建版本或发布产物。
- A01–A16：Agent 入口、协议、工具、存储及所有回归文件保留，上游未触及这些实现。O01–O10：历史分页/复合主键/队列、封面调度、作者过滤、缓存与颜色设置保留。R00–R12：收藏不做关键词过滤、缓存筛选与当前导航器、24×24 两行页码、异步保存/退场/调光均保留；封面状态同时遵守上游的封面区域约束和窄宽/大字号布局，收藏多选合入上游键盘及宽屏快捷操作。
- C01–C06：保留单任务 Android 全 8 包、fork 签名、skip_tests、范围检查与各平台缓存；发布校验仍在创建草稿前执行。M01–M02：维护和启动 Skill、固定分支/身份/验证记录规则保留。
- 合并冲突逐段处理：翻译和变更记录保留两方新增项；收藏测试同时保留计数历史夹具与上游根导航器；发布测试按当前单任务产物及上游草稿流程校验。实际检查结果随本次修复最终验证更新至迁移记录。


### 2026-11-10：测试耗时分析留档

- 保存[测试耗时分析与接续记录](../development/test_performance_analysis_20261110.zh.md)和配套统计快照，以 `dee61e8` 为源码基线，记录默认 2 进程、文件内串行、编译队列、599 个测试文件、真实资源夹具、覆盖率与范围分类等证据。
- 区分已确认事实、待测量占比及待审查候选，保留全量中止与分批验证边界；未认定大量测试无用，未执行性能优化或调整 CI。
- 用户决定当前暂缓解决；根 `agent.md` 增加接续入口，后续复用既有分析，不自动重新跑基准。本轮仅保存文档和统计摘要，未运行 Flutter、Python 测试或新的性能基准。

### 2026-11-10：全量检测等待修复与封面页码布局

- 基点 `7ba5a0e`，工作分支 `codex/agent-center-tab`。定向提取 CI run `42800686662` 的失败标记及堆栈，发现 14 项布局检测、6 项调光保存、3 项外壳显式亮度失败，以及后续两项各 10 分钟超时；没有逐行阅读全部日志。
- 阅读测试夹具在删除临时库、恢复设置前排空真实数据准入队列，避免已接受写入保留旧测试的 fake async Zone；新增延迟写入回归。异步门禁以有界真实时间等待，兼容覆盖率和繁忙文件系统。保留原始会话归属及最终退出等待断言。
- 全量覆盖率轮次另发现双监听图片测试的单帧等待竞争，`test/features/reader/display_image_provider_test.dart` 改为等待真实原生帧交付，继续验证两个消费者和退出准备/恢复，不修改图片提供器的产品逻辑。
- 修复 R06 页码重叠，R10 保留实时调光并恢复独立外壳输入契约。参考 Prime `codex/agent-center-tab` 的角标布局意图，仅改相关 Next 实现。
- 验证：首轮定向 33 项通过；全量覆盖率到 35 分钟预算中止，5984 项通过、155 项跳过，另有上述图片等待失败；修正后的失败项与剩余文件补跑 348 项通过，TV 89 项通过。严格分析、格式、结构/架构/版本、依赖与工具自检、Python 293 项（跳过 7 项）及差异检查通过。未做原生构建和真机验收，不记为最终单轮全量全绿。
- 最终验证结果与范围见[迁移记录](migration.md#全量检测等待与封面页码布局修复2026-11-10)。

### 2026-11-10：修复提交 `d28e4bd`

- 全量 Flutter 测试运行一次，约 12 分 29 秒：6251 通过、155 跳过、13 失败；其中 10 项是旧本地漫画屏蔽预期，2 项是新增后台退出的重复错误上报，1 项为测试着色器资源错误。
- 修正后仅重跑受影响的本地归档可见性、平台效果、阅读退出和后台保存四组：193 通过、23 跳过、无失败；着色器测试独立复跑通过。没有再声称完成第二次全量测试。
- 1200 项收藏/筛选/选择/导航、关键词/作者原因及删除、只读扫描、设置 Element/文字矩形回归通过；TV 门禁 89 项通过。
- Python 仓库脚本共运行 293 项，7 项跳过，其余通过；严格分析、格式、结构/架构、版本、锁定依赖来源/许可证检查通过。
- 标准 Flutter 渲染、真实字体的竖屏/横屏大字号画面菜单和保存/错误图标截图检查通过；未进行 Android/Apple/Windows/HarmonyOS 原生构建或真机帧率测量。
- 详细命令、初次迁移验证及限制保留于[迁移记录](migration.md#迁移回归修复核对2026-11-10北京时间)。

### 2026-11-10：建立长期登记表

- 登记全部 8 个开发提交的 Agent、性能/数据、阅读交互修复及构建更新，增加根 `agent.md` 的阅读和同步约束。
- 审查源仓库 `218f102`，登记尚未整合的冲突点及 Issue 候选；未合并上游，未向源仓库提交 Issue。
- 本次仅修改维护文档：Python 仓库脚本 293 项、7 项跳过，其余通过；结构/架构/版本、文档路径与编号完整性及 `git diff --check` 通过，未重跑全量 Flutter。上游核对的 5 项小范围探针及其证据边界见迁移记录和 Issue 候选。

### 2026-11-10：阅读退场、封面导航、调光与 Skill 入口

- 扩展 R05/R08/R10，保留退场的原阅读视图，原因封面独立进入详情，调光在预览和当前作用域保存值间正确衔接。
- 新增 M01–M02，将维护/启动流程保存为可发现 Skill，由根规则直接引用；仅这两个 Skill 目录加入版本控制，其余本地 Agent 目录仍忽略。
- 新增 12 项定向回归通过；严格 Flutter 分析、Python 293 项（跳过 7 项）、结构/架构/版本及 Skill 检查通过。用户因额度不足要求跳过测试，已停止未完成的全量测试并继续提交推送；不记为全量通过，不再启动测试。
- 详细验证范围及中止原因见[迁移记录](migration.md#阅读退场原因封面导航与调光续修2026-11-10)。
