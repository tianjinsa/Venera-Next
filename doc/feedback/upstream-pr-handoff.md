# 上游集中修复 PR 交接

更新时间：2026-11-13。目标是让新会话直接执行，不重新盘点整个 Agent 分支或重跑 Cloud 全量。用户要求：**以后从源仓库 main 另建一个工作分支，所有整理项集中一个 PR；各 Issue 可分别发布。** 本轮只整理稿件、交接与 fork 内修复，未创建上游 Issue/PR，也未新建上游 PR 分支。

## 先读这几项

1. [反馈索引](README.md)：12 份缺陷/组件稿和 6 份功能建议，证据与模板已分类。
2. 本文件的范围、实现映射和验证记录。
3. 仓库 `AGENTS.md`、`agent.md` 和两份 `.agents/skills/`：云环境可以运行有界定向测试，全量使用独立 `tests.yml`，不再走构建入口；派发后确认一次 URL／SHA，满 20 分钟再查看状态，之后未结束至少间隔 10 分钟。
4. 只在涉及对应行为时查 [保留登记](../agent/branch-change-register.md) / [迁移记录](../agent/migration.md)。不为接续任务重新遍历 6000 多项日志、全部 Agent 工具或旧 Prime 整仓差异。

## 范围更正：原 U11 已撤出上游缺陷清单

- 用户明确：标签/作者搜索无反应、退出详情后搜索出现在下层，是 agent 分支新增“关键词屏蔽原因→封面→漫画详情”入口后出现的问题。原版没有该新增入口；目前没有依据把它归为原版已有缺陷，也不能反向断言一定是新功能代码写错。责任可能涉及上游代码、新功能代码或两者适配，尚未确定。
- 原 U11 的公开 Issue 稿已移为[分支回归记录](../agent/keyword-reason-detail-navigation.md)，保留现象、修复和测试入口，**不发布上游 Bug Issue，不作为独立上游缺陷纳入 PR**。其余编号保持不变，不把后续稿件重编号为 U11。
- E04 仍是“新增可选原因封面和详情入口”的功能建议。未来实现 E04 时，应将标签/作者搜索、后续封面与返回链作为新功能的正确性回归；若需要导航适配，应在 E04 功能实现中解释，不能将新增入口所需的适配包装成上游原有 Bug 修复。
- 双导航器夹具证明的是所构造入口下的行为。不要为了恢复 U11 而仅给原版人工增加同类入口；若将来发现上游已有入口也有独立问题，需另行记录该真实入口及证据，再决定是否增加反馈项。

## 公开稿件写法：用户明确要求

- 当前 18 份正文以报告者本人“我”的口吻向上游反馈，不再写成代理对“报告者/本轮任务”的总结。
- 字段名称与顺序严格遵循对应 `.github/ISSUE_TEMPLATE/*.yaml`。缺陷依次写问题类型、版本、平台、设备、复现步骤、预期、实际等模板字段；**问题说明、界面现象和操作影响全部合并进“实际行为”**，不再另建“问题说明”“对我的影响”等小节。普通用户可执行的步骤仍放“复现步骤”。
- 功能建议的当前不便并入“需求场景”；设备信息也放在该字段内，源码参考折叠放入“建议方案”。缺陷源码、调用计数和夹具折叠放入“替代证据”。不要再为了叙事顺序把模板的字段调换。
- 设备型号统一为 `【设备型号】`，提交前可直接替换。已知环境继续使用 Android 15、骁龙 7gen2+、12 GB RAM；不要虚构具体机型。
- 用户此前对 17 份稿件确认原版 **1.18.4-rc.1**，覆盖早期仅记录 U06/U07 原版确认的旧范围。新增 U12 按本次现象独立记录，实际构建号／安装包来源、阅读环境和诊断待填，不将旧确认扩大为新安装包记录。原 U11 仍已撤出。
- U05a/U05b/U08/U12 的真实阅读诊断尚未提供，相关字段使用占位符。不要在用户正文中写“当前在云端、没有连接原设备”等代理身份的理由，更不要替用户编造采集尝试。U12 直接解释现象、影响及同步字节处理，链接当前仓库，不展开 Prime 修复历史。
- 原版现象按用户确认记录；具体根因仍按已有证据写。U01 的三种卡顿已由用户确认，“每次键盘动画更新都重建整个页面”仍是怀疑，不能写成已有逐帧记录。没有提供的帧率、耗时或诊断不能编造。
- 模板的下拉选择与确认项保留原文。界面问题未提供日志时，诊断方式与无法取得原因两个可选字段不作选择；保留日志说明与替代证据，不编造采集障碍。阅读性能稿的必填诊断仍使用真实待填占位符。
- 保留其余标题与编号；独立 Issue/同一个 PR 以补充后的 18 项清单为范围。U11 不复用，新增本问题编号 U12。公开 Issue 不放本地测试中断、云环境恢复、维护待办等代理工作过程。这些信息留在本交接和迁移记录。

