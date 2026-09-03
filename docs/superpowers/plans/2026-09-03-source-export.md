# Source Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 Source Workbench v0.1 导出闭环，支持把已保存的当前书源或全部 `StandarReader` 书源导出为 JSON / XBS，并通过系统保存对话框落盘。

**Architecture:** `SourceExportService` 只从 `SourceRepository` 读取持久化事实，复用 `encodeSourceJson()` 与 `encodeXbs()` 构建 `SourceExportPayload`。`SourceFileSaver` 隔离系统保存副作用，默认 adapter 使用 `file_picker 12.1.3` 的 `FilePicker.saveFile(fileName:, bytes:, mimeType:)`。`SourcePage` 只负责选择范围/格式、调用 service + saver、映射成功/取消/错误提示；`SourceEditor` 未保存 Draft 永远不进入导出链。

**Tech Stack:** Flutter 3.47.x、Dart 3.13.x、Riverpod 3.4.2、Drift 2.34.x、file_picker 12.1.3、flutter_test。

**Spec:** `docs/superpowers/specs/2026-09-03-source-export-design.md`

## Global Constraints

- 当前导出必须调用 `SourceRepository.getSource(id)`，不得使用 SourcePage 列表缓存代替。
- 全部导出只包含 `platform == 'StandarReader'`。
- `StoredSource.platform` 不写入 raw JSON。
- 单个书源仍输出 JSON 数组。
- JSON 只使用现有 `encodeSourceJson()`，UTF-8、无 BOM、不 pretty-print。
- XBS 固定为 `encodeSourceJson()` → UTF-8 bytes → `encodeXbs()`。
- 当前文件名 `<sourceName>.json/.xbs`；全部固定 `source-reader-export.json/.xbs`。
- 文件名 `/ \\ : * ? " < > |` 与控制字符替换为 `_`，尾部空格和 `.` 去除，空结果回退 `source`。
- MIME：JSON=`application/json`；XBS=`application/octet-stream`。
- 用户取消格式选择或系统保存都不是错误，不显示失败 Snackbar。
- `SourceController` 不新增导出职责；`SourceEditor` 不新增导出 callback，不暴露 Draft。
- 不实现 dirty tracking、多选、自动目录、分享、ZIP、非 `StandarReader` 导出、Source Tester 或 Reader。
- 新增/修改业务注释优先中文。
- 每个任务严格 RED → 验证预期失败 → GREEN → focused tests → analyze → 回归 → commit。

## File Map

```text
app/lib/features/sources/
├─ application/
│  ├─ source_export.dart
│  ├─ source_file_saver.dart
│  └─ source_providers.dart
├─ data/
│  └─ file_picker_source_file_saver.dart
└─ presentation/
   ├─ source_export_menu.dart
   └─ source_page.dart

app/test/features/sources/
├─ application/
│  ├─ source_export_test.dart
│  └─ source_export_provider_test.dart
└─ presentation/
   ├─ source_export_menu_test.dart
   ├─ source_page_test.dart
   └─ source_export_integration_test.dart

docs/omniroute/
└─ OR-006-source-export-menu.md
```

---

### Task 1: `SourceExportService` 与导出模型（强模型）

**Files:**
- Create: `app/lib/features/sources/application/source_export.dart`
- Create: `app/test/features/sources/application/source_export_test.dart`

**Consumes:**

```dart
Future<List<StoredSource>> SourceRepository.listSources();
Future<StoredSource?> SourceRepository.getSource(int id);
String encodeSourceJson(Iterable<SourceDocument> sources);
Uint8List encodeXbs(Uint8List sourceBytes);
```

**Produces:**

```dart
enum SourceExportFormat { json, xbs }
enum SourceExportScope { current, all }
enum SourceExportFailureReason {
  notFound,
  unsupportedPlatform,
  empty,
  encodingFailed,
}

final class SourceExportException implements Exception {
  const SourceExportException(this.reason, {this.cause});
  final SourceExportFailureReason reason;
  final Object? cause;
}

final class SourceExportPayload {
  const SourceExportPayload({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
    required this.exportedCount,
  });
  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  final int exportedCount;
}

String sanitizeSourceFileBaseName(String input);

final class SourceExportService {
  SourceExportService(this._repository);
  Future<SourceExportPayload> buildCurrent({
    required int id,
    required SourceExportFormat format,
  });
  Future<SourceExportPayload> buildAll({
    required SourceExportFormat format,
  });
}
```

