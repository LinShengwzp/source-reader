# OR-005：实现 SearchBookEditor 纯 UI 组件

## 任务性质

这是一个严格受控的机械 Presentation 任务。

只实现 `searchBook` 规则编辑表单、小型显式字段组件以及对应 widget tests。不要接 Riverpod，不接 `SourceEditor` / `SourcePage`，不访问 Repository / Drift / SQLite，也不要直接读写 raw JSON。

本工单开始时，Domain 与 Draft 已由强模型实现并经过 CI 验证。你只能消费它们，不得修改它们。

## 开始前

在仓库根目录执行：

```bash
git branch --show-current
git status --short
git pull --ff-only
```

必须满足：

- 当前分支为 `revival/flutter-workbench`。
- 开始前 working tree 为空。
- `git pull --ff-only` 成功。
- 不允许 rebase、reset、force push、amend 或改写历史。

如果任一条件不满足，停止并报告，不要自行处理未知本地修改。

## 唯一允许修改的文件

只允许创建以下 3 个文件：

```text
app/lib/features/sources/presentation/source_rule_fields.dart
app/lib/features/sources/presentation/source_search_book_editor.dart
app/test/features/sources/presentation/source_search_book_editor_test.dart
```

除此之外禁止修改任何文件，包括但不限于：

```text
app/lib/features/sources/presentation/source_search_book_draft.dart
app/lib/features/sources/presentation/source_editor.dart
app/lib/features/sources/presentation/source_editor_draft.dart
app/lib/features/sources/presentation/source_page.dart
app/lib/features/sources/application/**
app/lib/features/sources/domain/**
app/lib/features/sources/data/**
app/lib/core/**
app/pubspec.yaml
app/pubspec.lock
app/analysis_options.yaml
docs/**
.github/**
```

如果 Flutter 命令自动改写禁止文件，提交前恢复到 HEAD。

## 已存在的输入

### `SourceSearchBookDraft`

已经存在：

```text
app/lib/features/sources/presentation/source_search_book_draft.dart
```

它是本组件唯一的编辑数据模型。公开字段包括：

```dart
String requestInfo
String list
String bookName
String author
String cover
String desc
String cat
String status
String wordCount
String lastChapterTitle
String detailUrl
String? requestParamsEncode
String? responseEncode
String? responseFormatType
String success
String jsParser
String moreKeysText
```

以及：

```dart
SourceSearchBookDraft copyWith({...})
String? get moreKeysValidationError
```

`SearchBookEditor` 只能通过：

```dart
onChanged(value.copyWith(...))
```

向父组件提交新 Draft。

禁止：

- 调用 `applyTo()` 保存；
- 构造或修改 raw Map；
- 访问 `SourceDocument`；
- 自己实现 dirty-field 逻辑；
- 自己解析或序列化 `moreKeys`。

这些责任已经属于 Draft。

### `SourceRuleOptions`

已经存在：

```text
app/lib/features/sources/domain/source_rule_options.dart
```

必须直接复用，不要在 Widget 内重新写死协议值。

当前固定选项为：

```text
requestParamsEncode
- utf-8        -> utf-8
- 2147485234   -> gbk

responseEncode
- utf-8        -> utf-8
- 2147485232   -> 简体中文(gb2312)
- 2147485234   -> 简体中文(gbk)

responseFormatType
- str          -> 普通字符串
- base64str    -> Base64 字符串
- html         -> DOM
- xml          -> XML 结构
- json         -> JSON 结构
- data         -> 原始数据流
- filePath     -> 文件路径
```

## 目标接口

创建：

```dart
final class SearchBookEditor extends StatelessWidget {
  const SearchBookEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final SourceSearchBookDraft value;
  final ValueChanged<SourceSearchBookDraft> onChanged;
}
```

这个组件：

- 不保存；
- 不显示保存按钮；
- 不显示成功/失败 Snackbar；
- 不持有 source id 或 selection state；
- 不访问 raw JSON。

父级 `SourceEditor` 会在后续任务中统一负责会话状态和最终保存。

## 禁止动态 schema 引擎

本任务只允许显式、小型、类型明确的 Flutter Widget。

`source_rule_fields.dart` 可以包含类似：

```dart
final class RuleTextField extends StatelessWidget { ... }
final class RuleMultilineField extends StatelessWidget { ... }
final class RuleEnumField extends StatelessWidget { ... }
final class EditorSectionCard extends StatelessWidget { ... }
```

但禁止引入：

```text
RuleFieldSchema
RuleFieldDefinition
string model path
runtime reflection
generic Map mutation
callback registry
field-name switch dispatcher
动态表单 schema engine
```

不要为了后续 `bookDetail/chapterList/content` 预造框架。