## 已确认的基线与用户信息

- 源仓库：`CyrilPeng/Venera-Next`，本轮复核 main 为 `482810df369d126e4011be31d64408e33aede76f`，版本元数据 `1.18.4-rc.1+250`。下次先 fetch 并检查增量，不能假定 main 未前进。
- fork：`tianjinsa/Venera-Next`；日常二次开发分支：`codex/agent-center-tab`。本轮开始 HEAD `6a1fe07b20882f5d8e39f1144bab736ea0a5d619`；上游合并已保存为 `0da6946f`，共同祖先 `5eccbc7`。没有改 fork/main。
- 既有修复集中在 `d28e4bd`、`843a947`、`dee61e8`，它们包含多项行为与 fork 适配，**不能整提交迁到上游**。本轮新增阅读/导航补丁为 `0788c89380d8960db6647fe9b9acfb18609ddaf8`（`fix(reader): 修复加载跳动并统一详情搜索导航`）；阅读部分按 U08–U10 逐段适配，导航部分属于 agent 新入口回归，不能整提交当上游缺陷回移。E04 实现需要时才参考相应导航适配。
- Prime 只作为行为参考：`tianjinsa/venera-prime` 的 `codex/agent-center-tab@2e287566c6fad11b0085bbdf4a528e507021ec61`。上游 PR 不合并 Prime 历史、版本或整文件。
- 用户最早确认旧“待原版验证”表中的 **用户编号 2/4**：U06 收藏详情过场、U07 阅读首帧透明，不是 U02/U04。随后已明确保留的缺陷都在最新原版存在，不再将确认范围限制为两项。环境为 **1.18.4-rc.1 / Android 15 / 骁龙 7gen2+ / 12 GB RAM**；设备型号统一为 `【设备型号】`，提交时直接替换。
- U01 不能只讲额外历史查询。用户补充的实际现象是：从其他页面进入大收藏夹会卡顿；从收藏夹打开的漫画详情返回也会卡顿；点收藏夹内搜索按钮时，尚未输入文字，手机输入法弹出动画就非常卡顿。保留全部三条复现路径，不把问题缩成输入法打字慢。
- 阅读偶发卡顿和瀑布流上移对应 U08–U10，按用户最新确认写原版现象；原因封面新入口的标签导航仍按此前明确更正仅记作 agent 回归，原 U11 的上游缺陷归类已撤回。

## 范围与归因

