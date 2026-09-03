# Source Tester A1 Design

Date: 2026-09-03
Status: Approved design
Branch: `revival/flutter-workbench`

## 1. Goal

Source Tester A1 adds the first executable rule-testing path to Source Reader. It tests only the persisted `searchBook` configuration of a saved `StandarReader` source.

The user selects a saved source, enters a keyword, runs the test, and can inspect:

- the resolved request
- the HTTP response
- parsed search results
- per-rule parser traces and warnings

A1 deliberately stops before JavaScript execution, POST, WebView, book detail, chapter list, and chapter content.

## 2. Core invariant: persisted state only

Tester receives a database source id, then reloads the source from `SourceRepository` before every run.

It must not read or execute an unsaved `SourceEditor` draft.

Example:

```text
SQLite source = old
Workbench draft = new, unsaved

Run Source Tester
    ↓
Tester executes SQLite source = old
```

The UI must state that testing uses the saved version.

## 3. Scope

### 3.1 Supported in A1

- `StandarReader` sources only
- `searchBook` only
- GET requests only
- request placeholders:
  - `%@keyWord`
  - `%@pageIndex`
  - `%@offset`
  - `%@filter`
- absolute request URLs
- relative request URLs resolved from persisted `sourceUrl`
- global/top-level `httpHeaders`
- optional `searchBook.httpHeaders` extension overriding same-name global headers
- UTF-8 request parameter encoding
- GBK request parameter encoding for legacy value `2147485234`
- UTF-8 response decoding
- GB2312/GBK response decoding for legacy values `2147485232` and `2147485234`
- HTML response parsing through XPath
- JSON response parsing through:
  - legacy slash paths
  - standard JSONPath when the rule starts with `$`
- `list` plus all existing `searchBook` result fields:
  - `bookName`
  - `author`
  - `cover`
  - `desc`
  - `cat`
  - `status`
  - `wordCount`
  - `lastChapterTitle`
  - `detailUrl`
- relative URL completion for `cover` and `detailUrl`
- `moreKeys.skipCount`
- parser traces
- partial execution before unsupported JavaScript pipeline stages

### 3.2 Explicitly unsupported in A1

- request strings beginning with `@js:`
- `%@js`
- inline `@js:` execution
- `JSParser`
- POST
- `httpParams`
- cookie persistence/management
- `forbidCookie`
- `cacheTime`
- automatic retry / `tryCount`
- `webView`
- `webViewJs`
- `sourceRegex`
- automatic pagination
- `bookDetail`
- `chapterList`
- `chapterContent`
- test history persistence
- Web as a release acceptance platform

Unsupported behavior must be reported explicitly. The Tester must never silently guess equivalent behavior.

## 4. Architecture

Use a dedicated feature:

```text
features/source_tester/
  domain/
  application/
  data/
  presentation/
```

Dependency direction:

```text
SourceTesterPage
      ↓
SearchBookTestRunner
      ↓
RequestBuilder
      ↓
SourceHttpExecutor
      ↓
ResponseDecoder
      ↓
SourceRuleParserRegistry
   ├─ HtmlXPathRuleParser
   └─ JsonRuleParser
      ↓
SearchBookTestReport
```

`source_tester` may depend on source-domain/read boundaries such as `StoredSource`, `SourceDocument`, `SourceSearchBookDocument`, and `SourceRepository`.

The existing Sources feature must not depend on `source_tester` domain/application internals. Presentation integration may navigate to `SourceTesterPage` by source id.

No new database table is required.

## 5. Dependencies

Add only narrow execution dependencies:

- `http` for cross-platform HTTP
- `enough_convert` for pure-Dart GBK decoding/encoding support
- `xpath_selector` and `xpath_selector_html_parser` for HTML XPath execution
- `json_path` for standard JSONPath

Before implementation proceeds beyond dependency setup, CI must prove these packages resolve and analyze together on Flutter 3.47 / Dart 3.13.

