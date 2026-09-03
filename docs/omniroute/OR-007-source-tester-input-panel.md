# OR-007：实现 SourceTesterInputPanel 纯 UI 组件

## 任务性质

这是一个严格受控的机械 Presentation 任务。

只实现 Source Tester 的“搜索测试输入面板”和对应 widget tests。不要接 Riverpod，不读取书源，不调用 `SearchBookTestRunner`，不访问 Repository、SQLite、HTTP、编码器或解析器。

Source Tester 的请求构建、HTTP、编码、规则解析、Runner 与 provider 已由强模型完成并通过 CI。你只能实现一个无业务依赖的输入组件，提交后立即停止。

## 开始前

在仓库根目录执行：

```bash
git branch --show-current
git status --short
git pull --ff-only
```

必须满足：

- 当前分支为 `revival/flutter-workbench`。
- working tree 为空。
- `git pull --ff-only` 成功。
- 不允许 rebase、reset、force push、amend 或改写历史。

如果任一条件不满足，停止并报告，不要自行处理未知本地修改。

## 唯一允许修改的文件

只允许创建以下 2 个文件：

```text
app/lib/features/source_tester/presentation/source_tester_input_panel.dart
app/test/features/source_tester/presentation/source_tester_input_panel_test.dart
```

除此之外禁止修改任何文件，尤其禁止：

```text
app/lib/features/source_tester/application/**
app/lib/features/source_tester/data/**
app/lib/features/source_tester/domain/**
app/lib/features/sources/**
app/lib/core/**
app/pubspec.yaml
app/pubspec.lock
app/analysis_options.yaml
docs/**
.github/**
```

如果 Flutter 命令自动改写禁止文件，提交前恢复到 HEAD。

## 禁止 import

生产组件禁止 import：

```text
flutter_riverpod
features/source_tester/application/**
features/source_tester/data/**
features/source_tester/domain/**
features/sources/**
http
xpath_selector
xpath_selector_html_parser
json_path
enough_convert
```

生产文件除 Dart/Flutter SDK 外不应需要任何项目业务 import。

## 目标接口

创建：

```dart
final class SourceTesterInput {
  const SourceTesterInput({
    required this.keyWord,
    required this.pageIndex,
    required this.offset,
    required this.filter,
  });

  final String keyWord;
  final int pageIndex;
  final int offset;
  final String filter;
}

final class SourceTesterInputPanel extends StatelessWidget {
  const SourceTesterInputPanel({
    super.key,
    required this.running,
    required this.onRun,
  });

  final bool running;
  final ValueChanged<SourceTesterInput> onRun;
}
```

组件只负责采集、校验输入并调用 `onRun`，不负责将 `SourceTesterInput` 转成 application 层的 `SearchBookTestInput`。

## 稳定 Key

以下 Key 必须精确存在，不允许改名：

```text
source-tester-input-keyword
source-tester-input-page-index
source-tester-input-advanced-toggle
source-tester-input-advanced
source-tester-input-offset
source-tester-input-filter
source-tester-input-run
```

后续 `SourceTesterPage` 集成测试会依赖这些 Key，不要依赖具体 Card、ExpansionTile、TextFormField 层级。

## 初始状态

首次渲染必须满足：

```text
keyword     空
pageIndex   1
offset      0
filter      空
advanced    收起
```

高级区域收起时，`offset/filter` 输入框不应出现在可交互 widget tree 中；点击高级参数开关后显示。

不要持久化输入，不读取上一次运行参数。

## 行为要求

### A. keyword 必填

点击运行时：

- keyword `trim()` 后不能为空。
- 为空时不得调用 `onRun`。
- 必须在面板内显示可见校验错误。

传入回调的 `keyWord` 使用 trim 后的值。

不要在用户每敲一个字符时调用 `onRun`。

### B. pageIndex

默认值为：

```text
1
```

运行时必须是合法整数并满足：

```text
pageIndex >= 1
```

空值、非整数、0、负数均阻止回调并显示校验错误。

### C. offset

高级区域中的 offset 默认值为：

```text
0
```

运行时必须是合法整数并满足：

```text
offset >= 0
```

空值、非整数、负数均阻止回调并显示校验错误。

即使高级区域重新收起，之前用户输入的合法 offset 值也应保留在当前 widget 生命周期内，不要因折叠重置。

### D. filter

高级区域中的 filter 默认空字符串。

允许为空。

传入回调时使用 `trim()` 后的字符串。

### E. advanced 折叠

初始收起。

点击：

```text
source-tester-input-advanced-toggle
```

展开后必须可找到：

```text
source-tester-input-advanced
source-tester-input-offset
source-tester-input-filter
```

再次点击后收起。

可以使用 `ExpansionTile`、`AnimatedCrossFade`、局部 StatefulBuilder 或私有 StatefulWidget；但公开组件接口必须保持上面的 `StatelessWidget` 形状。如果需要内部状态，允许 `SourceTesterInputPanel` 返回一个私有 stateful 子组件。

### F. running 状态

当：

```dart
running == true
```

