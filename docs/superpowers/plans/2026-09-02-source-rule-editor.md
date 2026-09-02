# Source Rule Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Source Workbench 中建立四条主规则链可复用的 action 领域边界，并完整实现 `searchBook` 的安全编辑、保存、SQLite 持久化与 reload 回归。

**Architecture:** `SourceDocument` 仍以 raw JSON 为 canonical truth。新增 `SourceActionDocument` 作为四条主链共享的 typed facade，`SourceSearchBookDocument` 只增加搜索专属字段；UI 通过独立 `SourceSearchBookDraft` 工作，不直接修改 raw Map。`SearchBookEditor` 是可替换的纯 presentation 组件，最终仍由现有 `SourceEditor -> SourcePage -> SourceController -> Repository` 保存链一次提交整个 `SourceDocument`。

**Tech Stack:** Flutter 3.47.0、Dart 3.13.0、flutter_riverpod 3.4.2、Drift 2.34.3、flutter_test；不新增第三方 UI、JSON 编辑器或规则执行依赖。

**Spec:** `docs/superpowers/specs/2026-09-02-source-rule-editor-design.md`

## Global Constraints

- 只在 `revival/flutter-workbench` 工作，不修改历史 `main`。
- raw JSON 始终是书源唯一事实来源；顶层和 `searchBook` 内未知字段均不得丢失。
- 本轮只实现 `searchBook` UI/Draft，不实现 `bookDetail`、`chapterList`、`chapterContent` 的 presentation/Draft。
- `SourceActionDocument` 必须能被后续三条主链复用，但不得提前实现三条主链的具体 facade。
- `actionID`、`parserID` 第一版只读并原样保留。
- 规则文本不主动 trim；用户输入的规则字符串按原文本写回。
- enum 字段缺失时保持 null；未知 enum 值必须显示并 round-trip，不能自动替换成默认值。
- v1 不提供 enum 的“清空已设置值”操作；原来缺失的 enum 在用户未选择时继续缺失。
- 原始 `moreKeys` 为 Map/List 时，未修改必须保留原类型和值；修改后必须解析为 JSON 对象或数组，否则本地校验失败且不调用保存。
- 原始 `moreKeys` 为 String 或字段不存在时，修改后按 String 写回。
- 仅展开/查看空白 `searchBook` 区域不得创建新对象；从无到有第一次填写有效内容时创建 `actionID=searchBook`、`parserID=DOM`。
- Presentation 不直接读取/修改 `SourceDocument.toRaw()`，不访问 Repository、SQLite、Drift 或 Riverpod。
- 不引入旧版 `FormModelItem[]` 动态 schema 表单引擎。
- UI 布局不是领域契约；后续从折叠卡片切换到 Tab/侧栏时不得要求修改 Domain/Draft/Repository。
- 所有新业务注释优先中文。
- 每个实现任务执行 RED -> GREEN；完成前运行 focused test、`flutter analyze`、全量 `flutter test` 和 `git diff --check`。
- OmniRoute 只做精确白名单内的 presentation；必须自测、自 commit、自 push 并返回 SHA。

## File Structure

- Create `app/lib/features/sources/domain/source_action_document.dart`：四条主链共享 action facade。
- Create `app/lib/features/sources/domain/source_rule_options.dart`：presentation-neutral 的已知枚举值/标签。
- Create `app/lib/features/sources/domain/source_search_book_document.dart`：`searchBook` 专属 facade。
- Modify `app/lib/features/sources/domain/source_document.dart`：增加 `searchBook` getter 与 `copyWithSearchBook`。
- Create `app/lib/features/sources/presentation/source_search_book_draft.dart`：搜索规则临时草稿、dirty comparison 与 `moreKeys` 表示兼容。
- Create `app/lib/features/sources/presentation/source_rule_fields.dart`：小型显式表单控件。
- Create `app/lib/features/sources/presentation/source_search_book_editor.dart`：纯搜索规则 UI。
- Create `app/lib/features/sources/presentation/source_basic_editor_section.dart`：从当前 `SourceEditor` 拆出的基础四字段 UI。
- Modify `app/lib/features/sources/presentation/source_editor.dart`：组合 basic + searchBook draft，统一校验与一次保存。
- Add domain/draft/widget/editor/integration tests under matching `app/test/features/sources/...` paths。
- Create `docs/omniroute/OR-005-search-book-editor-widget.md` before delegating the pure UI task.

