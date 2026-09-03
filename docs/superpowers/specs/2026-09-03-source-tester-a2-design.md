# Source Tester A2 Design

Date: 2026-09-03
Status: Approved design
Branch: `revival/flutter-workbench`

## 1. Goal

Source Tester A2 adds the second executable rule-testing path to Source Reader: an independent `bookDetail` test.

A2 deliberately does not run Search first. The user provides the upper-level result URL manually, Tester reloads the persisted source by database id, executes the persisted `bookDetail` configuration, and exposes:

- the resolved request
- the HTTP response
- parsed book-detail metadata
- per-rule parser traces and warnings

The intended progression remains:

```text
Search -> Book Detail -> Chapter List -> Chapter Content
```

A2 covers only Book Detail.

## 2. Core invariants

### 2.1 Persisted state only

Tester receives only `sourceId` plus test input. Before every run, the Runner reloads the source from `SourceRepository`.

It must not execute an unsaved Workbench draft.

Example:

```text
SQLite sourceUrl = https://saved.example
Workbench draft sourceUrl = https://draft.example
Draft is not saved

Book Detail parentResult = /book/1

Run Tester
    ↓
request must resolve from https://saved.example
```

The UI continues to state:

```text
测试使用已保存版本
```

### 2.2 Raw JSON remains the source of truth

`SourceDocument` and action-specific document types are typed facades over raw JSON. Unknown historical or future fields must survive import, load, save, and export unchanged.

A2 does not normalize a source into an exhaustive DTO.

### 2.3 A2 extends Source Tester, not a second Tester subsystem

A2 reuses the existing HTTP, decoding, parser, and diagnostic infrastructure. Search and Book Detail keep independent Runner and result models because their orchestration and response shapes differ.

### 2.4 No Reader persistence

A2 adds no `books`, `chapters`, tester-history, cache, or other Reader tables. No database migration is required.

## 3. Scope

### 3.1 Supported in A2

- `StandarReader` sources only
- persisted `bookDetail` only
- independent manual upper-level result input
- GET requests only
- inherited request URL when `bookDetail.requestInfo` is absent/blank
- `%@result` substitution
- fixed absolute `bookDetail.requestInfo`
- fixed relative `bookDetail.requestInfo`
- global/top-level `httpHeaders`
- optional `bookDetail.httpHeaders` overriding same-name global headers
- UTF-8 response decoding
- GB2312/GBK response decoding using the same compatibility values as A1
- HTML response parsing through XPath
- JSON response parsing through legacy slash paths and standard JSONPath
- `||` rule pipelines
- partial declarative execution before unsupported JavaScript stages
- detail fields:
  - `cover`
  - `desc`
  - `cat`
  - `status`
  - `wordCount`
  - `lastChapterTitle`
- relative cover URL completion
- request/response/parser diagnostics
- mode switching inside the existing Source Tester page

### 3.2 Explicitly unsupported in A2

- automatic Search -> Book Detail execution
- `chapterList`
- `chapterContent`
- POST
- `httpParams`
- JavaScript runtime
- request strings beginning with `@js:`
- `%@js`
- inline `@js:` execution
- `JSParser` execution
- cookie persistence/management
- `forbidCookie`
- automatic retry / `tryCount`
- `cacheTime`
- WebView / `webViewJs`
- source regex execution beyond already-supported declarative parsing
- automatic pagination
- test-history persistence
- cover image fetching
- Web as a release acceptance platform
- `bookDetail` editing UI

Unsupported behavior must be reported explicitly. A2 must not silently guess an equivalent behavior.

## 4. Why Book Detail Editor is not part of A2

The current Workbench editing UI intentionally implements only `searchBook`. Earlier Source Rule Editor design reserved domain shapes for the remaining three main actions but explicitly deferred their Draft and presentation work.

A2 keeps that separation.

Combining the following in one milestone would bind two independent risk areas:

