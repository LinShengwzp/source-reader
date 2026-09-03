# Source Export 设计

## 1. 背景与目标

Source Workbench 已完成以下能力：

```text
JSON / XBS
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
Save
```

当前仍缺少 Workbench v0.1 验收闭环的最后一段：

```text
SQLite / saved SourceDocument
  ↓
Export
  ↓
JSON / XBS
```

本设计只完成“已保存书源的导出”。它不进入 Source Tester，不执行书源规则，也不读取 `SourceEditor` 中尚未保存的草稿。

第一版同时支持：

- 导出当前选中的一个书源。
- 导出当前平台的全部书源。
- JSON 格式。
- XBS 格式。

## 2. 核心原则

### 2.1 只有已保存状态可以导出

导出事实来源必须是 Repository 中的持久化记录，而不是 mounted `SourceEditor` 的临时 Draft。

因此：

- “导出当前”必须根据数据库 id 再调用 `SourceRepository.getSource(id)`。
- 不从 `SourceEditor` 获取当前表单字符串。
- 不为了导出增加 dirty-state tracking。
- 用户在编辑器里有未保存修改时，导出结果仍然是 SQLite 中最后一次成功保存的版本。

这是第一版的硬规则。

### 2.2 raw JSON 继续是导出事实来源

导出不得重新组装一个“已知字段 DTO”。

输出必须来自 `SourceDocument.toRaw()`，从而保留：

- 未知顶层字段。
- 未知 action 字段。
- 历史字段表达形式。
- 未来扩展字段。

已有 `encodeSourceJson()` 继续承担 JSON 序列化，不新增第二套 JSON encoder。

### 2.3 platform 是本地元数据，不进入 raw JSON

`StoredSource.platform` 不属于香色闺阁书源 raw JSON。

当前 Workbench 第一版只支持 `StandarReader` 平台导出，因此：

- “导出当前”仅允许 `platform == 'StandarReader'`。
- “导出全部”只导出 `platform == 'StandarReader'` 的记录。
- 不把 platform 人工写进导出 JSON。
- 不把其他平台记录混进同一个 JSON/XBS 文件。

未来如增加其他书源平台，再按平台扩展导出能力。

### 2.4 文件系统是可替换边界

Application 层不直接依赖系统文件选择器，不直接弹保存对话框。

文件保存通过窄接口 `SourceFileSaver` 完成。默认 adapter 使用项目现有的 `file_picker` 能力，负责把已经生成好的文件名、字节和 MIME 类型交给系统保存流程。

`SourceExportService` 不依赖 Flutter Widget、Riverpod 或 file_picker。

## 3. 推荐架构

整体数据流：

```text
SourcePage
   ↓
SourceExportService
   ├─ SourceRepository
   ├─ encodeSourceJson()
   └─ encodeXbs()
   ↓
SourceExportPayload
   ↓
SourceFileSaver
   ↓
FilePickerSourceFileSaver
```

职责边界如下。

### 3.1 `SourceExportService`

Application 层用例服务，负责：

- 从 Repository 读取已保存书源。
- 校验当前书源存在性和 platform。
- 对全部导出过滤 `StandarReader`。
- 根据格式编码 JSON / XBS。
- 生成默认文件名。
- 生成 MIME 类型。
- 返回导出数量。

它不负责：

- 弹文件保存窗口。
- 显示 Snackbar。
- 读取 UI Draft。
- 修改数据库。
- Riverpod 状态管理。

建议接口形态：