---

### Task 1: Shared action facade and rule options（强模型）

**Files:**
- Create: `app/lib/features/sources/domain/source_action_document.dart`
- Create: `app/lib/features/sources/domain/source_rule_options.dart`
- Create: `app/test/features/sources/domain/source_action_document_test.dart`

**Interfaces:**

```dart
final class SourceActionDocument {
  factory SourceActionDocument.fromRaw(Map<String, Object?> raw);

  String? get actionId;
  String? get parserId;
  String? get requestInfo;
  String? get requestParamsEncode;
  String? get responseEncode;
  String? get responseFormatType;
  String? get jsParser;
  Object? get moreKeysRaw;

  Map<String, Object?> toRaw();

  SourceActionDocument copyWithKnownFields({
    String? requestInfo,
    String? requestParamsEncode,
    String? responseEncode,
    String? responseFormatType,
    String? jsParser,
    Object? moreKeys,
  });
}
```

Rule option interface:

```dart
final class SourceRuleOption {
  const SourceRuleOption(this.value, this.label);
  final String value;
  final String label;
}

abstract final class SourceRuleOptions {
  static const requestParamsEncode = <SourceRuleOption>[
    SourceRuleOption('utf-8', 'utf-8'),
    SourceRuleOption('2147485234', 'gbk'),
  ];

  static const responseEncode = <SourceRuleOption>[
    SourceRuleOption('utf-8', 'utf-8'),
    SourceRuleOption('2147485232', '简体中文(gb2312)'),
    SourceRuleOption('2147485234', '简体中文(gbk)'),
  ];

  static const responseFormatType = <SourceRuleOption>[
    SourceRuleOption('str', '普通字符串'),
    SourceRuleOption('base64str', 'Base64 字符串'),
    SourceRuleOption('html', 'DOM'),
    SourceRuleOption('xml', 'XML 结构'),
    SourceRuleOption('json', 'JSON 结构'),
    SourceRuleOption('data', '原始数据流'),
    SourceRuleOption('filePath', '文件路径'),
  ];
}
```

- [ ] **Step 1: Write RED tests for shared fields, copy-on-write and options**

```dart
final original = SourceActionDocument.fromRaw(<String, Object?>{
  'actionID': 'searchBook',
  'parserID': 'DOM',
  'requestInfo': 'old-request',
  'responseFormatType': 'future-format',
  'moreKeys': <String, Object?>{'pageSize': 20},
  'futureActionField': <String, Object?>{'keep': true},
});

expect(original.actionId, 'searchBook');
expect(original.parserId, 'DOM');
expect(original.requestInfo, 'old-request');
expect(original.responseFormatType, 'future-format');
expect(original.moreKeysRaw, <String, Object?>{'pageSize': 20});

final changed = original.copyWithKnownFields(
  requestInfo: 'new-request',
  responseEncode: 'utf-8',
);
expect(changed.requestInfo, 'new-request');
expect(changed.responseEncode, 'utf-8');
expect(changed.toRaw()['actionID'], 'searchBook');
expect(changed.toRaw()['parserID'], 'DOM');
expect(
  changed.toRaw()['futureActionField'],
  <String, Object?>{'keep': true},
);
expect(changed.toRaw()['responseFormatType'], 'future-format');
```

Also assert the exact `SourceRuleOptions` values listed above.

- [ ] **Step 2: Verify RED**

Run from `app/`:

```bash
flutter test test/features/sources/domain/source_action_document_test.dart
```

Expected: FAIL because `source_action_document.dart` / `source_rule_options.dart` do not exist.

- [ ] **Step 3: Implement minimal immutable facade**

Implementation must defensively copy the top-level Map:

```dart
final class SourceActionDocument {
  SourceActionDocument._(this._raw);

  factory SourceActionDocument.fromRaw(Map<String, Object?> raw) {
    return SourceActionDocument._(Map<String, Object?>.from(raw));
  }

  final Map<String, Object?> _raw;

  String? get actionId => _stringValue('actionID');
  String? get parserId => _stringValue('parserID');
  String? get requestInfo => _stringValue('requestInfo');
  String? get requestParamsEncode => _stringValue('requestParamsEncode');
  String? get responseEncode => _stringValue('responseEncode');
  String? get responseFormatType => _stringValue('responseFormatType');
  String? get jsParser => _stringValue('JSParser');
  Object? get moreKeysRaw => _raw['moreKeys'];

  Map<String, Object?> toRaw() => Map<String, Object?>.from(_raw);

  String? _stringValue(String key) {
    final value = _raw[key];
    return value is String ? value : null;
  }
}
```

`copyWithKnownFields` writes only non-null arguments. Empty strings are valid explicit writes. `moreKeys == null` means “do not change”; v1 has no remove-moreKeys operation.

- [ ] **Step 4: Verify GREEN**

```bash
flutter test test/features/sources/domain/source_action_document_test.dart
flutter analyze
```

Expected: PASS / No issues found.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/sources/domain/source_action_document.dart \
  app/lib/features/sources/domain/source_rule_options.dart \
  app/test/features/sources/domain/source_action_document_test.dart
git commit -m "feat: add source action domain facade"
```

---

### Task 2: `searchBook` domain facade and `SourceDocument` integration（强模型）

**Files:**
- Create: `app/lib/features/sources/domain/source_search_book_document.dart`
- Modify: `app/lib/features/sources/domain/source_document.dart`
- Create: `app/test/features/sources/domain/source_search_book_document_test.dart`
- Modify: `app/test/features/sources/domain/source_document_test.dart`

**Interfaces:**

```dart
final class SourceSearchBookDocument {
  factory SourceSearchBookDocument.fromRaw(Map<String, Object?> raw);
  factory SourceSearchBookDocument.createDefault();

  SourceActionDocument get action;
  String? get list;
  String? get bookName;
  String? get author;
  String? get cover;
  String? get desc;
  String? get cat;
  String? get status;
  String? get wordCount;
  String? get lastChapterTitle;
  String? get detailUrl;
  String? get success;

  Map<String, Object?> toRaw();

  SourceSearchBookDocument copyWithKnownFields({
    String? requestInfo,
    String? requestParamsEncode,
    String? responseEncode,
    String? responseFormatType,
    String? jsParser,
    Object? moreKeys,
    String? list,
    String? bookName,
    String? author,
    String? cover,
    String? desc,
    String? cat,
    String? status,
    String? wordCount,
    String? lastChapterTitle,
    String? detailUrl,
    String? success,
  });
}
```

`SourceDocument` produces:

```dart
SourceSearchBookDocument? get searchBook;

SourceDocument copyWithSearchBook(SourceSearchBookDocument searchBook);
```

- [ ] **Step 1: Write RED domain tests**

Use a fixture with common fields, search-specific fields and an unknown nested field:

```dart
final search = SourceSearchBookDocument.fromRaw(<String, Object?>{
  'actionID': 'searchBook',
  'parserID': 'DOM',
  'requestInfo': '/search?q=%@keyWord',
  'list': '//div[@class="book"]',
  'bookName': './/h3/text()',
  'author': './/span/text()',
  'responseFormatType': 'future-format',
  'futureSearchField': <String, Object?>{'nested': <Object?>[1, 2]},
});

final changed = search.copyWithKnownFields(
  bookName: './/h2/text()',
  responseEncode: 'utf-8',
);
expect(changed.bookName, './/h2/text()');
expect(changed.action.responseFormatType, 'future-format');
expect(changed.toRaw()['actionID'], 'searchBook');
expect(changed.toRaw()['parserID'], 'DOM');
expect(
  changed.toRaw()['futureSearchField'],
  search.toRaw()['futureSearchField'],
);
```

`createDefault()` must produce exactly the two metadata fields before user edits:

```dart
expect(
  SourceSearchBookDocument.createDefault().toRaw(),
  <String, Object?>{
    'actionID': 'searchBook',
    'parserID': 'DOM',
  },
);
```

Add `SourceDocument` tests:

```dart
final source = SourceDocument.fromRaw(<String, Object?>{
  'sourceName': 'A',
  'futureTop': <String, Object?>{'keep': true},
  'searchBook': search.toRaw(),
});
expect(source.searchBook?.bookName, './/h3/text()');