- [ ] **Step 1: Write the RED test file with an explicit fake Repository**

Use a fake whose current-read and list-read data are independent, so tests can prove `buildCurrent` really calls `getSource`:

```dart
final class _FakeSourceRepository implements SourceRepository {
  _FakeSourceRepository({
    Map<int, StoredSource>? getById,
    List<StoredSource>? listed,
  })  : getById = getById ?? <int, StoredSource>{},
        listed = listed ?? <StoredSource>[];

  final Map<int, StoredSource> getById;
  final List<StoredSource> listed;
  final List<int> getCalls = <int>[];
  int listCalls = 0;

  @override
  Future<StoredSource?> getSource(int id) async {
    getCalls.add(id);
    return getById[id];
  }

  @override
  Future<List<StoredSource>> listSources() async {
    listCalls += 1;
    return List<StoredSource>.of(listed);
  }

  @override
  Future<int> insertSource({
    required String platform,
    required SourceDocument document,
  }) => throw UnimplementedError();

  @override
  Future<List<int>> insertSources({
    required String platform,
    required List<SourceDocument> documents,
  }) => throw UnimplementedError();

  @override
  Future<void> updateSource(int id, SourceDocument document) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}
```

Add a helper that creates `StoredSource` from raw JSON and an explicit platform.

- [ ] **Step 2: Add RED tests for current export and JSON array semantics**

```dart
test('buildCurrent 重新按 id 读取 Repository 并输出单元素 JSON 数组', () async {
  final stored = _storedSource(
    id: 7,
    platform: 'StandarReader',
    raw: <String, Object?>{
      'sourceName': '测试书源',
      'futureTop': <String, Object?>{'keep': true},
    },
  );
  final repository = _FakeSourceRepository(
    getById: <int, StoredSource>{7: stored},
    listed: <StoredSource>[
      _storedSource(
        id: 7,
        platform: 'StandarReader',
        raw: <String, Object?>{'sourceName': '列表旧值'},
      ),
    ],
  );

  final payload = await SourceExportService(repository).buildCurrent(
    id: 7,
    format: SourceExportFormat.json,
  );

  expect(repository.getCalls, <int>[7]);
  expect(repository.listCalls, 0);
  expect(payload.fileName, '测试书源.json');
  expect(payload.mimeType, 'application/json');
  expect(payload.exportedCount, 1);

  final raw = jsonDecode(utf8.decode(payload.bytes));
  expect(raw, isA<List<Object?>>());
  expect(raw, hasLength(1));

  final decoded = decodeSourceJson(utf8.decode(payload.bytes));
  expect(decoded.single.sourceName, '测试书源');
  expect(
    decoded.single.toRaw()['futureTop'],
    <String, Object?>{'keep': true},
  );
});
```

- [ ] **Step 3: Add RED tests for structured failures**

Use `await expectLater` because the service methods fail asynchronously:

```dart
await expectLater(
  service.buildCurrent(id: 404, format: SourceExportFormat.json),
  throwsA(
    isA<SourceExportException>().having(
      (error) => error.reason,
      'reason',
      SourceExportFailureReason.notFound,
    ),
  ),
);
```

Add the same pattern for:

```text
current platform != StandarReader -> unsupportedPlatform
buildAll after platform filtering is empty -> empty
```

For `encodingFailed`, configure `getById[1]` with:

```dart
SourceDocument.fromRaw(<String, Object?>{
  'sourceName': '无法编码',
  'futureValue': DateTime.utc(2026, 9, 3),
})
```

Then assert:

```dart
await expectLater(
  service.buildCurrent(id: 1, format: SourceExportFormat.json),
  throwsA(
    isA<SourceExportException>().having(
      (error) => error.reason,
      'reason',
      SourceExportFailureReason.encodingFailed,
    ),
  ),
);
```

Repository read errors are a separate concern and must not be wrapped as `encodingFailed`.

- [ ] **Step 4: Add RED tests for all-export filtering and XBS round-trip**

Configure list order `StandarReader A`, `OtherReader B`, `StandarReader C`. Assert decoded JSON names are exactly `A, C`, count is 2, and A/C unknown raw fields survive.

For XBS:

