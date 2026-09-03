# Source Export Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成 Source Workbench v0.1 的导出闭环，支持把已保存的当前书源或全部 `StandarReader` 书源导出为 JSON / XBS，并通过系统保存对话框落盘。

**Architecture:** `SourceExportService` 从 `SourceRepository` 重新读取持久化事实，复用现有 `encodeSourceJson()` 与 `encodeXbs()` 生成 `SourceExportPayload`。文件保存通过窄接口 `SourceFileSaver` 隔离，默认 adapter 使用 `file_picker 12.1.3` 的 `FilePicker.saveFile(fileName:, bytes:, mimeType:)`。`SourcePage` 只负责范围/格式交互、调用 service + saver、映射成功/取消/错误提示；未保存的 `SourceEditor` Draft 永远不进入导出链。

**Tech Stack:** Flutter 3.47.x、Dart 3.13.x、Riverpod 3.4.2、Drift 2.34.x、file_picker 12.1.3、flutter_test。

**Spec:** `docs/superpowers/specs/2026-09-03-source-export-design.md`

## Global Constraints

- 只有 Repository 中已经成功保存的状态可以导出。
- “导出当前”必须按数据库 id 调用 `SourceRepository.getSource(id)`，不得使用 SourcePage 列表缓存替代。
- “导出全部”只包含 `platform == 'StandarReader'` 的记录。
- `StoredSource.platform` 是本地元数据，不得写入 raw JSON。
- 单个书源导出仍固定使用 JSON 数组协议。
- JSON 使用现有 `encodeSourceJson()`，UTF-8、无 BOM、不 pretty-print。
- XBS 必须执行 `encodeSourceJson()` → UTF-8 bytes → `encodeXbs()`，不得维护第二套内容协议。
- 当前书源默认文件名 `<sourceName>.json/.xbs`；全部固定 `source-reader-export.json/.xbs`。
- 当前书源文件名中 `/ \\ : * ? " < > |` 与控制字符替换为 `_`，尾部空格和 `.` 去除，结果为空时回退 `source`。
- JSON MIME 为 `application/json`；XBS MIME 为 `application/octet-stream`。
- 用户取消格式对话框或系统保存对话框都属于正常流程，不显示失败。
- `SourceController` 不新增导出职责。
- `SourceEditor` 不新增导出 callback，不暴露 Draft。
- 不实现 dirty-state tracking、多选导出、自动目录、分享、ZIP、非 `StandarReader` 导出或 Source Tester。
- 新增/修改业务注释优先中文。
- 每个任务严格 RED → 验证失败原因 → GREEN → focused test → `flutter analyze` → 相关回归 → commit。

---

## File Structure

本轮最终目标文件如下：

```text
app/lib/features/sources/
├─ application/
│  ├─ source_export.dart                 # 导出格式、范围、payload、结构化错误、导出 service、文件名清理
│  ├─ source_file_saver.dart             # 文件保存窄接口
│  └─ source_providers.dart              # 增加 export service / saver provider
├─ data/
│  └─ file_picker_source_file_saver.dart # file_picker 保存 adapter
└─ presentation/
   ├─ source_export_menu.dart            # 纯范围 + 格式选择 UI
   └─ source_page.dart                   # 调用 export service + saver，映射提示

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

职责约束：

- `source_export.dart` 不依赖 Flutter Widget、Riverpod、file_picker、SQLite 实现。
- `source_file_saver.dart` 只依赖 `SourceExportPayload`。
- `file_picker_source_file_saver.dart` 不知道 Repository、scope、format 或 Snackbar。
- `source_export_menu.dart` 不读 Riverpod，不读 Repository，不直接保存文件。
- `source_page.dart` 不编码 JSON/XBS，不读 Editor Draft。

---

### Task 1: `SourceExportService` 与结构化导出模型（强模型）

**Files:**
- Create: `app/lib/features/sources/application/source_export.dart`
- Create: `app/test/features/sources/application/source_export_test.dart`

**Interfaces:**

- Consumes:

```dart
Future<List<StoredSource>> SourceRepository.listSources();
Future<StoredSource?> SourceRepository.getSource(int id);
String encodeSourceJson(Iterable<SourceDocument> sources);
Uint8List encodeXbs(Uint8List sourceBytes);
```

- Produces:

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

- [ ] **Step 1: Write RED tests for current JSON export and persisted read semantics**

Create `source_export_test.dart` with a focused fake Repository that records `getSource` and `listSources` calls.

Representative test:

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
  );
  final service = SourceExportService(repository);

  final payload = await service.buildCurrent(
    id: 7,
    format: SourceExportFormat.json,
  );

  expect(repository.getCalls, <int>[7]);
  expect(repository.listCalls, 0);
  expect(payload.fileName, '测试书源.json');
  expect(payload.mimeType, 'application/json');
  expect(payload.exportedCount, 1);

  final decoded = decodeSourceJson(utf8.decode(payload.bytes));
  expect(decoded, hasLength(1));
  expect(decoded.single.sourceName, '测试书源');
  expect(
    decoded.single.toRaw()['futureTop'],
    <String, Object?>{'keep': true},
  );
});
```

