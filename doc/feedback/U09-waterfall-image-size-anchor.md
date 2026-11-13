# [Bug]: 瀑布流向下阅读时，图片加载后把正在看的内容突然向上拉走

<!-- feedback-id: U09; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题类型 / Issue type

界面、导航与交互 / UI and interaction

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

1. 在原版 1.18.4-rc.1 中进入瀑布流。
2. 趁前面的图片还没有全部加载完，向下滑到后续已经显示的页面。
3. 继续阅读，观察上方图片加载出来时，当前内容是否在没有额外滑动的情况下突然上移。

### 预期行为 / Expected behavior

上方图片加载成真实尺寸时，正在看的内容尽量停留在原来的屏幕位置；手势不被打断，返回历史进度或主动跳页仍正确。

### 实际行为 / Actual behavior

瀑布流向下阅读时，上方尚未完成的图片加载出来后，下方正在阅读的内容会突然向上挪一截。这个变化不是我额外滑动造成的，当前阅读位置没有保持住。

我会突然丢失刚才正在看的位置，需要回滑才能接着读；连续往下滑时，这种反向跳动尤其干扰阅读。

### 问题位置与操作方式 / Affected screen and input

瀑布流；手机触摸向下滑动。上方图片仍在加载时继续阅读下方内容，图片加载后当前画面突然上移。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

### 替代证据 / Alternative evidence

<details>
<summary>源码定位与最小验证（供维护者参考）</summary>

最小验证中，占位高度从 300 变成 200 像素；在可控 400×600 视口里，当前页顶边从 -70 变为 -170，即上移 100 像素。这是组件坐标结果，不是手机实测位移。可进一步覆盖图片变大、横向/反向阅读和拖动中的加载；初次占位不能错误覆盖历史续页目标。

源码定位：

- [lib/features/reader/comic_image.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/comic_image.dart#L503)
- [lib/features/reader/continuous_scroll.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/continuous_scroll.dart)
- [lib/features/reader/continuous_view.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/continuous_view.dart)

已有最小验证入口：

- [test/features/reader/waterfall_loading_stability_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/waterfall_loading_stability_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
