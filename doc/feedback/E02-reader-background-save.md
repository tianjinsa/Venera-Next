# [Enhancement]: 阅读返回可先完成退场，后台保存并保留可查看的错误状态

<!-- feedback-id: E02; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

阅读器 / Reader

### 平台 / Platform

所有支持的平台 / All supported platforms（建议适用范围，不代表所有平台已完成实现/验收）

### 需求场景 / Use case

离开阅读器时，原版会等待已接受的保存/图像任务完成，期间显示保存对话框；较慢任务会让用户停留在阅读页。

### 建议方案 / Proposed solution

先冻结最终进度和前台阅读时长，把原会话已接受的保存与资源收尾移交后台；正常播放退场动画，右下角显示保存状态。失败保留可查看、手动关闭的错误，应用最终退出仍等待实际任务。

### 验收标准 / Acceptance criteria

- 离开阅读器无需等待慢保存完成，退场期间保留已加载画面。
- 最终页码/章节/阅读时长准确，不因返回丢失。
- 错误不自动消失，用户可查看详情；查看期间出现的新错误不被一并清掉。
- 最终窗口/应用退出仍等待原会话持久化与原生清理，取消和重复返回不重复提交。

### 截图或录屏 / Screenshots or video

本稿未附附件；可用普通测试数据验证上述完成条件。

### 实现参考与已有讨论

原版等待路径：[lib/features/reader/exit_guard.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/exit_guard.dart#L119)。这不是同步磁盘 I/O 的归因，也不等同于已关闭的 #112。参考 fork 的 `BackgroundSave`、`ReaderExitGuard`、读取会话注册表及 `reader_exit_integration_test.dart`。

源码核对基线：`482810df369d126e4011be31d64408e33aede76f`。这是功能/交互建议，不将现有设计冒称为已确认的数据损坏或崩溃。

### 提交前确认 / Checklist

- [x] 已检索相关建议，一稿聚焦一个目标。
- [x] 建议针对应用本体。
- [x] 文本未包含私人内容或凭据。
