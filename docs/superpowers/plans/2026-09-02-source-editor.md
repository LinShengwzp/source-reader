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
- 每个任务严格 RED → GREEN；每个任务独立 commit。
- OmniRoute 工单必须限定允许修改文件，运行 `flutter analyze`、相关 `flutter test`、全量 `flutter test`、`git diff --check`，并自行 commit 后返回 SHA。

## File Structure

- Create `app/lib/features/sources/application/source_selection.dart`：仅负责当前数据库 id 的选择状态。
- Create `app/lib/features/sources/presentation/source_editor_draft.dart`：纯 Dart 草稿模型与 `SourceDocument` 转换，不依赖 Flutter/Riverpod/Repository。
- Create `app/lib/features/sources/presentation/source_editor.dart`：四字段表单 widget，只通过回调提交 `SourceDocument`。
- Modify `app/lib/features/sources/application/source_controller.dart`：增加保存协调方法。
- Modify `app/lib/features/sources/presentation/source_list.dart`：增加 selectedId/onSelected，仍保持纯输入组件。
- Modify `app/lib/features/sources/presentation/source_page.dart`：组合 selection、宽窄屏 Editor、保存反馈与 selection reconciliation。
- Add/modify对应测试文件，按任务边界验证。

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

- [ ] **Step 1: Write the failing selection tests**

Create `app/test/features/sources/application/source_selection_test.dart`：

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

- [ ] **Step 2: Run the focused test and verify RED**

Run from `app/`:

```bash
flutter test test/features/sources/application/source_selection_test.dart
```

Expected: FAIL because `source_selection.dart` / `sourceSelectionProvider` does not exist.

- [ ] **Step 3: Implement the minimal modern Riverpod selection state**

Create `app/lib/features/sources/application/source_selection.dart`：

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

- [ ] **Step 4: Verify GREEN and static analysis**

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

- [ ] **Step 1: Extend the fake repository for observable updates**

In `source_controller_test.dart`, add fields to `FakeSourceRepository`:

```dart
Object? updateError;
int updateCalls = 0;
int? updatedId;
SourceDocument? updatedDocument;
```

Replace its `updateSource` with behavior that records `id/document`, throws `updateError` when configured, and on success replaces the matching `StoredSource` while preserving `id/platform/createdAt` and changing `updatedAt`.

- [ ] **Step 2: Write RED tests for success and failure**

Add tests that prove:

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

And failure:

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

- [ ] **Step 3: Run focused tests and verify RED**

```bash
flutter test test/features/sources/application/source_controller_test.dart
```

Expected: FAIL because `SourceController.updateSource(...)` is undefined.

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

Do not wrap repository errors in `AsyncValue.guard` before the repository update; a failed update must leave current controller state untouched.

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

`applyTo` assumes the UI has already validated sourceName and weight. It trims strings and parses weight with `int.parse`.

- [ ] **Step 1: Write RED tests for extraction and preservation**

Create tests covering a document like:

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

Assertions:

```dart
final draft = SourceEditorDraft.fromDocument(original);
expect(draft.sourceName, '旧名称');
expect(draft.sourceUrl, ' https://old.example ');
expect(draft.enabled, isTrue);
expect(draft.weight, '7');
```

Then create a changed draft and call `applyTo(original)`, asserting:

```dart
expect(updated.sourceName, '新名称');
expect(updated.sourceUrl, 'https://new.example');
expect(updated.enabled, isFalse);
expect(updated.weight, 12);
expect(updated.toRaw()['enable'], '0');
expect(updated.toRaw()['weight'], '12');
expect(updated.toRaw()['futureRule'], original.toRaw()['futureRule']);
```

Also test missing `sourceName/sourceUrl` produce empty draft strings and numeric/bool historical representations remain compatible through `copyWithKnownFields`.

- [ ] **Step 2: Run focused test and verify RED**

```bash
flutter test test/features/sources/presentation/source_editor_draft_test.dart
```

Expected: FAIL because `SourceEditorDraft` does not exist.

- [ ] **Step 3: Implement the pure Dart draft**

