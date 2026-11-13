# [Reader]: 图片加载期间滑动翻页偶发卡顿，进度刷新可能增加额外负担

<!-- feedback-id: U08; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 02-reader-performance.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=02-reader-performance.yaml)

### 问题类型 / Issue type

阅读卡顿、慢加载或内存异常 / Reader performance

### 应用版本 / App version

1.18.4-rc.1（官方原版）。

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 设备与系统 / Device and OS

- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 复现步骤 / Steps to reproduce

1. 在原版 1.18.4-rc.1 中打开漫画，保留图片正在加载的状态。
2. 在加载期间连续滑动阅读，留意偶发的停顿。
3. 维护者可按后面的最小验证连续发送进度，区分进度刷新问题与网络等待。

### 预期行为 / Expected behavior

加载进度适度更新并显示最新值，图片完成时立即出现；翻页尽量顺畅，换图、失败或退出后不再收到旧图片的进度更新。

### 实际行为 / Actual behavior

我滑动翻页时会不定时顿一下，手指滑动和画面跟随不够稳定，打断连续阅读。图片仍在加载时，我也希望能正常滑动查看已经显示的内容。

排查发现，图片还在加载时，每个下载分块都会立即刷新图片组件，进度更新没有合并，短时间内可能产生很多与滑动同时进行的更新。这是额外刷新负担的线索，是否能解释全部卡顿仍需进一步定位。

### 阅读环境 / Reading context

手机触摸滑动翻页，图片加载期间出现不定时停顿；除了等待图片出现，滑动画面本身也会短暂停顿。

### 诊断提供方式 / Diagnostic source

`【诊断提供方式：粘贴报告／上传附件／无法取得】`

### 日志或诊断报告 / Logs or diagnostic report

`【手动阅读诊断报告或附件】`

我目前提供的源码与组件线索见“替代证据”。

### 日志无法取得的原因 / Why diagnostics are unavailable

`【无法取得诊断的原因（如已提供报告，可删除本项）】`

### 替代证据 / Alternative evidence

<details>
<summary>源码定位与最小验证（供维护者参考）</summary>

修复前的最小组件验证在 40 毫秒窗口内从 10% 更新到 90%，没有约 100 毫秒的进度合并。该数字是刷新策略验证，不是设备帧率；不把网络等待或所有阅读卡顿都归因于此。

源码定位：

- [lib/features/reader/comic_image.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/comic_image.dart#L338)

已有最小验证入口：

- [test/features/reader/comic_image_progress_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/comic_image_progress_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
