# OR-004：实现四字段 SourceEditor 纯 UI 组件

## 任务性质

这是一个严格受控的机械 Presentation 任务。只实现独立的四字段编辑表单及其 widget tests，不接 Riverpod，不接 SourcePage，不访问 Repository / Drift / SQLite。

本工单开始时 `SourceEditor` 尚未被现有生产页面引用，因此完成后 `flutter analyze` 和全量 `flutter test` 必须全部 GREEN；不存在 OR-003 那种允许已知编译失败的例外。

## 开始前

在仓库根目录执行：

```bash
git branch --show-current
git status --short
git pull --ff-only
```

必须满足：

- 当前分支为 `revival/flutter-workbench`。
- 开始前 working tree 为空。
- `git pull --ff-only` 成功。
- 不允许 rebase、reset、force push、amend 或改写历史。

如果任一条件不满足，停止并报告，不要自行处理未知本地修改。

## 唯一允许修改的文件

```text
app/lib/features/sources/presentation/source_editor.dart
app/test/features/sources/presentation/source_editor_test.dart
```

两个文件当前都不存在，可以创建。

除此之外禁止修改任何文件，包括但不限于：

```text
app/lib/features/sources/presentation/source_editor_draft.dart
app/lib/features/sources/presentation/source_page.dart
app/lib/features/sources/presentation/source_list.dart
app/lib/features/sources/application/**
app/lib/features/sources/domain/**
app/lib/features/sources/data/**
app/lib/core/**
app/pubspec.yaml
app/pubspec.lock
app/analysis_options.yaml
docs/**
.github/**
```

如果 Flutter 命令自动改写禁止文件，提交前恢复到 HEAD。

## 已存在的输入

### StoredSource

编辑器接收一个 `StoredSource`：

```dart
source.id
source.document
```

数据库 id 只用于识别“是否切换到了另一条书源”，编辑器不得访问数据库。

### SourceEditorDraft

已经存在：

```text
app/lib/features/sources/presentation/source_editor_draft.dart
```

它负责：

```dart
SourceEditorDraft.fromDocument(source.document)
```

以及保存时：

```dart
draft.applyTo(source.document)
```

必须复用它。禁止在 `SourceEditor` 中重新从四个字段构造 raw JSON，否则会丢未知字段。

## 目标接口

创建：

```dart
typedef SourceDocumentSaveCallback = Future<void> Function(
  SourceDocument document,
);

final class SourceEditor extends StatefulWidget {
  const SourceEditor({
    super.key,
    required this.source,
    required this.onSave,
    this.onBack,
  });

  final StoredSource source;
  final SourceDocumentSaveCallback onSave;
  final VoidCallback? onBack;
}
```

组件只能拥有表单临时状态，不读取 Riverpod，不调用 Controller/Repository，不显示保存成功/失败 Snackbar。

## 第一版字段

仅允许四项：

```text
sourceName  书源名称
sourceUrl   书源地址
enable      启用
weight      权重
```

不增加其他香色规则字段，不增加 Raw JSON 编辑器，不增加删除、复制、测试书源、自动保存等功能。

## 稳定 Key

必须提供：

```text
source-editor-name
source-editor-url
source-editor-enabled
source-editor-weight
source-editor-save
source-editor-back
```

`source-editor-back` 仅在 `onBack != null` 时存在。

## 严格 TDD

### 1. 先写 RED widget tests

创建：

```text
app/test/features/sources/presentation/source_editor_test.dart
```

至少覆盖以下 7 个行为。

### 行为 A：四字段从 StoredSource 初始化

准备：

```dart
StoredSource(
  id: 1,
  platform: 'StandarReader',
  document: SourceDocument.fromRaw(<String, Object?>{
    'sourceName': '测试书源',
    'sourceUrl': 'https://old.example',
    'enable': '1',
    'weight': '7',
  }),
  ...
)
```

pump `SourceEditor` 后验证：

- `source-editor-name` controller.text == `测试书源`
- `source-editor-url` controller.text == `https://old.example`
- `source-editor-enabled` 当前值为 true
- `source-editor-weight` controller.text == `7`

### 行为 B：保存四字段且未知 raw JSON 不丢

原文档额外带：

```dart
'futureRule': <String, Object?>{
  'nested': <Object?>['keep', 42],
},
```

用户修改为：

```text
名称 = 新名称
地址 = https://new.example
启用 = false
权重 = 12
```

点击 `source-editor-save` 后，捕获 `onSave` 收到的 `SourceDocument`，验证：

```dart
expect(saved.sourceName, '新名称');
expect(saved.sourceUrl, 'https://new.example');
expect(saved.enabled, isFalse);
expect(saved.weight, 12);
expect(saved.toRaw()['futureRule'], original.toRaw()['futureRule']);
```

这条测试必须证明保存通过 `SourceEditorDraft.applyTo(original)` 保留未知字段。

### 行为 C：空名称拒绝保存

输入全空格名称，点击保存：

```text
书源名称不能为空
```

必须出现，且 `onSave` 调用次数保持 0。

### 行为 D：非法权重拒绝保存

权重输入 `abc`，点击保存：

```text
权重必须是整数
```

必须出现，且 `onSave` 调用次数保持 0。

