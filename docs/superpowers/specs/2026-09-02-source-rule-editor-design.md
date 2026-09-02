# Source Rule Editor 设计

## 1. 背景与目标

Source Workbench 已完成第一条最小编辑闭环：

```text
Import -> SQLite -> Select -> Edit basic fields -> Save -> Reload
```

当前 `SourceEditor` 只编辑 `sourceName`、`sourceUrl`、`enable`、`weight` 四个顶层字段。旧项目中的真正书源能力主要存在于嵌套 action 中，例如：

- `searchBook`
- `bookDetail`
- `chapterList`
- `chapterContent`

这四条主链具有相同的大体结构：请求信息、响应规则、更多配置，但每条 action 的响应字段不同。

本设计的目标是先为四条主链建立稳定、可复用的领域边界，同时只实现第一条 `searchBook` 的实际编辑 UI。这样可以为后续 `bookDetail`、`chapterList`、`chapterContent` 和 Source Tester 提供共同基础，又不会一次扩大实现范围。

## 2. 核心原则

### 2.1 raw JSON 继续是唯一事实来源

不得把香色闺阁书源转换成穷举全部字段的强类型 DTO。

`SourceDocument` 与 action document 都只是 raw JSON 上的 typed facade。任何未识别字段、未来字段、历史字段都必须在读取、编辑、保存、导出过程中保留。

### 2.2 UI 不得成为领域结构

Presentation 只负责展示和收集草稿，不决定书源 JSON 的结构。

禁止把 `searchBook` 的所有字段直接堆进一个巨型 `SourceEditor`。第一版 UI 可以采用 section/card/折叠布局，但这些布局不是架构契约。

未来把 UI 改成 Tab、侧边导航、桌面双栏或其他样式时，应主要修改 presentation 组件和 widget tests，不修改：

- `SourceDocument`
- action document
- Draft
- Repository
- SQLite schema
- Controller 保存链路

### 2.3 显式组件优先于万能动态表单

旧项目的 `FormModelItem[]`、字符串 `model/type` 和 callback 驱动模式只作为字段资料来源，不迁移成新的通用 schema 表单引擎。

允许抽取低层可复用控件，例如：

- `RuleTextField`
- `RuleMultilineField`
- `RuleEnumField`
- `RuleHelpButton`
- `EditorSectionCard`

但 `SearchBookEditor` 必须显式声明自己的业务字段。这样 IDE 重构、类型检查、特殊交互和后续维护都保持清晰。

### 2.4 编辑期间不直接修改 raw Map

所有表单修改先进入 Draft。只有点击整个 SourceEditor 的“保存”后，才通过 copy-on-write 生成新的 `SourceDocument`。

因此取消、保存失败、切换书源等行为不会污染当前持久化对象。

## 3. 四条主链的共同领域模型

### 3.1 `SourceActionDocument`

新增 action 层 raw wrapper，用于表达四条主链共享的字段和兼容规则。

第一阶段共同已知字段为：

```text
actionID
parserID
requestInfo
requestParamsEncode
responseEncode
responseFormatType
JSParser
moreKeys
```

其中：

- `actionID`、`parserID` 第一版只读，不在 UI 中直接编辑。
- 其他字段提供 typed getter。
- typed getter 只认符合预期的历史类型；无法识别的 raw 值不得被自动覆盖。
- `toRaw()` 返回顶层副本。
- copy 方法只改显式提供的已知字段，其余字段原样保留。

建议领域接口形态：

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

实际实现可以通过内部 helper 减少重复，但不得向 presentation 暴露任意 `Map<String, Object?>` mutation API。

### 3.2 `SourceSearchBookDocument`

`searchBook` 在共同字段之外增加响应规则字段：

```text
list
bookName
author
cover
desc
cat
status
wordCount
lastChapterTitle
detailUrl
success
```

其中 `success` 虽然旧 UI 将其放在“更多配置”，但它仍属于 `searchBook` 的已知字段。

推荐对外接口：

