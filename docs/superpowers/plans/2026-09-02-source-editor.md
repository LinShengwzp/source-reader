# Source Workbench Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Source Workbench 中实现“按数据库 id 选择书源 → 编辑 sourceName/sourceUrl/enable/weight → 保存到 SQLite → reload 后列表立即反映新值”的最小编辑闭环。

**Architecture:** 选择状态由独立 Riverpod `Notifier` 持有，只保存数据库 id。编辑器使用纯 Dart `SourceEditorDraft` 隔离表单临时状态，保存时基于原始 `SourceDocument.copyWithKnownFields(...)` 生成新文档，从而保留未知 raw JSON 字段。Presentation 不直接访问 Repository/Drift；所有保存都经 `SourceController.updateSource(...)`。

**Tech Stack:** Flutter 3.47.0、Dart 3.13.0、flutter_riverpod 3.4.2、Drift 2.34.3、flutter_test。

**Spec:** `docs/superpowers/specs/2026-09-02-source-editor-design.md`

## Global Constraints

- 继续使用 `revival/flutter-workbench`，不修改历史 `main`。
- `SourceDocument` raw JSON 是 canonical truth；未知字段不得丢失。
- 第一阶段只编辑 `sourceName`、`sourceUrl`、`enable`、`weight`。
- 不新增 Router、自动保存、多标签页、dirty guard、Raw JSON 编辑器、新增/删除书源。
- 选择身份必须使用数据库 `id`，不得使用列表 index 或 sourceName。
- Riverpod 3 新代码不得使用 legacy `StateProvider`；选择状态使用 `NotifierProvider`。
- Presentation 不得直接依赖 Drift、SQLite 或 `SqliteSourceRepository`。
- 代码注释继续使用中文。
- 每个实现任务严格 RED → GREEN，并拥有独立代码 commit。
- OmniRoute 工单由强模型先写入 `docs/omniroute/` 并单独 docs commit；OmniRoute 自身代码 commit 不得改工单文档。
- OmniRoute 必须运行指定 focused test、`flutter analyze`、全量 `flutter test`、`git diff --check`，自行 commit 后返回 SHA。

## File Structure

- Create `app/lib/features/sources/application/source_selection.dart`：当前数据库 id 的选择状态。
- Create `app/lib/features/sources/presentation/source_editor_draft.dart`：纯 Dart 草稿模型与 `SourceDocument` 转换。
- Create `app/lib/features/sources/presentation/source_editor.dart`：四字段表单 widget，只通过回调提交 `SourceDocument`。
- Modify `app/lib/features/sources/application/source_controller.dart`：增加保存协调方法。
- Modify `app/lib/features/sources/presentation/source_list.dart`：增加 `selectedId/onSelected`，仍保持纯输入组件。
- Modify `app/lib/features/sources/presentation/source_page.dart`：组合 selection、宽窄屏 Editor、保存反馈与 selection reconciliation。
- Create `docs/omniroute/OR-003-selectable-source-list.md`：SourceList 受控机械工单。
- Create `docs/omniroute/OR-004-source-editor-widget.md`：SourceEditor 受控机械工单。

---

### Task 1: Source selection state（强模型）

**Files:**
- Create: `app/lib/features/sources/application/source_selection.dart`
- Test: `app/test/features/sources/application/source_selection_test.dart`

**Interfaces:**
- Consumes: `flutter_riverpod` 的 `Notifier` / `NotifierProvider`。
- Produces:

```dart
final sourceSelectionProvider =
    NotifierProvider<SourceSelectionController, int?>(
  SourceSelectionController.new,
);

final class SourceSelectionController extends Notifier<int?> {
  @override
  int? build();

  void select(int id);
  void clear();
}
```

- [ ] **Step 1: Write the failing selection test**

Create `app/test/features/sources/application/source_selection_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/application/source_selection.dart';

void main() {
  test('selection 初始为空，select 按数据库 id 选择，clear 清空', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(sourceSelectionProvider), isNull);

    container.read(sourceSelectionProvider.notifier).select(42);
    expect(container.read(sourceSelectionProvider), 42);

    container.read(sourceSelectionProvider.notifier).clear();
    expect(container.read(sourceSelectionProvider), isNull);
  });
}
```

