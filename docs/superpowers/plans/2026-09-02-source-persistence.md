# Source Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Source Workbench 建立 Drift `sources` 表和显式 `SourceRepository`，让 `SourceDocument` 可以在内存 SQLite 与真实 Flutter 数据库之间稳定增删改查，并保证 `raw_json` 的未知字段不丢失。

**Architecture:** `SourceDocument.raw` 继续是书源内容唯一事实来源。SQLite 只额外保存列表/过滤需要的冗余元数据；Repository 负责 `SourceDocument <-> SourceRow` 映射，不允许出现通用 SQL Builder。持久化实体使用 `StoredSource` 暴露稳定数据库 id 与 platform，解决旧架构草案中 `listSources()` 丢失 id、无法可靠 update/delete 的问题。

**Tech Stack:** Flutter 3.47.0、Dart 3.13.x、drift 2.34.3、drift_flutter 0.3.1、drift_dev 2.34.5、build_runner 2.16.0、flutter_test。

**Spec:** `docs/revival/architecture.md`

## Global Constraints

- 只在 `revival/flutter-workbench` 分支实施，禁止修改 `main`。
- 第一阶段数据库只有 `sources` 表，禁止创建 books、chapters、groups 等 Reader 阶段表。
- `raw_json` 是书源内容唯一持久化事实来源；元数据列只能作为查询/列表冗余字段。
- `(platform, source_name)` 必须有数据库唯一约束。
- Repository API 必须显式，禁止新增万能 query/filter builder。
- Drift 可以使用自身代码生成；生成文件 `app_database.g.dart` 不作为手工修改目标。
- Riverpod 本计划不涉及，也不得借机添加 provider。
- 新增或修改业务注释优先使用中文。
- 每个生产行为必须先有能正确失败的测试，再写最小实现。
- 禁止顺手重构 codec、XBS 算法、旧 Vue/Tauri 代码。

---

## File Structure

本计划只新增/修改：

```text
.github/workflows/flutter-ci.yml
.gitignore
app/pubspec.yaml
docs/revival/architecture.md
app/lib/core/database/app_database.dart
app/lib/features/sources/domain/source_document.dart
app/lib/features/sources/data/source_repository.dart
app/lib/features/sources/data/sqlite_source_repository.dart
app/test/features/sources/domain/source_document_test.dart
app/test/features/sources/data/sqlite_source_repository_test.dart
```

由 build_runner 生成但不手工修改：

```text
app/lib/core/database/app_database.g.dart
```

---

### Task 1: 引入 Drift 工具链并让 CI 负责代码生成

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `.github/workflows/flutter-ci.yml`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: 当前 Flutter 3.47 / Dart 3.13 基线。
- Produces: `drift`、`drift_flutter` 运行依赖；`drift_dev`、`build_runner` 开发依赖；CI 在 analyze/test 前生成 Drift 代码。

- [ ] **Step 1: 修改 pubspec**

在 dependencies 增加：

```yaml
  drift: ^2.34.3
  drift_flutter: ^0.3.1
```

在 dev_dependencies 增加：

```yaml
  build_runner: ^2.16.0
  drift_dev: ^2.34.5
```

- [ ] **Step 2: 修改 CI**

在 `flutter pub get` 后、`flutter analyze` 前增加：

