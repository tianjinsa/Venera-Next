---
name: venera-cloud-startup
description: 启动或恢复 Venera Next 的 Codex Cloud 工作环境。先确认 /workspace/Venera-Next 和 codex/agent-center-tab，再进行编辑、验证、提交或推送；禁止在 main/work 等错误分支继续开发，避免启动时重复安装依赖或运行全量测试。
---

# Venera Next 云环境启动与恢复

此 Skill 适用于当前项目的云环境，可复制到云环境启动 Skill 配置中。它不会自动安装工具、运行测试、合并上游或发布版本。每次新会话或环境恢复后重新检查实际状态，不沿用上次环境 ID、当前目录或分支结论。

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

在第一次编辑、每次提交和推送前，执行下面的分支门禁；非零退出表示不能继续写入：

```sh
if [ "$(git rev-parse --show-toplevel)" != /workspace/Venera-Next ] || [ "$(git branch --show-current)" != codex/agent-center-tab ]; then
  printf '%s\n' '仓库或分支不匹配：停止写入，先保留现场并修正工作分支。' >&2
  exit 1
fi
```

目标分支不可获取时明确报告阻塞，不能改在 `main`、`work` 或临时分支完成提交。用户在当前会话明确指定了其他分支时，按其最新明确指令处理，并同步本分支维护约定。

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

Python 打包回归需要常规目录权限时，仅在相应子进程设 `umask 022`。不改全局权限，不将云端测试通过描述为 Android/Apple/Windows/HarmonyOS 原生或真机通过。

## 4. 核验 Git 身份

```sh
git config --local user.name 'Codex Cloud (GPT-6)'
git config --local user.email 'codex@openai.com'
git var GIT_AUTHOR_IDENT
git var GIT_COMMITTER_IDENT
```

author 与 committer 均须匹配。检查覆盖本地配置的 `GIT_AUTHOR_*` / `GIT_COMMITTER_*` 变量；只对本任务修正，不改全局配置。提交信息使用中文。每次提交前和推送前重新检查分支，不将启动时的检查视为永久有效。

## 5. 长测试只在完成后读取摘要

启动检查不自动运行测试。根据本次改动及 `CONTRIBUTING.md` 选择验证；需要全量 Flutter 回归时只启动一轮最终代码验证。下面的命令自行等待测试结束，再输出退出码与末尾摘要：

如果用户当前明确要求跳过测试，立即停止运行中的测试，不再启动测试，记录实际验证范围后继续已授权的提交推送；不得因默认测试要求反复确认或阻塞交付。

```sh
mkdir -p /workspace/work/current-validation
if flutter test --no-pub --reporter expanded > /workspace/work/current-validation/flutter-test.log 2>&1; then
  test_exit=0
else
  test_exit=$?
fi
printf 'Flutter test exit: %s\n' "$test_exit"
tail -n 12 /workspace/work/current-validation/flutter-test.log
exit "$test_exit"
```

正式任务使用独立日志目录，保留失败证据。执行工具若返回运行 ID，使用其完成等待能力，遵守单次等待上限；**不要不断轮询日志或进程，不循环调用 tail/rg/wc/stat/ps 查询进度**。等待期间可做独立审查或文档，不修改被验证的产品代码，不并发启动另一个 Flutter 测试/构建以争用测试资产。仅在完成后读取一次摘要；失败时再定位具体失败段。

用户补充新问题而必须修改代码时，先停止旧验证并记录中止，最终代码完成后统一运行。明确区分中止、全量通过、失败修正后定向通过和未运行，不虚报结果。

## 6. 完成前复核

更新维护登记表、迁移记录和 `CHANGELOG.md`。提交只包含本任务文件，检查中文提交信息、双重身份及正确分支。推送须已有用户授权；当前会话已授权的动作继续完成，不重复确认：

```sh
git branch --show-current
git status --short --branch
git push origin HEAD:refs/heads/codex/agent-center-tab
git ls-remote --heads origin refs/heads/codex/agent-center-tab
git rev-parse HEAD
```

确认远端 SHA 一致，报告提交、文档和真实验证范围。不要向 `main` 推送，不 force push，不自动清理用户工作或创建上游 Issue。