- 一份 Issue 一个问题；U05 原组合项拆为 U05a/U05b，旧编号保留。一个上游 PR 可以包含各问题的独立提交和统一验证。
- 缺陷稿 U01–U10（含 U05a/U05b，共 11 份）与建议 E01–E06 都在索引列全。后续“全部问题一个 PR”以这 17 项清单逐项勾选；原 U11 不在其中。E 项在 PR 中明确标为交互/功能扩展，不能当作数据损坏或崩溃。
- 不带入 Agent、联网模型、作者独立屏蔽、线条增强/夜览、历史每日统计/复合主键迁移、fork 签名、构建加速、发行身份/版本、仓库 Skill 或本目录反馈稿等 fork 专属内容。若某项通用修复依赖这些实现，应重写为上游已有服务的最小适配。
- 上游已经有菜单锁、左右白边裁剪、详细封面状态约束、大字号/选择器布局与收藏快捷操作；不要覆盖或重复修复。保留上游数据列、两级收藏、平台能力门禁、任务/取消所有权及备份同步格式。
- U06 已知有现象，但 `Navigator.of(key.currentContext)` 会找到该 Navigator 本身；不要再用“必然找到父 Navigator”解释。上游已经传递 heroID，不能写成完全缺失。先用原版 UI 对照和路由/Hero 控制器证据确认要提交的最小改动。
- 原 `onTapTag` 选择主导航器与 agent 新入口选择根导航器之间的关系，是排查线索；这不能独立确定上游代码有错。保留分支修复与回归；未来 E04 的实现应根据实际路由设计选择合适的导航器，不默认回移所有普通卡片的导航改动。
- #93/#112/#115/#118/#125 于 2026-11-13 读取时 closed，#129 open/awaiting-feedback；#125 仍有 investigating 标签。不是所有相似症状都同根因。后续发布前仅做必要增量去重，不为交接再次扫描整仓。

## 从上游建一个干净 PR 分支

当前仓库规则默认只在 `codex/agent-center-tab` 开发。本轮没有批准立刻切换；**新会话用户明确要求上游 PR 分支时，该明确指令优先于默认分支规则**，无需因旧规则再次确认。先保护现有工作，不能 reset/clean/强制切换或自动 stash。

```sh
cd /workspace/Venera-Next
git rev-parse --show-toplevel
git branch --show-current
git status --short --branch
git remote -v
# 工作树干净后，确认 upstream 指向 CyrilPeng/Venera-Next。
# 若不存在，可添加已核对 URL；若已存在但不同，先核对，勿直接覆盖。
git fetch --no-tags upstream main
git switch -c codex/upstream-reader-ui-fixes upstream/main
```

本轮环境仅有 origin remote，但已经通过显式 URL fetch 得到 `refs/remotes/upstream/main`；不要把这个引用误认为 remote 配置也已存在。需要时添加 `git remote add upstream https://github.com/CyrilPeng/Venera-Next.git`。

- 不从 Agent 分支直接开上游 PR，不把整个 Agent 分支合到新分支，不 cherry-pick 大迁移/上游合并提交。
- 用 `git show codex/agent-center-tab:<路径>` 读取参考，仅拣选适用函数/测试并按上游类型接口改写。先检查上游增量中是否已有等价实现，已有则记录替代 commit，不重复回移。
- 作者与提交者继续遵循根规则的 Codex Cloud 身份；新分支推到 fork 的同名远端，PR base 为 `CyrilPeng/Venera-Next:main`。所有问题同一个 PR，不逐项另开 PR。
- Issue 发布和 PR 创建要按新会话实际授权执行；本文件不是一次远程发布操作。

## 每项实现与验证映射