```yaml
      - name: Generate Drift code
        run: dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 3: 忽略唯一生成文件**

`.gitignore` 追加：

```gitignore
# Drift generated code
app/lib/core/database/app_database.g.dart
```

不得使用全局 `*.g.dart`，避免未来误忽略其他需要提交的生成文件。

- [ ] **Step 4: 验收**

CI 必须保持 GREEN：

```text
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git commit -m "chore: add Drift persistence toolchain"
```

---

### Task 2: 补齐 sourceType typed facade

**Files:**
- Modify: `app/test/features/sources/domain/source_document_test.dart`
- Modify: `app/lib/features/sources/domain/source_document.dart`

**Interfaces:**
- Consumes: `SourceDocument.fromRaw`。
- Produces: `String? get sourceType`，只读取 raw 的 `sourceType` 字符串，不归一化、不改写。

- [ ] **Step 1: 写失败测试**

追加：

```dart
test('sourceType 只读取字符串字段', () {
  expect(SourceDocument.fromRaw({'sourceType': 'text'}).sourceType, 'text');
  expect(SourceDocument.fromRaw({'sourceType': 1}).sourceType, isNull);
  expect(SourceDocument.fromRaw({}).sourceType, isNull);
});
```

- [ ] **Step 2: 确认 RED**

Expected: analyzer/test 因 `sourceType` getter 不存在而失败。

- [ ] **Step 3: 最小实现**

在 `sourceUrl` 后增加：

```dart
String? get sourceType => _stringValue('sourceType');
```

- [ ] **Step 4: 确认 GREEN**

```text
flutter analyze
flutter test test/features/sources/domain/source_document_test.dart
flutter test
```

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: expose source type metadata"
```

---

### Task 3: 定义数据库 schema 和 Repository contract

**Files:**
- Create: `app/lib/core/database/app_database.dart`
- Create: `app/lib/features/sources/data/source_repository.dart`
- Modify: `docs/revival/architecture.md`

**Interfaces:**
- Produces table `sources`：
  - `id INTEGER PRIMARY KEY AUTOINCREMENT`
  - `platform TEXT NOT NULL`
  - `source_name TEXT NOT NULL`
  - `source_type TEXT NULL`
  - `source_url TEXT NULL`
  - `enabled INTEGER/BOOLEAN NOT NULL`
  - `weight INTEGER NOT NULL`
  - `raw_json TEXT NOT NULL`
  - `created_at DATETIME NOT NULL`
  - `updated_at DATETIME NOT NULL`
  - `UNIQUE(platform, source_name)`
- Produces `StoredSource`：`id`, `platform`, `document`, `createdAt`, `updatedAt`。
- Produces `SourceRepository`：

```dart
abstract interface class SourceRepository {
  Future<List<StoredSource>> listSources();
  Future<StoredSource?> getSource(int id);
  Future<int> insertSource({
    required String platform,
    required SourceDocument document,
  });
  Future<void> updateSource(int id, SourceDocument document);
  Future<void> deleteSource(int id);
}
```

- [ ] **Step 1: 创建数据库 schema**

`SourceRows extends Table`，覆盖 `tableName => 'sources'`，避免生成含混的 `Source` 行类型。组合唯一键必须使用 Drift `uniqueKeys`。

`AppDatabase` 构造函数允许传入 `QueryExecutor?`，测试使用 `NativeDatabase.memory()`；生产默认使用：

```dart
static QueryExecutor _openConnection() {
  return driftDatabase(name: 'source_reader');
}
```

`schemaVersion` 固定为 `1`。

- [ ] **Step 2: 创建 Repository contract**

`StoredSource` 只负责持久化身份包装，不复制 `SourceDocument` 字段，不引入 DTO 映射层。

- [ ] **Step 3: 更新架构文档**

将旧的 `Future<List<SourceDocument>> listSources()` 草案改成 `StoredSource` 版本，并明确 platform 不属于书源 raw JSON，是本地持久化元数据。

- [ ] **Step 4: 生成代码并验收编译**

```text
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: define source persistence schema"
```

---

### Task 4: SQLite Repository RED 测试