Create `source_editor_draft.dart` with exactly the interface above. `fromDocument` uses `?? ''` for nullable strings and `document.weight.toString()` for weight. `applyTo` must call `original.copyWithKnownFields(...)`; it must never rebuild a raw map from only the four known fields.

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

**Files:**
- Modify: `app/lib/features/sources/presentation/source_list.dart`
- Create: `app/test/features/sources/presentation/source_list_test.dart`
- Create: `docs/omniroute/OR-003-selectable-source-list.md`

**Interfaces:**
- Consumes: `StoredSource.id` and existing list display fields.
- Produces:

```dart
SourceList({
  required List<StoredSource> sources,
  required int? selectedId,
  required ValueChanged<int> onSelected,
})
```

- [ ] **Step 1: Strong model writes the OR-003 work order before delegation**

The work order must allow only the three files listed above, forbid Domain/Application/Repository/Database/Codec changes, and require OmniRoute to self-commit and return SHA.

- [ ] **Step 2: OmniRoute writes RED widget tests**

Tests must prove:

```dart
await tester.tap(find.text('书源 B'));
expect(selectedIds, <int>[2]);
```

and selected visual identity must be testable using a stable key:

```dart
Key('source-list-tile-2')
```

with `ListTile.selected == true` when `selectedId == 2`.

A reordered list with the same selected id must still select the record whose database id is 2.

- [ ] **Step 3: Verify RED**

```bash
flutter test test/features/sources/presentation/source_list_test.dart
```

Expected: FAIL because current `SourceList` lacks selectedId/onSelected/keys.

- [ ] **Step 4: OmniRoute implements minimal selectable list**

Each tile must use:

```dart
key: Key('source-list-tile-${source.id}'),
selected: source.id == selectedId,
onTap: () => onSelected(source.id),
```

Do not add Riverpod reads or local selected state.

- [ ] **Step 5: Verify and self-commit**

```bash
flutter test test/features/sources/presentation/source_list_test.dart
flutter analyze
flutter test
git diff --check
git status --short
```

Commit:

```bash
git add docs/omniroute/OR-003-selectable-source-list.md app/lib/features/sources/presentation/source_list.dart app/test/features/sources/presentation/source_list_test.dart
git commit -m "feat: make source list selectable"
```

Return commit SHA for review.

---

### Task 5: OR-004 four-field SourceEditor widget（OmniRoute）

**Files:**
- Create: `app/lib/features/sources/presentation/source_editor.dart`
- Create: `app/test/features/sources/presentation/source_editor_test.dart`
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

- [ ] **Step 1: Strong model writes OR-004 with exact allowed files and UI contract**

Stable field keys:

```text
source-editor-name
source-editor-url
source-editor-enabled
source-editor-weight
source-editor-save
source-editor-back
```

`source-editor-back` is rendered only when `onBack != null`.

- [ ] **Step 2: OmniRoute writes RED tests**

Tests must prove:

1. Four fields initialize from `StoredSource.document`.
2. Editing name/url/enabled/weight and tapping save passes a `SourceDocument` with those four changed values while an unknown raw field remains present.
3. `sourceName.trim().isEmpty` shows `书源名称不能为空` and does not call `onSave`.
4. invalid `weight` shows `权重必须是整数` and does not call `onSave`.
5. While returned save Future is unresolved, save button has `onPressed == null`; after completion it becomes enabled again.
6. `onBack` callback is called only when the optional back button exists and is tapped.

- [ ] **Step 3: Verify RED**

```bash
flutter test test/features/sources/presentation/source_editor_test.dart
```

Expected: FAIL because `SourceEditor` does not exist.

- [ ] **Step 4: Implement minimal StatefulWidget**

Requirements:

- Initialize controllers/switch state from `SourceEditorDraft.fromDocument(source.document)`.
- Use `Form` validators with exact strings above.
- On valid save, build a `SourceEditorDraft` from current field values and call `draft.applyTo(source.document)`.
- Await `onSave(updatedDocument)`.
- Use a local `_saving` boolean solely to prevent duplicate submits.
- Do not catch/save-toast errors inside SourceEditor; errors must bubble to SourcePage.
- Dispose TextEditingControllers.

- [ ] **Step 5: Verify and self-commit**

