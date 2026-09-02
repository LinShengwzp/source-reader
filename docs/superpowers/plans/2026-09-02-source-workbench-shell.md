# Source Workbench Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在已稳定的 SourceRepository 之上建立 Riverpod Application 边界和第一版自适应 Source Workbench 页面，让应用能够从 SQLite 加载书源并稳定展示 loading/error/empty/list 四种状态。

**Architecture:** `AppDatabase` 与 `SourceRepository` 通过普通 Riverpod `Provider` 注入，`SourceController` 使用无 codegen 的 `AsyncNotifier` 作为唯一列表状态入口。Presentation 只消费 `AsyncValue<List<StoredSource>>`，不直接依赖 Drift 或 SQLite；宽屏使用左侧书源列表 + 右侧编辑区占位，窄屏只显示书源列表，为后续移动端导航和桌面 master-detail 留出明确边界。

**Tech Stack:** Flutter 3.47.0、Dart 3.13.x、flutter_riverpod 3.4.2、Drift 2.34.3、flutter_test。

**Spec:** `docs/revival/architecture.md`

## Global Constraints

- 只在 `revival/flutter-workbench` 分支实施，禁止修改 `main`。
- 禁止 Riverpod codegen、Freezed、mocking package 和新增依赖。
- UI 不允许直接 import Drift；数据库访问只能经过 `SourceRepository`。
- `SourceController` 第一版只负责加载与 reload，不提前实现导入、编辑、删除、搜索。
- 自适应阈值固定为 `840` logical pixels；本计划不做主题美化。
- 宽屏只建立 master-detail 壳，不实现真正 SourceEditor。
- 新增或修改业务注释优先使用中文。
- 每个生产行为先有失败测试，再写最小实现。
- 禁止顺手修改 JSON/XBS codec、数据库 schema、旧 Vue/Tauri 代码。

---

## File Structure

本计划新增/修改：

```text
app/lib/app/app.dart
app/lib/features/sources/application/source_providers.dart
app/lib/features/sources/application/source_controller.dart
app/lib/features/sources/presentation/source_page.dart
app/lib/features/sources/presentation/source_list.dart
app/test/features/sources/application/source_controller_test.dart
app/test/features/sources/presentation/source_page_test.dart
app/test/app/app_smoke_test.dart
```

---

### Task 1: 建立 Repository Provider 与 SourceController

**Files:**
- Create: `app/lib/features/sources/application/source_providers.dart`
- Create: `app/lib/features/sources/application/source_controller.dart`
- Test: `app/test/features/sources/application/source_controller_test.dart`

**Interfaces:**
- Produces `appDatabaseProvider: Provider<AppDatabase>`。
- Produces `sourceRepositoryProvider: Provider<SourceRepository>`。
- Produces `sourceControllerProvider: AsyncNotifierProvider<SourceController, List<StoredSource>>`。
- Produces `SourceController.reload(): Future<void>`。

- [ ] **Step 1: 写 FakeSourceRepository 与失败测试**

测试文件实现最小 fake，不引入 mock 包：

```dart
final class FakeSourceRepository implements SourceRepository {
  FakeSourceRepository(this.items);

  List<StoredSource> items;
  int listCalls = 0;

  @override
  Future<List<StoredSource>> listSources() async {
    listCalls += 1;
    return List<StoredSource>.of(items);
  }

  @override
  Future<StoredSource?> getSource(int id) => throw UnimplementedError();

  @override
  Future<int> insertSource({
    required String platform,
    required SourceDocument document,
  }) => throw UnimplementedError();

  @override
  Future<void> updateSource(int id, SourceDocument document) =>
      throw UnimplementedError();

  @override
  Future<void> deleteSource(int id) => throw UnimplementedError();
}
```

第一条测试通过顶层 `ProviderContainer(overrides: [...])` override `sourceRepositoryProvider`，等待：

```dart
final value = await container.read(sourceControllerProvider.future);
```

断言返回 fake 中的 `StoredSource` 且 `listCalls == 1`。

第二条测试修改 fake.items，执行：

```dart
await container.read(sourceControllerProvider.notifier).reload();
```

断言 controller state 更新为新列表且 `listCalls == 2`。

- [ ] **Step 2: 确认 RED**

Expected: analyzer 因 `source_providers.dart` / `source_controller.dart` 不存在而失败。

- [ ] **Step 3: 实现 provider 边界**

`source_providers.dart`：

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/core/database/app_database.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';
import 'package:source_reader/features/sources/data/sqlite_source_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
});

final sourceRepositoryProvider = Provider<SourceRepository>((ref) {
  return SqliteSourceRepository(ref.watch(appDatabaseProvider));
});
```

- [ ] **Step 4: 实现 SourceController**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/features/sources/application/source_providers.dart';
import 'package:source_reader/features/sources/data/source_repository.dart';

final sourceControllerProvider =
    AsyncNotifierProvider<SourceController, List<StoredSource>>(
  SourceController.new,
);

final class SourceController extends AsyncNotifier<List<StoredSource>> {
  @override
  Future<List<StoredSource>> build() {
    return ref.watch(sourceRepositoryProvider).listSources();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<StoredSource>>();
    state = await AsyncValue.guard(
      () => ref.read(sourceRepositoryProvider).listSources(),
    );
  }
}
```

- [ ] **Step 5: GREEN 验收**

```text
dart run build_runner build
flutter analyze
flutter test test/features/sources/application/source_controller_test.dart
flutter test
```

- [ ] **Step 6: Commit**