| 项 | 优先参考的实现 | 回移和回归要点 |
| --- | --- | --- |
| U01 | `lib/features/favorites/local_favorites_page.dart`、`comic_widgets/comic_list.dart`、`foundation/context.dart` | 保留用户的进入大收藏夹、详情返回、搜索唤起键盘三种场景；核对键盘 viewInsets 连续变化时的重建/整表计算，不把逐帧重建当成已测结论。“全部”零逐项历史查找；已读缓存失效；无关设置不重滤；保留多选/搜索/新增删除/目录切换及 Hero 身份。`local_favorites_refresh_test.dart` 的 1200 项夹具是逻辑计数，不是输入法动画性能报告。不要顺带移植作者规则或整份历史数据库。 |
| U02 | `features/settings/setting_components.dart`、`setting_field.dart` | 保留 Switch/Selector 的 Element 与宽度，仅更新相关字段；原队列、保存错误、重试及窗口等待保留。参考 `setting_persistence_test.dart`；兼容上游新 Select 约束。 |
| U03 | `features/reader/scaffold.dart`、`shell_host.dart`、`settings_effects.dart`、`features/settings/reader_brightness.dart` | 预览只刷新遮罩；释放预览时读取真实作用域已提交值；面板卸载后的晚到保存仍生效；独立外壳继续遵循显式输入。不要带入 fork 的画面增强菜单。回归全局/设备/单漫画、快捷/侧栏、延迟保存与图像子树身份。 |
| U04 | `features/history/history_model.dart` | 只修已知章节名条件，保留无名称回退、分组、总数和紧凑模式。上游原 Page 文案不要因 fork 偏好强制改成 P。对应 `history_progress_description_test.dart`、`detailed_reading_progress_test.dart`。 |
| U05a | `features/reader/continuous_view.dart` | 同章同页不通知外壳；仍按可见范围预取和更新真正变更的位置。原有当前页/缩放/自动阅读/跨章回归保留。 |
| U05b | `features/reader/gallery_view.dart` | 帧后合并工作所有者/内容/布局/页码/预取数；不能恢复旧的销毁 PhotoView 做法。参考画廊连续性、旋转、预取及所有权测试。 |
| U06 | `features/favorites/local_favorites_page.dart`、原导航/Hero 控制器 | 改动要由源/目标导航器和 Hero 证据支持；不能声称上游没传 heroID，也不能把 #129 当同一缺陷。复用详情导航/Hero 夹具并在用户原设备验收。 |
| U07 | `features/reader/reader_page.dart`、`loading.dart` | 两个入口都从首帧绘制主题表面背景；加载/未完成入场同样不透明，维持正常路由动画。 |
| U08 | `features/reader/comic_image.dart` | 100 ms 合并最新进度；帧、错误、换源、销毁取消待发布值。连续图像双线性采样可作为 Prime 优化参考，不宣称已证实全部卡顿原因。参考 `comic_image_progress_test.dart`；单图 PhotoView 与 ComicImage 路径区分。 |
| U09 | `features/reader/continuous_scroll.dart`、`continuous_view.dart` | 按当前已解码阅读页做布局阶段锚点补偿，保留手势，不画中间跳动帧；初次占位不能覆盖历史/显式目标。使用公开 sliver 几何接口，不修改官方依赖/SDK。新增 `waterfall_loading_stability_test.dart` 覆盖尺寸增减、LTR/RTL、拖动、首帧、初次加载；保留 chapterless page 2/1001 续读回归。 |
| U10 | `features/reader/continuous_view.dart`、`waterfall_controller.dart` | 前章晚到先等待滚动 idle，再以插入时最新可见项和 leading edge 恢复；RequestScope 取消监听/旧结果；不使用请求开始时的旧页码。回归晚到前章、拖动保持、换章/退出和重复请求。 |
| U12 | `network/images.dart`、`foundation/cache_manager.dart`；当前仓库 `a5222bca` | 分块采用紧凑字节缓冲，缓存保留独立字节快照；保留二进制、进度、源回调、调用方修改输入后的隔离和取消清理。U12 记录图片完成附近的间歇停顿，不将 U08 进度刷新或 U09 位置变化认定为同一根因；手机诊断仍需真实提供。 |
| E01 | 收藏/历史/本地/追更消费者及 `comic_list.dart` | 沿用上游 KeywordFilter，用户列表完整，发现/搜索继续过滤；不引入 fork 的作者独立屏蔽或 Agent。 |
| E02 | `components/background_save.dart`、`reader/exit_guard.dart`、`reader_page.dart`、`images.dart`、会话注册表及应用最终退出 | 移交前冻结最终进度；后台资源归原会话；退场保留已解码图；持久错误可查看手动关闭；最终退出等真实任务。慢/失败保存、重复返回、切换新阅读器、窗口关闭都要验收。 |
| E03 | `comic_widgets/comic_tile.dart` 的 `_ReadingHistoryBadge` | 给上游做可选紧凑显示，不删详细模式；24×24、独立两行、缺总数/完成状态、长数字/大字/无障碍和封面区域约束。 |
| E04 | `comic_widgets/keyword_hidden_notice.dart`；分支 `tag_navigation_test.dart` 仅作新功能回归参考 | 主动可选预览、封面与原因编辑分离；测试详情中的标签/作者搜索、推荐/结果继续打开、搜索→详情→原因列表的返回链。按该新增入口的实际导航设计做必要适配，保留原版默认隐藏图像的设计意图；原 U11 不另作上游缺陷。 |
| E05 | `features/settings/keyword_blocking.dart`、规则编辑/保存接口 | 原因编辑可直接删除，旧规则/旧窗口不能覆盖新状态；持久失败可重试，已接受保存不随窗口卸载丢失。 |
| E06 | 关键词设置入口、`keyword_hidden_notice.dart` | 只读收藏扫描、不重新启用收藏隐藏、不改库；分批/取消/generation 门禁；编辑删除后按真实规则重算；无逐本详情请求。 |

