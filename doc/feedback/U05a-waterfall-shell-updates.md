# [Reader]: 瀑布流同一页内滚动时仍重复刷新阅读界面，增加滚动负担

<!-- feedback-id: U05a; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 02-reader-performance.yaml -->

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

1. 使用普通本地或已缓存图片，进入跨章瀑布流模式。
2. 在一张较长的图片内缓慢上下滚动，保持章节和页码不变。
3. 观察滚动是否顺畅；维护者可用后面的定位信息统计同页滚动产生的更新次数。

### 预期行为 / Expected behavior

只有章节或页码真正改变时，才更新对应的阅读进度界面；正常滚动、图片预加载和跨章阅读继续工作。

### 实际行为 / Actual behavior

在同一张已加载图片内滚动时，显示的章节和页码都没有变化，跨章瀑布流的每次位置检查却仍会通知外层界面更新。没有新的进度需要展示，程序仍持续做额外刷新。

这会增加滚动期间的处理负担，可能让已经加载好的页面也不够顺滑，影响我连续阅读。

### 阅读环境 / Reading context

跨章瀑布流，同一张已加载页面内滚动。图片尺寸和刷新率未为本条单独记录。

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

跨章分支每次位置检查都调用 _setReaderLocation 和 onUpdate，普通连续模式会先比较页码。本条确认重复工作，不认定它解释所有卡顿。

源码定位：

- [lib/features/reader/continuous_view.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/continuous_view.dart#L554)

已有最小验证入口：

- [test/features/reader/continuous_owner_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/continuous_owner_test.dart)
- [test/features/reader/reader_exit_integration_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/reader_exit_integration_test.dart)

我查到 #125 讨论过阅读卡顿；本条聚焦同页重复刷新的路径，没有把两者的全部原因视为相同。

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