```text
Source Tester runtime expansion
+
Source Editor persistence/presentation expansion
```

Imported real-world sources already provide persisted `bookDetail` rules that can validate runtime compatibility. After A2 is stable, `bookDetail` editing should be implemented as a separate Source Rule Editor milestone using the domain boundary validated by A2.

## 5. Domain model

### 5.1 `SourceBookDetailDocument`

Add a typed raw-JSON facade:

```text
SourceBookDetailDocument
- action: SourceActionDocument
- cover
- desc
- cat
- status
- wordCount
- lastChapterTitle
```

It follows the same rules as `SourceSearchBookDocument`:

- raw JSON is retained internally
- getters expose only known string fields
- unknown fields are preserved
- `toRaw()` returns a defensive top-level copy

A2 does not require `createDefault()`, a Draft type, or presentation mutation APIs.

### 5.2 `SourceDocument.bookDetail`

Add:

```dart
SourceBookDetailDocument? get bookDetail;
```

Return a typed facade only when raw `bookDetail` is a Map with string keys that can be represented safely. Otherwise return null while preserving the original raw value.

A2 does not require `copyWithBookDetail()` because Tester is read-only.

### 5.3 Shared action fields

Continue using `SourceActionDocument` for:

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

No duplicate `bookDetail` action DTO is introduced.

## 6. Architecture

The target execution shape is:

```text
                        SourceTesterPage
                              |
                  +-----------+-----------+
                  |                       |
             SearchBook              BookDetail
                  |                       |
        SearchBookTestRunner      BookDetailTestRunner
                  |                       |
        SearchBookRequestBuilder  BookDetailRequestBuilder
                  +-----------+-----------+
                              |
                 SourceActionRequestBuilder
                              |
                   SourceHttpExecutor
                              |
                 SourceResponseDecoder
                              |
                 SourceRuleParserRegistry
                    |               |
               HTML/XPath          JSON
                              |
              SourceRulePipelineEvaluator
                  +-----------+-----------+
                  |                       |
      SearchBookResultParser    BookDetailResultParser
```

### 6.1 Business orchestration remains separate

Keep:

- `SearchBookTestRunner`
- `BookDetailTestRunner`

Do not introduce a universal generic Runner.

Search is a list-oriented workflow, while Book Detail parses one document context into one metadata result. Their failure semantics and input models are different enough that a shared universal Runner would obscure behavior rather than reduce duplication.

### 6.2 Runtime infrastructure is shared

Share only proven deterministic behavior:

- action request construction primitives
- HTTP executor
- response decoder
- parser registry
- parser adapters
- rule pipeline evaluator
- request/response snapshots
- rule trace model
- shared report tabs

A2 must not prematurely build a general-purpose 香色 execution engine.

## 7. Input model

Define:

```text
BookDetailTestInput
- parentResult: String
```

Presentation label:

```text
上一级结果 URL
```

Helper text:

```text
通常填写 searchBook.detailUrl。
requestInfo 为空或包含 %@result 时需要填写。
```

`parentResult` is not unconditionally required. Its necessity depends on persisted `bookDetail.requestInfo`.

## 8. Request semantics

A2 must preserve historical child-action URL inheritance.

### 8.1 Blank `requestInfo`

When `bookDetail.requestInfo` is missing or blank:

```text
parentResult -> effective request text
```

`parentResult` is required in this case.

If it is relative, resolve it against persisted `sourceUrl`.

Example:

```text
sourceUrl = https://example.com
parentResult = /book/123
bookDetail.requestInfo = empty

final request = https://example.com/book/123
```

A blank `bookDetail.requestInfo` is valid and must not produce A1's `requestInfoMissing` failure.

### 8.2 `%@result`

When configured request info contains `%@result`, replace it with the exact `parentResult` text.

Example:

```text
parentResult = https://example.com/book/123?a=1
requestInfo = /proxy?target=%@result

resolved request text = /proxy?target=https://example.com/book/123?a=1
```

