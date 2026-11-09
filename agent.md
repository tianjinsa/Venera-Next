# 项目代理约定

## 开发分支

- 二次开发和迁移工作均在 `codex/agent-center-tab` 分支进行。
- `main` 保留用于 GitHub fork 自动同步，不向 `main` 提交或合并开发改动。
- 修改 Agent、迁移修复或合并上游前，阅读 [迁移与功能维护清单](doc/agent/migration.md)，完成后更新行为、验证入口和实际验证结果。
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