final replaced = source.copyWithSearchBook(changed);
expect(replaced.searchBook?.bookName, './/h2/text()');
expect(replaced.toRaw()['futureTop'], <String, Object?>{'keep': true});
```

For malformed raw:

```dart
final malformed = SourceDocument.fromRaw(<String, Object?>{
  'searchBook': 'legacy-invalid-value',
});
expect(malformed.searchBook, isNull);
expect(malformed.toRaw()['searchBook'], 'legacy-invalid-value');
```

- [ ] **Step 2: Verify RED**

```bash
flutter test test/features/sources/domain/source_search_book_document_test.dart \
  test/features/sources/domain/source_document_test.dart
```

Expected: FAIL only because the new searchBook facade/API is undefined.

- [ ] **Step 3: Implement searchBook facade**

`SourceSearchBookDocument` owns its own copied raw Map. `action` is projected from the same raw values:

```dart
SourceActionDocument get action => SourceActionDocument.fromRaw(_raw);
```

When applying common-field changes, first apply `SourceActionDocument.copyWithKnownFields(...)`, then write search-specific non-null changes into that copied Map. Do not expose mutable raw references.

- [ ] **Step 4: Implement safe `SourceDocument.searchBook` conversion**

The getter must accept only a string-keyed Map and otherwise return null without modifying raw:

```dart
SourceSearchBookDocument? get searchBook {
  final value = _raw['searchBook'];
  if (value is! Map) return null;

  final converted = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) return null;
    converted[key] = entry.value;
  }
  return SourceSearchBookDocument.fromRaw(converted);
}

SourceDocument copyWithSearchBook(SourceSearchBookDocument searchBook) {
  final raw = toRaw();
  raw['searchBook'] = searchBook.toRaw();
  return SourceDocument.fromRaw(raw);
}
```

- [ ] **Step 5: Verify GREEN**

```bash
flutter test test/features/sources/domain/source_search_book_document_test.dart \
  test/features/sources/domain/source_document_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sources/domain/source_search_book_document.dart \
  app/lib/features/sources/domain/source_document.dart \
  app/test/features/sources/domain/source_search_book_document_test.dart \
  app/test/features/sources/domain/source_document_test.dart
git commit -m "feat: add search book domain facade"
```

---

### Task 3: `SourceSearchBookDraft` with dirty-aware raw preservation（强模型）

**Files:**
- Create: `app/lib/features/sources/presentation/source_search_book_draft.dart`
- Create: `app/test/features/sources/presentation/source_search_book_draft_test.dart`

**Interfaces:**

```dart
final class SourceSearchBookDraft {
  factory SourceSearchBookDraft.fromDocument(
    SourceSearchBookDocument? document,
  );

  final String requestInfo;
  final String list;
  final String bookName;
  final String author;
  final String cover;
  final String desc;
  final String cat;
  final String status;
  final String wordCount;
  final String lastChapterTitle;
  final String detailUrl;
  final String? requestParamsEncode;
  final String? responseEncode;
  final String? responseFormatType;
  final String success;
  final String jsParser;
  final String moreKeysText;

  SourceSearchBookDraft copyWith({...});
  String? get moreKeysValidationError;
  bool get hasEditableContent;
  SourceDocument applyTo(SourceDocument original);
}
```

The draft retains the original `SourceSearchBookDocument?` privately so apply can distinguish “unchanged missing field” from “user cleared an existing string field”.

- [ ] **Step 1: Write RED mapping and no-op creation tests**

For an existing document, assert every field maps to the draft and enum unknown values remain literal strings.

For no `searchBook`:

```dart
final source = SourceDocument.fromRaw(<String, Object?>{
  'sourceName': 'A',
  'futureTop': true,
});
final draft = SourceSearchBookDraft.fromDocument(source.searchBook);
expect(draft.requestInfo, '');
expect(draft.responseFormatType, isNull);
expect(draft.hasEditableContent, isFalse);
expect(draft.applyTo(source).toRaw(), source.toRaw());
```

- [ ] **Step 2: Write RED creation and metadata-preservation tests**

```dart
final created = draft.copyWith(
  requestInfo: '/search?q=%@keyWord',
  bookName: './/h3/text()',
).applyTo(source);