A2 intentionally does not automatically percent-encode `%@result`.

`%@result` represents an upper-level rule output, which may already be a path, URL, or preformatted token. Runtime-side encoding would alter historical rule semantics.

### 8.3 Fixed configured request

If `requestInfo` is non-empty and contains no `%@result`, execute it directly. `parentResult` may be empty.

The request may be absolute or relative to persisted `sourceUrl`.

### 8.4 Unknown placeholders

After Book Detail-specific substitution, any remaining placeholder matching `%@...` is rejected with `unknownPlaceholder`.

A2 does not invent values for:

```text
%@keyWord
%@pageIndex
%@offset
%@filter
```

although those placeholders exist in broader historical documentation. An independent Book Detail test has no such inputs.

### 8.5 Script requests

A configured request beginning with `@js:` or containing `%@js` remains unsupported and fails before any network call.

## 9. Request builder refactor

The existing A1 `SourceRequestBuilder` is search-specific and must not be copied for every action.

Refactor into three focused layers.

### 9.1 `SourceActionRequestBuilder`

Responsible only for shared deterministic request work:

- absolute/relative URI resolution
- `http` / `https` validation
- persisted `sourceUrl` fallback
- global header parsing
- action header parsing
- case-insensitive action-over-global header override
- residual unknown-placeholder rejection
- GET `SourceHttpRequest` construction

It must not know Search keyword/page semantics or Book Detail parent-result semantics.

### 9.2 `SearchBookRequestBuilder`

Preserve A1 behavior exactly:

```text
%@keyWord
%@filter
%@pageIndex
%@offset
```

including UTF-8 / GBK keyword and filter percent encoding.

Existing A1 request-builder tests are behavioral locks. The refactor must not change their observable outputs or failures.

### 9.3 `BookDetailRequestBuilder`

Responsible only for:

- deciding whether blank request info inherits `parentResult`
- determining whether `parentResult` is required
- raw `%@result` substitution
- passing the resulting request text and `bookDetail` action into `SourceActionRequestBuilder`

## 10. Header policy

Reuse A1 behavior unchanged.

Header sources:

```text
source.httpHeaders
+
bookDetail.httpHeaders
```

Action header names override global header names case-insensitively.

Accepted raw representations remain:

- Map-like object
- JSON string containing an object

String, number, and boolean values are converted to strings.

Invalid nested/list/null entries are skipped with warnings where A1 already does so. Invalid header JSON or a non-object top-level value produces `invalidHeaders`.

The runtime must not inject a hidden browser User-Agent.

## 11. HTTP execution

Reuse A1 `SourceHttpExecutor` and production adapter unchanged.

Policy remains:

- GET only
- timeout: 20 seconds
- maximum redirects: 5
- maximum response body: 5 MiB
- no automatic retry

HTTP 4xx/5xx remains a valid Tester response. Status, headers, decoded body, parser outcome, and HTTP warning are retained in the report.

Transport failures such as DNS/TLS/network failure, timeout, and body limit overflow remain structured execution errors.

## 12. Response decoding

Reuse A1 decoding behavior unchanged.

Configured `responseEncode` wins:

```text
utf-8        -> UTF-8
2147485232   -> GBK-compatible decoder, covering GB2312 content
2147485234   -> GBK
```

Without an explicit supported value:

1. use a recognized supported `Content-Type` charset
2. otherwise default to UTF-8

Malformed UTF-8 may use replacement characters while recording a warning.

Decoded body remains available to the response diagnostics view.

## 13. Parser registry

A1 currently performs parser selection inside its Runner. A2 makes the already-planned registry explicit:

```text
SourceRuleParserRegistry
```

Selection remains deterministic:

```text
html -> HTML/XPath parser
json -> JSON parser
```

Missing `responseFormatType` remains the legacy default `str`, not inferred from `parserID=DOM`.