Third-party parser APIs must remain behind Source Reader-owned adapters. Application and presentation code must not depend directly on XPath/JSONPath library result types.

## 6. Request building

Define application/domain request types independent of `package:http`:

```text
SourceHttpRequest
- uri
- method (A1 always GET)
- headers

SourceHttpResponse
- statusCode
- headers
- bodyBytes
- finalUri
- duration
```

### 6.1 Placeholder values

Default test parameters:

```text
keyWord = user input
pageIndex = 1
offset = 0
filter = ""
```

Known placeholders are replaced deterministically.

Unknown `%@...` placeholders cause a structured request-build error. They are not replaced with an empty string.

### 6.2 Request parameter encoding

For `%@keyWord` and `%@filter`:

- missing or `utf-8` -> UTF-8 percent encoding
- `2147485234` -> GBK bytes followed by percent encoding

Numeric page and offset values are inserted as decimal text.

### 6.3 URL resolution

If resolved `requestInfo` is absolute, request it directly.

If it is relative, resolve it against persisted `sourceUrl`.

Missing/invalid base URL produces a structured request-build error.

A request beginning with `@js:` produces `unsupportedScriptRequest` before any network call.

### 6.4 Headers

Top-level raw `httpHeaders` may be either:

- `Map<String, Object?>`
- JSON string containing an object

A `searchBook.httpHeaders` extension may use the same representations and overrides global headers by case-insensitive header name.

Invalid header shapes produce trace warnings or a structured configuration error according to whether the entire header set is unusable. The implementation must never inject a hidden browser User-Agent.

## 7. HTTP execution

`SourceHttpExecutor` is an interface. The production adapter uses `package:http`.

A1 policy:

- timeout: 20 seconds
- maximum redirects: 5
- maximum response body: 5 MiB
- no automatic retry
- GET only

HTTP 4xx/5xx is still a valid HTTP response for Tester purposes. The report must retain status, headers, body, and parser outcome.

Transport failures such as timeout, DNS failure, TLS failure, or body-limit overflow produce structured execution errors.

## 8. Response decoding

`ResponseDecoder` receives raw bytes plus headers and action configuration.

Explicit `responseEncode` wins:

```text
utf-8        -> UTF-8
2147485232   -> GBK-compatible decoder (covers GB2312 content)
2147485234   -> GBK
```

If no explicit value exists:

1. use a recognized `Content-Type` charset when supported
2. otherwise default to UTF-8

Malformed UTF-8 may use replacement characters, but the report must record a warning.

The decoded body is retained for inspection.

## 9. Parser compatibility layer

### 9.1 Registry

Define Source Reader-owned parser interfaces. Parser selection is based on `responseFormatType`.

A1 parser mapping:

```text
html -> XPath parser
json -> JSON parser
```

Other response format types return a structured unsupported-format result in A1.

### 9.2 HTML XPath

The XPath adapter targets common legacy rules such as:

```text
//table[@class='grid']//tr
//td[1]/a
//td[1]/a/@href
//div[@id='content']/text()
```

The adapter must support evaluation relative to a list item context.

When `list` produces multiple nodes, each field rule is evaluated against that item context. A field rule beginning with `//` must not accidentally escape to the document root if legacy Source Reader semantics expect it to apply to the current item.

The exact compatibility shim belongs in the adapter and must be locked by fixture tests.

### 9.3 JSON legacy slash path

Support the historical simple syntax, including examples conceptually equivalent to:

```text
key1/key2[1]/key3
key1/key2[-1]/key3
```

Legacy array index semantics:

- `[1]` = first item
- positive indexes are one-based
- `[-1]` = last item
- negative indexes count from the end

This parser is owned by Source Reader and does not pretend to be standard JSONPath.

### 9.4 Standard JSONPath

Rules beginning with `$` are delegated to the `json_path` adapter.