### 行为 E：保存过程中禁止重复提交

让 `onSave` 返回未完成的 `Completer<void>().future`。

点击保存并 `pump()` 后：

```dart
final button = tester.widget<FilledButton>(
  find.byKey(const Key('source-editor-save')),
);
expect(button.onPressed, isNull);
```

完成 completer 并 pump 后，按钮重新启用。

### 行为 F：返回按钮只在 onBack 存在时显示

`onBack == null`：

```dart
expect(find.byKey(const Key('source-editor-back')), findsNothing);
```

传入 callback 后必须找到按钮，点击一次 callback 恰好执行一次。

### 行为 G：同一个 mounted Editor 切换 source.id 时重载草稿

先 pump id=1：

```text
A / https://a.example / true / 1
```

再用同一位置 rebuild 为 id=2：

```text
B / https://b.example / false / 9
```

不更换 widget key，确保 Flutter 复用同一个 State。

rebuild 后四个控件必须全部显示 B 的值，不能残留 A 的草稿。

这要求生产实现正确实现 `didUpdateWidget`。

## 2. 运行 focused test，确认 RED

从 `app/` 执行：

```bash
flutter test test/features/sources/presentation/source_editor_test.dart
```

预期仅因为 `source_editor.dart` / `SourceEditor` 尚不存在而失败。

如果存在测试自身语法、fixture、lint 错误，先修测试并重跑，直到 RED 根因只剩目标生产行为缺失。

## 3. 最小 GREEN 实现

建议结构：

```dart
final _formKey = GlobalKey<FormState>();
late final TextEditingController _nameController;
late final TextEditingController _urlController;
late final TextEditingController _weightController;
bool _enabled = false;
bool _saving = false;
```

初始化必须复用 Draft：

```dart
void _loadSource(StoredSource source) {
  final draft = SourceEditorDraft.fromDocument(source.document);
  _nameController.text = draft.sourceName;
  _urlController.text = draft.sourceUrl;
  _weightController.text = draft.weight;
  _enabled = draft.enabled;
}
```

`initState()` 创建三个 controller 后调用 `_loadSource(widget.source)`。

### 必须处理 source 切换

```dart
@override
void didUpdateWidget(covariant SourceEditor oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.source.id != widget.source.id) {
    _loadSource(widget.source);
  }
}
```

不要按 sourceName 或列表 index 判断。

### 名称验证

```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return '书源名称不能为空';
  }
  return null;
}
```

### 权重验证

```dart
validator: (value) {
  if (value == null || int.tryParse(value.trim()) == null) {
    return '权重必须是整数';
  }
  return null;
}
```

### 保存

只在表单合法且当前未保存时提交：

```dart
Future<void> _save() async {
  if (_saving || !_formKey.currentState!.validate()) {
    return;
  }

  setState(() => _saving = true);
  try {
    final draft = SourceEditorDraft(
      sourceName: _nameController.text,
      sourceUrl: _urlController.text,
      enabled: _enabled,
      weight: _weightController.text,
    );
    await widget.onSave(draft.applyTo(widget.source.document));
  } finally {
    if (mounted) {
      setState(() => _saving = false);
    }
  }
}
```

不要在这里 catch 错误并显示 Snackbar；后续 SourcePage 负责用户反馈。

保存按钮：

```dart
FilledButton(
  key: const Key('source-editor-save'),
  onPressed: _saving ? null : _save,
  child: const Text('保存'),
)
```

### 返回

`onBack == null` 时不要创建返回按钮。

存在时使用 key：

```dart
const Key('source-editor-back')
```

### Dispose

必须 dispose 三个 `TextEditingController`。

## 4. 验收

从 `app/` 依次执行：

```bash
flutter test test/features/sources/presentation/source_editor_test.dart
flutter analyze
flutter test
git diff --check
```

本工单 **四项必须全部成功**。如果 analyze 或全量 test 失败，不允许以“后续 Task 6 会修”为理由提交；必须停止并报告，因为本组件目前没有现有生产调用方，不应破坏仓库。

回到仓库根目录：

```bash
git status --short
git diff --name-only
```

提交前实际修改只能是：

```text
app/lib/features/sources/presentation/source_editor.dart
app/test/features/sources/presentation/source_editor_test.dart
```

## Git 提交与推送

验收全绿后允许自行提交并 push：

```bash
git add app/lib/features/sources/presentation/source_editor.dart \
        app/test/features/sources/presentation/source_editor_test.dart

git commit -m "feat: add basic source editor widget"
git push origin revival/flutter-workbench
```

禁止 force push。

提交后执行：

```bash
git status --short
git show --stat --oneline HEAD
```

working tree 必须为空。

## 最终反馈格式

只需返回：

```text
1. RED：focused test 的预期失败原因
2. GREEN：focused test / flutter analyze / 全量 flutter test / git diff --check 结果
3. 测试覆盖：A-G 七项是否全部覆盖
4. 修改文件：实际修改文件列表
5. Commit：完整 SHA + commit message
6. Push：是否成功 push revival/flutter-workbench
7. git status --short：是否为空
8. 偏差：若当前 Flutter API 与工单示例不同，说明最小适配；否则写“无”
```

不要继续实现 SourcePage、Task 6 或其他任务。
