# 项目代理约定

开始工作前必须阅读并遵循 [agent.md](agent.md)。第一次编辑前先核验实际仓库根目录和完整分支名，二次开发仅在 `codex/agent-center-tab` 进行，不能在 `main`、`work` 或自动生成的任务分支继续开发。

本仓库的可发现 Skills：

- [云环境启动与恢复](.agents/skills/venera-cloud-startup/SKILL.md)：核验/安全切换正确分支，复用环境及身份，默认在 GitHub Actions 测试并记录准确 SHA/结果。
- [二次开发分支维护](.agents/skills/venera-agent-branch-maintenance/SKILL.md)：修改、验证、提交推送及上游整合时保留功能契约和维护记录。

全量测试使用 fork GitHub Actions 的独立 `tests.yml`（「全量测试」）；Cloud Codex 可以运行本次修改相关的有界定向测试，不自动启动本地全量或重型构建。构建使用 `build.yml`，不再传 `tests_only`。具体入口及结果记录遵循上述两份 Skill。