expect(created.searchBook?.action.actionId, 'searchBook');
expect(created.searchBook?.action.parserId, 'DOM');
expect(created.searchBook?.action.requestInfo, '/search?q=%@keyWord');
expect(created.searchBook?.bookName, './/h3/text()');
```

An existing raw object containing only `actionID/parserID` must remain present after an otherwise unchanged apply.

- [ ] **Step 3: Write RED dirty-field tests**

Use an existing `searchBook` that omits `author`, `cover`, enums, etc. Apply an unchanged draft and assert those missing keys are still absent. Then clear an existing string field and assert only that field becomes `''`.

This is mandatory to prevent “saving basic fields injects every absent searchBook field as empty string”.

- [ ] **Step 4: Write RED `moreKeys` representation tests**

Structured raw unchanged:

```dart
final rawMoreKeys = <String, Object?>{
  'pageSize': 20,
  'removeHtmlKeys': <Object?>['bookName'],
};
final source = SourceDocument.fromRaw(<String, Object?>{
  'searchBook': <String, Object?>{
    'actionID': 'searchBook',
    'parserID': 'DOM',
    'moreKeys': rawMoreKeys,
  },
});
final draft = SourceSearchBookDraft.fromDocument(source.searchBook);
final unchanged = draft.applyTo(source);
expect(unchanged.searchBook?.action.moreKeysRaw, rawMoreKeys);
expect(unchanged.searchBook?.action.moreKeysRaw, isA<Map>());
```

Structured raw changed:

```dart
final changed = draft.copyWith(
  moreKeysText: '{"pageSize":30,"maxPage":2}',
);
expect(changed.moreKeysValidationError, isNull);
final updated = changed.applyTo(source);
expect(
  updated.searchBook?.action.moreKeysRaw,
  <String, Object?>{'pageSize': 30, 'maxPage': 2},
);
```

Invalid structured edit:

```dart
final invalid = draft.copyWith(moreKeysText: '{bad json');
expect(invalid.moreKeysValidationError, 'moreKeys 必须是有效 JSON 对象或数组');
expect(() => invalid.applyTo(source), throwsFormatException);
```

Also prove original String `moreKeys` modified to `'{bad json'` remains a String and is allowed.

- [ ] **Step 5: Verify RED**

```bash
flutter test test/features/sources/presentation/source_search_book_draft_test.dart
```

Expected: FAIL because the draft does not exist.

- [ ] **Step 6: Implement dirty-aware draft**

Use `dart:convert` only for Map/List projection and validation. Store the original document privately:

```dart
SourceSearchBookDraft._({
  required SourceSearchBookDocument? original,
  ...
}) : _original = original;

final SourceSearchBookDocument? _original;
```

`copyWith` must always carry `_original` forward.

For each string field, compare current draft value with `(_original?.field ?? '')`; pass `null` to the domain `copyWithKnownFields` when unchanged and pass the actual current string—including `''`—when changed.

For enums, compare nullable values directly. v1 has no explicit enum-clear UI, so `null` continues to mean “unchanged/missing”.

For absent `searchBook`, return the original SourceDocument unless `hasEditableContent` is true. When creation is needed, start from `SourceSearchBookDocument.createDefault()` and only write non-empty/non-null fields.

- [ ] **Step 7: Verify GREEN**

```bash
flutter test test/features/sources/presentation/source_search_book_draft_test.dart
flutter test test/features/sources/domain/source_search_book_document_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/sources/presentation/source_search_book_draft.dart \
  app/test/features/sources/presentation/source_search_book_draft_test.dart
