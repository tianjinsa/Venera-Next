# [Enhancement]: 希望退出阅读时先返回上一页，保存进度在后台完成并明确提示失败

<!-- feedback-id: E02; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 06-enhancement.yaml -->

[对应上游功能建议表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=06-enhancement.yaml)

### 问题类型 / Issue type

功能建议 / Feature request

### 涉及功能 / Feature area

阅读器 / Reader

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 需求场景 / Use case

我希望离开阅读器时能先正常返回上一页，而不是一直停在阅读页等保存结束；同时，我也需要明确知道进度到底有没有保存成功。

保存较慢时，我点返回后仍要留在阅读页等待，不能马上继续浏览其他漫画。若改成后台保存却没有明显的失败提示，我又会担心下次打开时进度丢失。

我的使用环境：

- 应用：1.18.4-rc.1（官方原版）
- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 建议方案 / Proposed solution

我希望点返回后保留正常退场动画，进度在后台继续保存，右下角显示状态。保存失败时保留可查看的错误提示，让我明确处理；退出整个应用时仍等必要的保存完成。

<details>
<summary>已有实现参考与相关讨论（供维护者参考）</summary>

我理解当前返回是在等待异步任务完成，这不等于已经确定存在同步磁盘阻塞。#112 的旧关闭失败报告与这项体验建议分别讨论。

- [lib/features/reader/exit_guard.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/exit_guard.dart#L119)
- [test/features/reader/reader_exit_integration_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/reader_exit_integration_test.dart)
- [test/components/background_save_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/components/background_save_test.dart)

</details>

### 验收标准 / Acceptance criteria

- 慢保存不会一直挡住返回上一页。
- 退场时保留当前画面，最后的页码、章节和阅读时长正确。
- 失败提示不会自行消失，可以查看详情并手动关闭。
- 切换阅读另一部漫画不会串进度，退出应用不会丢下尚未完成的保存。

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