测试路径除特别注明外均在 `test/features/<同功能>/`；完整文件名已在各 Issue 稿链接。不要把 fork 原生/真机历史记录直接当成本次新 PR 的验证结果。

## 已有验证，避免浪费额度

- 上游合并阶段 74 项定向 Flutter 通过：页码/封面布局、收藏与导航、菜单锁、白边裁剪。
- 新增加载/导航/前章控制定向 36 项通过；连续模式、当前图片、输入及所有权兼容 36 项通过。初次续读边界修正后，7 项真实续读/初次加载定向通过。具体代码阶段不同，不能相加声称最终全部用例一次通过。
- 最终代码本地严格 Flutter 分析无问题，47 个变更 Dart 文件格式、结构/架构/版本检查通过；依赖来源/许可证和审查工具自检通过。Python 仓库脚本 328 项（7 跳过），鸿蒙脚本 51 项通过，均发生在用户改为 Actions 之前。
- 一个扩展定向轮次主动中止，另有续读边界失败后修正；它不是全绿记录。
- 本地全量在环境恢复后已没有活跃 runner，句柄也丢失；日志停在约 14:37，记录 2271 通过、52 跳过，`source_transaction_crash_test.dart` 的 `settingsPartial` 用例出现 30 秒超时。没有完整结束摘要，记为中断，不视作全量通过；未证实 OOM，也不因怀疑 Cloud 资源不足而删测试/放宽超时。
- 当时用户要求全量移至 GitHub Actions，新增旧入口 `build.yml tests_only=true / skip_tests=false`，复用原质量工作流并抑制安装包构建；当前已由独立 `tests.yml` 替代，定向测试可在云环境运行。历史结果仍按当时准确 SHA 记录，最新入口和结论见文末。

## 下一会话的最短执行清单

