# Flutter Revival Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `revival/flutter-workbench` 上建立可由 GitHub CI 验证的 Flutter 基线，并完成最小应用壳、`SourceDocument` 核心边界和 JSON codec，为后续 XBS、SQLite 与编辑器提供稳定接口。

**Architecture:** 新 Flutter 包位于 `app/`，旧 Vue/Tauri 代码暂时保留。业务核心采用 raw JSON 为唯一事实来源的 `SourceDocument`，Codec 与 Flutter UI、文件系统和数据库完全解耦。当前执行环境没有 Flutter SDK，因此本计划使用 GitHub Actions 作为权威的 `flutter analyze` / `flutter test` 验证环境，并仍然遵循 RED -> GREEN 顺序。

**Tech Stack:** Flutter 3.47.0 stable、Dart 3.13.x、flutter_riverpod 3.4.x、flutter_test、flutter_lints 6.x。数据库依赖本计划不引入。

**Spec:** `docs/revival/architecture.md`

## Global Constraints

- 只在 `revival/flutter-workbench` 分支实施，禁止修改 `main`。
- 新 Flutter 应用固定放在 `app/`。
- 本计划不删除旧 `src/`、`src-tauri/`。
- 本计划不升级 Tauri。
- raw JSON 是 `SourceDocument` 唯一事实来源，未知字段必须保留。
- Codec 不得依赖 Widget、文件选择器、SQLite 或平台 API。
- Riverpod 禁止 codegen。
- 新增/修改的业务注释优先使用中文。
- 禁止引入 Drift、SQLite、路由库、Freezed、json_serializable、build_runner。
- 每个生产行为必须先提交能在 CI 中正确失败的测试，再提交最小实现使其通过。
- 禁止顺手重构旧 Vue/Tauri 代码。

---

## File Structure

本计划最终只新增/修改以下文件：

```text
.github/workflows/flutter-ci.yml
.gitignore
app/
├─ analysis_options.yaml
├─ pubspec.yaml
├─ lib/
│  ├─ main.dart
│  ├─ app/
│  │  └─ app.dart
│  └─ features/
│     └─ sources/
│        ├─ domain/
│        │  └─ source_document.dart
│        └─ codec/
│           └─ source_json_codec.dart
└─ test/
   ├─ app/app_smoke_test.dart
   └─ features/sources/
      ├─ domain/source_document_test.dart
      └─ codec/source_json_codec_test.dart
```

本计划故意不创建 Android/iOS/Windows/macOS/Linux runner 目录。核心包与测试稳定后，再由后续独立任务通过官方 `flutter create . --platforms=...` 生成平台壳，避免当前无法运行 Flutter CLI 的环境手写生成文件。

---

### Task 1: 建立 Flutter CI 与包配置

**Files:**
- Create: `.github/workflows/flutter-ci.yml`
- Create: `app/pubspec.yaml`
- Create: `app/analysis_options.yaml`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: 无。
- Produces: GitHub CI 命令 `flutter pub get`、`flutter analyze`、`flutter test`；后续任务使用包名 `source_reader`。

- [ ] **Step 1: 增加 GitHub Actions workflow**

workflow 必须只在 `revival/flutter-workbench` 的 push/PR 上执行，并固定 Flutter `3.47.0`：

```yaml
name: Flutter CI

on:
  push:
    branches:
      - revival/flutter-workbench
  pull_request:
    branches:
      - revival/flutter-workbench

jobs:
  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4

      - name: Install Flutter 3.47.0
        shell: bash
        run: |
          git clone --depth 1 --branch 3.47.0 https://github.com/flutter/flutter.git "$RUNNER_TEMP/flutter"
          echo "$RUNNER_TEMP/flutter/bin" >> "$GITHUB_PATH"

      - name: Flutter version
        run: flutter --version

      - name: Install dependencies
        run: flutter pub get

      - name: Analyze
        run: flutter analyze

      - name: Test
        run: flutter test
```

- [ ] **Step 2: 创建最小 pubspec**

`app/pubspec.yaml`：

```yaml
name: source_reader
description: Cross-platform source workbench and reader.
publish_to: none
version: 0.1.0+1

environment:
  sdk: ">=3.13.0 <4.0.0"
  flutter: ">=3.47.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.4.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 3: 创建 analyzer 配置**

`app/analysis_options.yaml`：

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true

linter:
  rules:
    always_use_package_imports: true
    avoid_dynamic_calls: true
    prefer_final_locals: true
```

- [ ] **Step 4: 更新根 `.gitignore`**

在保留旧规则的前提下追加：

```gitignore
# 本机环境配置
.env
.env.*
!.env.example

# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.pub-cache/
.pub/
build/
app/.metadata
app/android/.gradle/
app/ios/Pods/
app/macos/Pods/
```