```dart
final class SourceSearchBookDocument {
  factory SourceSearchBookDocument.fromRaw(Map<String, Object?> raw);

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

实现不要求机械照抄以上签名，但必须满足相同的类型边界和 copy-on-write 语义。

### 3.3 后续三条主链

本轮不实现它们的 UI，但领域设计必须允许后续按同样方式增加：

```text
SourceBookDetailDocument
SourceChapterListDocument
SourceChapterContentDocument
```

这些类型复用共同 action 字段，并显式声明各自响应规则。

禁止提前实现这三条 action 的 presentation 或 Draft。

## 4. `SourceDocument` 对 action 的访问

`SourceDocument` 增加可选的 `searchBook` typed facade：

```dart
SourceSearchBookDocument? get searchBook;
```

只有 raw `searchBook` 本身是 Map 时才返回 typed document，否则返回 null，同时原始非法/未知值继续留在 raw JSON 中。

写回采用显式 copy：

```dart
SourceDocument copyWithSearchBook(
  SourceSearchBookDocument searchBook,
);
```

该方法只替换 raw JSON 的 `searchBook` 顶层键，不修改其他顶层字段。

第一阶段不提供删除 `searchBook` 的 UI。

## 5. 新建 `searchBook` 的规则

如果原始 raw JSON 没有 `searchBook`，仅仅打开或展开“书籍搜索”区域不得创建新对象。

只有用户真正填写了可编辑内容并保存时，才创建：

```json
{
  "searchBook": {
    "actionID": "searchBook",
    "parserID": "DOM",
    "...": "用户实际填写的字段"
  }
}
```

空白 draft 不应向 raw JSON 注入只含默认元数据的 `searchBook`。

如果原始 `searchBook` 已存在，即使只含 `actionID/parserID`，保存时也必须保留它，而不是因为“没有可编辑内容”将其删除。

## 6. Draft 设计

### 6.1 `SourceSearchBookDraft`

新增纯 Dart draft，负责在领域对象与表单字符串之间做转换。

建议字段：

```dart
final class SourceSearchBookDraft {
  const SourceSearchBookDraft({
    required this.requestInfo,
    required this.list,
    required this.bookName,
    required this.author,
    required this.cover,
    required this.desc,
    required this.cat,
    required this.status,
    required this.wordCount,
    required this.lastChapterTitle,
    required this.detailUrl,
    required this.requestParamsEncode,
    required this.responseEncode,
    required this.responseFormatType,
    required this.success,
    required this.jsParser,
    required this.moreKeysText,
  });

  factory SourceSearchBookDraft.fromDocument(
    SourceSearchBookDocument? document,
  );
}
```

文本规则默认使用空字符串表达 UI 空值。

三个 enum 字段必须使用 nullable string：

```text
requestParamsEncode
responseEncode
responseFormatType
```

`null` 表示原 raw 中没有该字段。UI 可以通过 hint 显示默认含义，但不得因为打开编辑器就把默认值写入 raw JSON。

### 6.2 未知 enum 值

历史书源可能出现新版枚举表不认识的值。

例如：

```json
{"responseFormatType":"future-format"}
```

编辑器必须：

1. 能显示当前未知值。
2. 不自动切回 `str` 或其他默认值。
3. 用户不修改时原样保存。
4. 用户主动选择已知值后才替换 raw 值。

Presentation 可将未知值临时加入当前下拉选项，显示为类似 `未知值：future-format`，但 unknown value 仍是实际 draft value。

## 7. `moreKeys` 的兼容处理

旧项目会把 `moreKeys` 的结构化 JSON 临时 stringify 后编辑，再在保存时 parse 回去。新版必须避免把历史 Map/List 无意转换成字符串。

因此第一版采用“文本投影 + 表示保留”的规则：

- 原始 `moreKeys` 为 Map/List：Draft 中显示稳定 JSON 文本。
- 原始 `moreKeys` 为 String：Draft 中显示原字符串。
- 用户没有修改 `moreKeysText`：保存时完整保留原始 raw 类型和值。
- 用户修改后：
  - 如果原始类型为 Map/List，则修改后的文本必须是有效 JSON，并写回解析后的结构化值。
  - 如果原始类型为 String 或字段不存在，则第一版允许按 String 写回，不做业务语义解析。

这不是 Source Tester 的规则校验，只是为了保证历史 raw 表示不会被编辑器静默破坏。

如果结构化 `moreKeys` 修改后 JSON 非法，属于本地表单校验错误，不调用 Controller 保存。

## 8. UI 组件边界

第一版 presentation 结构：

```text
SourceEditor
│
├─ BasicSourceEditorSection
│   └─ sourceName / sourceUrl / enable / weight
│
└─ SearchBookEditor
    │
    ├─ RequestSection
    │   └─ requestInfo
    │
    ├─ ResponseRulesSection
    │   ├─ list
    │   ├─ bookName
    │   ├─ author
    │   ├─ cover
    │   ├─ desc
    │   ├─ cat
    │   ├─ status
    │   ├─ wordCount
    │   ├─ lastChapterTitle
    │   └─ detailUrl
    │
    └─ AdvancedSection
        ├─ requestParamsEncode
        ├─ responseEncode
        ├─ responseFormatType
        ├─ success
        ├─ JSParser
        └─ moreKeys