## 字段与稳定 Key

所有字段必须有以下稳定 Key：

```text
search-book-request-info
search-book-list
search-book-book-name
search-book-author
search-book-cover
search-book-desc
search-book-cat
search-book-status
search-book-word-count
search-book-last-chapter-title
search-book-detail-url
search-book-request-params-encode
search-book-response-encode
search-book-response-format-type
search-book-success
search-book-js-parser
search-book-more-keys
search-book-advanced
```

建议中文标签：

```text
requestInfo           请求信息
list                  结果列表
bookName              书名
作者 author            作者
cover                 封面
 desc                 简介
cat                   分类
status                状态
wordCount             字数
lastChapterTitle      最新章节
 detailUrl            详情地址
requestParamsEncode   请求参数编码
responseEncode        响应编码
responseFormatType    响应格式
success               成功判断
JSParser              JS 解析器
moreKeys              更多参数
```

标签文案可做不影响语义的小幅调整，但稳定 Key 不允许变化。

## 布局要求

可以使用普通 Column、Card、section、`ExpansionTile` 等 Flutter 原生布局。

测试不得锁死某一种容器 Widget 类型，例如不要断言“必须是 Card”。重点测试字段行为和可达性。

建议：

1. 常用搜索字段直接可见；
2. 高级字段放在高级区域；
3. 高级区域初始视觉上折叠；
4. 高级区域的入口必须使用：

```dart
const Key('search-book-advanced')
```

测试应通过这个 key 展开，而不是依赖标题文本定位。

高级区域至少包含：

```text
requestParamsEncode
responseEncode
responseFormatType
success
JSParser
moreKeys
```

父级后续会用 `ValueKey<int>(source.id)` 处理书源切换，因此本任务不要增加 source session state。

## 文本字段行为

普通文本字段在 `onChanged` 时直接发出新的 Draft，例如：

```dart
onChanged: (text) {
  onChanged(value.copyWith(bookName: text));
}
```

必须是多行输入的字段：

```text
requestInfo
JSParser
moreKeys
```

可以给其余明显可能较长的规则文本更多行数，但不要改变上面三项的多行要求。

## enum 行为

以下三个字段必须使用枚举选择控件并直接消费 `SourceRuleOptions`：

```text
requestParamsEncode
responseEncode
responseFormatType
```

### 已知值

选择后必须传协议 `value`，不是 label。例如选择 `JSON 结构` 后：

```dart
value.copyWith(responseFormatType: 'json')
```

### null

v1 没有 enum clear 操作。

当前 Draft 值为 null 时可以显示 hint / 未设置状态，但不要增加“清空”菜单项。

### 未知历史值

如果 Draft 当前值不在固定 options 中，例如：

```text
responseFormatType = future-format
```

不得：

- 自动改成第一个已知值；
- 自动置 null；
- 因 Dropdown value 不存在而抛异常。

必须在当前控件的 items 中额外加入一个临时选项：

```text
value: future-format
label: 未知值：future-format
```

只有用户主动选择另一个已知值后，才通过 `onChanged` 替换它。

这一行为必须做 widget test。

## `moreKeys` 行为

Widget 不负责判断历史 raw 是 String、Map 还是 List；Draft 已经处理了这件事。

输入框显示：

```dart
value.moreKeysText
```

用户输入 `fieldText` 时：

```dart
final candidate = value.copyWith(moreKeysText: fieldText);
onChanged(candidate);
```

错误提示必须来自候选 Draft：

```dart
candidate.moreKeysValidationError
```

或等价的、能够随当前 `value` 重建后显示：

```dart
value.moreKeysValidationError
```

错误文本必须原样显示：

```text
moreKeys 必须是有效 JSON 对象或数组
```

禁止在 Widget 中重新 `jsonDecode`。

## 严格 TDD

### 1. 先写 RED widget tests

先创建：

```text
app/test/features/sources/presentation/source_search_book_editor_test.dart
```

生产文件此时不要创建。

至少覆盖以下 6 组行为。

### 行为 A：从 Draft 初始化代表字段

构造包含代表值的 `SourceSearchBookDraft`，pump `SearchBookEditor`。

至少验证：

```text
search-book-request-info
search-book-book-name
search-book-author
```

显示 Draft 当前值。

展开高级区域后再验证至少：

```text
search-book-response-format-type
search-book-js-parser
search-book-more-keys
```

能够显示当前 Draft 值。

### 行为 B：编辑 `bookName` 发出新 Draft 且其他值不变

初始 Draft 至少同时设置：

```text
bookName = 旧书名规则
author = 作者规则
requestInfo = 请求规则
```

编辑 `search-book-book-name` 后捕获 `onChanged`：