git commit -m "feat: add search book editor draft"
```

---

### Task 4: OR-005 pure `SearchBookEditor` UI（OmniRoute）

**Strong-model work order file:**
- Create: `docs/omniroute/OR-005-search-book-editor-widget.md`

**OmniRoute allowed files only:**
- Create: `app/lib/features/sources/presentation/source_rule_fields.dart`
- Create: `app/lib/features/sources/presentation/source_search_book_editor.dart`
- Create: `app/test/features/sources/presentation/source_search_book_editor_test.dart`

**Forbidden:** Domain, Draft, SourceEditor, SourcePage, Controller, Repository, Database, Codec, pubspec.

**Interface:**

```dart
final class SearchBookEditor extends StatelessWidget {
  const SearchBookEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SourceSearchBookDraft value;
  final ValueChanged<SourceSearchBookDraft> onChanged;
}
```

Stable field keys:

```text
search-book-request-info
search-book-list
search-book-book-name
search-book-author
search-book-cover
search-book-desc
search-book-cat
search-book-status
search-book-word-count
search-book-last-chapter-title
search-book-detail-url
search-book-request-params-encode
search-book-response-encode
search-book-response-format-type
search-book-success
search-book-js-parser
search-book-more-keys
search-book-advanced
```

- [ ] **Step 1: Strong model writes and commits OR-005**

The work order must explicitly state:

- no dynamic schema engine;
- `SearchBookEditor` does not save or access raw JSON;
- layout can use section/card/ExpansionTile, but tests must not assert a specific container widget type;
- advanced section starts visually collapsed but is reachable by the `search-book-advanced` key;
- unknown enum current value must be included as an extra item labeled `未知值：<value>`;
- no enum clear action in v1;
- text changes call `onChanged(value.copyWith(...))`;
- `JSParser`, `requestInfo`, `moreKeys` are multiline;
- `moreKeys` validator displays `value.copyWith(moreKeysText: fieldText).moreKeysValidationError`.

Docs commit:

```bash
git add docs/omniroute/OR-005-search-book-editor-widget.md
git commit -m "docs: add search book editor task"
```

- [ ] **Step 2: OmniRoute writes RED widget tests**

Tests must cover:

1. requestInfo + representative response fields initialize from the Draft.
2. editing `bookName` emits a Draft whose `bookName` changed and unrelated values remain unchanged.
3. selecting known `responseFormatType=json` emits `json`.
4. current unknown enum `future-format` is displayed without being replaced.
5. advanced fields are reachable and `JSParser`/`moreKeys` are multiline.
6. invalid structured `moreKeys` shows exactly `moreKeys 必须是有效 JSON 对象或数组`.

- [ ] **Step 3: OmniRoute verifies RED**

```bash
flutter test test/features/sources/presentation/source_search_book_editor_test.dart
```

Expected: FAIL because the editor files do not exist.

- [ ] **Step 4: OmniRoute implements minimal UI primitives and editor**

`source_rule_fields.dart` may contain only small explicit widgets such as:

```dart
final class RuleTextField extends StatelessWidget { ... }
final class RuleMultilineField extends StatelessWidget { ... }
final class RuleEnumField extends StatelessWidget { ... }
final class EditorSectionCard extends StatelessWidget { ... }
```

Do not introduce `RuleFieldSchema`, string model paths, runtime reflection, generic Map mutation, or callback registries.

Parent `SourceEditor` will later mount this widget with a key based on `StoredSource.id`; therefore this task must not invent source-selection/session state.

- [ ] **Step 5: OmniRoute verifies and self-commits**

```bash
flutter test test/features/sources/presentation/source_search_book_editor_test.dart
flutter analyze
flutter test
git diff --check
git status --short
```

All commands must be GREEN. Then:

```bash
git add app/lib/features/sources/presentation/source_rule_fields.dart \
  app/lib/features/sources/presentation/source_search_book_editor.dart \
  app/test/features/sources/presentation/source_search_book_editor_test.dart