```bash
flutter test test/features/sources/presentation/source_editor_test.dart
flutter analyze
flutter test
git diff --check
git status --short
```

Commit:

```bash
git add docs/omniroute/OR-004-source-editor-widget.md app/lib/features/sources/presentation/source_editor.dart app/test/features/sources/presentation/source_editor_test.dart
git commit -m "feat: add basic source editor widget"
```

Return commit SHA for review.

---

### Task 6: Adaptive SourcePage editor integration（强模型）

**Files:**
- Modify: `app/lib/features/sources/presentation/source_page.dart`
- Modify: `app/test/features/sources/presentation/source_page_test.dart`

**Interfaces:**
- Consumes: `sourceSelectionProvider`, `SourceList(selectedId:onSelected:)`, `SourceEditor`, `SourceController.updateSource(...)`.
- Produces: complete wide/narrow selection-edit-save behavior.

- [ ] **Step 1: Update existing page test helper to include selection state without mocking it**

Continue overriding Repository and SourceFilePicker only. Let `sourceSelectionProvider` use its real implementation so widget tests exercise actual selection semantics.

- [ ] **Step 2: Write RED tests for wide and narrow selection**

Wide (`Size(1200, 800)`): tap `Key('source-list-tile-1')`, then expect `Key('source-editor-name')` and existing master pane simultaneously.

Narrow (`Size(600, 800)`): tap the tile, expect list pane hidden and editor visible; tap `source-editor-back`, expect list visible and editor absent.

- [ ] **Step 3: Write RED tests for save success and failure**

Extend `TestSourceRepository` with observable `updateSource`. Success test edits name to `已保存名称`, taps save, then expects Snackbar `已保存` and the refreshed list/editor to contain the saved name.

Failure test configures a stable `StateError('save failed')`, edits a field, taps save, expects Snackbar containing `保存失败：Bad state: save failed`, and expects the edited field text still present because the editor was not replaced by a reload.

- [ ] **Step 4: Write RED test for selection reconciliation**

Start with selected id 1. Cause repository reload to return only id 2, call controller reload, then verify the page returns to unselected state: wide shows `选择一个书源开始编辑`; narrow shows list rather than a stale editor.

- [ ] **Step 5: Verify RED**

```bash
flutter test test/features/sources/presentation/source_page_test.dart
```

Expected: FAIL because current page does not consume selection or SourceEditor.

- [ ] **Step 6: Implement adaptive composition**

In `SourcePage.build`:

```dart
final selectedId = ref.watch(sourceSelectionProvider);
```

Pass `selectedId` and `onSelected` into SourceList. Resolve the selected source by id from the current `items`; never by index.

Use `ref.listen(sourceControllerProvider, ...)` to observe successful list changes. If current selected id is non-null and no returned record has that id, call `sourceSelectionProvider.notifier.clear()` after the provider change callback, not by mutating provider synchronously during widget layout.

Wide behavior:

```text
left  = SourceList
right = selected source ? SourceEditor : placeholder
```

Narrow behavior:

```text
selected == null ? SourceList : SourceEditor(onBack: clear)
```

- [ ] **Step 7: Implement save callback at page boundary**

The callback passed to SourceEditor must:

```dart
try {
  await ref.read(sourceControllerProvider.notifier).updateSource(
        id: source.id,
        document: document,
      );
  messenger.showSnackBar(const SnackBar(content: Text('已保存')));
} catch (error) {
  messenger.showSnackBar(
    SnackBar(content: Text('保存失败：$error')),
  );
  rethrow;
}
```

Because SourceEditor awaits `onSave`, rethrowing keeps the failure observable to it only for `_saving` cleanup; the editor must not replace its draft on failure.

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

- analyzer: `No issues found!`
- all tests pass
- `git diff --check` has no output

Manual smoke test on one available native platform:

1. Launch Source Reader.
2. Import one `.json` or `.xbs` source.
3. Select the imported source.
4. Change name, URL, enabled flag, and weight.
5. Save.
6. Confirm success feedback and refreshed list value.
7. Restart app and confirm saved values persist from SQLite.

The stage is complete only when automated tests additionally prove an unknown nested raw JSON field survives the edit-save path unchanged.