Third-party JSONPath result types are converted immediately into Source Reader-owned scalar/list/node values.

## 10. Rule pipeline and `||`

Treat `||` as a transformation pipeline, not fallback syntax.

Conceptually:

```text
stage A result -> stage B input -> stage C input
```

The tokenizer must not blindly call `split('||')`. It must avoid splitting `||` occurring inside quoted strings or nested expression constructs needed by JSONPath.

### 10.1 JavaScript stages

A1 never executes JavaScript.

If a rule is:

```text
//a/@href || @js: ...
```

A1 executes the supported XPath prefix, records its output, then marks the pipeline as partial with an `unsupportedJavaScriptStage` trace.

If JavaScript is the first stage, no parsed value is produced for that field and the trace records the unsupported stage.

A configured `JSParser` does not prevent normal declarative field rules from being tested; it is reported as skipped/unsupported.

## 11. SearchBook parsing

`list` is the only structurally required response rule for A1 search-result extraction.

### 11.1 HTML

```text
decoded document
  ↓ list XPath
list contexts
  ↓ each item
field XPath rules relative to item context
```

### 11.2 JSON

```text
decoded JSON
  ↓ list legacy path / JSONPath
list values
  ↓ each item
field rules relative to item value
```

If `list` cannot be evaluated at all, parsing fails at the search-list stage.

If an individual field fails for one item, that field is empty for that item and the trace captures the failure; other items and fields continue.

### 11.3 URL normalization

For `cover` and `detailUrl`, relative output is resolved using:

1. the final HTTP response URI
2. persisted `sourceUrl` as fallback

Already-absolute URLs remain unchanged.

### 11.4 `moreKeys`

A1 applies only deterministic `skipCount`.

`pageSize`, `maxPage`, `removeHtmlKeys`, and `requestFilters` may be shown in diagnostics but do not change A1 execution behavior.

## 12. Result limits

To protect the Tester UI:

- maximum parsed search results shown: 500
- larger result sets are truncated with a warning
- raw network body hard limit: 5 MiB
- response text panel may render only the first approximately 200,000 characters while preserving report metadata about the original decoded length

## 13. Debug report model

Each run returns a structured `SearchBookTestReport`.

Suggested shape:

```text
SearchBookTestReport
- sourceId
- sourceName
- input parameters
- request snapshot
- response snapshot
- parsedResults
- traces
- warnings
- overall outcome
```

Request snapshot includes:

- original `requestInfo`
- resolved URI
- method
- headers

Response snapshot includes:

- status code
- final URI
- response headers
- duration
- byte count
- selected encoding
- decoded body

Each parser trace should identify at least:

- field name
- original rule
- pipeline stages
- parser kind
- input context summary
- output summary
- warnings/errors
- whether the result is partial

The report is a diagnostic artifact. It is not persisted in A1.

## 14. Presentation

### 14.1 Entry point

Add a `测试` action to Source Workbench when a source is selected.

No selected source -> action disabled.

Opening it navigates to `SourceTesterPage(sourceId: selectedId)`.

Do not introduce a full app-shell/router redesign solely for A1.

### 14.2 Tester page

Header shows:

- persisted source name
- platform
- explicit notice: `测试使用已保存版本`

Input area:

```text
关键词
页码 = 1
高级参数
  offset = 0
  filter = ""
运行搜索测试
```

Result area uses four views/tabs:

```text
结果 | 请求 | 响应 | 解析日志
```

`结果` displays parsed text metadata only. A1 does not fetch cover images.

`响应` exposes decoded raw response text subject to UI truncation.

`解析日志` is the primary diagnostic surface for unsupported JavaScript, parser failures, partial pipelines, encoding warnings, and truncation warnings.

## 15. Error semantics

Use structured application errors rather than Chinese strings in lower layers.

Representative categories:

```text
sourceNotFound
unsupportedPlatform
searchBookMissing
requestInfoMissing
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
listRuleFailure
```

