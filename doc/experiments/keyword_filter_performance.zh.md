# 漫画关键词过滤基准

在 Windows x64、Ryzen 9 7940HX、Dart 3.11.1（Flutter 3.41.4）上运行 AOT 可执行文件。固定种子生成 1200 部漫画，每部有标题、副标题、简介和 20 个标签。128 条规则混合包含、独立词和精确标签，大小写选项各占一半。64 条短于 10 个字符，115 条短于 20 个，122 条短于 30 个。文本覆盖中文、日文、英文和希腊文。

每种方式计时 15 次扫描，交替先运行的方式，P95 使用最近秩。逐项校验两种方式都筛出相同的 150 部漫画。逐规则对照沿用产生字段和原文范围的详细匹配流程。表中计时范围是整批匹配，生成输入在计时前完成。新快照首次扫描包含惰性初始化和匹配。

| 场景 | 逐规则详细匹配中位数 / P95 | 索引布尔检测中位数 / P95 |
| --- | ---: | ---: |
| 第一轮，复用快照 | 358.548 / 369.867 ms | 32.233 / 33.342 ms |
| 第一轮，新快照首次扫描 | 544.374 / 587.431 ms | 46.653 / 48.014 ms |
| 第二轮，复用快照 | 395.954 / 584.309 ms | 31.931 / 48.239 ms |
| 第二轮，新快照首次扫描 | 546.058 / 588.224 ms | 46.604 / 48.939 ms |

另用相同输入中的 3600 个文字字段，比较 128 个区分大小写的字面子串。逐字段校验均命中相同的 925 个字段。

| 场景 | 合并字面正则中位数 / P95 | 稀疏 AC 自动机中位数 / P95 |
| --- | ---: | ---: |
| 第一轮 | 33.241 / 33.916 ms | 3.216 / 3.262 ms |
| 第二轮 | 33.226 / 33.597 ms | 3.191 / 3.295 ms |

作者名、完整标签及标签值用哈希集合查找。区分大小写的文字用 AC 自动机检测 UTF-16 子串。独立词只有在一组规则可能命中时才检查 Unicode 边界。列表命中即返回，原因窗口为可见行定位一条实际命中。

## Unicode 折叠对照

忽略大小写的文字检测使用 Unicode 单码点折叠后的 AC 扫描。配置规则和输入共用 Unicode CaseFolding 的 `C`、`S` 映射。长 s `ſ`（U+017F）与 `s` 同组，有点大写 I `İ`（U+0130）与 `i` 各自归组。详细原因用原文定位范围，支持辅助平面的大小写配对。 [Dart RegExp](https://api.dart.dev/dart-core/RegExp-class.html) · [ECMAScript Canonicalize](https://tc39.es/ecma262/multipage/text-processing.html#sec-runtime-semantics-canonicalize-ch)

独立 Dart 3.11.1 使用 15.1。Flutter 3.41.4 Windows 测试引擎 `e4b8dca3` 使用 16.0，比 15.1 多 27 条映射。按正则能识别的版本特征选择生成表，其他版本使用原合并正则。取 Unicode 15.0、15.1、16.0、17.0 折叠文件中出现的 3048 个码点，两套运行时各检查 4,643,628 个无序字符对，实际 AC 与各自正则零差异。仓库回归同时覆盖未配对代理项、独立词边界及混合规则。

Windows AOT 在同一可执行文件中并入 `a7ef814f` 的布尔扫描作对照。每组交替执行 15 次，逐条确认筛出的 150 部漫画一致。文字内核组仅比较 3600 个文字字段的 128 个字面子串，均命中相同的 937 个字段。

| 场景 | 基线中位数 / P95 | 折叠 AC 中位数 / P95 |
| --- | ---: | ---: |
| 混合规则，复用快照 | 30.023 / 32.454 ms | 21.257 / 21.910 ms |
| 混合规则，首次扫描 | 30.969 / 32.885 ms | 21.710 / 22.089 ms |
| 忽略大小写的文字内核 | 34.313 / 34.493 ms | 2.814 / 2.906 ms |

数据用于比较匹配内核及批量筛选耗时。Android 列表的实际帧耗时仍待测量。

在已完成依赖准备的仓库根目录运行以下命令。

```powershell
dart compile exe -o .dart_tool/keyword_filter_benchmark.exe tool/keyword_filter_benchmark.dart
.\.dart_tool\keyword_filter_benchmark.exe
```

生成器使用 Unicode 15.1 和 16.0 的官方数据，核验两份文件的 SHA-256。[Unicode 15.1 数据](https://www.unicode.org/Public/15.1.0/ucd/CaseFolding.txt) · [Unicode 16.0 数据](https://www.unicode.org/Public/16.0.0/ucd/CaseFolding.txt) · [Unicode 数据许可](../development/unicode-data-license.txt)

```powershell
python tool/generate_unicode_case_folding.py .dart_tool/CaseFolding-15.1.0.txt .dart_tool/CaseFolding-16.0.0.txt
```
