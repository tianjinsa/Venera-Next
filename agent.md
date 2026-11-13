# 项目代理约定

## 开发分支

- 云端启动或恢复先使用[启动 Skill](.agents/skills/venera-cloud-startup/SKILL.md)，修改、验证和上游整合使用[分支维护 Skill](.agents/skills/venera-agent-branch-maintenance/SKILL.md)。两份 Skill 位于标准 `.agents/skills/` 目录，并由根 `AGENTS.md` 直接引用。
- 二次开发和迁移工作均在 `codex/agent-center-tab` 分支进行。
- 第一次编辑、提交及推送前检查实际仓库根目录、完整分支名与工作树；不能因为环境默认 checkout、目录名或历史对话而假定分支正确，不在 `work` 或其他自动生成分支开发。
- `main` 保留用于 GitHub fork 自动同步，不向 `main` 提交或合并开发改动。
- 修改 Agent、二次开发修复、构建工作流或合并上游前，阅读 [分支功能与修复登记表](doc/agent/branch-change-register.md) 和 [迁移与功能维护清单](doc/agent/migration.md)。完成后同步行为、实现位置、验证入口及实际验证结果。
- 用户 2026-11-13 澄清：非全量测试可以在云环境运行，只有全量测试放在 fork 的 GitHub Actions。Cloud Codex 按修改范围运行有界定向回归，不自动启动本地全量或重型构建；全量使用工作分支 `build.yml` 的 `tests_only=true`、`skip_tests=false`，记录准确 SHA、run 链接和最终结果；详见两份 Skill。
- 测试耗时问题已有[分析与接续记录](doc/development/test_performance_analysis_20261110.zh.md)及统计快照。测试自身性能优化当前暂缓，验证运行位置已改为 GitHub Actions；后续接续先复用已确认基线，只补待测量项，不因启动新会话自动重跑全量、重复分析或修改测试策略。
- 合并上游时逐项核对登记表 A01–A16、O01–O10、R00–R12、C01–C06、M01–M02，不能因上游未包含某功能、文件无冲突或重构而静默移除本分支行为与回归测试。上游已有等价实现时，登记替代提交并验证后可统一实现；文件搬迁同步维护入口。
- 沿用 Venera Next 的功能目录、数据操作队列和类型化设置；不得用 Prime 的整文件覆盖替换 Next 的有效实现。

## 提交身份

- 所有由本项目 AI 代理创建的提交，作者（author）和提交者（committer）的姓名都必须完整写为：
  - `Codex Cloud (GPT-6)`（如果使用云端 Codex）。
  - `Codex (GPT-6)`（如果使用本地 Codex）。
- 使用代理专用的 noreply 邮箱 `codex@openai.com`，不要沿用仓库维护者的个人提交身份。
- 如果是云端 Codex，在本仓库设置本地配置：

  ```sh
  git config --local user.name 'Codex Cloud (GPT-6)'
  git config --local user.email 'codex@openai.com'
  ```

- 提交前检查 author 和 committer，避免环境变量覆盖本地配置；不要修改全局 Git 身份。
