# [Bug]: 收藏较多时进入或返回收藏夹会卡顿，打开搜索时输入法动画也严重卡顿

<!-- feedback-id: U01; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

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

1. 使用原版 1.18.4-rc.1，准备一个项目较多的收藏夹，阅读状态保持“全部”。
2. 从其他页面切换到收藏夹页面，观察进入时的卡顿。
3. 在该收藏夹中打开一本漫画的详情，再返回收藏夹，观察返回时的卡顿。
4. 点击收藏夹内的搜索按钮，先不输入文字，观察手机输入法的弹出动画；动画会非常卡顿。

### 预期行为 / Expected behavior

进入大收藏夹、从漫画详情返回及打开收藏夹内搜索时，页面和输入法动画都应流畅。输入法高度变化不应反复触发整份收藏列表的无关计算；阅读状态为“全部”时，不必逐本读取无需使用的阅读历史。搜索、阅读状态筛选和多选仍应正常。

### 实际行为 / Actual behavior

在项目较多的收藏夹中，我会在以下操作中遇到明显卡顿：

- 从其他页面切换到收藏夹页面时，进入过程会卡顿。
- 从收藏夹打开漫画详情，再返回收藏夹时，也会卡顿。
- 点击收藏夹内的搜索按钮后，手机输入法虽然能够唤出，但弹出动画非常卡顿；还没开始输入搜索文字，动画就已经不流畅。

这些停顿会打断我浏览收藏和从详情返回的操作。打开搜索时，输入法动画也受到明显影响，不能流畅地进入输入状态。

### 问题位置与操作方式 / Affected screen and input

项目较多的收藏夹；手机触摸操作。涉及切换到收藏夹、从收藏夹打开的漫画详情返回，以及点击收藏夹内搜索按钮后输入法弹出的过程。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

### 替代证据 / Alternative evidence

<details>
<summary>源码定位与最小验证（供维护者参考）</summary>

我怀疑输入法弹出动画更新时，页面跟着反复重建，进而重复处理整份收藏列表；目前没有逐帧构建记录，不能断言动画的每一帧都重建了整个页面。

源码线索与该怀疑相符：context.width/height/padding 等通过 MediaQuery.of 读取，订阅了完整的 MediaQuery，键盘 viewInsets 改变也可能触发这些使用者更新；收藏页构建会读取 _visibleComics，而“全部”状态仍逐本查找阅读历史。应进一步核对键盘动画期间真正重建的范围，以及过滤、历史查找和身份映射是否被重复执行。

已有 1200 项计数验证中，“全部”仍产生 1200 次历史查找。源码和计数验证确认的是不必要的历史查找、过滤及身份映射重算。查询调用次数不等于 SQLite 查询次数，也没有据此推算手机卡顿时长。

源码定位：

- [lib/foundation/context.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/foundation/context.dart#L58)
- [lib/features/favorites/local_favorites_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/favorites/local_favorites_page.dart#L238)
- [lib/features/favorites/local_favorites_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/favorites/local_favorites_page.dart#L158)
- [lib/features/comic_widgets/comic_list.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/comic_widgets/comic_list.dart#L67)

已有最小验证入口：

- [test/features/favorites/local_favorites_refresh_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/favorites/local_favorites_refresh_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已搜索现有 Issue，并将独立问题分开提交。 / I searched existing Issues and separated unrelated problems.
- [x] 我了解本仓库维护应用本体，源站内容、作品可用性和第三方源脚本应联系对应维护者。 / I understand this repository maintains the app; source content and third-party source scripts belong with their maintainers.
- [x] 我已检查附件与文本，移除账号、Cookie、Token、签名链接及私人内容。 / I reviewed and redacted credentials, signed URLs and private content.
