# [Bug]: 瀑布流上方图片加载为真实尺寸时，正在阅读的下方页面异常上移

<!-- feedback-id: U09; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题类型 / Issue type

界面、导航与交互 / UI and interaction

### 应用版本 / App version

源码对照：CyrilPeng/Venera-Next main@482810df369d126e4011be31d64408e33aede76f（版本元数据 1.18.4-rc.1+250）。组件复现运行于 fork 对应实现，不冒称官方安装包整体验证。

### 平台 / Platform

其他（请说明） / Other (please specify)：源码层核对；最小组件验证为 Linux 云端，不能据此声明各发行平台均实测。

### 设备与系统 / Device and OS

组件环境为 Linux、仓库锁定 Flutter 3.41.4；本项原版设备型号、系统/刷新率未单独采集。

### 复现步骤 / Steps to reproduce

1. 使用 400×600 视口，第一张图片先保持 300 像素高的加载占位，后续普通页面已解码。
2. 向下滚动，正在阅读第二页并记录其顶边。
3. 让上方第一张图解码为显示高度 200 像素，观察第二页位置；再覆盖图像变大、横向/反向及拖动中的加载。

### 预期行为 / Expected behavior

保持当前已解码阅读页的可见位置，首个绘制帧即补偿尺寸差，不取消手势或惯性；初次加载、显式跳页和历史续页不被占位项错误锚定。

### 实际行为 / Actual behavior

本轮修复前的最小组件复现中，第二页顶边从 -70 变为 -170，向上跳动 100 像素；不是用户额外滚动。上游使用同样的固定占位→真实尺寸布局，滚动代理没有异步尺寸的锚点补偿。

### 问题位置与操作方式 / Affected screen and input

本轮分支中的可控图片流组件复现，固定源码对照确认上游对应路径仍存在；没有宣称已运行纯净 upstream 整包或在原设备测得 100 像素。

### 诊断提供方式 / Diagnostic source

界面类日志选填；下方提供源码/组件证据。

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/reader/comic_image.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/comic_image.dart#L503)；[lib/features/reader/continuous_scroll.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/continuous_scroll.dart)；[lib/features/reader/continuous_view.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/continuous_view.dart)

复现输出：`Expected: near -70.0; Actual: -170.0; delta: -100.0`。

### 日志无法取得的原因 / Why diagnostics are unavailable

界面/布局/导航报告按上游表单可不附日志；没有编造错误日志或设备性能数据。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/reader/waterfall_loading_stability_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/waterfall_loading_stability_test.dart) 的首帧坐标、尺寸增减、LTR/RTL、拖动和初次加载回归；保留原有续页/换章测试。

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

已检索上游收藏、阅读和关键词相关讨论；本稿聚焦这一项独立行为。发布时可再核对新增讨论。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
