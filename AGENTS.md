# 项目代理约定

开始工作前必须阅读并遵循 [agent.md](agent.md)。第一次编辑前先核验实际仓库根目录和完整分支名，二次开发仅在 `codex/agent-center-tab` 进行，不能在 `main`、`work` 或自动生成的任务分支继续开发。

本仓库的可发现 Skills：

- [云环境启动与恢复](.agents/skills/venera-cloud-startup/SKILL.md)：核验/安全切换正确分支，复用环境及身份，长测试等待结束后才读取摘要。
- [二次开发分支维护](.agents/skills/venera-agent-branch-maintenance/SKILL.md)：修改、验证、提交推送及上游整合时保留功能契约和维护记录。