```dart
final payload = await service.buildAll(format: SourceExportFormat.xbs);
expect(payload.fileName, 'source-reader-export.xbs');
expect(payload.mimeType, 'application/octet-stream');

final plainBytes = decodeXbs(payload.bytes);
final decoded = decodeSourceJson(utf8.decode(plainBytes));
expect(decoded.map((item) => item.sourceName).toList(), <String?>['A', 'C']);
```

- [ ] **Step 5: Add RED filename tests**

Directly test the pure sanitizer:

```dart
expect(
  sanitizeSourceFileBaseName('A/B:C*D?E"F<G>H|I'),
  'A_B_C_D_E_F_G_H_I',
);
expect(sanitizeSourceFileBaseName('name...   '), 'name');
expect(sanitizeSourceFileBaseName('...   '), 'source');
expect(sanitizeSourceFileBaseName('\u0001\u0002'), '__');
```

Also verify current `.xbs` extension and all fixed `.json/.xbs` names through service payloads.

- [ ] **Step 6: Verify RED**

```bash
flutter test test/features/sources/application/source_export_test.dart
```

Expected: FAIL only because `source_export.dart` and its public symbols do not exist.

- [ ] **Step 7: Implement minimal production code**

Use this exact structure:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:source_reader/features/sources/codec/source_json_codec.dart';
import 'package:source_reader/features/sources/codec/xbs_codec.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';

const String _standarReaderPlatform = 'StandarReader';

enum SourceExportFormat { json, xbs }
enum SourceExportScope { current, all }
enum SourceExportFailureReason {
  notFound,
  unsupportedPlatform,
  empty,
  encodingFailed,
}

final class SourceExportException implements Exception {
  const SourceExportException(this.reason, {this.cause});
  final SourceExportFailureReason reason;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'SourceExportException($reason)'
      : 'SourceExportException($reason, cause: $cause)';
}

final class SourceExportPayload {
  const SourceExportPayload({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
    required this.exportedCount,
  });
  final String fileName;
  final Uint8List bytes;
  final String mimeType;
  final int exportedCount;
}

String sanitizeSourceFileBaseName(String input) {
  final replaced = input.replaceAll(
    RegExp(r'[\/\\:*?"<>|\x00-\x1F\x7F]'),
    '_',
  );
  final withoutTrailing = replaced.replaceFirst(RegExp(r'[ .]+$'), '');
  return withoutTrailing.isEmpty ? 'source' : withoutTrailing;
}

final class SourceExportService {
  SourceExportService(this._repository);
  final SourceRepository _repository;

  Future<SourceExportPayload> buildCurrent({
    required int id,
    required SourceExportFormat format,
  }) async {
    final source = await _repository.getSource(id);
    if (source == null) {
      throw const SourceExportException(SourceExportFailureReason.notFound);
    }
    if (source.platform != _standarReaderPlatform) {
      throw const SourceExportException(
        SourceExportFailureReason.unsupportedPlatform,
      );
    }
    return _buildPayload(
      sources: <StoredSource>[source],
      format: format,
      baseName: sanitizeSourceFileBaseName(source.document.sourceName ?? ''),
    );
  }

  Future<SourceExportPayload> buildAll({
    required SourceExportFormat format,
  }) async {
    final sources = (await _repository.listSources())
        .where((source) => source.platform == _standarReaderPlatform)
        .toList(growable: false);
    if (sources.isEmpty) {
      throw const SourceExportException(SourceExportFailureReason.empty);
    }
    return _buildPayload(
      sources: sources,
      format: format,
      baseName: 'source-reader-export',
    );
  }

  SourceExportPayload _buildPayload({
    required List<StoredSource> sources,
    required SourceExportFormat format,
    required String baseName,
  }) {
    try {
      final jsonText = encodeSourceJson(
        sources.map((source) => source.document),
      );
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonText));
      return switch (format) {
        SourceExportFormat.json => SourceExportPayload(
            fileName: '$baseName.json',
            bytes: jsonBytes,
            mimeType: 'application/json',
            exportedCount: sources.length,
          ),
        SourceExportFormat.xbs => SourceExportPayload(
            fileName: '$baseName.xbs',
            bytes: encodeXbs(jsonBytes),
            mimeType: 'application/octet-stream',
            exportedCount: sources.length,
          ),
      };
    } catch (error) {
      throw SourceExportException(
        SourceExportFailureReason.encodingFailed,
        cause: error,
      );
    }
  }
}
```

- [ ] **Step 8: Verify GREEN and commit**

```bash
flutter test test/features/sources/application/source_export_test.dart
flutter test test/features/sources/codec/source_json_codec_test.dart
flutter test test/features/sources/codec/xbs_codec_test.dart
flutter analyze
git add app/lib/features/sources/application/source_export.dart \
  app/test/features/sources/application/source_export_test.dart
