---
name: venera-agent-branch-maintenance
description: 维护 Venera Next 二次开发分支的功能、修复、性能和构建更新。修改本仓库、提交推送或合并上游时使用；先核验 codex/agent-center-tab，按长期登记表保留行为与回归测试。
---

# Venera Next 二次开发分支维护

## 先核验现场

本仓库位于 `/workspace/Venera-Next`，二次开发分支固定为 **`codex/agent-center-tab`**。`main` 只用于 fork 同步；`work`、自动生成的任务分支或其他 checkout 不能作为开发分支。

第一次修改文件前执行并查看结果：

```sh
cd /workspace/Venera-Next
git rev-parse --show-toplevel
git branch --show-current
git status --short --branch
```

当前分支必须与完整名称一致，不能仅根据「codex 开头」、目录名或此前对话推断。分支不对时按[云环境启动 Skill](../venera-cloud-startup/SKILL.md)的安全切换步骤处理。切换前保留现场；有未提交修改时不强制切换、不 reset、不清理、不自动 stash 或丢弃文件。

## 阅读与登记

在仓库根目录阅读：

- `AGENTS.md`、`agent.md`：分支、身份和架构要求。
- `doc/agent/branch-change-register.md`：当前必须保留的功能、修复、数据/性能及构建约束。
- `doc/agent/migration.md`：迁移基线、存储适配、历次真实验证和未验证范围。
- `CONTRIBUTING.md`：本次变更需要的检查；涉及上游归因再读 `doc/agent/upstream-issue-candidates.md`。

按任务定位受影响条目；合并上游时完整核对 A01–A16、O01–O10、R00–R12、C01–C06、M01–M02。沿用 Next 功能目录、类型化设置、任务所有权和数据队列，保留全部 Next 数据列及平台能力门禁。

每次功能或修复变更同步更新登记表、迁移记录及 `CHANGELOG.md`。登记可观察行为、实现位置、回归入口、来源/替代提交和实际验证结果。编号保持稳定；文件搬迁同步入口，不静默删除条目或测试。

`doc/agent/agent-branch-maintenance.md` 是旧 Prime 盘点，仅用于追溯；不能据此覆盖当前 Next 实现。

## 整合上游

1. 记录当前开发 HEAD、上次整合基线和本次目标上游提交；fetch 与完成整合分开记录。
2. 只在 `codex/agent-center-tab` 处理差异；同时保留分支契约和上游新增修复。
3. 逐段解决冲突，不用整份 Prime 文件或整文件 `ours/theirs` 代替分析。
4. 上游等价实现可以替代分支实现；先验证相关行为，再登记「上游等价覆盖：提交、行为、验证结果」。不以「上游没有该功能」为理由删除 Agent 或本分支优化。
5. 不自动合入 `main`、更改应用身份/版本、发布版本或提交 Issue；根据当前会话的授权完成提交与推送。

## 验证与长测试

先复现并验证受影响行为，检查生命周期、持久化失败及原有数据边界。运行本次变更所需的仓库检查；启动环境本身不自动运行全量测试。

用户明确要求跳过测试时，以当前会话要求为准：停止正在运行的测试，不启动新测试，记录未完成/跳过的范围；继续完成已授权的提交推送，不因仓库默认门禁再次要求确认。

全量 Flutter 测试超过 6000 项，可能持续 20 分钟以上。输出从开始就重定向到 `/workspace/work/<任务>/`，命令中安排测试结束后才打印退出码和摘要。使用执行工具的完成等待；不要循环读取 `tail`、`rg`、`wc`、文件时间或 `ps` 来获取进度。不要为读取过程日志反复调用工具。遵守单次等待时限，等待期间可以处理独立工作，不能同时修改正在验证的产品代码或启动第二个 Flutter 测试/构建。

若用户在测试途中补充了需要修改代码的问题，在编辑前停止这轮过时验证，记录为中止；最终代码完成后再统一验证。中止结果不计为通过。记录通过、跳过、失败和未运行的原生/真机项目，不把定向复跑描述成再次全量通过。

## 提交与交付

- 提交信息使用中文。云端 author 与 committer 均为 `Codex Cloud (GPT-6) <codex@openai.com>`；本地为 `Codex (GPT-6) <codex@openai.com>`。仅设置仓库本地 Git 配置，检查是否被身份环境变量覆盖。
- 提交前、推送前重新核验当前分支与工作树，明确待提交文件；保留用户已有修改。
- 推送使用完整目标：`git push origin HEAD:refs/heads/codex/agent-center-tab`，不 force push。核对远端 SHA 与本地 HEAD，再报告结果。
- 交付说明包含行为变化、真实验证和限制；无需重复请求会话已经授权的动作。
