# [Reader]: 图片加载成功时画面间歇性卡顿，连续模式明显、瀑布流较轻

<!-- feedback-id: U12; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 02-reader-performance.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=02-reader-performance.yaml)

### 问题类型 / Issue type

阅读卡顿、慢加载或内存异常 / Reader performance

### 应用版本 / App version

1.18.4-rc.1（Android 手机版；`【补充实际构建号及安装包来源】`）。

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 设备与系统 / Device and OS

- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 复现步骤 / Steps to reproduce

1. 打开漫画，使用纵向连续模式阅读，让后续图片在阅读过程中陆续加载。
2. 连续滑动，留意下一张图片刚加载出来前后的画面跟随情况。
3. 切换为瀑布流模式，以相同方式阅读并对比停顿程度。
4. 问题不定时出现，不是每张图片加载时都必现；连续模式比较明显，瀑布流也会出现，但程度较轻。

### 预期行为 / Expected behavior

图片加载和显示时，已经显示的内容仍能平稳跟随滑动。预加载应控制同步处理和临时内存占用，尽量避免多张图片接连完成时打断阅读。

### 实际行为 / Actual behavior

我在阅读过程中会遇到不定时的短暂停顿，滑动画面会顿一下，打断连续阅读。从我的观察看，停顿似乎更容易出现在图片刚加载成功、开始显示的时候，而不只是图片本身要等一段时间才能出现。

纵向连续模式的卡顿比较明显；瀑布流模式也会出现，但程度较轻。问题是间歇性的，我暂时没有找到每次都能触发的固定步骤，也还没有确认所有停顿是否来自同一个原因。

### 阅读环境 / Reading context

- 阅读模式：纵向连续、瀑布流。
- 内容入口（本地／WebDAV／扩展）：`【填写实际入口】`。
- 图片格式、尺寸和单张大小范围：`【填写实际情况】`。
- 屏幕刷新率：`【填写实际刷新率】`。
- 自定义图片处理开关：`【开启／关闭】`。
- 首次显示、立即回看及内存紧张时的已有对照：`【填写已观察到的情况】`。

### 诊断提供方式 / Diagnostic source

`【选择实际方式：粘贴报告／上传附件／无法取得】`

### 日志或诊断报告 / Logs or diagnostic report

`【粘贴手动阅读诊断报告或添加附件】`

### 日志无法取得的原因 / Why diagnostics are unavailable

`【仅在无法取得时，填写尝试过的采集方式及具体障碍；已有报告时删除本项】`

### 替代证据 / Alternative evidence

<details>
<summary>当前仓库中的相关改动</summary>

图片读取和解码使用异步接口，但下载分块的累积、整张图片的字节转换，以及缓存入队前准备快照，仍包含同步执行的工作。旧路径用普通 `List<int>` 保存图片字节，并再次复制整张图片，增加了同步处理和临时内存分配。

我已在自己维护的当前仓库中，将分块缓冲和缓存快照改为紧凑字节存储，同时保留写入隔离、源回调、进度和取消清理行为：

- [减少图片完成加载时的同步拷贝与内存分配](https://github.com/tianjinsa/Venera-Next/commit/a5222bcab780c58e4ea3097c1f0c8a3a51eb4b80)
- [相关验证及测量范围](https://github.com/tianjinsa/Venera-Next/blob/a5222bcab780c58e4ea3097c1f0c8a3a51eb4b80/doc/experiments/webdav_reader_performance.zh.md#2026-11-13-agent-分支续修)

这些验证说明该路径的同步工作可以减少，不能代替手机上的阅读诊断，也不能据此认定所有卡顿都已解决。

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [ ] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [ ] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