`str`, `base64str`, `xml`, `data`, `filePath`, and unknown formats remain unsupported for declarative A1/A2 parsing and produce `unsupportedResponseFormat`.

A2 must not silently reinterpret persisted format settings.

## 14. Rule pipeline evaluator

A1 currently owns common pipeline evaluation logic inside `SearchBookResultParser`. A2 requires the same behavior and therefore extracts it to a Source Reader-owned application service:

```text
SourceRulePipelineEvaluator
```

Suggested result shape:

```text
SourceRulePipelineEvaluation
- value
- contexts
- stages
- warnings
- errors
- partial
- executedDeclarative
```

Both Search and Book Detail parsers consume this service.

The extraction is a behavior-preserving A1 refactor, not a semantic rewrite.

### 14.1 `||`

Continue treating `||` as a transformation pipeline, not fallback syntax.

Existing tokenizer rules remain responsible for avoiding false splits inside quoted strings or nested JSONPath constructs.

### 14.2 JavaScript stages

A2 never executes JavaScript.

For:

```text
//div/text() || @js: ...
```

the declarative prefix executes, its output is retained, then the pipeline stops and records a partial unsupported-JS warning.

For a JS-only field, no parsed value is produced and the trace is marked partial.

Configured `bookDetail.JSParser` does not prevent declarative field rules from being tested; it is reported as skipped/unsupported.

## 15. Book Detail result parsing

Define:

```text
BookDetailResultParser
```

Book Detail is root-oriented rather than list-oriented.

Conceptually:

```text
response root
  |- cover
  |- desc
  |- cat
  |- status
  |- wordCount
  `- lastChapterTitle
```

There is no `list` rule and no list context requirement.

### 15.1 All detail fields are optional

No individual response field is structurally required.

A source may configure only one or two Book Detail fields and still be valid for A2 execution.

### 15.2 Per-field failure isolation

If one configured field fails, set only that field to null/empty and capture its trace error. Continue evaluating remaining fields.

One malformed rule must not abort the entire detail parse.

### 15.3 No configured fields

If none of the six supported fields has an executable rule, still retain successful request/response diagnostics.

Return an empty detail result plus a warning such as:

```text
bookDetail 未配置可执行响应规则
```

Do not turn this into a fatal network/test error.

### 15.4 JavaScript parser warning

If `bookDetail.JSParser` is configured, append an explicit warning that A2 did not execute it.

## 16. `moreKeys`

A2 does not expand compatibility via `moreKeys`.

Values such as the following do not alter Book Detail execution:

```text
skipCount
pageSize
maxPage
removeHtmlKeys
requestFilters
```

Configured unsupported keys may be surfaced as diagnostics.

Malformed `moreKeys` JSON remains a warning rather than a fatal test failure.

`skipCount` is specifically not applied to Book Detail because Book Detail has no list result.

## 17. URL normalization

Among A2 result fields, `cover` receives URL normalization.

For a relative cover output:

1. resolve against final HTTP response URI
2. fall back to persisted `sourceUrl`

Already-absolute URLs remain unchanged.

A2 does not fetch the cover image. It displays only the resulting URL text.

## 18. Report model

Keep shared diagnostics independent from action-specific result models.

### 18.1 Shared models

Continue using/refining:

```text
SourceRuleTrace
SourceTestRequestSnapshot
SourceTestResponseSnapshot
```

Rename A1-specific outcome terminology to a shared enum:

```text
SourceTestOutcome
- success
- completedWithWarnings
```

Both Search and Book Detail reports use it.

### 18.2 `BookDetailTestInputSnapshot`

Suggested shape:

```text
BookDetailTestInputSnapshot
- parentResult
```

### 18.3 `BookDetailTestResult`

Suggested shape:

```text
BookDetailTestResult
- cover
- desc
- cat
- status
- wordCount
- lastChapterTitle
```

### 18.4 `BookDetailTestReport`

Suggested shape:

```text
BookDetailTestReport
- sourceId
- sourceName
- platform
- input
- request
- response
- result
- traces
- warnings
- outcome
```

Do not introduce a highly generic `GenericTestReport<T...>` abstraction.

## 19. Request origin diagnostics

A2 introduces inherited requests, so request diagnostics should record where the request came from.

Define a shared concept similar to:

```text
SourceTestRequestOrigin
- configuredRequestInfo
- inheritedParentResult
```

The Request view can then render:

```text
请求来源：bookDetail.requestInfo
```

or:

```text
请求来源：继承上一级结果 URL
```

A1 always uses `configuredRequestInfo`.

This avoids confusing diagnostics where original `requestInfo` is blank but a valid request was executed.

## 20. Error semantics

Extend `SourceTestFailureReason` with Book Detail-specific reasons:

```text
bookDetailMissing
parentResultMissing
```

Existing shared reasons remain reusable:

```text
sourceNotFound
unsupportedPlatform
unsupportedScriptRequest
unknownPlaceholder
invalidBaseUrl
invalidHeaders
unsupportedRequestEncoding
transportFailure
timeout
responseTooLarge
unsupportedResponseEncoding
unsupportedResponseFormat
responseParseFailure
```

Search-specific reasons remain:

```text
searchBookMissing
requestInfoMissing
listRuleFailure
```

A2 must not use `requestInfoMissing` for blank `bookDetail.requestInfo`, because blank request info is valid inheritance semantics.

Presentation maps structured reasons to concise Chinese messages and retains detailed diagnostics where possible.

## 21. Runner orchestration

Define:

```text
BookDetailTestRunner
```

Execution order:

```text
repository.getSource(sourceId)
    ↓