```

组件职责：

### `SourceEditor`

- 组合基础信息和规则编辑器。
- 持有整份编辑 session 的临时状态。
- 负责统一表单校验。
- 只有一个最终“保存”按钮。
- 调用既有 `onSave(SourceDocument)`。
- 不访问 Repository、SQLite 或 Riverpod。

### `SearchBookEditor`

- 只接收 `SourceSearchBookDraft` 当前值和 typed callbacks。
- 不读取 `SourceDocument.raw`。
- 不直接保存。
- 不读 Riverpod。
- 不依赖 Repository。
- 不决定外层页面布局。

### Section 小组件

第一版可使用 card/expandable section，但 section 的“折叠/展开”属于 presentation 细节。

不得让 Draft 或 Domain 出现诸如：

```text
isAdvancedExpanded
tabIndex
selectedSection
```

这类 UI 状态。

## 9. 第一版视觉呈现

第一版建议：

```text
书籍搜索

[请求信息]
requestInfo 多行文本

[响应规则]
list
bookName
author
cover
desc
cat
status
wordCount
lastChapterTitle
detailUrl

[更多配置] 默认折叠
requestParamsEncode
responseEncode
responseFormatType
success
JSParser 多行文本
moreKeys 多行文本
```

帮助文档采用字段旁 info/help 入口或可展开帮助，不把旧版超长说明全部常驻在表单正文中。

第一版不引入代码编辑器、高亮、自动补全或语法诊断依赖。

## 10. 保存数据流

完整保存链路：

```text
StoredSource.document
        ↓
SourceEditorDraft + SourceSearchBookDraft
        ↓
用户修改 UI 草稿
        ↓
SourceEditor 统一校验
        ↓
基础字段 applyTo(original)
        ↓
searchBook draft applyTo(updatedDocument)
        ↓
新的 SourceDocument
        ↓
SourcePage.onSave
        ↓
SourceController.updateSource(id, document)
        ↓
Repository.updateSource
        ↓
SQLite
        ↓
