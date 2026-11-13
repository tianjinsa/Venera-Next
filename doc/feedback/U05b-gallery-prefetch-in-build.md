# [Reader]: 画廊停在同一页时仍重复安排预加载，增加无效工作

<!-- feedback-id: U05b; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 02-reader-performance.yaml -->

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

1. 使用普通本地或已缓存图片进入画廊模式。
2. 停在同一页，保持布局和预加载数量不变。
3. 打开/关闭阅读菜单等触发界面更新，检查是否反复执行同位置预加载；统计方式见后面的排查线索。

### 预期行为 / Expected behavior

相同内容、布局和页码的预加载合并处理；真正翻页或更换内容后再安排必要的新任务，已有画面和缩放保持不变。

### 实际行为 / Actual behavior

画廊停在同一页、漫画内容和阅读布局都没有变化时，其他界面更新仍会在页面重新构建时安排同一位置的预加载。缓存可能避免重复下载，但没有消除重复调用、遍历和配置创建。

没有新内容时仍重复安排这些工作，会增加阅读期间的处理负担，可能影响我的翻页响应和阅读顺畅程度。

### 阅读环境 / Reading context

画廊模式，同位置重复界面更新；与瀑布流同页通知的问题分别报告。

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

当前源码在 _buildPhotoPage 内直接调用 cache(index)。本条不声称主线每次翻页都会销毁 PhotoView。

源码定位：

- [lib/features/reader/gallery_view.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/gallery_view.dart#L346)

已有最小验证入口：

- [test/features/reader/gallery_page_continuity_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/gallery_page_continuity_test.dart)
- [test/features/reader/gallery_rotation_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/gallery_rotation_test.dart)
- [test/features/reader/image_precache_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/image_precache_test.dart)

我查到 #118 的旧翻页闪屏问题已修复；本条针对仍存在的构建期重复预加载，不重复报告旧的 PhotoView 销毁问题。

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