- [ ] **Step 2: Run focused test and verify RED**

From `app/`:

```bash
flutter test test/features/sources/application/source_selection_test.dart
```

Expected: FAIL because `source_selection.dart` / `sourceSelectionProvider` does not exist.

- [ ] **Step 3: Implement minimal selection state**

Create `app/lib/features/sources/application/source_selection.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final sourceSelectionProvider =
    NotifierProvider<SourceSelectionController, int?>(
  SourceSelectionController.new,
);

/// Source Workbench 当前选中的数据库书源 id。
final class SourceSelectionController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int id) {
    state = id;
  }

  void clear() {
    state = null;
  }
}
```

- [ ] **Step 4: Verify GREEN**

```bash
flutter test test/features/sources/application/source_selection_test.dart
flutter analyze
```

Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/sources/application/source_selection.dart app/test/features/sources/application/source_selection_test.dart
git commit -m "feat: add source selection state"
```

---

### Task 2: SourceController update coordination（强模型）

**Files:**
- Modify: `app/lib/features/sources/application/source_controller.dart`
- Modify: `app/test/features/sources/application/source_controller_test.dart`

**Interfaces:**
- Consumes: `SourceRepository.updateSource(int id, SourceDocument document)` and existing `reload()`.
- Produces:

```dart
Future<void> updateSource({
  required int id,
  required SourceDocument document,
})
```

- [ ] **Step 1: Extend FakeSourceRepository with observable update behavior**

Add fields:

```dart
Object? updateError;
int updateCalls = 0;
int? updatedId;
SourceDocument? updatedDocument;
```

Replace the current `updateSource` fake with:

```dart
@override
Future<void> updateSource(int id, SourceDocument document) async {
  updateCalls += 1;
  updatedId = id;
  updatedDocument = document;

  final error = updateError;
  if (error != null) {
    throw error;
  }

  final index = items.indexWhere((item) => item.id == id);
  if (index < 0) {
    throw StateError('source not found: $id');
  }

  final current = items[index];
  items[index] = StoredSource(
    id: current.id,
    platform: current.platform,
    document: document,
    createdAt: current.createdAt,
    updatedAt: DateTime.utc(2026, 9, 2, 9),
  );
}
```

- [ ] **Step 2: Write RED success/failure tests**

Success:

```dart
test('updateSource 成功后调用 Repository 并 reload 当前列表', () async {
  final fake = FakeSourceRepository(<StoredSource>[
    _storedSource(id: 1, name: '旧名称'),
  ]);
  final container = ProviderContainer(
    overrides: [sourceRepositoryProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);

  await container.read(sourceControllerProvider.future);
  final updated = SourceDocument.fromRaw(<String, Object?>{
    'sourceName': '新名称',
    'enable': '1',
    'weight': '0',
  });

  await container.read(sourceControllerProvider.notifier).updateSource(
        id: 1,
        document: updated,
      );

  expect(fake.updateCalls, 1);
  expect(fake.updatedId, 1);
  expect(fake.updatedDocument, same(updated));
  expect(fake.listCalls, 2);
  expect(
    container.read(sourceControllerProvider).requireValue.single.document.sourceName,
    '新名称',
  );
});
```

Failure:

```dart
test('updateSource 失败时不 reload、不污染当前列表并继续抛原异常', () async {
  final error = StateError('update failed');
  final fake = FakeSourceRepository(
    <StoredSource>[_storedSource(id: 1, name: '保留名称')],
  )..updateError = error;
  final container = ProviderContainer(
    overrides: [sourceRepositoryProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);

  await container.read(sourceControllerProvider.future);

  await expectLater(
    container.read(sourceControllerProvider.notifier).updateSource(
          id: 1,
          document: SourceDocument.fromRaw(<String, Object?>{
            'sourceName': '失败名称',
          }),
        ),
    throwsA(same(error)),
  );

  expect(fake.updateCalls, 1);
  expect(fake.listCalls, 1);
  expect(
    container.read(sourceControllerProvider).requireValue.single.document.sourceName,
    '保留名称',
  );
});
```

- [ ] **Step 3: Verify RED**

```bash
flutter test test/features/sources/application/source_controller_test.dart
```

Expected: FAIL only because `SourceController.updateSource(...)` is undefined.

- [ ] **Step 4: Implement minimal controller coordination**

Import `SourceDocument` and add:

```dart
/// 保存成功后刷新列表；保存失败时保留当前列表状态并继续抛出原异常。
Future<void> updateSource({
  required int id,
  required SourceDocument document,
}) async {
  await ref.read(sourceRepositoryProvider).updateSource(id, document);
  await reload();
}
```

Do not set `state = AsyncLoading()` before the repository update. A failed update must leave the already-loaded list untouched.

- [ ] **Step 5: Verify GREEN**

```bash
flutter test test/features/sources/application/source_controller_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sources/application/source_controller.dart app/test/features/sources/application/source_controller_test.dart
git commit -m "feat: coordinate source updates"
```

---

### Task 3: SourceEditorDraft preserving raw JSON（强模型）

**Files:**
- Create: `app/lib/features/sources/presentation/source_editor_draft.dart`
- Test: `app/test/features/sources/presentation/source_editor_draft_test.dart`

**Interfaces:**
- Consumes: `SourceDocument.sourceName/sourceUrl/enabled/weight` and `copyWithKnownFields(...)`.
- Produces:

```dart
final class SourceEditorDraft {
  const SourceEditorDraft({
    required this.sourceName,
    required this.sourceUrl,
    required this.enabled,
    required this.weight,
  });

  factory SourceEditorDraft.fromDocument(SourceDocument document);

  final String sourceName;
  final String sourceUrl;
  final bool enabled;
  final String weight;

  SourceDocument applyTo(SourceDocument original);
}
```

`applyTo` assumes UI validation has already succeeded. It trims `sourceName/sourceUrl` and parses weight with `int.parse`.

- [ ] **Step 1: Write RED extraction/preservation tests**

Fixture:

```dart
final original = SourceDocument.fromRaw(<String, Object?>{
  'sourceName': '旧名称',
  'sourceUrl': ' https://old.example ',
  'enable': '1',
  'weight': '7',
  'futureRule': <String, Object?>{
    'nested': <Object?>['keep', 42],
  },
});
```

Extraction assertions:

```dart
final draft = SourceEditorDraft.fromDocument(original);
expect(draft.sourceName, '旧名称');
expect(draft.sourceUrl, ' https://old.example ');
expect(draft.enabled, isTrue);
expect(draft.weight, '7');
```

Apply assertions:

```dart
final updated = const SourceEditorDraft(
  sourceName: '  新名称  ',
  sourceUrl: ' https://new.example ',
  enabled: false,
  weight: ' 12 ',
).applyTo(original);

expect(updated.sourceName, '新名称');
expect(updated.sourceUrl, 'https://new.example');
expect(updated.enabled, isFalse);
expect(updated.weight, 12);
expect(updated.toRaw()['enable'], '0');
expect(updated.toRaw()['weight'], '12');
expect(updated.toRaw()['futureRule'], original.toRaw()['futureRule']);
```

Also add a second test proving null `sourceName/sourceUrl` become empty draft strings, and a document using boolean `enable` plus integer `weight` keeps those historical raw representation types after `applyTo`.

- [ ] **Step 2: Verify RED**

```bash
flutter test test/features/sources/presentation/source_editor_draft_test.dart
```

Expected: FAIL because `SourceEditorDraft` does not exist.

- [ ] **Step 3: Implement the pure Dart draft**

```dart
import 'package:source_reader/features/sources/domain/source_document.dart';

final class SourceEditorDraft {
  const SourceEditorDraft({
    required this.sourceName,
    required this.sourceUrl,
    required this.enabled,
    required this.weight,
  });

  factory SourceEditorDraft.fromDocument(SourceDocument document) {
    return SourceEditorDraft(
      sourceName: document.sourceName ?? '',
      sourceUrl: document.sourceUrl ?? '',
      enabled: document.enabled,
      weight: document.weight.toString(),
    );
  }

  final String sourceName;
  final String sourceUrl;
  final bool enabled;
  final String weight;

  SourceDocument applyTo(SourceDocument original) {
    return original.copyWithKnownFields(
      sourceName: sourceName.trim(),
      sourceUrl: sourceUrl.trim(),
      enabled: enabled,
      weight: int.parse(weight.trim()),
    );
  }
}
```

- [ ] **Step 4: Verify GREEN**

```bash
flutter test test/features/sources/presentation/source_editor_draft_test.dart
flutter test test/features/sources/domain/source_document_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/sources/presentation/source_editor_draft.dart app/test/features/sources/presentation/source_editor_draft_test.dart
git commit -m "feat: add source editor draft"
```

---

### Task 4: OR-003 selectable SourceList（OmniRoute）

**Files implemented by OmniRoute:**
- Modify: `app/lib/features/sources/presentation/source_list.dart`
- Create: `app/test/features/sources/presentation/source_list_test.dart`

**Work order created first by strong model:**
- Create: `docs/omniroute/OR-003-selectable-source-list.md`

**Interfaces:**
- Consumes: `StoredSource.id` and existing display fields.
- Produces:

```dart
SourceList({
  required List<StoredSource> sources,
  required int? selectedId,
  required ValueChanged<int> onSelected,
})
```

- [ ] **Step 1: Strong model creates and commits OR-003**

The work order must allow only:

```text
app/lib/features/sources/presentation/source_list.dart
app/test/features/sources/presentation/source_list_test.dart
```

It must forbid Domain/Application/Repository/Database/Codec changes and require OmniRoute to self-commit and return SHA.

Docs-only commit:

```bash
git add docs/omniroute/OR-003-selectable-source-list.md
git commit -m "docs: add selectable source list task"
```

- [ ] **Step 2: OmniRoute writes RED widget tests**

Click identity:

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

Stable key/selected state:

```dart
final tile = tester.widget<ListTile>(
  find.byKey(const Key('source-list-tile-2')),
);
expect(tile.selected, isTrue);
```

Also rebuild with order `[id:2, id:1]` while `selectedId == 2`; id 2 must remain selected.

- [ ] **Step 3: Verify RED**

```bash
flutter test test/features/sources/presentation/source_list_test.dart
```

Expected: FAIL because current `SourceList` lacks `selectedId`, `onSelected`, and stable tile keys.

- [ ] **Step 4: Implement minimal selectable list**

Constructor gains the two fields. Each tile uses:

```dart
key: Key('source-list-tile-${source.id}'),
selected: source.id == selectedId,
onTap: () => onSelected(source.id),
```

No Riverpod reads and no local selected state.

- [ ] **Step 5: Verify and self-commit**

```bash
flutter test test/features/sources/presentation/source_list_test.dart
flutter analyze
flutter test
git diff --check
git status --short
```

Code commit:

```bash
git add app/lib/features/sources/presentation/source_list.dart app/test/features/sources/presentation/source_list_test.dart
git commit -m "feat: make source list selectable"
```

Return SHA for strong-model review.

---

### Task 5: OR-004 four-field SourceEditor widget（OmniRoute）

**Files implemented by OmniRoute:**
- Create: `app/lib/features/sources/presentation/source_editor.dart`
- Create: `app/test/features/sources/presentation/source_editor_test.dart`

**Work order created first by strong model:**
- Create: `docs/omniroute/OR-004-source-editor-widget.md`

**Interfaces:**
- Consumes: `StoredSource`, `SourceEditorDraft`.
- Produces:

```dart
typedef SourceDocumentSaveCallback = Future<void> Function(
  SourceDocument document,
);

SourceEditor({
  required StoredSource source,
  required SourceDocumentSaveCallback onSave,
  VoidCallback? onBack,
})
```

The widget owns only transient form state. It does not read Riverpod or Repository.

Stable keys:

```text
source-editor-name
source-editor-url
source-editor-enabled
source-editor-weight
source-editor-save
source-editor-back
```

- [ ] **Step 1: Strong model creates and commits OR-004**

The work order must allow only the two SourceEditor files above and explicitly forbid edits to `SourceEditorDraft`, SourceController, Repository, Database, Codec, SourcePage, and SourceList.

Docs-only commit:

```bash
git add docs/omniroute/OR-004-source-editor-widget.md
git commit -m "docs: add basic source editor task"
```

- [ ] **Step 2: OmniRoute writes RED tests**

Tests must prove all of the following:

1. Four fields initialize from `StoredSource.document`.
2. Editing name/url/enabled/weight and tapping save passes a `SourceDocument` with those four changes while an unknown nested raw field remains unchanged.
3. `sourceName.trim().isEmpty` shows exactly `书源名称不能为空` and does not call `onSave`.
4. Invalid weight shows exactly `权重必须是整数` and does not call `onSave`.
5. While a `Completer<void>` returned by `onSave` is unresolved, the save `FilledButton` has `onPressed == null`; after completer completion it becomes enabled.
6. `onBack == null` means no `source-editor-back`; when provided, tapping it invokes the callback once.
7. Rebuilding the same mounted `SourceEditor` with a different `StoredSource.id` replaces all four displayed draft values with the new source values.

- [ ] **Step 3: Verify RED**

```bash
flutter test test/features/sources/presentation/source_editor_test.dart
```

Expected: FAIL because `SourceEditor` does not exist.

- [ ] **Step 4: Implement minimal StatefulWidget**

Use `TextEditingController` for name/url/weight, a bool for enabled, and `_saving` for duplicate-submit protection.

Initialization helper:

```dart
void _loadSource(StoredSource source) {
  final draft = SourceEditorDraft.fromDocument(source.document);
  _nameController.text = draft.sourceName;
  _urlController.text = draft.sourceUrl;
  _weightController.text = draft.weight;
  _enabled = draft.enabled;
}
```

Required lifecycle handling:

```dart
@override
void didUpdateWidget(covariant SourceEditor oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.source.id != widget.source.id) {
    _loadSource(widget.source);
  }
}
```

This is mandatory so wide-screen selection A → B cannot reuse A's draft.

Validation:

```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return '书源名称不能为空';
  }
  return null;
}
```

Weight:

```dart
validator: (value) {
  if (value == null || int.tryParse(value.trim()) == null) {
    return '权重必须是整数';
  }
  return null;
}
```

Save handler must use `try/finally` so `_saving` always resets:

```dart
if (!_formKey.currentState!.validate() || _saving) {
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
```

Do not catch errors to show Snackbars inside `SourceEditor`; page-level callback owns user feedback.

Dispose all TextEditingControllers.

- [ ] **Step 5: Verify and self-commit**

```bash
flutter test test/features/sources/presentation/source_editor_test.dart
flutter analyze
flutter test
git diff --check
git status --short
```

Code commit:

```bash
git add app/lib/features/sources/presentation/source_editor.dart app/test/features/sources/presentation/source_editor_test.dart
git commit -m "feat: add basic source editor widget"
```

Return SHA for strong-model review.

---

### Task 6: Adaptive SourcePage editor integration（强模型）

**Files:**
- Modify: `app/lib/features/sources/presentation/source_page.dart`
- Modify: `app/test/features/sources/presentation/source_page_test.dart`

**Interfaces:**
- Consumes: `sourceSelectionProvider`, `SourceList(selectedId:onSelected:)`, `SourceEditor`, `SourceController.updateSource(...)`.
- Produces: complete wide/narrow selection-edit-save behavior.

- [ ] **Step 1: Extend TestSourceRepository with real fake updates**

Add `updateError`, `updateCalls`, and implement the same replace-by-id behavior used in Task 2 so SourcePage tests observe the refreshed data rather than mocking Controller internals.

- [ ] **Step 2: Write RED wide/narrow selection tests**

Wide (`Size(1200, 800)`):

```dart
await tester.tap(find.byKey(const Key('source-list-tile-1')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('source-master-pane')), findsOneWidget);
expect(find.byKey(const Key('source-editor-name')), findsOneWidget);
```

Narrow (`Size(600, 800)`): tap tile, expect master list absent and editor present; tap `source-editor-back`, expect list present and editor absent.

- [ ] **Step 3: Write RED save success/failure tests**

Success: edit name to `已保存名称`, tap save, settle, then expect:

```dart
expect(find.text('已保存'), findsOneWidget);
expect(repository.updateCalls, 1);
expect(find.text('已保存名称'), findsWidgets);
```

Failure: configure `updateError = StateError('save failed')`, type `草稿仍在`, tap save, then expect:

```dart
expect(find.textContaining('保存失败：Bad state: save failed'), findsOneWidget);
expect(
  tester.widget<TextFormField>(
    find.byKey(const Key('source-editor-name')),
  ).controller?.text,
  '草稿仍在',
);
```

The failure path must not reload the source list.

- [ ] **Step 4: Write RED selection reconciliation test**

Start with records id 1 and id 2. Select id 1. Change repository list to only id 2 and invoke Controller reload. After settle, selection must be cleared:

- wide: placeholder `选择一个书源开始编辑` is visible;
- narrow: SourceList is visible, stale SourceEditor is absent.

- [ ] **Step 5: Verify RED**

```bash
flutter test test/features/sources/presentation/source_page_test.dart
```

Expected: FAIL because current page does not consume selection or SourceEditor.

- [ ] **Step 6: Implement selection composition and reconciliation**

At build start:

```dart
final sources = ref.watch(sourceControllerProvider);
final selectedId = ref.watch(sourceSelectionProvider);
```

Install a provider listener:

```dart
ref.listen(sourceControllerProvider, (previous, next) {
  next.whenData((items) {
    final currentId = ref.read(sourceSelectionProvider);
    if (currentId == null) {
      return;
    }
    final stillExists = items.any((item) => item.id == currentId);
    if (!stillExists) {
      ref.read(sourceSelectionProvider.notifier).clear();
    }
  });
});
```

Resolve selected source strictly by id:

```dart
StoredSource? selectedSource;
for (final item in items) {
  if (item.id == selectedId) {
    selectedSource = item;
    break;
  }
}
```

Do not use list index or sourceName.

Wide:

```text
left  = SourceList
right = selectedSource != null ? SourceEditor : placeholder
```

Narrow:

```text
selectedSource == null ? SourceList : SourceEditor(onBack: clear)
```

- [ ] **Step 7: Implement save callback at page boundary**

The page callback catches update errors and converts them into user feedback. It must **not rethrow** after showing the failure Snackbar, because the button event must not emit an unhandled asynchronous Flutter error.

```dart
Future<void> saveSource(
  StoredSource source,
  SourceDocument document,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(sourceControllerProvider.notifier).updateSource(
          id: source.id,
          document: document,
        );
    messenger.showSnackBar(
      const SnackBar(content: Text('已保存')),
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('保存失败：$error')),
    );
  }
}
```

`SourceEditor` still exits `_saving` through its own `finally`. Since Controller does not reload on repository update failure, the mounted Editor and its controllers retain the user's draft.

- [ ] **Step 8: Verify focused and full GREEN**

```bash
flutter test test/features/sources/presentation/source_page_test.dart
flutter test test/features/sources/presentation/source_editor_test.dart
flutter test test/features/sources/presentation/source_list_test.dart
flutter test test/features/sources/application/source_controller_test.dart
flutter analyze
flutter test
git diff --check
```

Expected: all PASS.

- [ ] **Step 9: Commit**

```bash
git add app/lib/features/sources/presentation/source_page.dart app/test/features/sources/presentation/source_page_test.dart
git commit -m "feat: wire Source Workbench editor flow"
```

---

## Final Acceptance

After all six tasks, run from `app/`:

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
git diff --check
```

Expected:

- analyzer prints `No issues found!`;
- all tests pass;
- `git diff --check` prints nothing.

Manual smoke test on one available native platform:

1. Launch Source Reader.
2. Import one `.json` or `.xbs` source.
3. Select the imported source.
4. Change name, URL, enabled flag, and weight.
5. Save.
6. Confirm `已保存` feedback and refreshed list value.
7. Restart app and confirm saved values persist from SQLite.

The stage is complete only when automated tests additionally prove an unknown nested raw JSON field survives the edit-save path unchanged.
