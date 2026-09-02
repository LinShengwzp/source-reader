# Source Workbench 基础书源编辑器设计

日期：2026-09-02

## 目标

在现有 Source Workbench 中补齐第一条可编辑闭环：

```text
选择书源
  ↓
编辑已知字段
  ↓
保存
  ↓
Repository.updateSource
  ↓
SQLite
  ↓
SourceController.reload
  ↓
列表立即反映新值
```

第一阶段只编辑 4 个基础字段：

- `sourceName`
- `sourceUrl`
- `enable`
- `weight`

目标不是一次性迁移旧项目全部规则字段，而是先验证“选择 → 草稿编辑 → 保存 → 持久化 → 刷新”这一条最小、可扩展的 Workbench 主链。

## 非目标

本阶段明确不实现：

- `searchBook`、`bookDetail`、`chapterList`、`content` 等复杂规则编辑。
- Raw JSON 文本编辑器。
- 自动保存。
- 多标签页编辑。
- 撤销/重做历史。
- Source Tester 联动。
- 新增书源。
- 删除书源。
- 覆盖/冲突策略。
- 路由框架升级。

这些能力在基础编辑闭环稳定后独立设计。

## 核心原则

### 1. Raw JSON 仍是唯一事实来源

`SourceDocument` 的 raw JSON 继续作为书源内容的 canonical truth。

编辑器不得直接修改 raw Map，也不得把 SourceDocument 重建成仅包含已知字段的新对象。保存时必须基于原始 `SourceDocument` 调用 `copyWithKnownFields(...)` 产生新文档，从而保留未知字段、未来字段和平台扩展字段。

### 2. 持久化身份与书源内容继续分离

数据库 id、platform、createdAt、updatedAt 属于 `StoredSource` 的持久化身份。

编辑器只编辑 `SourceDocument` 内容。保存时通过 `SourceController.updateSource(id, document)` 进入 Repository，不允许 Presentation 层直接访问 Drift 或 SQLite。

### 3. 显式选择，不从 UI 文本反推身份

列表选择使用数据库 id。当前选中状态由独立 provider 表达：

```dart
final selectedSourceIdProvider = StateProvider<int?>((ref) => null);
```

选择状态不塞进 `SourceList` 内部，也不依赖列表 index。这样 reload、排序变化和未来过滤都不会改变书源身份。

### 4. 编辑状态使用独立 Draft