```bash
git commit -m "feat: add source application controller"
```

---

### Task 2: 定义 SourcePage 的状态与自适应布局

**Files:**
- Create: `app/lib/features/sources/presentation/source_list.dart`
- Create: `app/lib/features/sources/presentation/source_page.dart`
- Test: `app/test/features/sources/presentation/source_page_test.dart`

**Interfaces:**
- `SourcePage` 消费 `sourceControllerProvider`。
- `SourceList` 输入 `List<StoredSource>`，不读取 provider。
- 840 以下为窄屏列表；840 及以上为 master-detail。

- [ ] **Step 1: 写页面失败测试**

使用 `ProviderScope(overrides: [sourceRepositoryProvider.overrideWithValue(fake)])`。

覆盖四类行为：

1. empty：出现 `还没有书源`。
2. data：出现书源名称和 platform。
3. wide（`tester.view.physicalSize = const Size(1200, 800)` 且 DPR=1）：出现 key `source-master-pane` 与 `source-detail-pane`。
4. narrow（`Size(600, 800)`）：出现 `source-master-pane`，不存在 `source-detail-pane`。

错误 fake 让 `listSources()` 抛 `StateError('load failed')`，断言页面出现 `加载书源失败` 和 `重试`。

- [ ] **Step 2: 确认 RED**

Expected: presentation 文件不存在导致 analyzer/test 失败。

- [ ] **Step 3: 实现无状态 SourceList**

每个条目至少显示：

```text
sourceName（缺失时显示“未命名书源”）
platform
启用/停用
```

不得在列表中实现删除、编辑、菜单。

- [ ] **Step 4: 实现 SourcePage**

`SourcePage extends ConsumerWidget`：

```text
Scaffold
  AppBar(title: Source Workbench, reload IconButton)
  body:
    loading -> CircularProgressIndicator
    error   -> 加载书源失败 + 重试
    data    -> LayoutBuilder
```

`constraints.maxWidth >= 840` 时：

```text
Row
  SizedBox(width: 320, key: source-master-pane, child: SourceList)
  VerticalDivider
  Expanded(key: source-detail-pane, child: 选择一个书源开始编辑)
```

窄屏时：

```text
SizedBox(key: source-master-pane, child: SourceList)
```

空数据由 `SourceList` 显示 `还没有书源`。

- [ ] **Step 5: GREEN 验收**

```text
flutter analyze
flutter test test/features/sources/presentation/source_page_test.dart
flutter test
```

- [ ] **Step 6: Commit**

```bash
git commit -m "feat: add adaptive source workbench shell"
```

---

### Task 3: 将应用入口切换到 SourcePage

**Files:**
- Modify: `app/lib/app/app.dart`
- Modify: `app/test/app/app_smoke_test.dart`

**Interfaces:**
- `SourceReaderApp` 的 home 变为 `SourcePage`。
- 根 ProviderScope 继续由 `main.dart` 提供，本任务不修改 `main.dart`。

- [ ] **Step 1: 更新 smoke test 为真实首页语义**

测试仍断言 `Source Workbench`，并追加断言新空数据库最终出现 `还没有书源`。

测试必须在 `ProviderScope` 中 override `sourceRepositoryProvider` 为返回空列表的 fake，避免 widget smoke test 打开真实文件数据库。

- [ ] **Step 2: 确认 RED**

在 app.dart 尚未使用 SourcePage 时，`还没有书源` 断言失败。

- [ ] **Step 3: 最小接线**

`SourceReaderApp` 保持 MaterialApp，仅将：

```dart
home: SourcePage(),
```

作为首页。

- [ ] **Step 4: 全量 GREEN**

```text
dart run build_runner build
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: wire Source Workbench home"
```

---

### Task 4: 准备 OmniRoute 第一张机械工单

**Files:**
- Create: `docs/omniroute/OR-001-generate-flutter-platform-runners.md`

**Interfaces:**
- 不产生 Dart 业务接口。
- 工单只能生成 Flutter 官方平台 runner。

- [ ] **Step 1: 写工单**

工单必须明确：

```text
工作分支：revival/flutter-workbench
工作目录：app/
唯一目标：生成 Android、iOS、Linux、macOS、Windows 平台 runner。
允许新增：app/android/**, app/ios/**, app/linux/**, app/macos/**, app/windows/**
禁止修改：app/lib/**, app/test/**, docs/**, .github/**
禁止新增依赖，禁止修改业务逻辑，禁止顺手重构。
```

建议执行：

```bash
flutter create \
  --platforms=android,ios,linux,macos,windows \
  --project-name source_reader \
  --org com.linshengwzp \
  .
```

执行后必须检查 `git diff`。如果 `pubspec.yaml`、`lib/` 或 `test/` 被 Flutter 模板改写，恢复这些非平台文件，仅保留 platform runner。

验收：

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

Commit：

```bash
git commit -m "chore: generate Flutter platform runners"
```

- [ ] **Step 2: Commit**

```bash
git commit -m "docs: add first OmniRoute platform task"
```

---

## Self-Review

- Repository/SQLite 不泄漏到 UI。
- Riverpod 无 codegen，无新增依赖。
- controller 只有 load/reload，没有提前实现编辑操作。
- 宽窄屏边界有 widget test 锁定。
- 页面有 loading/error/empty/data 四态。
- smoke test 不访问真实磁盘数据库。
- OmniRoute 工单严格限制为平台生成物，完全不允许碰业务代码。
- 没有 SourceEditor、导入、文件选择或 Reader 功能的提前实现。
