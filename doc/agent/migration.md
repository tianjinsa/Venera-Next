# Prime Agent → Venera Next 迁移与维护清单

本分支是用户的二次开发分支。`main` 只用于 GitHub fork 同步；开发、修复、提交和合并上游均在 `codex/agent-center-tab` 进行。

## 迁移基线

- 目标：`tianjinsa/Venera-Next`，基线 `5eccbc7fa3361c2385d670ba9c54161bcb3cf95b`。
- 来源：[`tianjinsa/venera-prime` 的 Agent 分支](https://github.com/tianjinsa/venera-prime/tree/codex/agent-center-tab)，提交 `2e287566c6fad11b0085bbdf4a528e507021ec61`。
- Prime 的 fork 源仓库为 `venera-app/venera-prime`；来源分支与源仓库的共同祖先是 `228fd8d08b3b7c8f40959cc15f7434c163ba50b3`。按该祖先至来源提交的差异迁移，原始差异为 168 个文件。
- 不合并 Prime 的版本号、应用身份、平台发行配置和历史 Release。Next 的版本保持 `1.18.3+249`，已有收藏层级、阅读模式、WebDAV、事务恢复、依赖治理和各平台代码继续使用 Next 实现。
- `doc/agent/agent-branch-maintenance.md` 是迁移前的 Prime 功能盘点，原路径和历史验证记录只用于追溯；当前实现与验证结果以本文为准。

## 功能核对

| 编号 | 保留行为 | Next 中的实现与验证入口 |
| --- | --- | --- |
| A01 | 手机、宽屏独立 Agent 入口；旧启动索引 0/1/2/3 映射为 0/1/3/4；惰性初始化 | `app_shell/main_page.dart`、`components/navigation_bar.dart`、`features/agent/agent_integration.dart`；`test/agent/agent_page_test.dart` |
| A02 | 切换页面继续运行，展示运行、待确认和未读状态；最终退出停止任务、等待配置写入再关闭存储 | `agent_session.dart`、`main.dart` 注入 `ApplicationHost.closeAgent`；`agent_session_test.dart`、`test/app_runtime/application_host_test.dart` |
| A03 | Chat Completions、OpenAI Responses、Anthropic Messages；流式、非流式、思考深度、工具续接、取消 | `agent_protocol.dart`、`agent_http_adapter.dart`；`agent_protocol*_test.dart`、`agent_http_adapter_test.dart` |
| A04 | 模型配置、复制、服务商模型发现、分页搜索、图片能力和请求补丁 | `agent_model_*.dart`；对应模型编辑、发现、选择、页头回归 |
| A05 | 多轮任务、停止重试、重新生成、编辑重发；运行中插入与 FIFO 消息队列分别保留 | `agent_controller.dart`、`agent_queue_view.dart`；控制器、队列和对话交互回归 |
| A06 | 根据真实用量压缩上下文，保留原历史与成对工具调用/结果 | `agent_context.dart`、`agent_wire.dart`；`agent_context_controller_test.dart` |
| A07 | 图片/纯文本附件，校验、预览、持久化和清理；Android 原生相册及取消恢复 | `agent_images.dart`、`agent_files.dart`、`agent_file_picker.dart`；`IO.withFileSelection` 使用 Next 的令牌计数；原生 `AgentImagePicker.kt` 迁入 Next 包名 |
| A08 | `comic_read_cover(covers)` 批量读取 1–10 张封面，逐项回执和跨协议多图历史；旧单图调用兼容 | `agent_tools_cover.dart`；`agent_cover_test.dart` |
| A09 | 会话搜索、切换、重命名、多选删除、资源占用与附件清理 | `agent_store.dart` 及会话/资源页面；对应存储、图片和文本回归 |
| A10 | 源、搜索、分类、榜单、评论、收藏、稍后再看、追更、历史、本地、下载、屏蔽、统计、导航工具；分页与逐项回执 | `agent_tools*.dart`、`agent_app_bridge.dart`；`agent_more_tools_test.dart`、`agent_storage_tools_test.dart` |
| A11 | 源日志、分页代码读取/搜索、精确编辑、备份限额及还原 | 源替换使用 Next `ComicSourceManager.replaceScript` 的事务和回滚，安装/更新使用 Next 来源服务；对应源工具回归 |
| A12 | Bing、Google、Tavily、DeepSeek 独立配置，默认关闭，验证码/限流如实失败，来源去重 | `agent_web_search.dart`、`agent_search_browser.dart`；搜索和设置回归 |
| A13 | Responses/Messages 原生联网、思考与引用续接；不为 Chat Completions 虚构原生搜索 | 协议和原生搜索回归 |
| A14 | 长流式内容懒渲染、折叠、Markdown 拖动、输入区避让键盘、用户离开底部后不强制跟随 | 对话、长内容、滚动、输入区和设置布局回归 |
| A15 | 展示懒加载、元数据复用、局部查询、批量通知；等持久化完成才报告写入成功 | `BatchedNotifications`、Next 管理器异步 API；展示性能和存储工具回归 |
| A16 | `read_web(pages)` 批量 1–5 页、Markdown 正文提取、分页、缓存、取消、响应限额；不下载图片或执行网页脚本 | `agent_web_reader.dart`、`agent_web_readability.dart`；网页读取和正文识别回归 |
| O01 | 历史首批 60 条后台读取，稳定时间/ID/类型游标、整库搜索、跨页选择与删除、过期结果丢弃 | `features/history/history_paging.dart`、`history_pager.dart`、`history_page.dart`；`test/prime_migration/history_*test.dart` |
| O02 | 历史封面按卡片尺寸解码；有效封面不请求详情；无效封面去重、限并发和失败冷却；过滤/更新保留图片状态；标签和键盘变化复用已解析配置，真实配置改变及热重载仍可重新解析 | `history_image_provider.dart`、`components/image.dart`、漫画列表身份键及缩略图 `ResizeImagePolicy.fit`；历史页和图像生命周期回归 |
| O03 | 封面最多 6 个并发，同 key 合并、30 秒失败冷却；所有消费者取消时撤销排队 | `network/thumbnail_request_queue.dart` 在 Next `SharedImageRequests` 内调度，保留流式进度和原生请求清理；队列与网络回归 |
| O04 | 独立作者规则，精确作者名称及 author/artist 标签；复用不可变快照，支持规则原地修改 | `features/comic_widgets/comic_blocking.dart`；保留 Next 的包含/独立词/精确标签及大小写选项，不降为旧 Prime 匹配器；作者与现有关键词回归 |
| O05 | 历史只过滤作者；本地/网络收藏、稍后再看、追更、Agent 展示不做关键词/作者过滤；普通发现/搜索保留过滤 | 网格和两种分页列表共享过滤开关；历史页、作者、Agent 展示及现有列表回归 |
| O06 | 键盘变化不触发无关列表重查；收藏现有查询所有权、搜索与已读筛选保留；晚到追更结果不能恢复已关闭状态 | `foundation/context.dart` 使用 `MediaQuery` 分项订阅；沿用 Next 收藏查询与追更 generation 门禁 |
| O07 | 可用内存 1/16，32–192 MiB；压力时最多 32 MiB 并暂停预解码；退出 1 秒后收缩，重入取消旧收缩；TV 上限继续有效 | `features/reader/image_cache_policy.dart`、预加载与阅读页面；缓存策略及阅读生命周期回归 |
| O08 | 最后进度、前台阅读时长、控制器/计时器/监听清理、旧异步回调门禁 | 沿用 Next 的 `ReadingSessionTracker`、进度队列、`ImageWork` 与各视口所有权；画廊预取移到帧后合并调度 |
| O09 | 线条增强及强度，暗色/暖色/红色夜览；黑线不变浅、纸白不提亮；实时调整不重建阅读子树，评论可跳过增强但保留夜览 | 类型化 `ReaderPreferences`、`reader_appearance.dart`；真实像素颜色回归、单漫画/设备优先级和控制器保护 |
| O10 | 历史后台读不阻塞进度保存；WAL 快照、恢复前等待读取；锁/权限错误保留数据 | 历史连接选择 WAL，读取受 Next `AppDataOperations` 保护；修复旧单 ID 主键，保留 Next 的章节名称、总页数与阅读时长列；继续使用 Next SQLite 快照；Pica 跨库导入在独占门禁下临时切回 DELETE，成功或失败后恢复 WAL，保留原子事务检查 |

表内 Agent 文件路径均相对 `lib/features/agent/`，未注明的 Agent 测试相对 `test/agent/`。

## 对 Next 数据服务的适配

- 稍后再看使用 Next 的收藏夹，不另建 Prime `read_later.db`。漫画完整描述继续存在 Agent 会话的元数据中，Next 收藏项沿用其自身字段格式。离线/已卸载来源的 `Unknown:<type>` 身份在操作和撤销中保持数值类型。
- 收藏写入、移动、删除、历史修改、本地删除与下载控制等待 Next 管理器完成。批量通知仍通过数据操作发布边界，监听者不会借用写入者的权限。
- 收藏工具返回父目录/子目录信息；不删除仍有子目录的父目录；叶目录撤销恢复其父子关系和原始收藏时间。Next 原有目录排序、网络关联和事务机制保留。历史撤销使用完整快照，恢复章节、分组和累计阅读时长；等待期间出现的新记录不会被旧快照覆盖。
- Agent 阅读统计复用 `history.db` 的总时长，新增同库的每日增量表并在原时长事务中写入。旧 Next 历史只有累计时长，因此不虚构迁移前的每日分布；已有累计时间仍计入总时长。
- 聊天和搜索配置、密钥、会话、附件、源代码备份仍只在本机独立 `agent/` 目录，Next 常规备份和 WebDAV 不自动包含。已有 Prime Agent 目录格式兼容；迁移代码不会读取用户设备数据或自动复制密钥。
- 进程内后台运行不表示杀进程后继续运行。原生 Google/Bing WebView 回退在 Linux 上仍受原实现的平台限制，HTTP 搜索与配置的 API 引擎可用。

## 验证记录（2026-11-10，北京时间）

- 全量 `flutter test --no-pub`：6256 项通过，155 项按原有条件跳过，无失败。覆盖新增 Agent 回归和 Next 原有收藏、阅读、同步、持久化与生命周期回归。
- 最终封面配置复用优化后，历史页、漫画列表、封面组件和迁移回归另有 90 项通过；新增回归先复现了切换标签重复加载失败封面的行为。
- TV 配置检查：使用仓库质量流程相同的 `--flavor tv` 和编译参数，89 项通过。
- 针对性真实本地 HTTP、Agent 收藏/稍后再看/完整撤销、离线身份、历史分页/搜索/跨页选择、作者屏蔽、流式封面调度和颜色像素回归均通过。
- Python 仓库脚本测试：共 258 项，251 项通过，7 项按原有平台条件跳过。此云端默认 `umask 077` 会使 Debian 打包测试目录权限变为 0700；以进程内 `umask 022` 运行通过，未改打包代码。
- 结构检查、架构边界清单和版本一致性检查通过。新增协议/存储/纯策略登记为业务代码，页面、浏览器与跨页面工具编排登记为界面代码；不放宽已有业务到界面的限制。
- `flutter analyze --fatal-infos --fatal-warnings --no-pub`、变更 Dart 格式、`flutter pub get --enforce-lockfile`、依赖来源/许可证检查、独立代码审查工具的自检与严格分析、`git diff --check` 均通过。
- 已尝试 Linux debug 构建，环境缺少 `clang++`，CMake 未能生成构建文件。Android、Apple、Windows、HarmonyOS 原生构建与真机验证未运行；不将单元测试或 Prime 历史设备报告写成这些平台已通过。
- 未使用用户的真实模型、付费搜索 Key 或设备数据进行外部服务联调；协议与传输测试使用模拟服务和本地 HTTP。

## 数据与代码回退

- 历史表原单 ID 主键在事务内迁移为 `(id, type)`，保留全部 Next 扩展列；增加分页索引和每日时长表。其他数据库保持 Next 原有日志策略。
- 数据回退使用迁移前的完整应用备份，通过 Next 原有恢复流程完成；不要把不同来源的同 ID 记录强行合并回单 ID 主键。
- 代码回退可撤销本次迁移提交并从锁文件恢复依赖。新增设置和每日统计表对旧代码是额外字段；需要精确恢复迁移前数据时，同时恢复上述备份。`main` 不参与回退操作。

## 后续合并

1. 记录工作树状态与当前提交；从 `main` 获取上游变化，只在开发分支逐项整合。
2. 按 A01–A16、O01–O10 和 Next 新增行为同时核对，特别检查导航索引、收藏层级、源编辑事务、阅读退出、历史主键/列和备份生命周期。
3. 运行 `CONTRIBUTING.md` 的门禁，检查受影响的真实业务契约；同步本表、使用说明和 `CHANGELOG.md`。
4. 不用整文件覆盖解决跨版本差异，不把旧设备性能记录当成本次验证，不自动发布版本或合入 `main`。