```dart
enum SourceExportFormat {
  json,
  xbs,
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

实际实现可以调整命名，但职责边界必须保持一致。

### 3.2 `SourceFileSaver`

文件保存边界只接受已构建好的 payload。

建议接口：

```dart
abstract interface class SourceFileSaver {
  Future<bool> save(SourceExportPayload payload);
}
```

返回语义：

- `true`：用户完成保存。
- `false`：用户取消系统保存流程。
- 抛异常：系统保存失败。

用户取消属于正常流程，不视为错误。

### 3.3 `FilePickerSourceFileSaver`

Data adapter 只负责调用系统保存能力。

它不知道：

- Repository。
- SourceDocument。
- 当前 / 全部范围。
- JSON / XBS 编码规则。
- Snackbar 文案。

这样未来即使增加分享面板或其他保存 adapter，也不需要改 export service。

## 4. 导出范围

### 4.1 导出当前

流程：

```text
selected database id
  ↓
repository.getSource(id)
  ↓
record exists?
  ↓
platform == StandarReader?
  ↓
[record.document]
  ↓
encode
```

即使 `SourcePage` 当前列表里已有对应 `StoredSource`，export service 仍应重新 `getSource(id)`。

原因是导出语义明确要求读取当前持久化事实，而不是依赖 UI 层手中的对象引用。

如果 id 已不存在，返回结构化 `notFound` 错误。

如果 platform 不支持，返回结构化 `unsupportedPlatform` 错误。

### 4.2 导出全部

流程：

```text
repository.listSources()
  ↓
where platform == StandarReader
  ↓
SourceDocument[]
  ↓
encode
```

如果过滤后为空，返回结构化 `empty` 错误，不生成 `[]` 文件。

第一版不增加：

- 多选书源导出。
- 按 enabled 筛选。
- 按 sourceType 筛选。
- 按搜索结果筛选。
- 跨平台混合导出。

## 5. 编码规则

### 5.1 JSON

继续调用已有：

```dart
encodeSourceJson(Iterable<SourceDocument> sources)
```

硬规则：

- 单个书源也输出 JSON 数组。
- 多个书源按输入顺序输出数组。
- 不改成“单个对象 / 多个数组”的双重协议。
- UTF-8 编码。
- 不增加 BOM。
- 第一版不 pretty-print，沿用现有稳定 compact JSON 输出。

JSON MIME：

```text
application/json
```

### 5.2 XBS

XBS 不重新定义 JSON 结构。

流程固定为：

```text
SourceDocument[]
  ↓
encodeSourceJson()
  ↓
UTF-8 JSON bytes
  ↓
encodeXbs()
  ↓
XBS bytes
```

因此 JSON 与 XBS 只在最后一层封装不同，内容语义保持一致。

XBS MIME：

```text
application/octet-stream
```

## 6. 默认文件名

### 6.1 当前书源

使用保存记录的 `sourceName`：

```text
<sourceName>.json
<sourceName>.xbs
```

不使用编辑器内尚未保存的新名称。

### 6.2 全部书源

固定：

```text
source-reader-export.json
source-reader-export.xbs
```

第一版不加入时间戳，以保持文件名稳定和可预测。

### 6.3 文件名清理

当前书源名称经过纯函数 sanitizer。

规则：

1. `/ \\ : * ? " < > |` 替换为 `_`。
2. 控制字符替换为 `_`。
3. 去掉文件名结尾的空格和 `.`。
4. 处理后为空时回退为 `source`。
5. 中文、英文、数字及其他正常字符原样保留。

第一版不负责系统级自动重名编号。若目标路径已存在，交给系统保存流程处理。

## 7. 错误模型

Application 层使用结构化错误原因，不直接拼中文 UI 文案。

最低需要表达：

```text
notFound
unsupportedPlatform
empty
encodingFailed
```

可以使用 sealed exception、enum + exception 或其他清晰的 Dart 表达，但禁止 UI 通过匹配任意异常字符串来判断业务原因。

语义：

- `notFound`：导出当前时数据库 id 已不存在。
- `unsupportedPlatform`：当前记录不是 `StandarReader`。
- `empty`：全部导出过滤后没有任何 `StandarReader` 记录。
- `encodingFailed`：JSON / UTF-8 / XBS 编码阶段失败。