validate source exists
    ↓
validate platform == StandarReader
    ↓
validate persisted bookDetail exists
    ↓
BookDetailRequestBuilder
    ↓
SourceHttpExecutor
    ↓
SourceResponseDecoder
    ↓
SourceRuleParserRegistry
    ↓
BookDetailResultParser
    ↓
collect warnings + HTTP warning + trace diagnostics
    ↓
BookDetailTestReport
```

Outcome rule mirrors A1:

- no warning and no trace diagnostics -> `success`
- otherwise -> `completedWithWarnings`

## 22. Presentation

### 22.1 Tester mode selector

The existing `SourceTesterPage(sourceId)` remains the entry point.

Add a simple two-mode selector near the top:

```text
[ 搜索测试 ] [ 书籍详情 ]
```

A Flutter `SegmentedButton` is appropriate, but the exact widget is presentation detail rather than an architecture contract.

Default mode remains Search to preserve A1 behavior.

### 22.2 Search mode

Keep existing A1 interaction and semantics unchanged:

```text
关键词
页码
高级参数
运行搜索测试
```

Existing useful widget keys should remain stable where practical.

### 22.3 Book Detail mode

Input area:

```text
上一级结果 URL

通常填写 searchBook.detailUrl。
requestInfo 为空或包含 %@result 时需要填写。