运行按钮必须 disabled，用户点击不得调用 `onRun`。

输入框是否 disabled 不做强制要求，不要额外设计 loading overlay。

当 `running == false` 时，运行按钮恢复可用。

### G. 一次点击一次回调

所有输入合法且 `running == false` 时，一次运行按钮点击只能同步触发一次：

```dart
onRun(
  SourceTesterInput(
    keyWord: ...,
    pageIndex: ...,
    offset: ...,
    filter: ...,
  ),
);
```

不要 debounce、retry、延迟触发或自动再次运行。

### H. 严格保持纯 UI

禁止：

- Riverpod / Provider。
- Repository / SQLite。
- `SearchBookTestRunner`。
- `SearchBookTestInput`。
- HTTP 请求。
- response parser / XPath / JSONPath。
- 读取 sourceId。
- Snackbar / toast。
- Navigator。
- 自动运行。
- 网络状态判断。
- 把输入持久化到数据库或 preferences。
- 为未来需求新增额外字段。

## 建议实现方式

允许使用：

```text
Form
TextFormField
TextEditingController
ExpansionTile
FilledButton / ElevatedButton
```

为了保持公开组件为 `StatelessWidget`，推荐：

```dart
SourceTesterInputPanel extends StatelessWidget
  -> private _SourceTesterInputForm extends StatefulWidget
```

controller、Form key 和展开状态全部放在私有 stateful 实现内。

`SourceTesterInputPanel` 本身不要缓存业务状态。

## 严格 TDD

### 1. 先写 RED

先创建：

```text
app/test/features/source_tester/presentation/source_tester_input_panel_test.dart
```

生产文件此时不要创建。

至少覆盖以下 8 组行为：

1. **默认值与高级区域收起**
   - keyword 空
   - pageIndex == `1`
   - advanced 初始收起
   - offset/filter 不可见

2. **高级区域展开**
   - 点击 advanced toggle
   - offset == `0`
   - filter == 空
   - 对应稳定 Key 可找到

3. **keyword 必填**
   - 空 keyword 点击运行
   - callback 0 次
   - 可见校验错误

4. **pageIndex 非法**
   - 至少覆盖非整数和 `0`
   - callback 0 次

5. **offset 非法**
   - 展开高级区域
   - 输入负数或非整数
   - callback 0 次

6. **合法默认高级参数运行**
   - keyword 输入 `  测试小说  `
   - pageIndex 保持 1
   - advanced 不需要展开
   - callback 精确收到：
   ```dart
   keyWord: '测试小说'
   pageIndex: 1
   offset: 0
   filter: ''
   ```
   - 只调用一次

7. **合法自定义高级参数运行**
   - pageIndex = 3
   - offset = 20
   - filter = `  完结  `
   - callback 精确收到 trim 后值
   - 只调用一次

8. **running 禁止运行**
   - `running=true`
   - 运行按钮 disabled
   - callback 0 次

测试使用稳定 Key 驱动主要行为；不要锁死具体 Material 容器层级、字体大小、padding、颜色或中文提示文案。

### 2. Verify RED

从 `app/` 执行：

```bash
flutter test test/features/source_tester/presentation/source_tester_input_panel_test.dart
```

预期只因为：

```text
source_tester_input_panel.dart
SourceTesterInputPanel
SourceTesterInput
```

尚不存在而失败。

如果测试自身存在 lint、finder、pump、Form 或 Flutter API 错误，先修测试并重跑，直到 RED 根因只剩目标生产 UI 缺失。

### 3. 最小 GREEN

RED 正确后，再创建：

```text
app/lib/features/source_tester/presentation/source_tester_input_panel.dart
```

运行按钮逻辑建议保持直接：

```text
running -> return
Form.validate() -> false 则 return
parse values
onRun(SourceTesterInput(...))
```

不要 catch `onRun`，也不要把回调改成 async。页面级异步状态与错误展示属于后续 `SourceTesterPage`。

## 验收

从 `app/` 依次执行：

```bash
flutter test test/features/source_tester/presentation/source_tester_input_panel_test.dart
flutter analyze
flutter test
git diff --check
```

四项必须全部 GREEN。

提交前确认：

```bash
git status --short
git diff --name-only HEAD
```

最终提交只能包含允许的两个文件。

提交：

```bash
git add \
  app/lib/features/source_tester/presentation/source_tester_input_panel.dart \
  app/test/features/source_tester/presentation/source_tester_input_panel_test.dart

git commit -m "feat: add source tester input panel"
git push origin revival/flutter-workbench
```

禁止 amend、rebase、force push。

## 完成后只返回

1. RED 失败原因。
2. focused widget test 结果。
3. `flutter analyze` 结果。
4. 全量 `flutter test` 结果。
5. `git diff --check` 结果。
6. 修改文件列表。
7. Commit SHA。
8. Push 是否成功。
9. `git status --short` 是否为空。
10. 任何偏差；没有则写“无”。

完成 OR-007 后立即停止，不要继续实现 `SourceTesterPage`、report UI、navigation 或 platform networking。