系统保存异常由 `SourceFileSaver` 向上传递，Presentation 统一视为保存阶段失败。

## 8. Presentation 交互

`SourcePage` AppBar 增加一个稳定的“导出”入口。

第一版交互：

```text
导出
 ├─ 导出当前
 │    └─ JSON / XBS
 └─ 导出全部
      └─ JSON / XBS
```

范围选择与格式选择均为临时 UI 状态，不进入 Riverpod，也不持久化。

### 8.1 导出当前入口

没有 selected id 时：

- “导出当前”保留显示。
- 入口禁用。

这样菜单结构稳定，用户也能理解为什么当前不可用。

### 8.2 格式选择

选择“导出当前”或“导出全部”后，再显示小型格式选择对话框：

```text
JSON
XBS
取消
```

用户取消格式选择：

- 不调用 export service。
- 不调用 file saver。
- 不显示失败提示。

### 8.3 保存结果

流程：

```text
选择范围 + 格式
  ↓
SourceExportService.build...
  ↓
SourceFileSaver.save(payload)
  ├─ true  → 成功 Snackbar
  ├─ false → 静默结束
  └─ throw → 失败 Snackbar
```

成功提示：

```text
已导出 1 个书源
已导出 N 个书源
```

业务错误建议映射：

```text
notFound             → 当前书源已不存在
unsupportedPlatform  → 当前书源平台暂不支持导出
empty                → 没有可导出的书源
encodingFailed       → 导出编码失败
```

其他异常：

```text
导出失败：<error>
```

用户取消系统保存流程时不显示 Snackbar。

## 9. Riverpod Provider 组合

新增：

```text
sourceExportServiceProvider
sourceFileSaverProvider
```

推荐依赖：

```text
sourceExportServiceProvider
  ↓
SourceExportService(sourceRepositoryProvider)

sourceFileSaverProvider
  ↓
FilePickerSourceFileSaver()
```

不把导出方法塞进 `SourceController`。

原因：

- `SourceController` 当前职责是列表状态、reload、import/update 后的状态刷新。
- 导出不修改列表状态。
- 编码与文件保存属于独立用例。
- 避免 Controller 逐步变成万能 application service。

## 10. 与未保存编辑会话的关系

第一版不增加 dirty confirmation，也不阻止用户在未保存草稿存在时点击导出。

行为明确为：

```text
SQLite 中保存值 = A
SourceEditor 未保存草稿 = B
点击导出当前
=> 文件中仍是 A
```

如果用户希望导出 B，必须先点击 SourceEditor 唯一的“保存”按钮，等 Repository update 成功后再导出。

导出功能不得通过以下方式绕开此规则：

- 读取 TextEditingController。
- 暴露 SourceEditor Draft 给 SourcePage。
- 临时调用 Draft.applyTo()。
- 把 export callback 注入 SourceEditor。

## 11. 测试策略

### 11.1 Application 单元测试

覆盖 `SourceExportService`：

1. `buildCurrent(id, json)` 重新调用 `getSource(id)` 并输出一个元素的 JSON 数组。
2. 当前记录不存在返回 `notFound`。
3. 当前记录 platform 非 `StandarReader` 返回 `unsupportedPlatform`。
4. `buildAll(json)` 只包含 `StandarReader`。
5. 全部过滤后为空返回 `empty`。
6. JSON 导出 decode round-trip 后 unknown raw 字段仍存在。
7. XBS 导出经过 `decodeXbs` + UTF-8 + `decodeSourceJson` 后内容一致。
8. 当前文件名正确清理非法字符。
9. 空文件名回退 `source`。
10. 全部导出固定文件名。
11. `exportedCount` 与实际导出文档数一致。

测试应使用 fake `SourceRepository`，但 fake 只服务于 export service 的读取行为，不扩展生产 Repository 接口。

### 11.2 FileSaver adapter

系统保存对话框不适合在普通 widget/unit test 中真实弹出。

原则：