运行详情测试
```

The UI does not decide definitively whether the input is required; Runner/request-builder validation remains authoritative because only persisted request configuration determines that requirement.

### 22.4 Report tabs

Both modes use:

```text
结果 | 请求 | 响应 | 解析日志
```

Book Detail Result shows six fixed fields so missing values are visually obvious while debugging:

```text
封面
简介
分类
状态
字数
最新章节
```

Missing values may render as `—`.

## 23. Shared report presentation

The current A1 report widget couples all four tabs directly to `SearchBookTestReport`.

A2 should extract a small shared diagnostic shell such as:

```text
SourceTestReportTabs
```

Shared responsibilities:

- TabBar
- Request view
- Response view
- Trace view

Action-specific Result content remains separate:

```text
SearchBookResultsView
BookDetailResultView
```

Do not introduce a universal business result renderer.

## 24. Page state semantics

`SourceTesterPage` may keep action-specific report state independently:

```text
mode
SearchBookTestReport?
BookDetailTestReport?
running
error
```

Switching modes does not discard the previous report. A user can run Search, run Book Detail, then switch back and still inspect the Search report.

While one run is in progress, disable mode switching or otherwise guarantee that an asynchronous result cannot be rendered into the wrong mode. The simplest A2 policy is to disable switching during a run.

## 25. Providers

Continue provider-managed infrastructure lifecycles.

Add providers for narrow A2 services, including:

- shared action request builder
- search request builder after refactor
- book-detail request builder
- parser registry
- pipeline evaluator
- book-detail result parser
- book-detail runner

The HTTP executor provider continues to own/close its production client.

Runners continue to reload persisted data through the existing `SourceRepository` provider.

## 26. Platform networking

A1 already made the minimum required native network-policy changes. A2 should not duplicate or broaden them.

Acceptance targets remain native Flutter platforms where ordinary networking is available:

- Android
- iOS
- macOS
- Windows
- Linux

Web remains excluded as a general third-party source tester because browser CORS prevents arbitrary source requests without a proxy architecture.

## 27. Testing strategy

CI must never depend on live novel websites.

Use fixtures, fake HTTP executors, mock clients where appropriate, and real local Drift only for integration boundaries.

### 27.1 Domain tests

Cover at least:

- valid `bookDetail` raw Map -> typed facade
- six known field getters
- shared action access
- unknown fields preserved by raw facade behavior
- malformed/non-Map `bookDetail` -> null accessor while raw value remains preserved

### 27.2 Shared request refactor regression

Before adding Book Detail behavior, lock the existing Search behavior through tests.

After `SourceActionRequestBuilder` extraction, all A1 request tests must continue to pass unchanged in observable behavior:

- UTF-8 keyword encoding
- GBK keyword encoding
- placeholder substitution
- unknown-placeholder rejection
- relative URL resolution
- header parsing/override
- invalid-header behavior

### 27.3 Book Detail request tests

Cover at least:

- blank request info + absolute parent result
- blank request info + relative parent result
- `%@result` raw substitution
- fixed absolute request without parent result
- fixed relative request without parent result
- missing parent result when inheritance requires it
- missing parent result when `%@result` requires it
- unknown placeholder
- script request rejection
- global/action header override
- invalid headers
- request-origin snapshot semantics

### 27.4 Pipeline extraction regression

A1 parser/pipeline tests must remain green while moving common pipeline logic out of `SearchBookResultParser`.

Lock at least:

- tokenization that preserves quoted/nested `||`
- declarative pipeline stages
- supported prefix before JS
- JS-only stage
- trace warning/error semantics

### 27.5 Book Detail parser tests

HTML fixtures:

- `cover`
- `desc`
- `cat`
- `status`
- `wordCount`
- `lastChapterTitle`
- relative cover normalization

JSON fixtures:

- legacy slash paths
- standard JSONPath

Failure behavior:

- one field failure does not abort other fields
- JS suffix creates partial result
- JS-only field yields no value with diagnostic
- configured `JSParser` warning
- no configured fields returns empty result plus warning
- malformed response/root produces the appropriate structured parser failure where root creation itself is impossible

### 27.6 Runner tests

Cover at least:

- source not found
- unsupported platform
- missing `bookDetail`
- inherited request path
- configured request path
- UTF-8 response
- GBK response
- HTTP 404 retained with warning
- HTTP 500 retained with warning
- transport failure
- parser warnings
- final `SourceTestOutcome`

### 27.7 Presentation tests

Cover at least:

- Search remains default mode
- switching to Book Detail
- Book Detail parent-result input/help text
- running/loading state
- successful detail result fields
- request origin display
- response display
- parser trace display
- structured error mapping
- previous Search report preserved after mode switch
- previous Book Detail report preserved after mode switch
- unsafe mode switch prevented while running

### 27.8 Real SQLite integration

At minimum verify:

```text
Drift
 -> SqliteSourceRepository
 -> BookDetailTestRunner
 -> fake HTTP
 -> decoder
 -> parser
 -> BookDetailTestReport