新增纯 Dart 模型：

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
}
```

`weight` 在 Draft 中保留为 String，使 UI 能表达输入中的临时状态，例如空字符串或 `-`，而不是每个按键都强制解析成 int。

保存前再执行校验和解析。

## 组件职责

### selectedSourceIdProvider

职责：

- 保存当前选中的数据库 id。
- `null` 表示未选择。
- 不读取 Repository。
- 不保存 SourceDocument 副本。

### SourceController

新增行为：

```dart
Future<void> updateSource({
  required int id,
  required SourceDocument document,
})
```

行为：

1. 调用 `SourceRepository.updateSource(id, document)`。
2. 成功后调用 `reload()`。
3. 更新失败时继续向上传播原异常。
4. 更新失败时不得先清空当前列表。

`reload()` 仍是唯一重新读取持久化列表的入口。

### SourceEditorDraft

职责：

- 从 `SourceDocument` 提取 4 个基础字段供表单使用。
- 作为 Presentation 层可变输入状态与领域文档之间的隔离层。
- 不依赖 Flutter、Riverpod、Repository。

保存转换：

```dart
final weightValue = int.parse(draft.weight.trim());
final updated = original.copyWithKnownFields(
  sourceName: draft.sourceName.trim(),
  sourceUrl: draft.sourceUrl.trim(),
  enabled: draft.enabled,
  weight: weightValue,
);
```

### SourceList

改造成纯展示 + 选择输入组件：

```dart
SourceList(
  sources: sources,
  selectedId: selectedId,
  onSelected: onSelected,
)
```

职责：

- 渲染列表。
- 显示选中态。
- 点击时回传 `source.id`。

禁止：

- 自己持有 selected id。
- 读取 Riverpod。
- 保存书源。
- 打开数据库。

### SourceEditor

独立 widget，输入：

```dart
SourceEditor(
  source: storedSource,
  onSave: ...,
)
```

职责：

- 初始化 Draft。
- 编辑 4 个基础字段。
- 做本地表单校验。
- 调用 `onSave(updatedDocument)`。
- 展示保存中的禁用状态。

它不知道 Repository、Drift 或 SQLite。

## 表单规则

### sourceName

- 必填。
- `trim()` 后不能为空。
- 保存时写入 trim 后的值。

### sourceUrl

- 第一阶段允许为空。
- 保存时写入 trim 后的字符串。
- 不在此阶段验证 URL scheme，避免把历史书源中可能存在的特殊地址格式误判为非法。

### enabled

- Switch/Checkbox 布尔输入。
- 保存时依赖 `SourceDocument.copyWithKnownFields()` 保留原有 `enable` 表达类型。

### weight

- 文本/数字输入。
- `trim()` 后必须能被 `int.tryParse()` 解析。
- 不额外限制正负范围。
- 保存时依赖 `SourceDocument.copyWithKnownFields()` 保留原有 string/int 表达类型。

## 宽屏交互

断点继续沿用现有 `840px`。

宽屏布局：

```text
┌──────────────┬─────────────────────────────┐
│ SourceList   │ SourceEditor                │
│              │                             │
│ ● A          │ 名称   [............]       │
│   B          │ 地址   [............]       │
│   C          │ 启用   [✓]                  │
│              │ 权重   [ 10 ]               │
│              │                             │
│              │              [保存]         │
└──────────────┴─────────────────────────────┘
```

行为：

- 未选择时右侧显示现有“选择一个书源开始编辑”。
- 点击列表项后更新 `selectedSourceIdProvider`。
- 右侧根据 id 从当前 `List<StoredSource>` 中找到对应记录并显示 SourceEditor。
- reload 后若选中 id 仍存在，继续保持选中。
- reload 后若选中 id 不存在，则清空 selection。

## 窄屏交互

本阶段不引入 Router。

窄屏页面有两个状态：

```text
selectedSourceId == null  → SourceList
selectedSourceId != null  → SourceEditor
```

Editor 顶部提供返回操作，返回时仅把 `selectedSourceIdProvider` 设为 null。

不使用 Navigator push/pop，避免现在为单一 Workbench 页面提前绑定未来应用级导航方案。

## 未保存修改策略

第一阶段采用最简单、确定的策略：

- 草稿只存在于当前 SourceEditor widget 生命周期。
- 切换到另一个书源或窄屏返回列表时，未保存修改直接丢弃。
- 本阶段不弹“是否保存”确认框。

原因：自动保存、dirty guard 和跨书源草稿缓存都会显著扩大状态模型。等基础编辑闭环稳定后再单独设计 dirty-state 保护。

## 错误处理

### 表单校验失败

- 不调用 Controller。
- 在对应字段附近显示本地校验错误。

### Repository / Controller 保存失败

- Draft 保留在 Editor 中。
- 页面显示 `保存失败：<message>` Snackbar。
- 当前列表保持原值。
- 不把整个 SourceController state 改成错误页。

### 保存成功

- Controller update 完成并 reload。
- 页面显示 `已保存` Snackbar。
- 选中 id 保持不变。
- Editor 用 reload 后的新 `StoredSource` 重新建立已保存状态。

## 测试策略

### Domain / Draft 单元测试

验证：

1. `SourceEditorDraft.fromDocument` 正确读取 4 个字段。
2. 保存转换只修改 4 个已知字段。
3. 未知嵌套 raw 字段完整保留。
4. `enable` 与 `weight` 的历史表达类型仍由 SourceDocument 保留。

### Controller 单元测试

验证：

1. `updateSource` 调用 Repository 正确 id/document。
2. 成功后 reload。
3. 失败时不 reload。
4. 失败异常原样向上传播。
5. 当前已加载列表在失败时保持不变。

### SourceList widget test

验证：

1. 点击项目回传数据库 id。
2. selectedId 显示选中态。
3. reload 后列表顺序变化不影响基于 id 的选择语义。

### SourceEditor widget test

验证：

1. 4 个字段正确初始化。
2. 修改字段后保存得到正确的新 SourceDocument。
3. 空 sourceName 阻止保存。
4. 非整数 weight 阻止保存。
5. 保存中按钮禁用，防止重复提交。

### SourcePage widget test

验证：

1. 宽屏点击列表后右侧出现 Editor。
2. 宽屏未选择时显示 placeholder。
3. 窄屏点击列表后切换到 Editor。
4. 窄屏返回恢复列表。
5. 保存成功 Snackbar。
6. 保存失败 Snackbar 且 Editor 草稿不丢。

## 实施边界

### 强模型负责

- `selectedSourceIdProvider` 的状态边界。
- `SourceController.updateSource`。
- `SourceEditorDraft` 及 raw JSON 保留测试。
- SourcePage 宽窄屏状态组合。
- 保存失败时状态语义。

### OmniRoute 可负责

仅在强模型先定义接口和测试边界后，拆成受控工单：

- SourceList 增加 `selectedId` / `onSelected` 和选中视觉。
- SourceEditor 四字段纯 UI。
- Snackbar / 按钮等机械 Presentation 接线。

每张 OmniRoute 工单必须：

1. 指定允许修改文件。
2. 明确禁止修改 Domain、Repository、数据库、Codec。
3. 运行指定测试、`flutter analyze`、`git diff --check`。
4. 自行 commit。
5. 返回 commit SHA 供强模型审查。

## 完成标准

本阶段完成时必须能在真实 Workbench 中完成：

```text
导入书源
  ↓
列表中选择书源
  ↓
编辑名称 / 地址 / 启用 / 权重
  ↓
保存
  ↓
SQLite 更新
  ↓
列表刷新并显示新值
```

同时必须有自动化测试证明未知 raw JSON 字段在整个编辑保存过程中没有丢失。