git commit -m "feat: add search book editor widget"
git push origin revival/flutter-workbench
```

Return the full commit SHA for strong-model review.

---

### Task 5: Integrate basic + searchBook drafts into `SourceEditor`（强模型）

**Files:**
- Create: `app/lib/features/sources/presentation/source_basic_editor_section.dart`
- Modify: `app/lib/features/sources/presentation/source_editor.dart`
- Modify: `app/test/features/sources/presentation/source_editor_test.dart`

**Interfaces consumed:**

```dart
SourceEditorDraft.fromDocument(SourceDocument document)
SourceSearchBookDraft.fromDocument(SourceSearchBookDocument? document)
SearchBookEditor(value: ..., onChanged: ...)
```

Existing `SourceEditor` public constructor and `SourceDocumentSaveCallback` must remain unchanged so SourcePage needs no API modification.

- [ ] **Step 1: Write RED editor integration tests**

Extend `source_editor_test.dart` with:

1. existing `searchBook.requestInfo/bookName` values are visible.
2. editing one basic field and searchBook fields then saving yields one `SourceDocument` containing all changes.
3. unknown top-level and unknown searchBook nested fields survive the same save.
4. malformed structured `moreKeys` prevents `onSave` and shows the local validation error.
5. source id A -> B reloads both basic fields and searchBook fields.

Representative save assertion:

```dart
expect(saved?.sourceName, '新名称');
expect(saved?.searchBook?.action.requestInfo, '/new-search');
expect(saved?.searchBook?.bookName, './/h2/text()');
expect(saved?.toRaw()['futureTop'], original.toRaw()['futureTop']);
expect(
  saved?.searchBook?.toRaw()['futureSearchField'],
  original.searchBook?.toRaw()['futureSearchField'],
);
```

- [ ] **Step 2: Verify RED**

```bash
flutter test test/features/sources/presentation/source_editor_test.dart
```

Expected: existing tests pass; new searchBook integration tests fail because SourceEditor does not compose the new editor.

- [ ] **Step 3: Extract current four-field presentation**

Create `SourceBasicEditorSection` without moving session state out of `SourceEditor`:

```dart
final class SourceBasicEditorSection extends StatelessWidget {
  const SourceBasicEditorSection({
    super.key,
    required this.nameController,
    required this.urlController,
    required this.weightController,
    required this.enabled,
    required this.onEnabledChanged,
  });

  final TextEditingController nameController;
  final TextEditingController urlController;
  final TextEditingController weightController;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
}
```

Keep existing stable keys and exact validation messages (`书源名称不能为空`, `权重必须是整数`).

- [ ] **Step 4: Add searchBook draft to the editor session**

State adds:

```dart
late SourceSearchBookDraft _searchBookDraft;
```

`_loadSource` initializes both drafts:

```dart
void _loadSource(StoredSource source) {
  final basic = SourceEditorDraft.fromDocument(source.document);
  _nameController.text = basic.sourceName;
  _urlController.text = basic.sourceUrl;
  _weightController.text = basic.weight;
  _enabled = basic.enabled;
  _searchBookDraft = SourceSearchBookDraft.fromDocument(source.document.searchBook);
}
```

Mount the search editor with source identity at the composition boundary:

```dart
SearchBookEditor(
  key: ValueKey<int>(widget.source.id),
  value: _searchBookDraft,
  onChanged: (value) {
    setState(() => _searchBookDraft = value);
  },
),
```

This forces a fresh presentation subtree when source id changes while Domain/Draft remain UI-agnostic.

- [ ] **Step 5: Keep one atomic save**

After the existing basic draft apply:

```dart
final basicDraft = SourceEditorDraft(
  sourceName: _nameController.text,
  sourceUrl: _urlController.text,
  enabled: _enabled,
  weight: _weightController.text,
);
final withBasicFields = basicDraft.applyTo(widget.source.document);
final document = _searchBookDraft.applyTo(withBasicFields);
await widget.onSave(document);
```

`FormState.validate()` runs before `_saving = true`; invalid structured `moreKeys` therefore never calls `onSave` and never enters repository/controller code.

Keep the existing `try/finally` duplicate-submit protection unchanged.

- [ ] **Step 6: Verify focused GREEN**

```bash
flutter test test/features/sources/presentation/source_editor_test.dart
flutter test test/features/sources/presentation/source_search_book_editor_test.dart
flutter test test/features/sources/presentation/source_search_book_draft_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/sources/presentation/source_basic_editor_section.dart \
  app/lib/features/sources/presentation/source_editor.dart \
  app/test/features/sources/presentation/source_editor_test.dart
