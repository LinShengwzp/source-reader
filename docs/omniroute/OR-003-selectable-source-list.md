# OR-003：让 SourceList 支持按数据库 id 选择

## 任务性质

这是一个严格受控的机械 Presentation 任务。不要扩展功能，不要重构周边代码。

目标是在现有 `SourceList` 上增加外部控制的选中态和点击回调，使后续 `SourcePage` 能通过数据库 `id` 管理当前书源选择。

## 开始前

必须在仓库根目录执行：

```bash
git branch --show-current
git status --short
git pull --ff-only
```

要求：

- 当前分支必须是 `revival/flutter-workbench`。
- `git status --short` 在开始前必须为空。
- `git pull --ff-only` 必须成功。
- 不允许 rebase、reset、force push、amend 或改写历史。

如果任一条件不满足，停止任务并直接报告，不要自行处理未知本地改动。

## 唯一允许修改的文件

```text
app/lib/features/sources/presentation/source_list.dart
app/test/features/sources/presentation/source_list_test.dart
```

第二个测试文件当前不存在，可以创建。

除此之外任何文件都禁止修改，包括但不限于：

```text
app/lib/features/sources/application/**
app/lib/features/sources/domain/**
app/lib/features/sources/data/**
app/lib/core/**
app/lib/features/sources/presentation/source_page.dart
app/lib/features/sources/presentation/source_editor_draft.dart
app/pubspec.yaml
app/pubspec.lock
app/analysis_options.yaml
docs/**
.github/**
```

如果 Flutter 命令自动改写了禁止文件，提交前必须恢复到 HEAD。

## 已存在的输入模型

`SourceList` 当前只接收：

```dart
SourceList(
  sources: sources,
)
```

每条数据是 `StoredSource`，数据库身份使用：

```dart
source.id
```

禁止使用列表 index、`sourceName` 或 platform 作为选择身份。

## 目标接口

把 `SourceList` 改为：

```dart
SourceList({
  super.key,
  required this.sources,
  required this.selectedId,
  required this.onSelected,
});

final List<StoredSource> sources;
final int? selectedId;
final ValueChanged<int> onSelected;
```

`SourceList` 必须继续保持纯输入组件：

- 不读取 Riverpod。
- 不持有自己的 selected state。
- 不访问 Repository / Drift / SQLite。
- 不负责保存、编辑、导航。

## 严格 TDD

### 1. 先写 RED 测试

创建：

```text
app/test/features/sources/presentation/source_list_test.dart
```

至少覆盖以下 3 个行为。

### 行为 A：点击回传数据库 id

准备 id 1 / id 2 两个书源：

```dart
final selectedIds = <int>[];

await tester.pumpWidget(
  MaterialApp(
    home: SourceList(
      sources: <StoredSource>[
        _storedSource(id: 1, name: '书源 A'),
        _storedSource(id: 2, name: '书源 B'),
      ],
      selectedId: null,
      onSelected: selectedIds.add,
    ),
  ),
);

await tester.tap(find.text('书源 B'));

expect(selectedIds, <int>[2]);
```

### 行为 B：selectedId 控制视觉选中态

每个 ListTile 必须具有稳定 key：

```dart
Key('source-list-tile-${source.id}')
```

测试：

```dart
final tile = tester.widget<ListTile>(
  find.byKey(const Key('source-list-tile-2')),
);

expect(tile.selected, isTrue);
```

同时验证另一条记录 `selected == false`。

### 行为 C：列表重排后仍按 id 选择

第一次顺序：

```text
id 1
id 2
```

第二次 rebuild 顺序：

```text
id 2
id 1
```

保持：

```dart
selectedId: 2
```

rebuild 后 `source-list-tile-2` 仍必须 `selected == true`。

测试辅助 `_storedSource(...)` 可以放在测试文件内，风格参考现有 `source_page_test.dart`。

### 2. 运行 focused test，确认 RED

从 `app/` 执行：

```bash
flutter test test/features/sources/presentation/source_list_test.dart
```

预期：因为当前 `SourceList` 尚无 `selectedId` / `onSelected` / stable key 而失败。

如果失败原因是测试自身语法、lint 或 fixture 错误，先修测试并重新运行，直到 RED 只由目标生产行为缺失导致。

### 3. 写最小 GREEN 实现

每条 `ListTile` 只增加：

```dart
key: Key('source-list-tile-${source.id}'),
selected: source.id == selectedId,
onTap: () => onSelected(source.id),
```

并增加 constructor / fields。

不得顺手：

- 改样式体系。
- 改空状态文案。
- 改名称/platform/启停展示。
- 增加 hover/context menu。
- 增加 Riverpod。
- 增加编辑器或路由。

## 验证

生产实现完成后，从 `app/` 依次执行：

```bash
flutter test test/features/sources/presentation/source_list_test.dart
flutter analyze
flutter test
git diff --check
```

全部必须成功。

然后回到仓库根目录执行：

```bash
git status --short
git diff --name-only
```

提交前实际修改文件必须严格只有：

```text
app/lib/features/sources/presentation/source_list.dart
app/test/features/sources/presentation/source_list_test.dart
```

如果出现其他文件，先恢复，不得把额外文件带入 commit。

## Git 提交与推送

允许你自己提交并推送到当前分支。

```bash
git add app/lib/features/sources/presentation/source_list.dart \
        app/test/features/sources/presentation/source_list_test.dart

git commit -m "feat: make source list selectable"
git push origin revival/flutter-workbench
```

禁止 force push。

提交后再执行：

```bash
git status --short
git show --stat --oneline HEAD
```

要求 working tree 为空。

## 最终反馈格式

只需返回以下信息：

```text
1. RED：focused test 的预期失败原因
2. GREEN：focused test / flutter analyze / 全量 flutter test / git diff --check 结果
3. 修改文件：实际修改的文件列表
4. Commit：完整 SHA + commit message
5. Push：是否成功推送 revival/flutter-workbench
6. git status --short：是否为空
7. 偏差：若因当前 Flutter/API 实际行为与工单不同，说明你做了什么最小适配；没有则写“无”
```

不要继续实现 OR-004 或其他任务。
