# Source Reader Revival Architecture

## 1. 目标

本分支将旧的 Vue 3 + Tauri 1 实验项目重生为一个以 Flutter 为唯一客户端技术栈的跨平台应用。

产品路线固定为：

1. **Source Workbench**：导入、查看、编辑、校验、持久化和导出香色闺阁书源。
2. **Source Tester**：逐步测试搜索、详情、目录、正文解析链路，并展示请求、响应、解析输入输出、错误与耗时。
3. **Reader**：在前两阶段稳定后，再增加书架、搜索加书、阅读、进度与缓存。

第一阶段不实现完整阅读器，也不迁移旧项目中尚未真正落地的书籍、章节、分组等数据库设计。

## 2. 分支与旧项目策略

- `main` 保留 2023 年的 Vue + Tauri 1 历史状态。
- 新开发只在 `revival/flutter-workbench` 进行。
- 新 Flutter 应用放在仓库根目录的 `app/`。
- 在 Flutter 完成 XBS/JSON 导入、编辑、保存、导出闭环之前，不删除 `src/` 与 `src-tauri/`。
- 不进行 Tauri 1 -> Tauri 2 迁移。Flutter 已经是重生版本的宿主框架，升级 Tauri 只会形成无收益的中间迁移。

## 3. 技术栈

- Flutter 3.47.x stable 作为目标开发线。
- Dart 3.13.x。
- 状态管理使用 Riverpod 3.x，但**禁止 Riverpod codegen**。
- SQLite 使用 Drift 2.x + `drift_flutter`。
- Drift 允许使用自身代码生成，但生成文件不作为 OmniRoute 手工修改目标。
- 测试使用 `flutter_test`。
- 新增或修改的业务注释优先使用中文。

依赖版本在实际引入任务中以当时 pub.dev 稳定版为准，并在计划中固定后再修改。

## 4. 核心设计原则

### 4.1 raw JSON 是唯一事实来源

书源格式存在历史字段、扩展字段以及未来未知字段。新版编辑器不能因为不认识字段而在导出时丢失信息。

因此核心对象不是一个穷举所有字段的强类型 DTO，而是 `SourceDocument`：

```dart
final class SourceDocument {
  SourceDocument(Map<String, dynamic> raw);

  Map<String, dynamic> get raw;
}
```

已知字段通过 typed facade 访问，例如 `sourceName`、`sourceUrl`、`enable`、`weight`。表单只能修改 `raw` 中对应字段，其余未知字段必须原样保留。

### 4.2 Codec 与 UI/文件系统解耦

XBS 和 JSON codec 只处理字节、字符串和 Dart 数据结构，不直接调用 Flutter 文件选择器，不依赖 Widget，不依赖 SQLite。

文件选择属于 presentation/application 边界，codec 可以独立做 round-trip 测试。

### 4.3 数据库只保存当前真正需要的数据

第一阶段只有 `sources` 表：

```text
id
platform
source_name
source_type
source_url
enabled
weight
raw_json
created_at
updated_at
```

唯一约束为 `(platform, source_name)`。

其中 `raw_json` 是持久化事实来源，其余列只承担列表、过滤、排序与索引职责。

禁止提前创建 `books`、`chapters`、`book_groups` 等 Reader 阶段表。

### 4.4 Repository 必须显式且窄

不重建旧版通用 SQL Builder。第一阶段只允许出现语义明确的方法：

```dart
abstract interface class SourceRepository {
  Future<List<SourceDocument>> listSources();
  Future<SourceDocument?> getSource(int id);
  Future<int> insertSource(SourceDocument source);
  Future<void> updateSource(int id, SourceDocument source);
  Future<void> deleteSource(int id);
}
```

如果后续需要查询能力，应增加具体方法，而不是重新引入万能查询对象。

### 4.5 桌面和移动端共享业务层，不强行共享布局

宽屏采用 master-detail 工作台布局，窄屏采用页面导航。Domain、codec、repository、controller 共享，presentation 可以根据宽度采用不同组合。

## 5. 目录结构

目标结构如下：

```text
app/lib/
├─ app/
│  ├─ app.dart
│  ├─ router.dart
│  └─ theme.dart
├─ core/
│  ├─ database/
│  └─ errors/
├─ features/
│  └─ sources/
│     ├─ domain/
│     │  ├─ source_document.dart
│     │  ├─ source_bundle.dart
│     │  ├─ source_format.dart
│     │  └─ source_validator.dart
│     ├─ codec/
│     │  ├─ json_codec.dart
│     │  └─ xbs_codec.dart
│     ├─ data/
│     │  ├─ source_repository.dart
│     │  └─ sqlite_source_repository.dart
│     ├─ application/
│     │  ├─ source_controller.dart
│     │  └─ source_editor_state.dart
│     └─ presentation/
│        ├─ source_page.dart
│        ├─ source_list.dart
│        ├─ source_editor.dart
│        └─ source_import_page.dart
└─ shared/
   └─ widgets/
```

目录只在对应功能真正出现时创建，禁止一次性生成空文件占位。

## 6. 旧项目复用策略

### 直接迁移/重写核心逻辑

- `src/utils/xbsTool/xbsTools.ts`：作为 XBS codec 行为基准，重写为 Dart，并用 round-trip fixture 锁定行为。
- `src/utils/xbsTool/xbsFileTools.ts`：仅保留“支持 XBS/JSON 导入”的产品需求，不迁 FileReader 实现。
- `src/utils/Models.ts`：提取书源平台、类型、编码等领域知识，不照搬旧 DTO。
- `src/views/nodes/ModifyFormModel.ts`：作为表单字段和帮助文档的领域资料，逐批迁移。

### 只保留交互思想

- `NodeList.vue`
- `NodeDetail.vue`
- `NodeModify.vue`
- 节点导入页面

### 明确不迁移

- `src/utils/storage/Sqlite.ts`
- `src/utils/storage/Table.ts`
- 旧 Pinia 状态流
- 未落地的 Rust `service/model/storage`
- 旧 Tauri SQL 集成

## 7. OmniRoute 使用边界

OmniRoute 不允许承担架构设计、跨模块重构或模糊任务。

每个任务必须包含：

- 唯一目标；
- 允许修改的精确文件；
- 禁止修改的文件/模块；
- 明确输入输出或行为；
- 测试文件；
- 验收命令；
- 独立 commit message；
- “禁止顺手重构”。

理想任务规模是 1～4 个生产文件 + 1 个测试文件。

以下内容由主架构工作流负责，不下放给 OmniRoute：

- SourceDocument 边界；
- XBS codec 核心实现；
- 数据库 schema 和 migration；
- Repository 接口；
- 全局状态边界；
- adaptive UI shell；
- Source Tester runtime。

## 8. 第一阶段验收闭环

Source Workbench v0.1 至少必须稳定完成：

```text
XBS / JSON
   ↓
Decode
   ↓
SourceDocument[]
   ↓
Validate
   ↓
SQLite
   ↓
Reload
   ↓
Edit known fields without dropping unknown fields
   ↓
Encode
   ↓
JSON / XBS
```

在这个闭环完成之前，不进入 Reader 功能开发。