git commit -m "feat: integrate search book rule editing"
```

---

### Task 6: Real SQLite rule-editor regression（强模型）

**Files:**
- Create: `app/test/features/sources/presentation/source_rule_editor_integration_test.dart`

**Purpose:** prove the full existing production chain persists searchBook edits without introducing a fake Controller/Repository implementation.

- [ ] **Step 1: Write integration test using memory SQLite**

Test setup:

```dart
final database = AppDatabase(NativeDatabase.memory());
addTearDown(database.close);
final repository = SqliteSourceRepository(
  database,
  now: () => DateTime.utc(2026, 9, 2, 13),
);

final id = await repository.insertSource(
  platform: 'StandarReader',
  document: SourceDocument.fromRaw(<String, Object?>{
    'sourceName': '集成书源',
    'sourceUrl': 'https://example.com',
    'enable': '1',
    'weight': '1000',
    'futureTop': <String, Object?>{'keep': true},
    'searchBook': <String, Object?>{
      'actionID': 'searchBook',
      'parserID': 'DOM',
      'requestInfo': '/old-search',
      'bookName': './/old-name',
      'futureSearchField': <String, Object?>{'keep': 42},
    },
  }),
);
```

Pump a 1200x800 `SourcePage` under `ProviderScope` with `sourceRepositoryProvider.overrideWithValue(repository)`.

Then:

```dart
await tester.tap(find.byKey(Key('source-list-tile-$id')));
await tester.pumpAndSettle();
await tester.enterText(
  find.byKey(const Key('search-book-request-info')),
  '/new-search?q=%@keyWord',
);
await tester.enterText(
  find.byKey(const Key('search-book-book-name')),
  './/h2/text()',
);
await tester.tap(find.byKey(const Key('source-editor-save')));
await tester.pumpAndSettle();
```

Persisted assertions:

```dart
final stored = await repository.getSource(id);
expect(stored?.document.searchBook?.action.requestInfo, '/new-search?q=%@keyWord');
expect(stored?.document.searchBook?.bookName, './/h2/text()');
expect(stored?.document.toRaw()['futureTop'], <String, Object?>{'keep': true});
expect(
  stored?.document.searchBook?.toRaw()['futureSearchField'],
  <String, Object?>{'keep': 42},
);
expect(find.text('已保存'), findsOneWidget);
```

Also assert the mounted editor shows the reloaded new values after `Controller.reload()` completes.

- [ ] **Step 2: Verify test**

```bash
flutter test test/features/sources/presentation/source_rule_editor_integration_test.dart
```

Expected: PASS after Tasks 1-5. If it fails, use systematic-debugging rather than weakening assertions.

- [ ] **Step 3: Run final acceptance suite**

From `app/`:

```bash
flutter pub get
dart run build_runner build
flutter test test/features/sources/domain/source_action_document_test.dart
flutter test test/features/sources/domain/source_search_book_document_test.dart
flutter test test/features/sources/presentation/source_search_book_draft_test.dart
flutter test test/features/sources/presentation/source_search_book_editor_test.dart
flutter test test/features/sources/presentation/source_editor_test.dart
flutter test test/features/sources/presentation/source_rule_editor_integration_test.dart
flutter analyze
flutter test
git diff --check
```

Expected: every command GREEN; no analyzer issues.

- [ ] **Step 4: Commit**

```bash
git add app/test/features/sources/presentation/source_rule_editor_integration_test.dart
git commit -m "test: cover search book sqlite editing flow"
```

---

## Completion Review

Before declaring the feature complete, verify all of the following against the spec:

- `SourceActionDocument` exists and is not searchBook-specific.
- unknown top-level and action fields survive.
- malformed non-Map `searchBook` remains untouched unless explicitly replaced.
- empty missing searchBook is not created by view/save alone.
- existing metadata-only searchBook is not deleted.
- absent fields remain absent when the user did not edit them.
- unknown enum round-trips and appears in the UI.
- structured `moreKeys` retains Map/List representation when untouched.
- invalid structured `moreKeys` is blocked locally.
- `SearchBookEditor` has no Riverpod/Repository/raw-Map dependency.
- SourceEditor still has exactly one save action and existing save-failure behavior remains intact.
- real SQLite regression proves save -> reload -> persisted value.
- no `bookDetail/chapterList/chapterContent` UI or Draft was added.
- no dynamic schema/form engine was introduced.
