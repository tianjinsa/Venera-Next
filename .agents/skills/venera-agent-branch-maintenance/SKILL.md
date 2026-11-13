---
name: venera-agent-branch-maintenance
description: 维护 Venera Next 二次开发分支的功能、修复、性能和构建更新。修改本仓库、提交推送或合并上游时使用；先核验 codex/agent-center-tab，按长期登记表保留行为，云环境运行有界定向测试，全量使用 fork 的 GitHub Actions。
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

## 验证：云环境定向测试，全量使用 GitHub Actions

按用户 2026-11-13 的最新澄清，**非全量测试可以在云环境运行，只有全量测试在 `tianjinsa/Venera-Next` 的 GitHub Actions** 运行。Cloud Codex 根据修改范围运行有界定向回归，不自动启动本地全量或重型构建，不以云端算力不足为理由删测试、延长用例超时或修改 SDK。

1. 完成可审查的代码和文档，核验分支、身份和差异；按会话已授权的范围提交并推送。测试必须对应准确源码 SHA，后续改产品代码需验证新 SHA。
2. 优先复用现有 PR 检查；需要手动测试时，在工作分支调用 `build.yml` 的 `tests_only: true`、`skip_tests: false`。该入口复用 `analyze.yml` 的完整质量门禁，不构建安装包、不发布 Release、不创建临时 PR。示例：

   ```sh
   gh workflow run build.yml --repo tianjinsa/Venera-Next \
     --ref codex/agent-center-tab \
     -f tests_only=true -f skip_tests=false \
     -f build_android=false -f build_windows=false \
     -f build_macos=false -f build_ios=false \
     -f build_linux_x64=false -f build_linux_arm64=false
   ```

目标分支若不含 tests_only，使用其已有的 PR 质量检查；不要机械提交未知输入，也不要把 fork CI 专属改动夹进上游 PR。

3. 记录 run URL、head SHA、所需 job 和最终 conclusion；派发成功、queued、in_progress 都不是测试通过。派发后仅确认一次 URL／SHA；全量通常至少需要 20 分钟，运行满 20 分钟前不反复查询，之后仍未结束时至少间隔 10 分钟再查，用户主动要求状态时除外。期间处理独立文档，不使用每分钟 watcher；结束或失败后才读取必要日志段，不下载/重读整份数千项过程日志。
4. 失败时定位失败用例及原因，修正后只为新变更/未解决问题安排必要验证。源任务/原生资源、持久化失败、TV、最终退出等待等既有门禁不能因改用 Actions 丢失。
5. 若云环境中已有本地测试，用户改为 Actions 后停止旧轮次并记录为中止；环境重连后先核对进程和最终摘要，句柄丢失不等于测试完成。不自动重跑本地全量，也不把超时/环境中断写成通过或武断归因为 OOM。

根据修改范围选择有界本地定向用例，无需为已授权的定向测试另行确认；输出写 `/workspace/work/<任务>/`，等待结束后读取一次摘要，不并发本地测试/构建，不修改正在被验证的产品代码。复用历史证据和 CI 缓存，启动环境本身不自动测试，全量仅在 Actions 运行。

用户明确要求跳过测试时，以当前会话要求为准：不启动新测试，停止已要求停止的轮次，记录跳过/中止范围，继续已授权的提交推送，不再次索要同一授权。凭据或工作流权限不足时说明具体失败和可运行命令，不获取或展示秘密、不擅自扩大权限。

## 提交与交付

- 提交信息使用中文。云端 author 与 committer 均为 `Codex Cloud (GPT-6) <codex@openai.com>`；本地为 `Codex (GPT-6) <codex@openai.com>`。仅设置仓库本地 Git 配置，检查是否被身份环境变量覆盖。
- 提交前、推送前重新核验当前分支与工作树，明确待提交文件；保留用户已有修改。
- 推送使用完整目标：`git push origin HEAD:refs/heads/codex/agent-center-tab`，不 force push。核对远端 SHA 与本地 HEAD，再报告结果。
- 交付说明包含行为变化、真实验证和限制；无需重复请求会话已经授权的动作。