1. 读本文件和 README，核验目录/分支/现有修改及准确 SHA；不要重新启动 Cloud 全量，定向用例按实际改动选择。
2. 核对已有 Actions run 结论，只读必要失败摘要；未完成不当作通过。
3. 用户明确启动上游 PR 工作后，从最新 upstream/main 建上面那个单独分支，按映射逐项回移/适配。先处理确定缺陷，再把 E 项作为明确的交互扩展纳入同一 PR；不夹带 fork 专属功能。
4. 每项带最小、有效业务回归，保留原生命周期/持久化门禁；更新上游 CHANGELOG，格式/结构/依赖及质量门禁按其当前规则执行。
5. 在 fork 对应 PR 分支使用 GitHub Actions 验证。`tests_only` 是本轮 fork/Agent 分支新增入口，从 upstream/main 创建的纯净 PR 分支未必包含它，不能机械传入未知参数或为了测试把 fork CI 改动混进上游 PR。可以在修复可审查后创建下面那个同一草稿 PR，使用上游现有 pull_request 质量门禁，验证通过后再标 ready；不要另开测试 PR。默认 Skill 的分支名服从新会话明确授权，不能误推 Agent/main。记录 SHA/run/job，失败修正后核对新 SHA。
6. 按授权一次性创建一个上游 PR，描述问题→行为→验证及原生/真机限制。各 Issue 分别提交，并把编号链接回 PR；不要把本轮的“未发布稿件”说成已有线上 Issue。

## 本轮 CI 与交付记录

- 产品修复：`0788c89380d8960db6647fe9b9acfb18609ddaf8`。
- 反馈、Skill 与 tests_only 入口：`423e67a326d594e5f226005fe56e279dcfdd4135`。
- 本轮 [Actions run 43364772554](https://github.com/tianjinsa/Venera-Next/actions/runs/43364772554)，验证 head SHA **`423e67a326d594e5f226005fe56e279dcfdd4135`**，tests_only=true / skip_tests=false，所有安装包开关 false。
- 首次派发 HTTP 503，核对未创建运行后重试成功；不是创建了两轮。交付时仍在运行：元数据/脚本检查、analyze、Apple 目录授权与 iOS Rhttp 兼容检查 success；Android Provider 与 Rhttp 原生任务尚在运行，Flutter 完整回归等待原生库。后续会话先查询该 run 的最终结论，不能据此声称全量通过。后续仅补文档的提交不自动当作另一个已验证源码 SHA。

读取本轮最终结果时只需先执行：

```sh
gh run view 43364772554 --repo tianjinsa/Venera-Next \
  --json url,headSha,status,conclusion,jobs
```

若失败，只读取失败 job 的必要日志/堆栈；不重跑 Cloud 测试，不重新解析全部历史日志。先核对 headSha 是否为 `423e67a326d594e5f226005fe56e279dcfdd4135`。本轮后续仅文档/Skill 说明提交不意味着另一份产品源码已被验证。

## U12 与最新运行接续（2026-11-13）

- U12 直接说明图片刚加载成功附近的间歇卡顿、连续模式明显／瀑布流较轻，链接当前仓库 `a5222bca`，不展开 Prime 修复历史。实际安装包和阅读诊断仍需按真实情况填写；未发布上游 Issue。
- 最新产品源码为 `a5222bcab780c58e4ea3097c1f0c8a3a51eb4b80`，定向三轮共 345 项通过、23 项按原条件跳过，另有可重复的同步字节准备对照；不把这些结果当作手机帧率或全量通过。
- 最新 [Actions 43401061170](https://github.com/tianjinsa/Venera-Next/actions/runs/43401061170) 验证该 SHA，最终 success，所有质量任务通过；旧 `c0a80e33` 的 `43398732298` 已被新任务并发取消。上方 `423e67a3` 的旧运行最终已 success，但不覆盖本次新源码。
- 后续手动全量使用新独立入口 `tests.yml`（Actions 名「全量测试」），`build.yml tests_only` 已删除；本段旧 run 当时仍使用旧入口，不重写其真实调用历史。
- 不重复派发、不每分钟查看状态。派发后先等运行满 20 分钟；仍未结束时至少间隔 10 分钟，用户主动要求状态时除外。只读取必要最终摘要／失败堆栈，不反复读取数千项日志。最新结论同步至[迁移记录](../agent/migration.md#反馈稿与-ci-等待2026-11-13)。