**Files:**
- Create: `app/test/features/sources/data/sqlite_source_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `SourceRepository`, `StoredSource`。
- Future implementation target: `SqliteSourceRepository`。

- [ ] **Step 1: 测试 insert/get 保留未知字段**

使用 `AppDatabase(NativeDatabase.memory())`。插入：

```dart
SourceDocument.fromRaw({
  'sourceName': '测试书源',
  'sourceType': 'text',
  'sourceUrl': 'https://example.com',
  'enable': '1',
  'weight': '12',
  'futureExtension': {'mode': 'x'},
})
```

断言：

```text
id > 0
platform == 'StandarReader'
sourceName == 测试书源
sourceType == text
enabled == true
weight == 12
futureExtension == {'mode': 'x'}
```

- [ ] **Step 2: 测试 list 顺序确定**

插入两个不同书源，`listSources()` 必须按数据库 `id ASC` 返回，不能依赖 SQLite 未指定顺序。

- [ ] **Step 3: 测试 update**

修改 `sourceName`、`weight`，同时保留 `futureExtension`，断言：
- id 不变；
- platform 不变；
- createdAt 不变；
- raw 未知字段仍存在；
- 元数据列与 raw 新值一致。

- [ ] **Step 4: 测试 delete**

删除后 `getSource(id)` 返回 null。

- [ ] **Step 5: 测试空 sourceName 被拒绝**

`null`、`''`、纯空白 sourceName 的 insert/update 必须抛 `ArgumentError`，不能把不可定位的记录写入数据库。

- [ ] **Step 6: 确认 RED**

Expected: 因 `sqlite_source_repository.dart` 不存在而 analyzer/test 失败；依赖安装和 Drift 生成必须成功。

- [ ] **Step 7: Commit**

```bash
git commit -m "test: define SQLite source repository behavior"
```

---

### Task 5: 实现 SqliteSourceRepository

**Files:**
- Create: `app/lib/features/sources/data/sqlite_source_repository.dart`

**Interfaces:**
- Implements: `SourceRepository`。
- Constructor:

```dart
SqliteSourceRepository(
  AppDatabase database, {
  DateTime Function()? now,
})
```

默认时钟返回 `DateTime.now().toUtc()`，测试可注入固定时钟。

- [ ] **Step 1: 实现 raw_json 映射**

写入使用：

```dart
jsonEncode(document.toRaw())
```

读取必须 `jsonDecode` 后确认顶层是 `Map<String, Object?>`，否则抛 `FormatException`。

- [ ] **Step 2: 实现 insert**

插入前验证 `sourceName != null && sourceName.trim().isNotEmpty`。

冗余元数据列严格从 `SourceDocument` 读取：`sourceName`, `sourceType`, `sourceUrl`, `enabled`, `weight`。`createdAt` 与 `updatedAt` 使用同一时钟值。

- [ ] **Step 3: 实现 get/list**

`getSource(id)` 使用 `getSingleOrNull()`；`listSources()` 显式 `ORDER BY id ASC`。

- [ ] **Step 4: 实现 update**

只按 id 更新 source_name/source_type/source_url/enabled/weight/raw_json/updated_at，不修改 `platform` 和 `created_at`。若 id 不存在，抛 `StateError`。

- [ ] **Step 5: 实现 delete**

按 id 删除。不存在时保持幂等，不抛异常。

- [ ] **Step 6: GREEN 验收**

```text
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test test/features/sources/data/sqlite_source_repository_test.dart
flutter test
```

- [ ] **Step 7: Commit**

```bash
git commit -m "feat: add SQLite source repository"
```

---

### Task 6: 清理旧本机代理 `.env`

**Files:**
- Delete: `.env`

**Interfaces:**
- 无业务接口变化。

- [ ] **Step 1: 删除已跟踪 `.env`**

该文件只有本机 `HTTP_PROXY` / `HTTPS_PROXY`，新版不把开发机代理作为应用配置。

- [ ] **Step 2: 全量验收**

```text
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove tracked local proxy env"
```

---

## Self-Review

- Source Workbench 第一阶段唯一 `sources` 表要求已覆盖。
- `raw_json` canonical 要求由 Repository integration test 覆盖。
- `(platform, source_name)` 唯一约束落在 Drift schema。
- Repository 没有通用查询对象。
- list/update/delete 所需 id 通过 `StoredSource` 补齐，修正旧架构草案接口缺陷。
- 平台 metadata 明确与 raw JSON 分离。
- 没有 Reader 表、Riverpod provider、UI、文件选择器或 XBS 修改。
- 所有行为任务均包含 RED/GREEN 验收，无占位步骤。
