# Source Import Implementation Plan

> **For agentic workers:** 按任务逐项实施。任何任务不得越过允许文件边界，也不得顺手重构。

**Goal:** 建立第一条真正可操作的 Source Workbench 业务闭环：选择 `.json` / `.xbs` 书源文件，解析为 `SourceDocument`，以事务方式批量写入 SQLite，随后刷新 `SourceList`。

**Architecture:** 文件选择仅负责返回文件名和 bytes；`SourceImportService` 负责格式识别、XBS/UTF-8/JSON 解码、预校验和调用 Repository；`SourceRepository` 提供事务批量写入；Presentation 不接触 Drift、XBS 实现或文件系统细节。

**Tech Stack:** Flutter 3.47.0、Dart 3.13.x、Riverpod 3.4.2、Drift 2.34.3、file_picker 12.1.3。

## Global Constraints

- 工作分支固定 `revival/flutter-workbench`。
- 第一版仅支持 platform `StandarReader`。
- 只支持 `.json` 与 `.xbs`，扩展名大小写不敏感。
- `raw JSON` 仍是 `SourceDocument` 唯一事实来源，未知字段必须保留。
- 批量导入必须 all-or-nothing；任意一条校验、唯一约束或数据库写入失败时不得留下部分记录。
- Codec 不依赖 Repository；Repository 不依赖文件选择；Presentation 不 import Drift。
- 不引入 Freezed、Riverpod codegen、mocking package。
- 不修改数据库 schema。
- 新增业务注释优先中文。

---

## Task 1：Repository 事务批量插入（核心，由强模型实施）

**Files:**
- Modify: `app/lib/features/sources/data/source_repository.dart`
- Modify: `app/lib/features/sources/data/sqlite_source_repository.dart`
- Modify: `app/test/features/sources/data/sqlite_source_repository_test.dart`

新增：

```dart
Future<List<int>> insertSources({
  required String platform,
  required List<SourceDocument> documents,
});
```

要求：
- 在进入事务前校验所有 `sourceName` 非空。
- 同一批次使用一个 timestamp。
- 使用 Drift transaction。
- 返回与输入顺序一致的数据库 id。
- `insertSource` 保持兼容，可复用批量逻辑。

测试：
1. 两条合法书源批量写入并返回两个 id。
2. 第二条与数据库已有书源发生唯一键冲突时，第一条也必须回滚。
3. 同一批次内部重名时整批回滚。
4. 中间存在空 `sourceName` 时，在写数据库前失败且数据库保持不变。

---

## Task 2：SourceImportService（核心，由强模型实施）

**Files:**
- Create: `app/lib/features/sources/application/source_import.dart`
- Create: `app/test/features/sources/application/source_import_test.dart`

定义最小模型：

```dart
final class SourceImportPayload {
  const SourceImportPayload({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

final class SourceImportResult {
  const SourceImportResult({required this.importedCount});
  final int importedCount;
}
```

`SourceImportService`：
- 输入 `SourceRepository`。
- `.json`：UTF-8 → `decodeSourceJson`。
- `.xbs`：`decodeXbs` → UTF-8 → `decodeSourceJson`。
- UTF-8 文本允许开头 BOM，解析前去除 U+FEFF。
- `[]` 必须拒绝，不能报告“成功导入 0 条”。
- 在 Repository 调用前检查全部 `sourceName` 非空。
- 默认 platform 固定 `StandarReader`。
- 非 `.json/.xbs` 抛 `FormatException`。
- 调用 `insertSources`，成功返回 `SourceImportResult`。

测试至少覆盖：
1. JSON 单对象。
2. JSON 数组。
3. UTF-8 BOM JSON。
4. XBS（使用现有 encodeXbs 构造 fixture）。
5. 大小写扩展名。
6. 不支持扩展名。
7. 空数组。
8. 缺失/空白 sourceName。
9. Repository 失败向上传播且不伪造成功结果。

---

## Task 3：OR-002 文件选择适配器（OmniRoute）

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/lib/features/sources/application/source_file_picker.dart`
- Create: `app/lib/features/sources/data/file_picker_source_file_picker.dart`
- Modify: `app/lib/features/sources/application/source_providers.dart`

依赖固定：

```yaml
file_picker: ^12.1.3
```

接口：

```dart
abstract interface class SourceFilePicker {
  Future<SourceImportPayload?> pickSourceFile();
}
```

适配器：
- 使用系统原生 picker。
- 只允许 `json`、`xbs`。
- 单文件。
- `withData: true`。
- 用户取消返回 null。
- 文件有 name 但 bytes 为 null 时抛 `StateError`，不得自行用路径补读。

Provider：

```dart
final sourceFilePickerProvider = Provider<SourceFilePicker>(...);
```

禁止修改 Controller、UI、Codec、Repository、数据库。

验收：

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

---

## Task 4：Controller 导入协调（核心，由强模型实施）

**Files:**
- Modify: `app/lib/features/sources/application/source_controller.dart`
- Modify: `app/lib/features/sources/application/source_providers.dart`
- Modify: `app/test/features/sources/application/source_controller_test.dart`

新增：

```dart
Future<SourceImportResult> importPayload(SourceImportPayload payload)
```

行为：
1. 调用 `SourceImportService`。
2. 成功后 reload 列表。
3. import 失败时保持当前已加载列表，不把列表 state 改成 error。
4. 异常继续向上传播给 UI 显示。

---

## Task 5：OR-003 导入按钮与反馈（OmniRoute）

**Files:**
- Modify: `app/lib/features/sources/presentation/source_page.dart`
- Modify: `app/test/features/sources/presentation/source_page_test.dart`

行为：
- AppBar 新增“导入书源”按钮。
- 点击后通过 `sourceFilePickerProvider` 获取 payload。
- 用户取消不显示错误、不刷新。
- 有 payload 时调用 `sourceControllerProvider.notifier.importPayload(payload)`。
- 成功 Snackbar：`已导入 N 个书源`。
- 失败 Snackbar：`导入失败：<message>`。
- 不实现拖拽、不实现多选、不实现导出、不实现覆盖/跳过冲突策略。

测试使用 Provider override fake picker，不调用真实平台插件。

---

## Acceptance

完整闭环：

```text
.json/.xbs
   ↓
SourceFilePicker
   ↓
SourceImportPayload
   ↓
SourceImportService
   ↓
SourceRepository.insertSources(transaction)
   ↓
SQLite
   ↓
SourceController.reload()
   ↓
SourceList
```

全量验收：

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

不得出现平台文件选择代码进入 codec、Drift 类型进入 UI、部分导入残留或未知 raw 字段丢失。