git commit -m "feat: add source export service"
```

---

### Task 2: File saver boundary、adapter 与 Providers（强模型）

**Files:**
- Create: `app/lib/features/sources/application/source_file_saver.dart`
- Create: `app/lib/features/sources/data/file_picker_source_file_saver.dart`
- Modify: `app/lib/features/sources/application/source_providers.dart`
- Create: `app/test/features/sources/application/source_export_provider_test.dart`

**Produces:**

```dart
abstract interface class SourceFileSaver {
  Future<bool> save(SourceExportPayload payload);
}

final sourceExportServiceProvider = Provider<SourceExportService>(...);
final sourceFileSaverProvider = Provider<SourceFileSaver>(...);
```

- [ ] **Step 1: Write RED provider tests**

`source_export_provider_test.dart` must use a fake Repository and prove the export service provider consumes the overridden repository:

```dart
test('sourceExportServiceProvider 使用 sourceRepositoryProvider', () async {
  final repository = _ProviderTestRepository(
    <StoredSource>[_storedSource(id: 1, name: 'Provider 书源')],
  );
  final container = ProviderContainer(
    overrides: [
      sourceRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  final payload = await container
      .read(sourceExportServiceProvider)
      .buildAll(format: SourceExportFormat.json);

  expect(repository.listCalls, 1);
  expect(payload.exportedCount, 1);
});
```

Also compile/wire the saver without invoking a native dialog:

```dart
test('sourceFileSaverProvider 默认提供 SourceFileSaver', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  expect(container.read(sourceFileSaverProvider), isA<SourceFileSaver>());
});
```

- [ ] **Step 2: Verify RED**

```bash
flutter test test/features/sources/application/source_export_provider_test.dart
```

Expected: FAIL because the new saver/provider symbols do not exist.

- [ ] **Step 3: Implement saver boundary and `file_picker` adapter**

`source_file_saver.dart`:

```dart
import 'package:source_reader/features/sources/application/source_export.dart';

abstract interface class SourceFileSaver {
  Future<bool> save(SourceExportPayload payload);
}
```

`file_picker_source_file_saver.dart`:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:source_reader/features/sources/application/source_export.dart';
import 'package:source_reader/features/sources/application/source_file_saver.dart';

/// 使用系统保存对话框保存已完成编码的书源 payload。
final class FilePickerSourceFileSaver implements SourceFileSaver {
  @override
  Future<bool> save(SourceExportPayload payload) async {
    final uri = await FilePicker.saveFile(
      fileName: payload.fileName,
      bytes: payload.bytes,
      mimeType: payload.mimeType,
    );
    return uri != null;
  }
}
```

For file_picker 12.1.3, `saveFile` returns `Future<Uri?>`; `null` means user cancellation.

- [ ] **Step 4: Wire providers**

Add to `source_providers.dart`:

```dart
final sourceExportServiceProvider = Provider<SourceExportService>((ref) {
  return SourceExportService(ref.watch(sourceRepositoryProvider));
});

final sourceFileSaverProvider = Provider<SourceFileSaver>((ref) {
  return FilePickerSourceFileSaver();
});
```

Do not touch `SourceController`.

- [ ] **Step 5: Verify GREEN and commit**

```bash
flutter test test/features/sources/application/source_export_provider_test.dart
flutter test test/features/sources/application/source_export_test.dart
flutter analyze
git add app/lib/features/sources/application/source_file_saver.dart \
  app/lib/features/sources/data/file_picker_source_file_saver.dart \
  app/lib/features/sources/application/source_providers.dart \
  app/test/features/sources/application/source_export_provider_test.dart
git commit -m "feat: add source export file saver"
```

---

### Task 3: OR-006 pure export menu + format dialog（OmniRoute）

**Strong-model work order:**
- Create: `docs/omniroute/OR-006-source-export-menu.md`

**OmniRoute allowed files only:**
- Create: `app/lib/features/sources/presentation/source_export_menu.dart`
- Create: `app/test/features/sources/presentation/source_export_menu_test.dart`

**Forbidden:** SourcePage, SourceEditor, Controller, Providers, Repository, Database, codec, `source_export.dart`, saver boundary/adapter, pubspec.

**Consumes:**

```dart
enum SourceExportFormat { json, xbs }
enum SourceExportScope { current, all }
```

**Produces:**

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

Stable keys:

```text
source-export-menu
source-export-current
source-export-all
source-export-format-dialog
source-export-format-json
source-export-format-xbs
source-export-format-cancel
```

- [ ] **Step 1: Strong model writes and commits OR-006**

The work order must explicitly require:

```text
A. current remains visible but disabled when canExportCurrent=false
B. all remains enabled
C. choosing current/all opens JSON/XBS/取消 dialog
D. JSON callback is exact scope + SourceExportFormat.json once
E. XBS callback is exact scope + SourceExportFormat.xbs once
F. cancel does not call callback
G. no Riverpod, Repository, saver, Snackbar, persistent state or default auto-selection
H. tests use stable keys and behavior, not container styling
```

Commit the work order:

```bash
git add docs/omniroute/OR-006-source-export-menu.md
git commit -m "docs: add source export menu task"
```

- [ ] **Step 2: OmniRoute executes strict RED → GREEN**

Required widget tests:

```text
A. current disabled / all enabled
B. current enabled
C. current + JSON callback
D. current + XBS callback
E. all + JSON callback
F. dialog cancel is silent
```

RED command:

```bash
flutter test test/features/sources/presentation/source_export_menu_test.dart
```

Expected RED: editor file missing / symbols undefined, no unrelated failure.

Minimal implementation may use `PopupMenuButton<SourceExportScope>` and `showDialog<SourceExportFormat>`. Only call:

```dart
await onExport(scope, format);
```

when returned `format != null`.

- [ ] **Step 3: OmniRoute verifies, commits, pushes, returns SHA**

```bash
flutter test test/features/sources/presentation/source_export_menu_test.dart
flutter analyze
flutter test
git diff --check
git status --short
git add app/lib/features/sources/presentation/source_export_menu.dart \
  app/test/features/sources/presentation/source_export_menu_test.dart
git commit -m "feat: add source export menu"
git push origin revival/flutter-workbench
```

Strong model must review actual diff + CI before Task 4.

---

### Task 4: Integrate export into `SourcePage`（强模型）

**Files:**
- Modify: `app/lib/features/sources/presentation/source_page.dart`
- Modify: `app/test/features/sources/presentation/source_page_test.dart`

- [ ] **Step 1: Upgrade SourcePage test fakes to support current-read races**

`TestSourceRepository` must let `getSource` be independently configured from `listSources`:

```dart
final Future<StoredSource?> Function(int id)? onGetSource;
final List<int> getCalls = <int>[];

@override
Future<StoredSource?> getSource(int id) async {
  getCalls.add(id);
  final handler = onGetSource;
  if (handler != null) {
    return handler(id);
  }
  final currentItems = items;
  if (currentItems == null) {
    return null;
  }
  for (final item in currentItems) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}
```

Update constructors to accept `onGetSource`. Update `_storedSource` helper to accept optional `platform`, defaulting to `StandarReader`.

Add saver fake:

```dart
final class FakeSourceFileSaver implements SourceFileSaver {
  FakeSourceFileSaver({this.result = true, this.error});
  final bool result;
  final Object? error;
  final List<SourceExportPayload> payloads = <SourceExportPayload>[];

  @override
  Future<bool> save(SourceExportPayload payload) async {
    final currentError = error;
    if (currentError != null) {
      throw currentError;
    }
    payloads.add(payload);
    return result;
  }
}
```

Extend `_pumpPage` with `SourceFileSaver? saver` and override `sourceFileSaverProvider` with a fake default; existing import tests must remain unchanged.

- [ ] **Step 2: Write RED export behavior tests**

Drive UI only through Task 3 stable keys. Add exact tests:

```text
1. AppBar shows source-export-menu.
2. no selection -> source-export-current disabled, source-export-all enabled.
3. select id=2 -> current JSON -> getCalls == [2], saver one payload, `.json`, count 1, Snackbar `已导出 1 个书源`.
4. all XBS -> saver payload `.xbs`, MIME application/octet-stream, exportedCount equals StandarReader count.
5. saver result=false -> no `已导出` and no `导出失败` Snackbar.
6. empty StandarReader set -> `没有可导出的书源`.
7. list still contains selected id but onGetSource returns null -> `当前书源已不存在`.
8. selected item platform OtherReader -> `当前书源平台暂不支持导出`.
9. selected item has DateTime unknown raw -> `导出编码失败`.
10. saver throws StateError('disk failed') -> contains `导出失败：Bad state: disk failed`.
```

For test 7, keep the item in `items` so selection is valid, but configure:

```dart
onGetSource: (id) async => null,
```

This is the exact race the service contract must handle.

- [ ] **Step 3: Verify RED**

```bash
flutter test test/features/sources/presentation/source_page_test.dart
```

Expected: existing tests pass; new export tests fail because SourcePage does not mount/use export flow.

- [ ] **Step 4: Mount the pure export menu**

Add to `AppBar.actions` without removing import/reload:

```dart
SourceExportMenu(
  canExportCurrent: selectedId != null,
  onExport: (scope, format) => _exportSource(
    context,
    ref,
    scope: scope,
    format: format,
    selectedId: selectedId,
  ),
),
```

Do not pass `StoredSource`, controllers, Drafts or Editor callbacks.

- [ ] **Step 5: Add export orchestration and structured error mapping**

```dart
Future<void> _exportSource(
  BuildContext context,
  WidgetRef ref, {
  required SourceExportScope scope,
  required SourceExportFormat format,
  required int? selectedId,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final service = ref.read(sourceExportServiceProvider);
    final payload = switch (scope) {
      SourceExportScope.current => await service.buildCurrent(
          id: selectedId!,
          format: format,
        ),
      SourceExportScope.all => await service.buildAll(format: format),
    };
    final saved = await ref.read(sourceFileSaverProvider).save(payload);
    if (!saved || !messenger.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('已导出 ${payload.exportedCount} 个书源')),
    );
  } on SourceExportException catch (error) {
    if (!messenger.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(_exportErrorMessage(error.reason))),
    );
  } catch (error) {
    if (!messenger.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('导出失败：$error')),
    );
  }
}

String _exportErrorMessage(SourceExportFailureReason reason) {
  return switch (reason) {
    SourceExportFailureReason.notFound => '当前书源已不存在',
    SourceExportFailureReason.unsupportedPlatform => '当前书源平台暂不支持导出',
    SourceExportFailureReason.empty => '没有可导出的书源',
    SourceExportFailureReason.encodingFailed => '导出编码失败',
  };
}
```

- [ ] **Step 6: Verify GREEN and commit**

```bash
flutter test test/features/sources/presentation/source_page_test.dart
flutter test test/features/sources/presentation/source_export_menu_test.dart
flutter test test/features/sources/presentation/source_editor_test.dart
flutter analyze
git add app/lib/features/sources/presentation/source_page.dart \
  app/test/features/sources/presentation/source_page_test.dart
git commit -m "feat: integrate source export flow"
```

---

### Task 5: Real SQLite export regressions + final acceptance（强模型）

**Files:**
- Create: `app/test/features/sources/presentation/source_export_integration_test.dart`

- [ ] **Step 1: Write real SQLite all-export filtering regression**

```dart
final database = AppDatabase(NativeDatabase.memory());
addTearDown(database.close);
final repository = SqliteSourceRepository(
  database,
  now: () => DateTime.utc(2026, 9, 3, 12),
);

await repository.insertSource(
  platform: 'StandarReader',
  document: SourceDocument.fromRaw(<String, Object?>{
    'sourceName': 'A',
    'futureTop': <String, Object?>{'keep': true},
  }),
);
await repository.insertSource(
  platform: 'OtherReader',
  document: SourceDocument.fromRaw(<String, Object?>{
    'sourceName': 'B',
    'otherOnly': true,
  }),
);

final payload = await SourceExportService(repository).buildAll(
  format: SourceExportFormat.json,
);
final decoded = decodeSourceJson(utf8.decode(payload.bytes));
expect(decoded, hasLength(1));
expect(decoded.single.sourceName, 'A');
expect(
  decoded.single.toRaw()['futureTop'],
  <String, Object?>{'keep': true},
);
expect(payload.exportedCount, 1);
```

- [ ] **Step 2: Write real SourcePage regression proving unsaved Draft exclusion**

Insert saved state:

```dart
final id = await repository.insertSource(
  platform: 'StandarReader',
  document: SourceDocument.fromRaw(<String, Object?>{
    'sourceName': '数据库旧名称',
    'sourceUrl': 'https://example.com',
    'enable': '1',
    'weight': '1000',
    'searchBook': <String, Object?>{
      'actionID': 'searchBook',
      'parserID': 'DOM',
      'requestInfo': '/saved-search',
    },
  }),
);
```

Pump 1200x800 real `SourcePage` with:

```dart
sourceRepositoryProvider.overrideWithValue(repository),
sourceFileSaverProvider.overrideWithValue(capturingSaver),
```

Then:

```text
select source-list-tile-$id
edit source-editor-name -> 未保存新名称
edit search-book-request-info -> /unsaved-search
DO NOT tap source-editor-save
open source-export-menu
choose source-export-current
choose source-export-format-json
```

Decode captured payload and assert persisted values:

```dart
final decoded = decodeSourceJson(
  utf8.decode(capturingSaver.payloads.single.bytes),
);
expect(decoded.single.sourceName, '数据库旧名称');
expect(
  decoded.single.searchBook?.action.requestInfo,
  '/saved-search',
);
```

Also assert the mounted Editor still shows `未保存新名称` and `/unsaved-search` after export. Export must neither save nor reset the Draft.

- [ ] **Step 3: Focused integration verification**

```bash
flutter test test/features/sources/presentation/source_export_integration_test.dart
```

Expected: PASS. On failure, invoke `superpowers:systematic-debugging`; do not weaken persisted-vs-draft assertions.

- [ ] **Step 4: Final acceptance suite**

From `app/`:

```bash
flutter pub get
dart run build_runner build
flutter test test/features/sources/application/source_export_test.dart
flutter test test/features/sources/application/source_export_provider_test.dart
flutter test test/features/sources/presentation/source_export_menu_test.dart
flutter test test/features/sources/presentation/source_page_test.dart
flutter test test/features/sources/presentation/source_export_integration_test.dart
flutter analyze
flutter test
git diff --check
```

Expected: every command exits 0; analyzer reports no issues; full suite has zero failures; `git diff --check` has no output.

- [ ] **Step 5: Commit integration regression**

```bash
git add app/test/features/sources/presentation/source_export_integration_test.dart
git commit -m "test: cover source export sqlite flow"
```

---

## Completion Review

Before declaring completion, verify all of these against the spec:

- `SourceExportService` is outside `SourceController`.
- current export reads `getSource(id)` and never accepts a Presentation `StoredSource` as truth.
- all export filters exactly `StandarReader`.
- platform metadata is not injected into raw JSON.
- single export is still a JSON array.
- JSON and XBS round-trip preserve unknown raw fields.
- JSON UTF-8/no BOM/compact behavior remains from existing codec.
- XBS decrypts to the same JSON-array semantics.
- current and all filenames/MIME values are exact.
- sanitizer covers forbidden/control/trailing/empty cases.
- empty all-export generates no payload.
- native saver returns false on canceled `saveFile`.
- format cancel and saver cancel are silent.
- structured business failures map to approved Chinese messages.
- arbitrary saver failures map to `导出失败：<error>`.
- SourcePage has one current/all → JSON/XBS export flow.
- SourceEditor public API is unchanged and Draft remains private.
- real SQLite test proves unsaved Editor changes are excluded.
- no dirty tracking, multi-select, share, non-StandarReader export, Source Tester or Reader work leaked into this phase.

## Execution Handoff

```text
Task 1  strong model: export service
Task 2  strong model: saver boundary + adapter + providers
Task 3  OmniRoute OR-006: pure export menu
Task 4  strong model: SourcePage integration
Task 5  strong model: SQLite regressions + final acceptance
```

At Task 3, strong model first commits `docs/omniroute/OR-006-source-export-menu.md`, then stops for OmniRoute execution. After OmniRoute returns a SHA, strong model reviews the actual diff and CI before Task 4.
