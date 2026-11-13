# [Reader]: 图片下载进度逐分块刷新 ComicImage，滑动时产生密集重建

<!-- feedback-id: U08; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 02-reader-performance.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=02-reader-performance.yaml)

### 问题类型 / Issue type

阅读卡顿、慢加载或内存异常 / Reader performance

### 应用版本 / App version

源码对照：CyrilPeng/Venera-Next main@482810df369d126e4011be31d64408e33aede76f（版本元数据 1.18.4-rc.1+250）。组件复现运行于 fork 对应实现，不冒称官方安装包整体验证。

### 平台 / Platform

其他（请说明） / Other (please specify)：源码层核对；最小组件验证为 Linux 云端，不能据此声明各发行平台均实测。

### 设备与系统 / Device and OS

组件环境为 Linux、仓库锁定 Flutter 3.41.4；本项原版设备型号、系统/刷新率未单独采集。

### 复现步骤 / Steps to reproduce

1. 在可控图片流夹具中挂载 `ComicImage`，暂不交付最终帧。
2. 连续发送下载分块进度；在小于 100 毫秒的窗口内从 10% 推进到 90%。
3. 比较进度刷新和组件重建；再交付帧、错误、更换图片或卸载。

### 预期行为 / Expected behavior

合并高频进度更新，例如 100 毫秒发布最新值；最终帧立即显示；错误、换源和卸载取消待发布进度，避免旧回调复活加载状态。

### 实际行为 / Actual behavior

每个 `_handleImageChunk` 都立即 setState。本轮修复前的夹具观察到短窗口内 10% 直接变为 90%，没有进度刷新合并。用户在迁移分支报告了滑动偶发卡顿；相同逐块刷新路径也存在于上游，但尚未证明该路径是原版任意卡顿的唯一原因。

### 阅读环境 / Reading context

连续/瀑布流和使用 ComicImage 的多图画廊；不把单图 PhotoView 自动归入同一回调路径。Prime 中已有进度合并和连续阅读双线性采样，可参考其行为，不整文件覆盖 Next。

### 诊断提供方式 / Diagnostic source

无法取得（需说明原因并提供替代证据） / Unavailable (explain and provide alternatives)

### 日志或诊断报告 / Logs or diagnostic report

[lib/features/reader/comic_image.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/reader/comic_image.dart#L338)

本轮组件复现输出：`Expected: 0.1; Actual: 0.9`，窗口 40 毫秒；这是刷新策略复现，不是设备 FPS/CPU 测量。

### 日志无法取得的原因 / Why diagnostics are unavailable

当前排查在云端，没有连接原设备的原版阅读会话，无法从该会话导出手动阅读诊断；没有拿 Prime 的旧报告或其他用户报告冒充本项诊断。

### 替代证据 / Alternative evidence

最小验证/回归入口：[test/features/reader/comic_image_progress_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/reader/comic_image_progress_test.dart) 覆盖高频合并、帧完成、错误、源替换和卸载。

已区分源码核对、fork 组件验证和原版用户实测；未附原设备数据不表示测得零卡顿。

### 截图或录屏 / Screenshots or video

本稿未附录屏或图片。已有的可控复现及已确认的原版现场如上，不虚构附件。

### 相关讨论与范围

不把 Prime 2026-10-11 的旧设备报告当作当前 Next 的性能报告，也不等同于 #125 的全部历史根因。

### 提交前确认 / Checklist

- [x] 已检索相关 Issue，并将独立问题分开整理。
- [x] 本报告针对应用本体，不要求维护第三方源内容。
- [x] 文本未包含账号、Cookie、Token、签名链接、私人漫画或数据库。