```dart
expect(changed.bookName, '新书名规则');
expect(changed.author, original.author);
expect(changed.requestInfo, original.requestInfo);
```

只测试 Draft callback，不要保存到 SourceDocument。

### 行为 C：已知 enum 选择传协议值

展开高级区域。

将 `responseFormatType` 选择为 `json`，验证：

```dart
expect(changed.responseFormatType, 'json');
```

不要断言 callback 收到中文 label。

### 行为 D：未知 enum 原样展示

初始：

```text
responseFormatType = future-format
```

展开高级区域后必须看到：

```text
未知值：future-format
```

并且在用户没有主动选择新值前，不得触发一次把它替换成已知值的 `onChanged`。

### 行为 E：高级字段可达且多行

通过：

```dart
find.byKey(const Key('search-book-advanced'))
```

展开高级区域。

验证：

```text
search-book-js-parser
search-book-more-keys
```

对应文本输入是多行输入。

同时验证常用区：

```text
search-book-request-info
```

也是多行输入。

不要通过 Card/ExpansionTile 的具体层级结构做断言。

### 行为 F：非法结构化 `moreKeys` 显示 Draft 的本地错误

创建一个**原始 moreKeys 为 Map/List** 的 `SourceDocument`，再通过：

```dart
SourceSearchBookDraft.fromDocument(source.searchBook)
```

得到 Draft，这样 Draft 才知道它是结构化历史表示。

编辑 `search-book-more-keys` 为：

```text
{bad json
```

让测试宿主保存最新 `onChanged` Draft 并重新 pump `SearchBookEditor`（或使用等价状态宿主），然后必须看到完整错误：

```text
moreKeys 必须是有效 JSON 对象或数组
```

不要在 test 或 Widget 中复制 JSON 验证逻辑。

## 2. Verify RED

从 `app/` 运行：

```bash
flutter test test/features/sources/presentation/source_search_book_editor_test.dart
```

预期只因为：

```text
source_search_book_editor.dart
source_rule_fields.dart
SearchBookEditor
```

尚不存在而失败。

如果测试自身存在 fixture、lint、API 使用错误，先修测试并重跑，直到 RED 根因只剩目标生产 UI 缺失。

## 3. 最小 GREEN 实现

RED 正确后，再创建：

```text
app/lib/features/sources/presentation/source_rule_fields.dart
app/lib/features/sources/presentation/source_search_book_editor.dart
```

### `source_rule_fields.dart`

只做本任务真正重复的小型显式 Widget。

要求：

- 类型明确；
- 不持有业务状态；
- 不知道 SourceDocument/raw JSON；
- 不实现动态 schema；
- 不实现保存；
- `RuleEnumField` 能安全合并未知当前值；
- enum 固定选项来自调用方传入的 `SourceRuleOption` 列表或直接消费现有类型，不复制协议列表。

### `SearchBookEditor`

保持 `StatelessWidget`。

所有业务变更只调用：

```dart
onChanged(value.copyWith(...))
```

不要添加本地 Draft 副本、`setState`、Provider 或 controller session。

## 4. 验收

从 `app/` 依次执行：

```bash
flutter test test/features/sources/presentation/source_search_book_editor_test.dart
flutter analyze
flutter test
git diff --check
```

四项必须全部 GREEN。

回到仓库根目录：

```bash
git status --short
git diff --name-only
```

提交前实际修改只能是：

```text
app/lib/features/sources/presentation/source_rule_fields.dart
app/lib/features/sources/presentation/source_search_book_editor.dart
app/test/features/sources/presentation/source_search_book_editor_test.dart
```

如果存在任何其他文件修改，恢复到 HEAD 后重新验证。

## Git 提交与推送

全部验收通过后自行提交：

```bash
git add app/lib/features/sources/presentation/source_rule_fields.dart \
        app/lib/features/sources/presentation/source_search_book_editor.dart \
        app/test/features/sources/presentation/source_search_book_editor_test.dart

git commit -m "feat: add search book editor widget"
git push origin revival/flutter-workbench
```

禁止 force push。

提交后执行：

```bash
git status --short
git show --stat --oneline HEAD
```

working tree 必须为空。

## 最终反馈格式

只需返回：

```text
1. RED：focused test 的预期失败原因
2. GREEN：focused test / flutter analyze / 全量 flutter test / git diff --check 结果
3. 测试覆盖：A-F 六组行为是否全部覆盖
4. 修改文件：实际修改文件列表
5. Commit：完整 SHA + commit message
6. Push：是否成功 push revival/flutter-workbench
7. git status --short：是否为空
8. 偏差：若 Flutter API 与工单示例不同，说明最小适配；否则写“无”
```

不要继续实现 `SourceEditor` 集成、`SourcePage`、Task 5 或其他任务。