Controller.reload
```

保存仍是整个 SourceDocument 的一次原子提交概念，不提供“只保存 searchBook”的独立按钮。

## 11. 保存失败与切换行为

沿用已经通过测试的 SourceEditor 行为：

- Repository 保存失败时，Page 显示 `保存失败：<message>`。
- Controller 不 reload。
- 当前 mounted Editor 保留用户草稿。
- 不把异常 rethrow 到 Flutter 按钮事件循环。
- 从书源 A 切换到数据库 id 不同的书源 B 时，整个 Draft 必须重新从 B 的 `SourceDocument` 初始化。
- 窄屏返回列表仍然直接丢弃未保存草稿，第一阶段不增加 dirty confirmation。

## 12. 不在本轮进行的规则验证

Source Workbench 本轮只保证“可安全编辑和保存 raw JSON”，不证明规则运行正确。

明确不做：

- 网络请求。
- `%@keyWord` 等替换变量执行。
- `@js:` 运行。
- XPath/DOM/CSS 规则解析。
- `JSParser` 语法检查。
- 搜索结果模型解析。
- 请求/响应日志。
- 耗时统计。

这些属于 Source Tester。

## 13. 枚举常量

从旧项目领域资料迁移以下已知枚举，但不迁移旧 FormModel schema：

### source type

```text
text   -> 文本/小说
comic  -> 图片/漫画/壁纸
audio  -> 音频/音乐/听书
video  -> 视频/电影/电视剧
```

本轮 searchBook UI 不要求新增 sourceType 编辑控件，但枚举可以作为后续基础信息扩展的领域资料。

### requestParamsEncode

```text
utf-8       -> utf-8
2147485234  -> gbk
```

### responseEncode

```text
utf-8       -> utf-8
2147485232  -> 简体中文(gb2312)
2147485234  -> 简体中文(gbk)
```

### responseFormatType

```text
str       -> 普通字符串
base64str -> Base64 字符串
html      -> DOM
xml       -> XML 结构
json      -> JSON 结构
data      -> 原始数据流
filePath  -> 文件路径
```

枚举定义应放在 domain/presentation-neutral 的位置，不能写死在 widget 内。

## 14. 测试策略

### 14.1 Domain

测试 `SourceActionDocument` / `SourceSearchBookDocument`：

1. 正确读取共同字段和 searchBook 专属字段。
2. 修改已知字段时保留未知嵌套字段。
3. `actionID/parserID` 保留。
4. 未知 enum 值原样保留。
5. `SourceDocument.copyWithSearchBook()` 不修改其他顶层 raw 字段。
6. raw `searchBook` 非 Map 时 getter 返回 null，但原始 raw 值仍保留。

### 14.2 Draft

测试：

1. 有 searchBook 时完整映射到 Draft。
2. 没有 searchBook 时得到空草稿，但 apply 空草稿不创建对象。
3. 从无 searchBook 开始填写任一实际字段后，保存创建 `actionID=searchBook`、`parserID=DOM`。
4. 原有 searchBook 只含元数据时不会被删除。
5. nullable enum 缺失时保持 null。
6. unknown enum round-trip。
7. `moreKeys` Map/List 未修改时保持原始类型。
8. 结构化 `moreKeys` 修改为合法 JSON 后按结构化值写回。
9. 结构化 `moreKeys` 修改为非法 JSON 时返回本地校验错误，不生成待保存文档。

### 14.3 Widget

`SearchBookEditor` 测试重点是行为，不锁死 card/tab 等具体布局：

1. 主要字段能显示 Draft 值。
2. 输入变化通过 typed callback 回传。
3. enum 能选择已知值。
4. unknown enum 能作为当前值显示。
5. 更多配置可被用户访问。
6. `JSParser` / `moreKeys` 支持多行文本。

不要用测试把“必须是 ExpansionTile”之类的视觉实现固化成产品契约。

### 14.4 SourceEditor

测试：

1. 基础字段和 searchBook 同一次保存生成一个新 `SourceDocument`。
2. unknown top-level + unknown searchBook nested raw 都保留。
3. 本地 `moreKeys` 校验失败不调用 onSave。
4. 保存过程中继续禁止重复提交。
5. source.id 变化时基础 Draft 和 searchBook Draft 一起重载。

### 14.5 Integration

至少增加一条真实 SQLite 链路证明：

```text
导入/已有 StoredSource
 -> 选择
 -> 修改 searchBook.bookName/requestInfo
 -> 保存
 -> SQLite update
 -> Controller reload
 -> 再次读取仍为新值
 -> 未知 raw 字段仍存在
```

## 15. OmniRoute 边界

主模型负责：

- action domain facade。
- `SourceDocument` action 接口。
- Draft 与 raw-preservation 测试。
- `moreKeys` 表示兼容。
- SourceEditor session/data-flow 整合。
- SQLite integration regression。

OmniRoute 可以承担边界清晰的 presentation 工作，例如：

- `RuleTextField` 等机械控件。
- `SearchBookEditor` section UI。
- 已定义行为下的 widget tests。

每个 OmniRoute 工单仍必须限制精确文件并要求 focused/full test、analyze、`git diff --check` 全绿。不得再制造“公共 API required 参数变化但禁止改调用点”的暂时红分支。

## 16. 本轮实现范围

本轮实现：

```text
SourceActionDocument
SourceSearchBookDocument
SourceDocument.searchBook / copyWithSearchBook
SourceSearchBookDraft
searchBook enum constants
SearchBookEditor
SourceEditor 与 searchBook Draft 的组合
保存后的 SQLite/reload 集成回归
```

本轮不实现：

```text
bookDetail UI/Draft
chapterList UI/Draft
chapterContent UI/Draft
bookWorld/shudanList 动态分组
顶层全部基础字段补齐
raw JSON 编辑器
规则执行器
Source Tester runtime
代码高亮/自动补全
创建/删除书源
dirty confirmation
```

## 17. 完成标准

本轮完成后，应能安全完成：

```text
选择一个已有书源
    ↓
打开书籍搜索配置
    ↓
编辑 requestInfo / 响应规则 / 更多配置
    ↓
与基础字段一起保存
    ↓
SQLite 持久化
    ↓
Controller reload
    ↓
重新打开后值一致
    ↓
顶层未知字段 + searchBook 未知字段均未丢失
```

同时领域边界已经足够稳定，使后续 `bookDetail`、`chapterList`、`chapterContent` 可以复用 action 基础能力，而不要求再次重构 `SourceDocument` 或保存链路。