Also assert the decoded top level is an array by checking:

```dart
final raw = jsonDecode(utf8.decode(payload.bytes));
expect(raw, isA<List<Object?>>());
expect(raw, hasLength(1));
```

- [ ] **Step 2: Add RED tests for errors, filtering, XBS and filenames**

Add exact behavior tests:

```text
1. current id missing -> SourceExportFailureReason.notFound
2. current platform != StandarReader -> unsupportedPlatform
3. buildAll(json) filters out non-StandarReader and preserves order
4. buildAll with no StandarReader -> empty
5. JSON round-trip preserves unknown raw
6. XBS round-trip through decodeXbs + utf8 + decodeSourceJson preserves raw
7. exportedCount equals exported document count
8. current name `A/B:C*D?E"F<G>H|I` -> `A_B_C_D_E_F_G_H_I.json`
9. trailing spaces/dots are removed before extension
10. only invalid/trailing characters becoming empty -> `source.json`
11. all JSON filename is source-reader-export.json
12. all XBS filename is source-reader-export.xbs
13. invalid JSON-encodable raw value wraps as encodingFailed
```

For the encoding failure test, use a persisted-looking `SourceDocument` whose unknown raw field contains `DateTime.utc(2026, 9, 3)`; `jsonEncode` must fail and the service must surface:

```dart
expect(
  () => service.buildCurrent(id: 1, format: SourceExportFormat.json),
  throwsA(
    isA<SourceExportException>().having(
      (error) => error.reason,
      'reason',
      SourceExportFailureReason.encodingFailed,
    ),
  ),
);
```

- [ ] **Step 3: Verify RED**

Run from `app/`:

```bash
flutter test test/features/sources/application/source_export_test.dart
```

Expected: FAIL because `source_export.dart` and its public types do not exist. There must be no unrelated existing-test failure.

- [ ] **Step 4: Implement the minimal export model and service**

`source_export.dart` should follow this structure:

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
```

`SourceExportService` implementation rules:

```dart
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

    final baseName = sanitizeSourceFileBaseName(
      source.document.sourceName ?? '',
    );
    return _buildPayload(
      sources: <StoredSource>[source],
      format: format,
      baseName: baseName,
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

Do not catch Repository read errors as `encodingFailed`; only the encoding block may wrap errors.

- [ ] **Step 5: Verify GREEN and regressions**

```bash
flutter test test/features/sources/application/source_export_test.dart
flutter test test/features/sources/codec/source_json_codec_test.dart
flutter test test/features/sources/codec/xbs_codec_test.dart
flutter analyze
```

Expected: all PASS / no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sources/application/source_export.dart \
  app/test/features/sources/application/source_export_test.dart
git commit -m "feat: add source export service"
```

---

### Task 2: File saver boundary、file_picker adapter 与 Providers（强模型）

**Files:**
- Create: `app/lib/features/sources/application/source_file_saver.dart`
- Create: `app/lib/features/sources/data/file_picker_source_file_saver.dart`
- Modify: `app/lib/features/sources/application/source_providers.dart`
- Create: `app/test/features/sources/application/source_export_provider_test.dart`

**Interfaces consumed:**

```dart
SourceExportService(SourceRepository repository)
SourceExportPayload
sourceRepositoryProvider
```

**Interfaces produced:**

```dart
abstract interface class SourceFileSaver {
  Future<bool> save(SourceExportPayload payload);
}

final class FilePickerSourceFileSaver implements SourceFileSaver {
  @override
  Future<bool> save(SourceExportPayload payload);
}

final sourceExportServiceProvider = Provider<SourceExportService>(...);
final sourceFileSaverProvider = Provider<SourceFileSaver>(...);
```

