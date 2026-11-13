# [Bug]: 收藏夹选择“全部”仍逐本查历史，收藏多时进入和刷新增加无效开销

<!-- feedback-id: U01; upstream: 482810df369d126e4011be31d64408e33aede76f; template: 05-bug.yaml -->

[对应上游表单](https://github.com/CyrilPeng/Venera-Next/issues/new?template=05-bug.yaml)

### 问题说明

我想反馈收藏夹展示效率的问题：阅读状态已经选择“全部”，展示列表却仍然需要为每本漫画读取一次历史。收藏较多时，进入收藏夹、切换后返回和无关设置更新都会因此多做处理。

我目前提供的是源码核对和已有的最小验证结果，尚未为这一项单独补充原版手机复测。

### 实际行为 / Actual behavior

选择“全部”后，即使只是重新进入同一收藏夹，程序仍逐本处理阅读历史；修改无关阅读设置也会重新处理整份列表。界面上没有新的筛选结果需要显示，却仍然承担这一轮完整计算。

### 对我的影响

我的收藏越多，这些没有必要的处理就越多，可能表现为进入列表要等、刷新和后续操作不够跟手。我希望“全部”模式不必为了无需使用的阅读历史承担额外开销；目前还没有这项在我原版手机上的独立耗时测量。

### 预期行为 / Expected behavior

选择“全部”时直接展示收藏，不逐本查询阅读历史；只有实际需要已读/未读筛选时再处理。无关设置不应让整份列表重新计算，搜索和多选仍应正常。

### 复现步骤 / Steps to reproduce

1. 打开收藏数量较多的收藏夹。
2. 阅读状态选择“全部”，保持搜索条件不变。
3. 切换到其他页面再返回，或修改与收藏内容无关的阅读设置，再观察列表进入和刷新。

### 应用版本 / App version

1.18.4-rc.1（我使用的官方原版）。

### 平台 / Platform

Android 手机／平板 / Android phone or tablet

### 设备与系统 / Device and OS

- 设备型号：`【设备型号】`
- 系统：Android 15
- 处理器：骁龙 7gen2+
- 内存：12 GB

### 问题位置与操作方式 / Affected screen and input

收藏列表；重点是大列表进入、返回和无关设置刷新，不涉及源站加载速度。

### 问题类型 / Issue type

界面、导航与交互 / UI and interaction

### 诊断提供方式 / Diagnostic source

我暂未附设备日志，提供下方源码和已有验证线索。

### 日志或诊断报告 / Logs or diagnostic report

我暂未附设备运行日志；下面附已有的排查线索。

### 日志无法取得的原因 / Why diagnostics are unavailable

这项是界面/交互反馈，我暂未附运行日志。

### 替代证据 / Alternative evidence

<details>
<summary>源码定位与最小验证（供维护者参考）</summary>

已有 1200 项计数验证中，“全部”仍产生 1200 次历史查找。源码和计数验证确认的是不必要的历史查找、过滤及身份映射重算。查询调用次数不等于 SQLite 查询次数，也没有据此推算手机卡顿时长。

源码定位：

- [lib/features/favorites/local_favorites_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/favorites/local_favorites_page.dart#L238)
- [lib/features/favorites/local_favorites_page.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/favorites/local_favorites_page.dart#L158)
- [lib/features/comic_widgets/comic_list.dart](https://github.com/CyrilPeng/Venera-Next/blob/482810df369d126e4011be31d64408e33aede76f/lib/features/comic_widgets/comic_list.dart#L67)

已有最小验证入口：

- [test/features/favorites/local_favorites_refresh_test.dart](https://github.com/tianjinsa/Venera-Next/blob/codex/agent-center-tab/test/features/favorites/local_favorites_refresh_test.dart)

</details>

### 截图或录屏 / Screenshots or video

我暂未附截图或录屏。

### 提交前确认 / Checklist

- [x] 我已检索相关 Issue，并把不同问题分开说明。
- [x] 我反馈的是应用本体的问题。
- [x] 我已检查正文，没有包含账号、Cookie、Token、签名链接或私人内容。