旧仓库已跟踪的 `.env` 不在本任务删除；后续单独处理 tracked file，避免把环境清理和 Flutter 基线混在一个提交。

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/flutter-ci.yml .gitignore app/pubspec.yaml app/analysis_options.yaml
git commit -m "chore: establish Flutter CI baseline"
```

CI 此时可以因为还没有 `lib/main.dart` 而失败，这是预期的基线状态；Task 2 会用测试驱动补齐应用壳。

---

### Task 2: 最小 Flutter 应用壳

**Files:**
- Create: `app/test/app/app_smoke_test.dart`
- Create: `app/lib/main.dart`
- Create: `app/lib/app/app.dart`

**Interfaces:**
- Consumes: Flutter SDK、Riverpod `ProviderScope`。
- Produces: `SourceReaderApp extends StatelessWidget`，应用标题 `Source Reader`，首页可见文本 `Source Workbench`。

- [ ] **Step 1: 写失败的 smoke test**

`app/test/app/app_smoke_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/app/app.dart';

void main() {
  testWidgets('应用启动后显示 Source Workbench 首页', (tester) async {
    await tester.pumpWidget(const SourceReaderApp());

    expect(find.text('Source Workbench'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 推送测试并确认 RED**

等待 GitHub Actions。

Expected: FAIL，因为 `package:source_reader/app/app.dart` 不存在。失败原因必须是缺少待实现应用壳，而不是 workflow、Flutter 安装或 pub get 失败。

- [ ] **Step 3: 写最小实现**

`app/lib/app/app.dart`：

```dart
import 'package:flutter/material.dart';

final class SourceReaderApp extends StatelessWidget {
  const SourceReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Source Reader',
      home: Scaffold(
        body: Center(
          child: Text('Source Workbench'),
        ),
      ),
    );
  }
}
```

`app/lib/main.dart`：

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:source_reader/app/app.dart';

void main() {
  runApp(const ProviderScope(child: SourceReaderApp()));
}
```

- [ ] **Step 4: 确认 GREEN**

CI 必须全部通过：

```text
flutter pub get
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git add app/lib/main.dart app/lib/app/app.dart
git commit -m "feat: add minimal Flutter application shell"
```

---

### Task 3: SourceDocument raw JSON 边界

**Files:**
- Create: `app/test/features/sources/domain/source_document_test.dart`
- Create: `app/lib/features/sources/domain/source_document.dart`

**Interfaces:**
- Consumes: `Map<String, Object?>`。
- Produces:
  - `SourceDocument.fromRaw(Map<String, Object?> raw)`
  - `Map<String, Object?> toRaw()`
  - `String? get sourceName`
  - `String? get sourceUrl`
  - `bool get enabled`
  - `int get weight`
  - `SourceDocument copyWithKnownFields({String? sourceName, String? sourceUrl, bool? enabled, int? weight})`

- [ ] **Step 1: 写 unknown-field preservation 失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_document.dart';

void main() {
  test('修改已知字段时保留未知字段', () {
    final source = SourceDocument.fromRaw(<String, Object?>{
      'sourceName': '旧名称',
      'sourceUrl': 'https://example.com',
      'enable': 1,
      'weight': 5,
      'futureExtension': <String, Object?>{'mode': 'x'},
    });

    final changed = source.copyWithKnownFields(sourceName: '新名称');
    final raw = changed.toRaw();

    expect(raw['sourceName'], '新名称');
    expect(raw['futureExtension'], <String, Object?>{'mode': 'x'});
  });
}
```

- [ ] **Step 2: 确认 RED**

Expected: FAIL，因为 `SourceDocument` 尚不存在。

- [ ] **Step 3: 添加 enable/weight normalization 测试**

同一测试文件追加：

```dart
test('兼容历史 enable 与 weight 表达', () {
  expect(SourceDocument.fromRaw({'enable': 1}).enabled, isTrue);
  expect(SourceDocument.fromRaw({'enable': 0}).enabled, isFalse);
  expect(SourceDocument.fromRaw({'enable': true}).enabled, isTrue);
  expect(SourceDocument.fromRaw({'enable': '0'}).enabled, isFalse);
  expect(SourceDocument.fromRaw({'enable': '1'}).enabled, isTrue);
  expect(SourceDocument.fromRaw({'weight': '12'}).weight, 12);
  expect(SourceDocument.fromRaw({'weight': 7}).weight, 7);
  expect(SourceDocument.fromRaw({'weight': null}).weight, 0);
});
```

- [ ] **Step 4: 写最小实现**

要求：

1. 构造时复制输入 Map，避免外部继续修改原 Map 影响 document。
2. `toRaw()` 返回新的 Map，不暴露内部可变 Map 引用。
3. `copyWithKnownFields` 从 raw 副本修改指定键。
4. `enabled` 只把 `true`、数字非 0、字符串 `"1"`/`"true"` 识别为 true；`"0"` 必须是 false。
5. `weight` 接受 int、num、可解析整数的 String，其余返回 0。
6. 不添加本任务测试未要求的字段 facade。

- [ ] **Step 5: 确认 GREEN**

Run in CI:

```text
flutter analyze
flutter test test/features/sources/domain/source_document_test.dart
flutter test
```

- [ ] **Step 6: Commit**

```bash
git add app/test/features/sources/domain/source_document_test.dart app/lib/features/sources/domain/source_document.dart
git commit -m "feat: add source document domain boundary"
```

---

### Task 4: JSON Codec

**Files:**
- Create: `app/test/features/sources/codec/source_json_codec_test.dart`
- Create: `app/lib/features/sources/codec/source_json_codec.dart`

**Interfaces:**
- Consumes: `SourceDocument`。
- Produces:
  - `List<SourceDocument> decodeSourceJson(String text)`
  - `String encodeSourceJson(Iterable<SourceDocument> sources)`
  - `FormatException` 用于非法 JSON 或非对象/对象数组顶层结构。

- [ ] **Step 1: 写单对象和数组 decode 失败测试**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/codec/source_json_codec.dart';

void main() {
  test('单个 JSON 对象解码为一个书源', () {
    final sources = decodeSourceJson('{"sourceName":"A","unknown":123}');

    expect(sources, hasLength(1));
    expect(sources.single.sourceName, 'A');
    expect(sources.single.toRaw()['unknown'], 123);
  });

  test('JSON 对象数组解码为多个书源', () {
    final sources = decodeSourceJson('[{"sourceName":"A"},{"sourceName":"B"}]');

    expect(sources.map((source) => source.sourceName), ['A', 'B']);
  });
}
```

- [ ] **Step 2: 确认 RED**

Expected: FAIL，因为 codec 尚不存在。

- [ ] **Step 3: 添加非法顶层结构测试**

```dart
test('拒绝字符串等非对象顶层 JSON', () {
  expect(() => decodeSourceJson('"abc"'), throwsFormatException);
  expect(() => decodeSourceJson('[1, 2, 3]'), throwsFormatException);
});
```

- [ ] **Step 4: 添加 round-trip unknown-field 测试**

```dart
test('encode/decode round-trip 保留未知字段', () {
  const input = '[{"sourceName":"A","future":{"flag":true}}]';

  final encoded = encodeSourceJson(decodeSourceJson(input));
  final raw = jsonDecode(encoded) as List<Object?>;
  final first = raw.single as Map<String, Object?>;

  expect(first['future'], <String, Object?>{'flag': true});
});
```

- [ ] **Step 5: 写最小实现**

实现约束：

1. 使用 `dart:convert`。
2. 顶层 Map -> 1 个 `SourceDocument`。
3. 顶层 List -> 每一项必须是 Map，否则抛 `FormatException`。
4. 不在 codec 内做业务必填校验；例如缺少 `sourceName` 仍可 decode，业务校验属于后续 `SourceValidator`。
5. `encodeSourceJson` 输出 JSON 数组，即使只有一个 source 也输出数组，便于批量导出保持一致。
6. 禁止排序 raw key，禁止删除 null/未知字段。

- [ ] **Step 6: 确认 GREEN**

```text
flutter analyze
flutter test test/features/sources/codec/source_json_codec_test.dart
flutter test
```

- [ ] **Step 7: Commit**

```bash
git add app/test/features/sources/codec/source_json_codec_test.dart app/lib/features/sources/codec/source_json_codec.dart
git commit -m "feat: add source JSON codec"
```

---

### Task 5: 基线验收与平台壳后续入口

**Files:**
- Modify: `docs/revival/architecture.md` only if implementation revealed a factual mismatch. Otherwise no file changes.

**Interfaces:**
- Consumes: Tasks 1-4。
- Produces: 下一份计划的稳定输入接口，不新增功能。

- [ ] **Step 1: 验证 CI**

分支 HEAD 必须同时满足：

```text
flutter pub get        PASS
flutter analyze        PASS
flutter test           PASS
```

- [ ] **Step 2: 核对禁止项**

确认本计划没有：

```text
Drift / SQLite
Freezed
json_serializable
build_runner
路由库
XBS 实现
旧 Vue/Tauri 重构
Reader 数据表
```

- [ ] **Step 3: 记录下一阶段入口**

下一份独立计划固定为：

```text
1. 从旧 xbsTools.ts 建立 fixture
2. Dart XBS codec RED/GREEN round-trip
3. SourceBundle
4. SourceValidator
5. 再进入 Drift/SQLite repository
```

平台 runner 生成也作为独立机械任务执行：

```bash
cd app
flutter create . \
  --project-name source_reader \
  --org com.anmi \
  --platforms android,ios,windows,macos,linux
```

执行平台生成任务时必须先备份/检查 `pubspec.yaml`、`lib/main.dart` 与 `analysis_options.yaml`，生成后只保留必要平台文件，禁止让模板覆盖已实现架构代码。

---

## Self-Review

- Spec coverage：覆盖新分支、Flutter-only、raw JSON 单一事实来源、Codec 解耦、Riverpod 无 codegen、旧项目保留。
- Intentional omissions：XBS、SQLite、adaptive UI、文件选择和 Reader 均属于后续独立计划，本计划不提前实现。
- Type consistency：所有后续接口统一使用 `Map<String, Object?>`，避免 `dynamic` 泄漏；JSON codec 统一返回 `List<SourceDocument>`。
- OmniRoute boundary：Task 2 以后可以拆成机械小任务，但 `SourceDocument` 与 XBS 核心仍由主架构工作流审核和控制。