- [ ] **Step 1: Write RED provider wiring test**

Create `source_export_provider_test.dart` proving the provider graph uses the overridden Repository and exposes the saver boundary.

```dart
test('sourceExportServiceProvider 使用 sourceRepositoryProvider', () async {
  final repository = _ProviderTestRepository(
    <StoredSource>[
      _storedSource(id: 1, name: 'Provider 书源'),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      sourceRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);

  final service = container.read(sourceExportServiceProvider);
  final payload = await service.buildAll(format: SourceExportFormat.json);

  expect(repository.listCalls, 1);
  expect(payload.exportedCount, 1);
});
```

Also verify:

```dart
test('sourceFileSaverProvider 默认提供 SourceFileSaver', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  expect(container.read(sourceFileSaverProvider), isA<SourceFileSaver>());
});
```

The test must not call the real system save dialog.

- [ ] **Step 2: Verify RED**

```bash
flutter test test/features/sources/application/source_export_provider_test.dart
```

Expected: FAIL because `SourceFileSaver`, `sourceExportServiceProvider`, and `sourceFileSaverProvider` do not exist.

- [ ] **Step 3: Implement `SourceFileSaver` and the thin adapter**

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

/// 使用系统原生保存对话框保存已经编码完成的书源 payload。
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

`file_picker 12.1.3` 的该 API 返回 `Future<Uri?>`；`null` 代表用户取消。

- [ ] **Step 4: Wire providers**

Extend `source_providers.dart` with imports for `source_export.dart`, `source_file_saver.dart`, and `file_picker_source_file_saver.dart`, then add:

```dart
/// 只从 Repository 读取已保存书源并构建导出 payload。
final sourceExportServiceProvider = Provider<SourceExportService>((ref) {
  return SourceExportService(ref.watch(sourceRepositoryProvider));
});

/// 系统文件保存边界；Presentation 不直接依赖 file_picker。
final sourceFileSaverProvider = Provider<SourceFileSaver>((ref) {
  return FilePickerSourceFileSaver();
});
```

Do not add export methods to `SourceController`.

- [ ] **Step 5: Verify GREEN**

```bash
flutter test test/features/sources/application/source_export_provider_test.dart
flutter test test/features/sources/application/source_export_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sources/application/source_file_saver.dart \
  app/lib/features/sources/data/file_picker_source_file_saver.dart \
  app/lib/features/sources/application/source_providers.dart \
  app/test/features/sources/application/source_export_provider_test.dart
git commit -m "feat: add source export file saver"
```

---

### Task 3: OR-006 pure export menu + format dialog（OmniRoute）

**Strong-model work order file:**
- Create: `docs/omniroute/OR-006-source-export-menu.md`

**OmniRoute allowed files only:**
- Create: `app/lib/features/sources/presentation/source_export_menu.dart`
- Create: `app/test/features/sources/presentation/source_export_menu_test.dart`

**Forbidden:** SourcePage, SourceEditor, Controller, Provider, Repository, Database, codec, source_export.dart, source_file_saver.dart, data adapters, pubspec.

**Interfaces consumed:**

```dart
enum SourceExportFormat { json, xbs }
enum SourceExportScope { current, all }
```

**Interface produced:**

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

The work order must require all of the following:

- `SourceExportMenu` is pure presentation and never reads Riverpod.
- The first menu contains exactly the semantic actions “导出当前” and “导出全部”.
- `canExportCurrent == false` leaves “导出当前” visible but disabled.
- Selecting either enabled scope opens a small format dialog with JSON / XBS / 取消.
- Canceling the format dialog does not call `onExport`.
- Selecting JSON calls `onExport(scope, SourceExportFormat.json)` exactly once.
- Selecting XBS calls `onExport(scope, SourceExportFormat.xbs)` exactly once.
- No persistent format state, no default format auto-selection, no file saving, no Snackbar.
- Widget tests assert behavior and stable keys, not exact PopupMenu/Dialog implementation class beyond what interaction needs.

Docs commit:

```bash
git add docs/omniroute/OR-006-source-export-menu.md
git commit -m "docs: add source export menu task"
```

- [ ] **Step 2: OmniRoute writes RED widget tests**

Required tests:

```text
A. canExportCurrent=false -> current visible and disabled; all enabled
B. canExportCurrent=true -> current enabled
C. current -> JSON calls onExport(current, json) once
D. current -> XBS calls onExport(current, xbs) once
E. all -> JSON calls onExport(all, json) once
F. cancel format dialog -> callback not called
```

