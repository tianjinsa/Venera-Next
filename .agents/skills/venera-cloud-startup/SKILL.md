---
name: venera-cloud-startup
description: 启动或恢复 Venera Next 的 Codex Cloud 工作环境。先确认 /workspace/Venera-Next 和 codex/agent-center-tab，再进行编辑、验证、提交或推送；禁止在 main/work 等错误分支继续开发，复用依赖，默认在 fork 的 GitHub Actions 测试，不在 Cloud 自动跑本地测试。
---

# Venera Next 云环境启动与恢复

## 1. 固定仓库与分支，先检查后修改

仓库必须是 **`/workspace/Venera-Next`**，二次开发分支必须是 **`codex/agent-center-tab`**。`main` 仅用于 fork 自动同步，`work` 或其他平台自动生成分支不是开发分支。不要创建第二份 checkout/worktree，也不要重新 clone 来绕开分支问题。

先执行只读检查：

```sh
cd /workspace/Venera-Next
git rev-parse --show-toplevel
git branch --show-current
git status --short --branch
git log -1 --format='%h %s'
```

确认仓库根目录和**完整分支名**。在结果确认之前，不编辑文件、不安装项目依赖、不运行会修改工作树的生成器、不提交或推送。第一次进度更新说明实际工作分支，不要只说「已进入项目」。

如果分支正确，保留已有修改并继续。如果分支不对：

1. 检查 `git status --porcelain=v1 --untracked-files=all`。有已有修改时停止写入，说明实际分支、目标分支和需保留的修改；可以继续独立的只读分析。不要自动 reset、clean、stash 或强制 checkout。
2. 工作树干净且本地目标分支存在时，执行 `git switch codex/agent-center-tab`，不要停留在 `work`。
3. 本地目标分支不存在时，先核对 origin 对应 `tianjinsa/Venera-Next`，再只获取并跟踪目标分支：

   ```sh
   git fetch --no-tags origin refs/heads/codex/agent-center-tab:refs/remotes/origin/codex/agent-center-tab
   git switch --track -c codex/agent-center-tab origin/codex/agent-center-tab
   ```

4. 重新执行根目录、分支、工作树及 HEAD 检查，确认后才开始修改。不自动删除原分支或其独有提交，不自动 pull/merge/rebase，不修改 `main`。

## 2. 读取仓库规则

阅读根目录 `AGENTS.md`、`agent.md`、`.agents/skills/venera-agent-branch-maintenance/SKILL.md`、`doc/agent/branch-change-register.md` 和 `doc/agent/migration.md`。按任务核对相关功能；合并上游时检查全表。旧 Prime 文档只作追溯，当前 Next 的数据队列、类型化设置、扩展字段和平台门禁必须保留。

云环境工具可用时，读取当前环境状态一次，核对返回的环境与当前 executor。仅在任务需要网络/依赖变更时检查对应网络及凭据就绪情况；不反复轮询环境状态，不输出凭据或完整环境变量。

## 3. 复用当前开发环境

使用现有 SDK、缓存和原生测试库：

```sh
export PATH=/workspace/flutter-sdk/bin:/workspace/rust/cargo/bin:/workspace/python-tools/bin:$PATH
export PUB_CACHE=/workspace/.pub-cache XDG_CONFIG_HOME=/workspace/.config
export CARGO_HOME=/workspace/rust/cargo RUSTUP_HOME=/workspace/rust/rustup CI=true
export PYTHONPATH=/workspace/python-tools
export LD_LIBRARY_PATH=/workspace/Venera-Next/build/test-native/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
cd /workspace/Venera-Next
command -v git flutter dart python
```

必要时读取 `/workspace/venera-setup-notes.txt`。不要仅因为进入了新会话就重新安装 SDK、更新锁文件或重跑环境准备；只修复实际缺少的能力。需要解析依赖时使用锁定版本：`flutter pub get --enforce-lockfile`。不得修改 Flutter SDK 来掩盖项目或测试问题。中间文件和日志放在 `/workspace/work/<任务>/`，不放仓库根目录或用户主目录。

GitHub Actions 的 Python 打包回归需要常规目录权限时，仅在相应子进程设 `umask 022`。不改全局权限，不将云端测试通过描述为 Android/Apple/Windows/HarmonyOS 原生或真机通过。

## 4. 测试交给 GitHub Actions

用户已明确：Cloud Codex 可能算力有限，**默认在 fork 的 GitHub Actions 跑测试**。本地只做编辑、文档、源码核对、格式及轻量静态检查；不要因启动/恢复会话就运行 Flutter、Python、原生测试或重型构建，也不要重复安装原生测试环境。

- 先读取[分支维护 Skill](../venera-agent-branch-maintenance/SKILL.md)的 Actions 流程。使用现有 PR 检查，或工作分支的 `build.yml`：`tests_only=true`、`skip_tests=false`，六个平台安装包开关均为 false；测试复用 `analyze.yml`，不发布版本。
- 先完成源码并按会话授权提交推送，再触发对应 SHA 的验证；记录 run URL、head SHA、job conclusion 和失败摘要。queued/in_progress 不当作通过，旧 SHA 的结果不当作新源码的通过。
- 可以在 CI 等待期间处理独立文档。不频繁查询状态，不循环读取完整日志；失败后只提取需要的失败名称和堆栈。已完成的历史结果不因新会话自动重跑。
- 环境重连导致旧句柄丢失时，先确认本地进程是否还存在、是否有完整结束摘要；中断/部分通过/超时要如实记录。停止已明确切换到 CI 的本地轮次，不重复启动本地全量，不把资源问题推断为已证实 OOM。
- 只有用户明确要求本地复现时才跑有界最小用例，沿用结束后读取一次摘要的规则，且不并发启动第二个测试/构建或修改被验证的产品代码。
- 用户要求跳过或停止测试时，停止相应轮次并记录，不阻塞已授权的提交推送，不再次索要确认。

## 5. 完成前复核

更新维护登记表、迁移记录和 `CHANGELOG.md`。提交只包含本任务文件，检查中文提交信息、双重身份及正确分支。