```

No external network dependency.

### 27.9 Persisted-vs-draft integration regression

At minimum:

```text
SQLite source contains saved sourceUrl/bookDetail
Workbench opens source and changes sourceUrl without saving
Open Tester in Book Detail mode
Run with relative parentResult
Tester must use persisted SQLite sourceUrl/bookDetail
Return to Workbench
Unsaved draft must remain unchanged
```

The existing A1 persisted-state integration regression must continue to pass.

### 27.10 Full regression gate

Existing Source Workbench, import/export, rule editor, persistence, and Source Tester A1 tests must remain green.

## 28. CI and reproducibility

Keep the current Flutter verification environment and hosted-package source stable.

CI continues to run:

```text
flutter pub get
build_runner
flutter analyze
flutter test
clean worktree checks
git diff --check
```

The workflow step currently named around A1 may be renamed to a Source Tester-generic label when A2 begins, while preserving the same baseline diff verification unless a later plan deliberately changes that baseline.

A2 should not introduce new runtime package dependencies unless implementation proves one is strictly necessary. The current HTTP, encoding, XPath, and JSONPath dependencies are expected to be sufficient.

## 29. OmniRoute boundary

OmniRoute may receive only small deterministic presentation tasks with strict file allowlists, for example:

- Book Detail input panel
- Book Detail result widget
- Source Tester mode selector

Each delegated task should have narrow expected text/keys and a focused widget test.

Do not delegate the following to OmniRoute:

- `SourceBookDetailDocument` compatibility boundary
- shared request-builder refactor
- `%@result` semantics
- header/encoding behavior
- pipeline evaluator extraction
- parser registry
- Book Detail parser
- Runner orchestration
- report-domain changes
- persisted-state integration

## 30. Implementation sequencing constraints

The implementation plan should preserve A1 during every refactor rather than performing a large rewrite followed by recovery.

Recommended sequencing:

```text
1. Book Detail domain facade
2. Extract shared action request builder
3. Prove A1 request behavior remains green
4. Add Book Detail request builder
5. Extract shared pipeline evaluator
6. Prove A1 parser behavior remains green
7. Add Book Detail result parser
8. Add parser registry
9. Add Book Detail Runner/report/providers
10. Add Book Detail presentation components
11. Integrate mode switching
12. Add SQLite/persisted-draft integration regressions
13. Full analyze/test/cleanliness verification
```

Implementation tasks should use RED -> GREEN -> regression verification and remain small enough that failures are attributable to one boundary.

## 31. Acceptance criteria

A2 is complete only when all of the following are true:

1. A saved `StandarReader` with persisted `bookDetail` can be tested independently by supplying an upper-level result URL where required.
2. Blank `bookDetail.requestInfo` correctly inherits the upper-level result instead of failing with `requestInfoMissing`.
3. `%@result` uses raw substitution and does not receive implicit URL encoding.
4. Fixed `bookDetail.requestInfo` can execute without a parent result when it does not reference `%@result`.
5. Shared request infrastructure preserves all A1 Search behavior.
6. Shared pipeline infrastructure preserves all A1 parser behavior.
7. HTML XPath and JSON rules can parse all six supported detail fields.
8. One field failure does not abort other fields.
9. JavaScript remains explicit unsupported/partial behavior and is never silently executed.
10. Request, response, result, and parser traces are inspectable in the existing Tester page.
11. Search remains the default mode and prior reports survive mode switches.
12. Tester continues to execute persisted SQLite state rather than unsaved Workbench draft state.
13. No Reader/test-history database tables or migrations are added.
14. No live-site CI dependency is introduced.
15. Full Flutter analyze/test and repository cleanliness verification pass.