- [ ] **Step 3: OmniRoute verifies RED**

```bash
flutter test test/features/sources/presentation/source_export_menu_test.dart
```

Expected: FAIL because `source_export_menu.dart` does not exist.

- [ ] **Step 4: OmniRoute implements minimal pure widget**

Implementation may use `PopupMenuButton<SourceExportScope>` + `showDialog<SourceExportFormat>`, but must preserve the public interface and keys above.

The format dialog should return only these values:

```dart
SourceExportFormat.json
SourceExportFormat.xbs
null
```

Only after a non-null format is returned may it call:

```dart
await onExport(scope, format);
```

- [ ] **Step 5: OmniRoute verifies and self-commits**

```bash
flutter test test/features/sources/presentation/source_export_menu_test.dart
flutter analyze
flutter test
git diff --check
git status --short
```

All commands must be GREEN. Then:

```bash
git add app/lib/features/sources/presentation/source_export_menu.dart \
  app/test/features/sources/presentation/source_export_menu_test.dart
git commit -m "feat: add source export menu"
git push origin revival/flutter-workbench
```

Return the full commit SHA and test summary for strong-model review.

---

### Task 4: Integrate export flow into `SourcePage`（强模型）

**Files:**
- Modify: `app/lib/features/sources/presentation/source_page.dart`
- Modify: `app/test/features/sources/presentation/source_page_test.dart`

**Interfaces consumed:**

```dart
SourceExportMenu(
  canExportCurrent: bool,
  onExport: Future<void> Function(SourceExportScope, SourceExportFormat),
)

sourceExportServiceProvider
sourceFileSaverProvider
SourceExportException
SourceExportFailureReason
```

**Public behavior produced:**

```text
AppBar export menu
  -> choose current/all
  -> choose JSON/XBS
  -> build payload from saved Repository state
  -> save payload
  -> success / silent cancel / mapped error Snackbar
```

- [ ] **Step 1: Extend the SourcePage test fakes before adding behavior tests**

Modify `TestSourceRepository` so `getSource(id)` can return from configured `items` and records calls:

```dart
final List<int> getCalls = <int>[];

@override
Future<StoredSource?> getSource(int id) async {
  getCalls.add(id);
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

Add a fake saver:

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

Extend `_pumpPage` with optional `SourceFileSaver? saver` and override `sourceFileSaverProvider` with the fake. Keep existing import tests working unchanged.

- [ ] **Step 2: Write RED SourcePage export tests**

Add tests for:

```text
1. AppBar shows export menu.
2. No selection -> current action visible disabled; all action available.
3. Selected id -> current JSON export calls repository.getSource(selectedId), saver once, success says `已导出 1 个书源`.
4. All XBS export calls listSources through service, saver receives .xbs and correct count.
5. Saver returns false -> no success and no failure Snackbar.
6. buildAll with no StandarReader -> `没有可导出的书源`.
7. selected id disappeared before export -> `当前书源已不存在`.
8. selected record platform unsupported -> `当前书源平台暂不支持导出`.
9. encoding failure -> `导出编码失败`.
10. saver throws StateError('disk failed') -> text contains `导出失败：Bad state: disk failed`.
```

Use only the stable menu/dialog keys from Task 3 to drive interactions.

- [ ] **Step 3: Verify RED**

```bash
flutter test test/features/sources/presentation/source_page_test.dart
```

Expected: existing tests PASS; new export tests FAIL because SourcePage does not mount `SourceExportMenu` or invoke export providers.

- [ ] **Step 4: Mount `SourceExportMenu` in the AppBar**

In `SourcePage.build`, add the menu to `appBar.actions` without removing import or reload:

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

Do not pass `StoredSource` or any Editor state into this callback.

- [ ] **Step 5: Implement the export orchestration in SourcePage**

Add a private method with this control flow:

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
```

Map structured failures with an exhaustive switch:

```dart
String _exportErrorMessage(SourceExportFailureReason reason) {
  return switch (reason) {
    SourceExportFailureReason.notFound => '当前书源已不存在',
    SourceExportFailureReason.unsupportedPlatform => '当前书源平台暂不支持导出',
    SourceExportFailureReason.empty => '没有可导出的书源',
    SourceExportFailureReason.encodingFailed => '导出编码失败',
  };
}
```

`selectedId!` is valid only because Task 3 keeps current disabled when null. Do not invent fallback id values.