- 尽量把全部可测试逻辑放在 export service。
- `FilePickerSourceFileSaver` 保持极薄。
- 不为了 mock 一个第三方静态 API 再制造复杂抽象层。
- adapter 至少必须被 analyzer/编译链覆盖。

如果实际 `file_picker` API 允许自然依赖注入，可以增加 focused test；否则不强求系统文件对话框自动化。

### 11.3 Presentation Widget 测试

覆盖：

1. 未选择书源时“导出当前”禁用。
2. 已选择书源时“导出当前”可用。
3. “导出全部”始终可选择，是否为空由 service 决定。
4. 选择范围后显示 JSON / XBS 格式选项。
5. 取消格式选择不调用 service / saver。
6. saver 返回 `false` 时不显示错误。
7. saver 返回 `true` 时显示正确导出数量。
8. `notFound` / `unsupportedPlatform` / `empty` 映射正确提示。
9. saver 抛异常时显示 `导出失败`。

Widget tests 使用 fake service / fake saver 或 provider override，不真实访问系统文件对话框。

### 11.4 SQLite Integration

至少增加两条真实 SQLite 回归。

#### 全部导出平台过滤

```text
insert StandarReader A
insert other-platform B
  ↓
buildAll(json)
  ↓
decodeSourceJson(payload)
  ↓
只包含 A
```

同时证明 A 的 unknown raw 字段没有丢失。

#### 当前导出只认已保存状态

```text
SQLite 中 sourceName/requestInfo = old
  ↓
SourcePage 选择该记录
  ↓
SourceEditor 输入 new，但不保存
  ↓
执行“导出当前”构建
  ↓
decode payload
  ↓
仍然是 old
```

这条测试用于锁住“导出不读取 Draft”这一核心契约。

如果完整 Widget + 系统 saver 难以集成，测试可以在真实 SQLite + export service 层证明数据来源，同时另用 widget test 证明 Page 调用的是 export provider，而不是 Editor Draft。

## 12. OmniRoute 边界

主架构工作流负责：

- `SourceExportService`。
- export error model。
- 与 Repository 的数据来源语义。
- JSON/XBS 编码整合。
- provider 边界。
- SourcePage 数据流整合。
- 真实 SQLite integration。

OmniRoute 可以承担边界明确的 presentation 或 adapter 小任务，例如：

- 导出菜单 / 格式对话框纯 Widget。
- `FilePickerSourceFileSaver` 极薄 adapter。
- 已定义行为下的 widget tests。

每个 OmniRoute 工单必须继续包含精确白名单、focused/full test、analyze、`git diff --check` 和独立 commit message。

## 13. 明确不在本轮实现

- 导出未保存 Draft。
- dirty-state tracking。
- 保存前确认或导出前确认。
- 多选书源导出。
- 按 sourceType / enabled / 搜索条件导出。
- 记住上次导出格式。
- 自动导出目录。
- 导出历史。
- 分享面板。
- ZIP 压缩。
- 平台元数据写入 raw JSON。
- 非 `StandarReader` 导出。
- `bookDetail` / `chapterList` / `chapterContent` 编辑。
- Source Tester 网络请求或规则执行。

## 14. 验收标准

本轮完成后必须满足：

```text
SQLite saved source(s)
  ↓
SourceExportService
  ↓
JSON / XBS payload
  ↓
SourceFileSaver
  ↓
system save flow
```

并且：

- 当前与全部两种范围均可用。
- JSON 与 XBS 两种格式均可用。
- 单个书源仍输出数组协议。
- unknown raw 字段不丢失。
- 导出当前重新读取 Repository。
- 未保存 Draft 不进入导出结果。
- 全部导出只包含 `StandarReader`。
- 空结果不生成文件。
- 用户取消不是错误。
- SourceController 不承担导出职责。
- SourceEditor 不增加导出 callback。
- 不进入 Source Tester 或 Reader 范围。
