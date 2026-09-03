# OR-006：实现 SourceExportMenu 纯 UI 组件

## 任务性质

这是一个严格受控的机械 Presentation 任务。

只实现“导出范围菜单 + JSON/XBS 格式选择对话框”和对应 widget tests。不要接 Riverpod，不接 `SourcePage`，不访问 Repository、SQLite、`SourceExportService` 实例或 `SourceFileSaver`，也不要显示 Snackbar。

核心导出模型已经由强模型实现并通过 CI。你只能消费已有枚举类型，不得修改 application/domain/data 层。

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
app/lib/features/sources/presentation/source_export_menu.dart
app/test/features/sources/presentation/source_export_menu_test.dart
```

除此之外禁止修改任何文件，尤其禁止：

```text
app/lib/features/sources/presentation/source_page.dart
app/lib/features/sources/presentation/source_editor.dart
app/lib/features/sources/application/**
app/lib/features/sources/data/**
app/lib/features/sources/domain/**
app/lib/core/**
app/pubspec.yaml
app/pubspec.lock
app/analysis_options.yaml
docs/**
.github/**
```

如果 Flutter 命令自动改写禁止文件，提交前恢复到 HEAD。

## 已存在的输入

从：

```text
app/lib/features/sources/application/source_export.dart
```

直接消费：

```dart
enum SourceExportFormat { json, xbs }
enum SourceExportScope { current, all }
```

不得复制或重新定义这些枚举。

## 目标接口

创建：

```dart
typedef SourceExportSelectionCallback = Future<void> Function(
  SourceExportScope scope,
  SourceExportFormat format,
);

final class SourceExportMenu extends StatelessWidget {
  const SourceExportMenu({
    super.key,
    required this.canExportCurrent,
    required this.onExport,
  });

  final bool canExportCurrent;
  final SourceExportSelectionCallback onExport;
}
```

组件只负责选择“范围 + 格式”并回调，不执行任何导出业务。

## 稳定 Key

以下 Key 必须精确存在，不允许改名：

```text
source-export-menu
source-export-current
source-export-all
source-export-format-dialog
source-export-format-json
source-export-format-xbs
source-export-format-cancel
```

后续 `SourcePage` 集成测试会依赖这些 Key，而不是依赖容器类型或中文文案。

## 行为要求

### A. 当前书源不可导出时

当：

```dart
canExportCurrent == false
```

必须满足：

- `source-export-current` 仍然可见。
- 当前书源项处于 disabled 状态，用户操作不得打开格式对话框。
- `source-export-all` 仍然可用。

不要通过“隐藏当前项”实现禁用。

### B. 当前书源可导出时

当：

```dart
canExportCurrent == true
```

当前书源项可点击。

### C. 范围选择后再选格式

用户选择：

```text
导出当前
或
导出全部
```

之后显示格式选择对话框，至少包含：

```text
JSON
XBS
取消
```

对话框必须带：

```dart
const Key('source-export-format-dialog')
```

格式按钮分别使用规定的稳定 Key。

### D. JSON 回调

选择 JSON 后，只调用一次：

```dart
await onExport(scope, SourceExportFormat.json);
```

`scope` 必须与用户之前选择的 current/all 完全一致。

### E. XBS 回调

选择 XBS 后，只调用一次：

```dart
await onExport(scope, SourceExportFormat.xbs);
```

### F. 取消静默

点击：

```text
source-export-format-cancel
```

或对话框返回 null 时：

- 不调用 `onExport`。
- 不自动选择默认格式。
- 不显示 Snackbar。

### G. 严格保持纯 UI

禁止：

- Riverpod / Provider。
- Repository / SQLite。
- `SourceFileSaver`。
- 创建或调用 `SourceExportService`。
- 读取 selected id。
- Snackbar / toast。
- 持久化格式选择。
- 自动记忆上一次格式。
- 默认自动执行 JSON。
- 新增第三种格式。

可以使用 `PopupMenuButton<SourceExportScope>`、`showDialog<SourceExportFormat>` 或等价 Flutter 原生组件。

## 严格 TDD

### 1. 先写 RED

先创建：

```text
app/test/features/sources/presentation/source_export_menu_test.dart
```

生产文件此时不要创建。

至少覆盖以下 6 组行为：

1. **current disabled / all enabled**
   - `canExportCurrent=false`
   - current 可见但禁用
   - all 可打开格式对话框

2. **current enabled**
   - `canExportCurrent=true`
   - current 可打开格式对话框

3. **current + JSON**
   - callback 精确收到：
   ```dart
   SourceExportScope.current,
   SourceExportFormat.json
   ```
   - 且只调用一次

4. **current + XBS**
   - callback 精确收到 current + xbs
   - 且只调用一次

5. **all + JSON**
   - callback 精确收到 all + json
   - 且只调用一次

6. **取消静默**
   - 打开格式对话框后点击 cancel
   - callback 调用次数为 0

测试必须使用稳定 Key 驱动主要行为，不要锁死 Card、ListTile、PopupMenuItem 等具体容器层级。

### 2. Verify RED

从 `app/` 执行：

```bash
flutter test test/features/sources/presentation/source_export_menu_test.dart
```

预期只因为：

```text
source_export_menu.dart
SourceExportMenu
```

尚不存在而失败。

如果测试自身存在 lint、fixture、异步 pump 或 Flutter API 错误，先修测试并重跑，直到 RED 根因只剩目标生产 UI 缺失。

### 3. 最小 GREEN

RED 正确后，再创建：

```text
app/lib/features/sources/presentation/source_export_menu.dart
```

建议流程：

```dart
范围点击
  -> showDialog<SourceExportFormat>()
  -> format == null ? return
  -> await onExport(scope, format)
```

不要自行 catch `onExport` 异常。错误展示属于后续 `SourcePage`，不属于这个纯 UI 组件。

## 验收

从 `app/` 依次执行：

```bash
flutter test test/features/sources/presentation/source_export_menu_test.dart
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
  app/lib/features/sources/presentation/source_export_menu.dart \
  app/test/features/sources/presentation/source_export_menu_test.dart

git commit -m "feat: add source export menu"
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

完成 OR-006 后立即停止，不要继续修改 `SourcePage` 或做 Task 4。