- [ ] **Step 6: Verify GREEN and existing page behavior**

```bash
flutter test test/features/sources/presentation/source_page_test.dart
flutter test test/features/sources/presentation/source_export_menu_test.dart
flutter test test/features/sources/presentation/source_editor_test.dart
flutter analyze
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/sources/presentation/source_page.dart \
  app/test/features/sources/presentation/source_page_test.dart
git commit -m "feat: integrate source export flow"
```

---

### Task 5: Real SQLite export regressions + final acceptance（强模型）

**Files:**
- Create: `app/test/features/sources/presentation/source_export_integration_test.dart`

**Consumes:** real `AppDatabase(NativeDatabase.memory())`, `SqliteSourceRepository`, real `SourceExportService`, real `SourcePage`, fake `SourceFileSaver` only for capturing system-save output.

- [ ] **Step 1: Write real SQLite regression for all-export platform filtering**

Setup:

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
```

Assertion:

```dart
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

- [ ] **Step 2: Write real SourcePage regression proving unsaved Draft is excluded**

Insert one real `StandarReader` record with saved values:

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

Pump a 1200x800 real `SourcePage` with only these overrides:

```dart
sourceRepositoryProvider.overrideWithValue(repository)
sourceFileSaverProvider.overrideWithValue(capturingSaver)
```

Then:

```text
1. select source id
2. edit source-editor-name to `未保存新名称`
3. edit search-book-request-info to `/unsaved-search`
4. DO NOT tap source-editor-save
5. open source-export-menu
6. choose source-export-current
7. choose source-export-format-json
```

Decode `capturingSaver.payloads.single.bytes` and assert:

```dart
expect(decoded.single.sourceName, '数据库旧名称');
expect(
  decoded.single.searchBook?.action.requestInfo,
  '/saved-search',
);
```

Also assert the mounted Editor still visibly contains the unsaved values after export. This proves export neither saves nor resets the Draft.

- [ ] **Step 3: Run focused integration tests**

```bash
flutter test test/features/sources/presentation/source_export_integration_test.dart
```

Expected: PASS after Tasks 1-4. If it fails, use `superpowers:systematic-debugging`; do not weaken the persisted-vs-draft assertions.

- [ ] **Step 4: Run final acceptance suite**

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

Expected: every command GREEN; full suite has zero failures; analyzer has no issues; diff check has no output.

- [ ] **Step 5: Commit integration regression**

```bash
git add app/test/features/sources/presentation/source_export_integration_test.dart
git commit -m "test: cover source export sqlite flow"
```

---

## Completion Review

Before declaring Source Export complete, verify each item against the spec:

- `SourceExportService` exists outside `SourceController`.
- current export calls `getSource(id)` and never consumes a `StoredSource` passed from Presentation.
- all export filters exactly `platform == 'StandarReader'`.
- platform is absent from exported raw JSON unless it originally existed as a raw field for unrelated reasons.
- single export still decodes from a JSON array.
- JSON uses UTF-8 without BOM and no separate pretty encoder.
- XBS decrypts to the same JSON array semantics.
- unknown top-level and nested raw fields survive export round-trip.
- current filename sanitizer handles forbidden/control/trailing characters and empty fallback.
- all filenames are exactly `source-reader-export.json` / `.xbs`.
- MIME values are exact.
- empty all-export generates no payload.
- `FilePickerSourceFileSaver` returns false on `FilePicker.saveFile(...) == null`.
- format-dialog cancel and saver cancel are silent.
- structured export failures map to the approved Chinese UI messages.
- arbitrary saver exceptions map to `导出失败：<error>`.
- SourcePage has one export entry with current/all → JSON/XBS flow.
- SourceEditor API is unchanged and no Draft is exposed.
- real SQLite regression proves unsaved Editor changes are not exported.
- no dirty-state tracking, Reader, Source Tester, multi-select, share or non-StandarReader export was added.

## Execution Handoff

Recommended execution sequence:

```text
Task 1  strong model: export service
Task 2  strong model: saver boundary + adapter + providers
Task 3  OmniRoute OR-006: pure export menu
Task 4  strong model: SourcePage integration
Task 5  strong model: SQLite regressions + final acceptance
```

At Task 3, strong model must first commit `docs/omniroute/OR-006-source-export-menu.md`, then stop and hand the exact work order to OmniRoute. After OmniRoute returns a commit SHA, strong model reviews the actual diff and CI before starting Task 4.
