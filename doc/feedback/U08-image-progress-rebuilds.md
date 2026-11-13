# [Reader]: 图片加载期间滑动翻页偶发卡顿，进度刷新可能增加额外负担

<!-- feedback-id: U08; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 02-reader-performance.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=02-reader-performance.yaml)

### 问题说明

我之前在二次开发版本里遇到过滑动翻页偶发卡顿。排查时发现，图片还在加载时，每个下载分块都会立即刷新图片组件，短时间内可能产生很多与滑动同时进行的更新。

### 实际行为 / Actual behavior

我看到的现象是滑动翻页会不定时顿一下。组件层已确认进度更新没有合并；它是否解释所有卡顿、在原版手机上影响多大，还需要进一步验证。

### 对我的影响

卡顿会打断连续翻页，手指滑动和画面跟随不够稳定。我希望加载进度能正常显示，同时避免过密的刷新影响阅读操作。

### 预期行为 / Expected behavior

加载进度适度更新并显示最新值，图片完成时立即出现；翻页尽量顺畅，换图、失败或退出后不再收到旧图片的进度更新。

### 复现步骤 / Steps to reproduce

1. 在尚未修复的二次开发版本中打开漫画，保留图片正在加载的状态。
2. 在加载期间连续滑动阅读，留意偶发的停顿。
3. 维护者可按后面的最小验证连续发送进度，区分进度刷新问题与网络等待。

### 应用版本 / App version

发现现象的二次开发版本：`【二次开发版本及构建号】`。

我用于对照的官方原版：1.18.4-rc.1；这不代表本条已经在原版手机上单独复测。

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 设备与系统 / Device and OS

- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 阅读环境 / Reading context

现象首先来自二次开发版本。上游有相同的图片进度刷新路径，但我尚未为此条补充原版手机对照诊断。涉及 ComicImage 的连续/瀑布流及多图画廊路径。

### 问题类型 / Issue type

阅读卡顿、慢加载或内存异常 / Reader performance

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

- [x] 我已检索相关 Issue，并把不同问题分开说明。
- [x] 我反馈的是应用本体的问题。
- [x] 我已检查正文，没有包含账号、Cookie、Token、签名链接或私人内容。