Presentation maps them to concise Chinese messages and keeps detailed diagnostics in the report/log surface when possible.

## 16. Platform networking

A1 is a native-platform feature.

Native targets must permit ordinary internet access and legacy HTTP sources where platform policy otherwise blocks them.

Implementation planning must verify and make the minimum required Android and Apple network-policy changes. Windows and Linux use normal native networking.

Web is explicitly excluded from A1 acceptance because browser CORS prevents a general third-party source tester without a proxy architecture.

## 17. Testing strategy

CI must never depend on live novel websites.

Use deterministic fixtures and fake HTTP executors.

### 17.1 Pure/unit tests

Cover at least:

- UTF-8 keyword percent encoding
- GBK keyword percent encoding
- placeholder substitution
- unknown placeholder rejection
- relative URL resolution
- header parsing and override
- response encoding selection
- malformed UTF-8 warning
- pipeline tokenization without breaking nested/quoted `||`
- supported prefix plus unsupported JS partial result
- HTML XPath list extraction
- HTML field extraction relative to list context
- attribute and `text()` extraction
- legacy JSON slash path including `[1]` and `[-1]`
- standard JSONPath
- relative `cover`/`detailUrl` completion
- `skipCount`
- one-field failure without aborting all results
- 500-result truncation

### 17.2 HTTP adapter tests

Use a mock/fake client or local deterministic adapter boundary to verify:

- GET mapping
- redirect policy
- timeout mapping
- body-size limit
- 4xx/5xx retained as responses

No external network dependency.

### 17.3 Presentation tests

Cover at least:

- Workbench test action disabled without selection
- selected source opens Tester by database id
- persisted-version notice shown
- running shows loading state
- success populates Result/Request/Response/Trace surfaces
- structured errors map to user-facing messages
- unsupported JS appears as explicit diagnostic, not silent empty output

### 17.4 Real SQLite integration regression

At minimum:

```text
SQLite source contains old saved searchBook
Workbench opens source and edits request/rules without saving
Open Tester and run
Tester must execute old SQLite searchBook
Workbench draft must remain unchanged
```

Also verify that a real persisted `StandarReader` record can traverse:

```text
Drift -> SqliteSourceRepository -> SearchBookTestRunner -> fake HTTP -> parser -> report
```

### 17.5 Regression gate

Existing Source Workbench tests must remain green.

## 18. OmniRoute boundary

OmniRoute may receive only small deterministic UI tasks with strict file allowlists, for example:

- Tester input panel
- result list presentation
- one trace presentation widget

Do not delegate these to OmniRoute:

- request construction
- character encoding
- HTTP execution policy
- parser adapters
- pipeline tokenization/execution
- Runner orchestration
- persisted-state semantics
- SQLite integration tests

## 19. Acceptance criteria

A1 is complete only when all are true:

1. A persisted `StandarReader` source can run `searchBook` with a keyword using GET.
2. The resolved request is inspectable.
3. Status, headers, timing, encoding, and raw decoded response are inspectable.
4. HTML XPath search rules can produce book results from legacy-style fixtures.
5. JSON legacy slash paths and standard JSONPath can produce book results.
6. UTF-8 and GBK/GB2312 source behavior is covered by deterministic tests.
7. Unsupported JavaScript is explicit and may yield partial declarative results where applicable.
8. Every configured field can produce a useful parser trace.
9. Unsaved Workbench drafts never affect Tester execution and are not reset by testing.
10. Native platform network configuration permits intended source requests.
11. No live-site dependency exists in CI.
12. Full Flutter codegen/analyze/test verification is green.

## 20. Deferred work

The following belong to later specs:

- JavaScript runtime and compatibility sandbox
- POST / request-object execution
- cookies/session/login
- WebView requests
- retry/cache policies
- `bookDetail`
- `chapterList`
- `chapterContent`
- reader UI
- source test history
- cover loading during tests
- Web proxy architecture
