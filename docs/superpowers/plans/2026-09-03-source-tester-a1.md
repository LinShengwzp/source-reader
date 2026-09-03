# Source Tester A1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native Source Tester that reloads a persisted `StandarReader` source by database id, executes its saved `searchBook` GET request, decodes UTF-8/GBK responses, parses HTML XPath or JSON rules, and exposes request/response/result/trace diagnostics without executing JavaScript.

**Architecture:** Add an isolated `features/source_tester` feature. Source Reader-owned request, response, parser, and report contracts sit above `package:http`, XPath, JSONPath, and charset libraries. `SearchBookTestRunner` is the single orchestration boundary: repository reload → request build → HTTP → decode → parser selection → search result parse → report. Workbench navigates by source id only, so unsaved editor draft state never enters the Tester.

**Tech Stack:** Flutter 3.47.0, Dart 3.13, Riverpod 3.4.2, Drift, `http ^1.6.0`, `enough_convert ^1.6.0`, `xpath_selector ^3.0.2`, `xpath_selector_html_parser ^3.0.1`, `json_path ^0.9.0`.

**Spec:** `docs/superpowers/specs/2026-09-03-source-tester-a1-design.md`

## Global Constraints

- Branch: `revival/flutter-workbench`; do not modify `main`.
- Implementation baseline before plan docs: `32f9a5a826f78b0609073f9141c4226daee271cf`.
- Every run calls `SourceRepository.getSource(sourceId)` again; no draft or cached `StoredSource` may be executed.
- A1 supports only `platform == 'StandarReader'`, `searchBook`, and GET.
- Placeholders: `%@keyWord`, `%@pageIndex`, `%@offset`, `%@filter`; unknown `%@...` is an error.
- A1 never executes `@js:`, `%@js`, inline JavaScript, or `JSParser`.
- Parser formats are supported only when persisted `responseFormatType` is exactly `html` or `json`.
- Missing `responseFormatType` follows historical default `str` and returns `unsupportedResponseFormat`; never infer HTML from `parserID=DOM`.
- Request encoding: missing/`utf-8`, or legacy GBK `2147485234`.
- Response encoding: `utf-8`, GB2312 legacy `2147485232`, GBK legacy `2147485234`.
- Do not inject a hidden browser User-Agent.
- HTTP: timeout 20 s, max redirects 5, max body 5 MiB, no automatic retry; 4xx/5xx remain valid Tester responses.
- Parsed results shown: max 500, then truncate with warning.
- Response text UI: render at most 200,000 characters and show truncation notice.
- CI never calls a live novel site.
- Raw source JSON stays authoritative; testing never rewrites a source.
- Comments are Chinese when comments materially improve readability.
- OmniRoute may touch only explicit presentation allowlists. It must not own request building, encoding, HTTP policy, parser adapters, pipeline logic, runner/providers, persisted semantics, or SQLite integration.

## File Structure

```text
app/lib/features/source_tester/
  domain/
    source_http.dart
    source_rule_value.dart
    source_test_error.dart
    source_test_report.dart
  application/
    source_request_builder.dart
    source_response_decoder.dart
    source_rule_pipeline.dart
    source_rule_parser.dart
    search_book_result_parser.dart
    search_book_test_runner.dart
    source_tester_providers.dart
  data/
    package_http_source_executor.dart
    html_xpath_rule_parser.dart
    json_rule_parser.dart
  presentation/
    source_tester_input_panel.dart
    source_tester_report_view.dart
    source_tester_page.dart
```

Tests mirror responsibilities under `app/test/features/source_tester/`. Do not create a Tester database table and do not add Tester methods to `SourceController`.

---

### Task 1: Dependency compatibility gate

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/pubspec.lock`
- Create: `app/test/features/source_tester/dependency_smoke_test.dart`

**Produces:** five execution dependencies proven compatible with Flutter 3.47 / Dart 3.13 before production Tester code exists.

- [ ] **Step 1: Write the RED dependency smoke test**

```dart
import 'package:enough_convert/enough_convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:json_path/json_path.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

void main() {
  test('Source Tester dependencies resolve together', () {
    final client = http.Client();
    addTearDown(client.close);

    final jsonPath = JsonPath(r'$');
    final html = HtmlXPath.html('<html><body>ok</body></html>');

    expect(jsonPath.read(<String, Object?>{'ok': true}), isNotEmpty);
    expect(html.query('//body').nodes, isNotEmpty);
    expect(gbk.decode(gbk.encode('中文')), '中文');
  });
}
```

`xpath_selector` remains an explicit direct dependency because the HTML adapter is built on that API family, while the smoke test uses the higher-level `HtmlXPath` entry point.

- [ ] **Step 2: Run RED before changing dependencies**

From `app/`:

```bash
flutter test test/features/source_tester/dependency_smoke_test.dart
```

Expected: compile failure because the packages are not dependencies.

- [ ] **Step 3: Add exact dependency floors**

```yaml
  http: ^1.6.0
  enough_convert: ^1.6.0
  xpath_selector: ^3.0.2
  xpath_selector_html_parser: ^3.0.1
  json_path: ^0.9.0
```

Do not upgrade unrelated packages.

- [ ] **Step 4: Verify the gate**

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test test/features/source_tester/dependency_smoke_test.dart
flutter test
```

Expected: all pass. Stop the feature if package resolution or analyze fails.

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/test/features/source_tester/dependency_smoke_test.dart
git commit -m "build: add source tester dependencies"
```

---

### Task 2: HTTP domain contracts and structured failures

**Files:**
- Create: `app/lib/features/source_tester/domain/source_http.dart`
- Create: `app/lib/features/source_tester/domain/source_test_error.dart`
- Create: `app/test/features/source_tester/domain/source_http_test.dart`
- Create: `app/test/features/source_tester/domain/source_test_error_test.dart`

**Produces:**

```dart
enum SourceHttpMethod { get }

final class SourceHttpRequest {
  SourceHttpRequest({
    required Uri uri,
    required SourceHttpMethod method,
    Map<String, String> headers = const {},
  });
  final Uri uri;
  final SourceHttpMethod method;
  final Map<String, String> headers;
}

final class SourceHttpResponse {
  SourceHttpResponse({
    required int statusCode,
    required Map<String, String> headers,
    required List<int> bodyBytes,
    required Uri finalUri,
    required Duration duration,
  });
  final int statusCode;
  final Map<String, String> headers;
  final List<int> bodyBytes;
  final Uri finalUri;
  final Duration duration;
}

abstract interface class SourceHttpExecutor {
  Future<SourceHttpResponse> execute(SourceHttpRequest request);
}
```

and:

```dart
enum SourceTestFailureReason {
  sourceNotFound,
  unsupportedPlatform,
  searchBookMissing,
  requestInfoMissing,
  unsupportedScriptRequest,
  unknownPlaceholder,
  invalidBaseUrl,
  invalidHeaders,
  unsupportedRequestEncoding,
  transportFailure,
  timeout,
  responseTooLarge,
  unsupportedResponseEncoding,
  unsupportedResponseFormat,
  responseParseFailure,
  listRuleFailure,
}

final class SourceTestException implements Exception {
  const SourceTestException(this.reason, {this.message, this.cause});
  final SourceTestFailureReason reason;
  final String? message;
  final Object? cause;
}
```

- [ ] **Step 1: RED tests** require request/response construction, defensive unmodifiable copies for headers/body, and preservation of `reason/message/cause`.
- [ ] **Step 2: Run RED**

```bash
flutter test test/features/source_tester/domain/
```

Expected: missing production files.

- [ ] **Step 3: Implement contracts** with `Map.unmodifiable(Map.of(...))` and `List.unmodifiable(...)`; domain imports no `package:http`.
- [ ] **Step 4: Verify GREEN**

```bash
flutter analyze
flutter test test/features/source_tester/domain/
```

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/domain app/test/features/source_tester/domain
git commit -m "feat: add source tester contracts"
```

---

### Task 3: Persisted request builder, placeholders, encoding, and headers

**Files:**
- Create: `app/lib/features/source_tester/application/source_request_builder.dart`
- Create: `app/test/features/source_tester/application/source_request_builder_test.dart`

**Consumes:** `StoredSource`, source raw/facades, Task 2 HTTP/errors.

**Produces:**

```dart
final class SearchBookTestInput {
  const SearchBookTestInput({
    required this.keyWord,
    this.pageIndex = 1,
    this.offset = 0,
    this.filter = '',
  });
  final String keyWord;
  final int pageIndex;
  final int offset;
  final String filter;
}

final class BuiltSearchBookRequest {
  const BuiltSearchBookRequest({
    required this.originalRequestInfo,
    required this.request,
    required this.warnings,
  });
  final String originalRequestInfo;
  final SourceHttpRequest request;
  final List<String> warnings;
}

final class SourceRequestBuilder {
  BuiltSearchBookRequest build({
    required StoredSource source,
    required SearchBookTestInput input,
  });
}
```

- [ ] **Step 1: RED UTF-8 template test** with saved `sourceUrl=https://example.com/base/` and `requestInfo=/search?q=%@keyWord&p=%@pageIndex&o=%@offset&f=%@filter`; assert `三体` percent encoding, relative URL resolution, page `1`, offset `0`.
- [ ] **Step 2: RED GBK test** with `requestParamsEncode=2147485234`; expected bytes come from an explicit fixture constant, not the production helper.
- [ ] **Step 3: RED structured error tests**:

```text
blank requestInfo              -> requestInfoMissing
requestInfo begins @js:        -> unsupportedScriptRequest
unknown %@token                -> unknownPlaceholder
relative URL + bad sourceUrl   -> invalidBaseUrl
unknown requestParamsEncode    -> unsupportedRequestEncoding
```

- [ ] **Step 4: RED header tests** read raw copies only:

```dart
source.document.toRaw()['httpHeaders'];
source.document.searchBook!.toRaw()['httpHeaders'];
```

Support Map and JSON-object String. Merge case-insensitively with searchBook overriding global. Scalar String/num/bool values stringify. Bad entry inside an otherwise valid object is skipped with warning. Invalid JSON or non-object JSON is `invalidHeaders`. Assert no hidden User-Agent appears.

- [ ] **Step 5: Run RED**

```bash
flutter test test/features/source_tester/application/source_request_builder_test.dart
```

- [ ] **Step 6: Implement** with explicit known-token replacement and a post-scan for remaining `%@identifier`; percent-encode only inserted keyword/filter bytes.
- [ ] **Step 7: Verify GREEN + regression**

```bash
flutter analyze
flutter test test/features/source_tester/application/source_request_builder_test.dart
flutter test
```

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/source_tester/application/source_request_builder.dart app/test/features/source_tester/application/source_request_builder_test.dart
git commit -m "feat: build source tester requests"
```

---

### Task 4: Response decoding and charset diagnostics

**Files:**
- Create: `app/lib/features/source_tester/application/source_response_decoder.dart`
- Create: `app/test/features/source_tester/application/source_response_decoder_test.dart`

**Produces:**

```dart
enum SourceResponseEncoding { utf8, gbk }

final class DecodedSourceResponse {
  const DecodedSourceResponse({
    required this.text,
    required this.encoding,
    required this.warnings,
  });
  final String text;
  final SourceResponseEncoding encoding;
  final List<String> warnings;
}

final class SourceResponseDecoder {
  DecodedSourceResponse decode({
    required SourceHttpResponse response,
    required String? configuredEncoding,
  });
}
```

- [ ] **Step 1: RED explicit encoding tests**: `utf-8`, `2147485232`, `2147485234`, unknown explicit value.
- [ ] **Step 2: RED charset fallback tests**: case-insensitive Content-Type charset `utf-8`, `gbk`, `gb2312`; absent/unknown charset falls back UTF-8.
- [ ] **Step 3: RED malformed UTF-8 test**: replacement decoding succeeds and warning is recorded.
- [ ] **Step 4: Run RED**

```bash
flutter test test/features/source_tester/application/source_response_decoder_test.dart
```

- [ ] **Step 5: Implement** using `utf8.decode(..., allowMalformed: true)` plus strict-decode probe for warnings; `gbk.decode(...)` handles both legacy Chinese encodings.
- [ ] **Step 6: Verify and commit**

```bash
flutter analyze
flutter test test/features/source_tester/application/source_response_decoder_test.dart
git add app/lib/features/source_tester/application/source_response_decoder.dart app/test/features/source_tester/application/source_response_decoder_test.dart
git commit -m "feat: decode source tester responses"
```

---

### Task 5: Source-owned rule values and safe `||` pipeline tokenizer

**Files:**
- Create: `app/lib/features/source_tester/domain/source_rule_value.dart`
- Create: `app/lib/features/source_tester/application/source_rule_pipeline.dart`
- Create: `app/test/features/source_tester/application/source_rule_pipeline_test.dart`

**Produces:**

```dart
sealed class SourceRuleValue { const SourceRuleValue(); }
final class SourceRuleScalar extends SourceRuleValue {
  const SourceRuleScalar(this.value);
  final Object? value;
}
final class SourceRuleList extends SourceRuleValue {
  const SourceRuleList(this.values);
  final List<SourceRuleValue> values;
}
abstract interface class SourceRuleContext {
  SourceRuleValue summarize();
}
final class SourceRulePipelineStage {
  const SourceRulePipelineStage({required this.expression, required this.isJavaScript});
  final String expression;
  final bool isJavaScript;
}
List<SourceRulePipelineStage> tokenizeSourceRulePipeline(String rule);
```

- [ ] **Step 1: RED tokenizer tests** prove top-level split for `//a/@href || @js: ...` and no split inside `$.items[?(@.a == "x||y")].name`; include quotes, escaped quotes, `()`, `[]`, `{}`.
- [ ] **Step 2: RED malformed tests** for unbalanced quote/bracket; must throw a deterministic pipeline-format exception, not guess stages.
- [ ] **Step 3: Run RED**.
- [ ] **Step 4: Implement a character scanner** tracking quote, escaping, and nesting depth; mark JavaScript when trimmed stage begins `@js:` or `%@js`.
- [ ] **Step 5: Verify and commit**

```bash
flutter analyze
flutter test test/features/source_tester/application/source_rule_pipeline_test.dart
git add app/lib/features/source_tester/domain/source_rule_value.dart app/lib/features/source_tester/application/source_rule_pipeline.dart app/test/features/source_tester/application/source_rule_pipeline_test.dart
git commit -m "feat: add source rule pipeline"
```

---

### Task 6: Parser contract and JSON compatibility adapter

**Files:**
- Create: `app/lib/features/source_tester/application/source_rule_parser.dart`
- Create: `app/lib/features/source_tester/data/json_rule_parser.dart`
- Create: `app/test/features/source_tester/data/json_rule_parser_test.dart`

**Produces:**

```dart
enum SourceRuleParserKind { htmlXPath, jsonLegacyPath, jsonPath }

final class SourceRuleEvaluation {
  const SourceRuleEvaluation({
    required this.value,
    required this.contexts,
    required this.parserKind,
  });
  final SourceRuleValue value;
  final List<SourceRuleContext> contexts;
  final SourceRuleParserKind parserKind;
}

abstract interface class SourceRuleParser {
  SourceRuleContext createRoot(String responseText);
  SourceRuleEvaluation evaluate({
    required SourceRuleContext context,
    required String expression,
  });
}
```

`JsonRuleParser` uses `JsonPath(expression).read(contextJsonValue)` only when trimmed expression begins `$`; otherwise use Source Reader's legacy slash path. Therefore `$` is rooted at the context passed into `evaluate`, including a list item context.

- [ ] **Step 1: RED legacy path fixture**: `items[1]/name=A`, `items[2]/name=B`, `items[-1]/name=B`, `items[-2]/name=A`; zero/out-of-range returns empty result.
- [ ] **Step 2: RED relative context**: evaluate `items`, then `name` within each item context and get A/B without root restart. Also evaluate `$.name` against each item context and get A/B.
- [ ] **Step 3: RED RFC JSONPath**: root `$.items[*].name` returns A/B; `JsonPathMatch` never escapes this file.
- [ ] **Step 4: RED invalid JSON/expression**: invalid response root is `responseParseFailure`; malformed rule produces adapter evaluation error for later trace capture.
- [ ] **Step 5: Run RED**

```bash
flutter test test/features/source_tester/data/json_rule_parser_test.dart
```

- [ ] **Step 6: Implement legacy parser and JSONPath adapter**.
- [ ] **Step 7: Verify and commit**

```bash
flutter analyze
flutter test test/features/source_tester/data/json_rule_parser_test.dart
git add app/lib/features/source_tester/application/source_rule_parser.dart app/lib/features/source_tester/data/json_rule_parser.dart app/test/features/source_tester/data/json_rule_parser_test.dart
git commit -m "feat: parse source tester JSON rules"
```

---

### Task 7: HTML XPath compatibility adapter

**Files:**
- Create: `app/lib/features/source_tester/data/html_xpath_rule_parser.dart`
- Create: `app/test/features/source_tester/fixtures/search_fixture.html`
- Create: `app/test/features/source_tester/data/html_xpath_rule_parser_test.dart`

**Produces:** `HtmlXPathRuleParser implements SourceRuleParser`; HTML/XPath package types remain private.

- [ ] **Step 1: Add fixture** with two distinct `table.grid > tr` rows covering:

```text
//table[@class='grid']//tr
//td[1]/a
//td[3]
//td[1]/a/@href
//td[2]/a/text()
```

- [ ] **Step 2: RED root tests**: list query returns two contexts; text and attribute extraction succeed.
- [ ] **Step 3: RED legacy relative-context test**: field rule `//td[1]/a` evaluated on each row yields its own title. If `xpath_selector_html_parser` interprets node-context `//` from document root, normalize only adapter execution for non-root contexts; never rewrite persisted rules.
- [ ] **Step 4: RED invalid/empty XPath tests**: no match is empty; invalid expression becomes adapter evaluation error.
- [ ] **Step 5: Run RED**

```bash
flutter test test/features/source_tester/data/html_xpath_rule_parser_test.dart
```

- [ ] **Step 6: Implement with `HtmlXPath`/node query APIs**, immediately converting library outputs into Source Reader values/private contexts.
- [ ] **Step 7: Verify and commit**

```bash
flutter analyze
flutter test test/features/source_tester/data/html_xpath_rule_parser_test.dart
git add app/lib/features/source_tester/data/html_xpath_rule_parser.dart app/test/features/source_tester/fixtures/search_fixture.html app/test/features/source_tester/data/html_xpath_rule_parser_test.dart
git commit -m "feat: parse source tester XPath rules"
```

---

### Task 8: SearchBook result parsing, traces, URL normalization, and limits

**Files:**
- Create: `app/lib/features/source_tester/domain/source_test_report.dart`
- Create: `app/lib/features/source_tester/application/search_book_result_parser.dart`
- Create: `app/test/features/source_tester/application/search_book_result_parser_test.dart`

**Produces:**

```dart
final class SearchBookTestItem {
  const SearchBookTestItem({
    this.bookName,
    this.author,
    this.cover,
    this.desc,
    this.cat,
    this.status,
    this.wordCount,
    this.lastChapterTitle,
    this.detailUrl,
  });
  final String? bookName;
  final String? author;
  final String? cover;
  final String? desc;
  final String? cat;
  final String? status;
  final String? wordCount;
  final String? lastChapterTitle;
  final String? detailUrl;
}

final class SourceRuleTrace {
  const SourceRuleTrace({
    required this.field,
    required this.rule,
    required this.stages,
    required this.outputSummary,
    required this.warnings,
    required this.errors,
    required this.partial,
  });
  final String field;
  final String rule;
  final List<String> stages;
  final String outputSummary;
  final List<String> warnings;
  final List<String> errors;
  final bool partial;
}

final class SearchBookParseResult {
  const SearchBookParseResult({required this.items, required this.traces, required this.warnings});
  final List<SearchBookTestItem> items;
  final List<SourceRuleTrace> traces;
  final List<String> warnings;
}
```

and `SearchBookResultParser.parse(...)` taking saved searchBook, parser, response text, final response URI, and persisted sourceUrl.

- [ ] **Step 1: RED `list` semantics**: missing/blank or unevaluable list → `listRuleFailure`; valid list with zero matches → successful empty result.
- [ ] **Step 2: RED field isolation**: bad author rule does not destroy good bookName or other items; trace records author failure.
- [ ] **Step 3: RED JS partial**: supported prefix `//td[1]/a/@href || @js: ...` retains prefix output and marks trace partial; JS-first produces no value and explicit unsupported diagnostic; `JSParser` is skipped with warning without blocking declarative fields.
- [ ] **Step 4: RED URL normalization** for `cover/detailUrl`: absolute unchanged; relative uses final response URI, persisted sourceUrl fallback.
- [ ] **Step 5: RED moreKeys/limit**: Map or JSON-string `skipCount >= 0` applies; configured `pageSize/maxPage/removeHtmlKeys/requestFilters` only add diagnostics; after skip cap to 500 and warn.
- [ ] **Step 6: Run RED**

```bash
flutter test test/features/source_tester/application/search_book_result_parser_test.dart
```

- [ ] **Step 7: Implement field order** exactly:

```text
bookName, author, cover, desc, cat, status, wordCount, lastChapterTitle, detailUrl
```

Never mutate saved source raw data.

- [ ] **Step 8: Verify and commit**

```bash
flutter analyze
flutter test test/features/source_tester/application/search_book_result_parser_test.dart
flutter test test/features/source_tester/data/
git add app/lib/features/source_tester/domain/source_test_report.dart app/lib/features/source_tester/application/search_book_result_parser.dart app/test/features/source_tester/application/search_book_result_parser_test.dart
git commit -m "feat: parse search book test results"
```

---

### Task 9: Production HTTP executor

**Files:**
- Create: `app/lib/features/source_tester/data/package_http_source_executor.dart`
- Create: `app/test/features/source_tester/data/package_http_source_executor_test.dart`

**Produces:**

```dart
final class PackageHttpSourceExecutor implements SourceHttpExecutor {
  PackageHttpSourceExecutor({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.maxRedirects = 5,
    this.maxBodyBytes = 5 * 1024 * 1024,
  });
}
```

- [ ] **Step 1: RED mapping test** using injected fake/mock `http.Client`; assert GET URI/headers and response snapshot.
- [ ] **Step 2: RED 404/500 tests**: return response, do not throw transport error.
- [ ] **Step 3: RED timeout/transport tests**: timeout → `timeout`; client exception → `transportFailure` with cause.
- [ ] **Step 4: RED body-limit test**: streamed body over limit by one byte stops accumulation and throws `responseTooLarge`.
- [ ] **Step 5: RED redirect policy**: captured `http.Request.followRedirects == true` and `maxRedirects == 5`.
- [ ] **Step 6: Run RED**

```bash
flutter test test/features/source_tester/data/package_http_source_executor_test.dart
```

- [ ] **Step 7: Implement with `http.Client.send`**, incremental byte counting and stopwatch duration. Resolve final URI exactly as:

```dart
final finalUri = switch (response) {
  http.BaseResponseWithUrl(:final url) => url,
  _ => request.uri,
};
```

Close only an internally owned client, never an injected client during `execute`.

- [ ] **Step 8: Verify and commit**

```bash
flutter analyze
flutter test test/features/source_tester/data/package_http_source_executor_test.dart
git add app/lib/features/source_tester/data/package_http_source_executor.dart app/test/features/source_tester/data/package_http_source_executor_test.dart
git commit -m "feat: execute source tester HTTP requests"
```

---

### Task 10: SearchBookTestRunner and Riverpod assembly

**Files:**
- Modify: `app/lib/features/source_tester/domain/source_test_report.dart`
- Create: `app/lib/features/source_tester/application/search_book_test_runner.dart`
- Create: `app/lib/features/source_tester/application/source_tester_providers.dart`
- Create: `app/test/features/source_tester/application/search_book_test_runner_test.dart`
- Create: `app/test/features/source_tester/application/source_tester_providers_test.dart`

**Produces:**

```dart
final class SearchBookTestRunner {
  Future<SearchBookTestReport> run({
    required int sourceId,
    required SearchBookTestInput input,
  });
}
```

`SearchBookTestReport` contains persisted source identity, normalized input, request snapshot, response snapshot, parsed items, traces, warnings, and outcome.

- [ ] **Step 1: RED persisted-state tests**: `getSource(sourceId)` exactly once per run; null → sourceNotFound; wrong platform → unsupportedPlatform; no searchBook → searchBookMissing. Runner accepts no SourceDocument/draft parameter.
- [ ] **Step 2: RED HTML orchestration**: fake repository + fake HTTP + fixture HTML produces full report.
- [ ] **Step 3: RED JSON orchestration**: saved `responseFormatType=json` selects JsonRuleParser and returns items.
- [ ] **Step 4: RED unsupported format**: missing/`str`/`xml` → unsupportedResponseFormat even when `parserID=DOM`.
- [ ] **Step 5: RED 500 continuation**: status 500 body can still decode/parse and report preserves 500.
- [ ] **Step 6: Run RED**

```bash
flutter test test/features/source_tester/application/search_book_test_runner_test.dart
```

- [ ] **Step 7: Implement fixed orchestration order**:

```text
repository reload -> validate -> request build -> HTTP -> decode -> parser select -> result parse -> report
```

- [ ] **Step 8: Add overrideable providers** for executor, builder, decoder, both parsers, result parser, and runner. Runner provider watches existing `sourceRepositoryProvider`; Sources must not import Tester application/domain.
- [ ] **Step 9: Verify and commit**

```bash
flutter analyze
flutter test test/features/source_tester/application/
flutter test
git add app/lib/features/source_tester/domain/source_test_report.dart app/lib/features/source_tester/application app/test/features/source_tester/application
git commit -m "feat: run persisted search book tests"
```

---

### Task 11: OR-007 pure input panel

**Files:**
- Create by strong model: `docs/omniroute/OR-007-source-tester-input-panel.md`
- OmniRoute allowlist only:
  - Create: `app/lib/features/source_tester/presentation/source_tester_input_panel.dart`
  - Create: `app/test/features/source_tester/presentation/source_tester_input_panel_test.dart`

**Produces:**

```dart
final class SourceTesterInput {
  const SourceTesterInput({
    required this.keyWord,
    required this.pageIndex,
    required this.offset,
    required this.filter,
  });
  final String keyWord;
  final int pageIndex;
  final int offset;
  final String filter;
}

final class SourceTesterInputPanel extends StatelessWidget {
  const SourceTesterInputPanel({
    super.key,
    required this.running,
    required this.onRun,
  });
  final bool running;
  final ValueChanged<SourceTesterInput> onRun;
}
```

- [ ] **Step 1: Strong model writes OR-007 task doc** forbidding Riverpod, repository, source_tester/application, HTTP/parser packages, and platform APIs.
- [ ] **Step 2: Record delegation base**:

```bash
OR_BASE=$(git rev-parse HEAD)
```

- [ ] **Step 3: OmniRoute RED → GREEN** for: required keyword; page default 1 and >=1; collapsed advanced section; offset default 0 and >=0; filter default empty; run button disabled while running; invalid numbers block callback; one tap = one callback.
- [ ] **Step 4: OmniRoute verifies**:

```bash
flutter test test/features/source_tester/presentation/source_tester_input_panel_test.dart
flutter analyze
flutter test
git diff --check "$OR_BASE"..HEAD
git status --short
```

- [ ] **Step 5: Strong model independently reviews actual diff and exact CI SHA** before accepting OR-007.

---

### Task 12: Report UI and Tester page

**Files:**
- Create: `app/lib/features/source_tester/presentation/source_tester_report_view.dart`
- Create: `app/lib/features/source_tester/presentation/source_tester_page.dart`
- Create: `app/test/features/source_tester/presentation/source_tester_report_view_test.dart`
- Create: `app/test/features/source_tester/presentation/source_tester_page_test.dart`

**Produces:** `SourceTesterPage({required int sourceId})`.

- [ ] **Step 1: RED report-view tests** require four stable keys:

```text
source-tester-tab-results
source-tester-tab-request
source-tester-tab-response
source-tester-tab-traces
```

Results show text metadata only. Request shows method/URI/headers. Response shows status/final URI/duration/bytes/encoding/headers/body; body over 200,000 chars is truncated with visible note. Traces show field/rule/stages/output/warnings/errors/partial.

- [ ] **Step 2: RED page tests** override repository and runner. Require persisted source header, `测试使用已保存版本`, running state, successful report installation, structured Chinese error mapping, and visible unsupported-JS diagnostics.
- [ ] **Step 3: Run RED**

```bash
flutter test test/features/source_tester/presentation/source_tester_report_view_test.dart test/features/source_tester/presentation/source_tester_page_test.dart
```

- [ ] **Step 4: Implement report view** with normal Flutter widgets only; no syntax-highlighting/editor dependency.
- [ ] **Step 5: Implement page** with transient run state only. Convert `SourceTesterInput` to `SearchBookTestInput`; runner receives only sourceId + normalized input.
- [ ] **Step 6: Verify and commit**

```bash
flutter analyze
flutter test test/features/source_tester/presentation/
git add app/lib/features/source_tester/presentation/source_tester_report_view.dart app/lib/features/source_tester/presentation/source_tester_page.dart app/test/features/source_tester/presentation/source_tester_report_view_test.dart app/test/features/source_tester/presentation/source_tester_page_test.dart
git commit -m "feat: add source tester page"
```

---

### Task 13: Workbench navigation and persisted-draft SQLite regression

**Files:**
- Modify: `app/lib/features/sources/presentation/source_page.dart`
- Modify: `app/test/features/sources/presentation/source_page_test.dart`
- Create: `app/test/features/source_tester/presentation/source_tester_navigation_test.dart`
- Create: `app/test/features/source_tester/presentation/source_tester_integration_test.dart`

- [ ] **Step 1: RED Workbench action test**: visible key `source-test-action`; no selection disabled, selection enabled.
- [ ] **Step 2: RED navigation test**: select id 2, tap test action, assert pushed `SourceTesterPage` receives exactly id 2; no StoredSource/draft passed.
- [ ] **Step 3: Run RED**

```bash
flutter test test/features/sources/presentation/source_page_test.dart test/features/source_tester/presentation/source_tester_navigation_test.dart
```

- [ ] **Step 4: Implement minimal Navigator push**:

```dart
IconButton(
  key: const Key('source-test-action'),
  tooltip: '测试书源',
  onPressed: selectedId == null
      ? null
      : () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SourceTesterPage(sourceId: selectedId),
            ),
          ),
  icon: const Icon(Icons.science_outlined),
)
```

No Router/AppShell refactor.

- [ ] **Step 5: RED real SQLite persisted-vs-draft test**: persist saved source/searchBook, open SourcePage, edit source name and requestInfo without save, open Tester, fake HTTP captures request. Assert captured URI uses saved request, Tester uses persisted identity, fixture parses, navigating back preserves unsaved Workbench draft.
- [ ] **Step 6: Add real repository-runner integration** proving:

```text
Drift -> SqliteSourceRepository -> SearchBookTestRunner -> fake HTTP -> decoder -> parser -> report
```

- [ ] **Step 7: Verify and commit**

```bash
flutter analyze
flutter test test/features/source_tester/presentation/source_tester_navigation_test.dart test/features/source_tester/presentation/source_tester_integration_test.dart
flutter test
git add app/lib/features/sources/presentation/source_page.dart app/test/features/sources/presentation/source_page_test.dart app/test/features/source_tester/presentation/source_tester_navigation_test.dart app/test/features/source_tester/presentation/source_tester_integration_test.dart
git commit -m "feat: connect workbench to source tester"
```

---

### Task 14: Native network policy

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/ios/Runner/Info.plist`
- Modify: `app/macos/Runner/Info.plist`
- Modify: `app/macos/Runner/DebugProfile.entitlements`
- Modify: `app/macos/Runner/Release.entitlements`
- Create: `app/test/features/source_tester/platform/source_tester_platform_config_test.dart`

- [ ] **Step 1: RED config test** reads runner text files from `app/` working directory and requires:

Android:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
android:usesCleartextTraffic="true"
```

iOS/macOS Info.plist:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

Both macOS entitlements:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

- [ ] **Step 2: Run RED**

```bash
flutter test test/features/source_tester/platform/source_tester_platform_config_test.dart
```

- [ ] **Step 3: Apply minimum policy changes**: add Android INTERNET permission and cleartext application flag; add ATS dictionary to iOS/macOS Info.plist; add network.client to both macOS entitlement files; preserve existing unrelated keys including debug network.server.
- [ ] **Step 4: Verify**

```bash
flutter analyze
flutter test test/features/source_tester/platform/source_tester_platform_config_test.dart
flutter test
```

Also run `flutter build apk --debug` when the execution environment has Android build prerequisites; if CI lacks them, this build becomes a local pre-release check rather than weakening analyze/test gates.

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/AndroidManifest.xml app/ios/Runner/Info.plist app/macos/Runner/Info.plist app/macos/Runner/DebugProfile.entitlements app/macos/Runner/Release.entitlements app/test/features/source_tester/platform/source_tester_platform_config_test.dart
git commit -m "build: enable native source tester networking"
```

---

### Task 15: Final acceptance review

**Files:** no planned production changes.

- [ ] **Step 1: Fresh full verification from `app/`**

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

Expected: zero analyzer issues and zero failed tests.

- [ ] **Step 2: Repository cleanliness from root**

```bash
git diff --check 32f9a5a826f78b0609073f9141c4226daee271cf..HEAD
git status --short
```

Expected: diff-check exit 0 and clean status.

- [ ] **Step 3: Requirement checklist**

```text
GET only                         yes
StandarReader/searchBook only    yes
persisted state only             yes
UTF-8 + GBK request encoding     yes
UTF-8 + GB2312/GBK response      yes
HTML XPath                       yes
legacy JSON + RFC JSONPath       yes
JS never executed                yes
JS partial trace                 yes
request/response/result/traces   yes
500-result cap / 5 MiB cap       yes
20 s timeout / 5 redirects       yes
4xx/5xx retained                 yes
no live-site CI                  yes
native network config            yes
Web excluded                     yes
no Tester DB table               yes
no SourceController pollution    yes
```

- [ ] **Step 4: Architecture leakage review** rejects completion if Sources domain/application imports Tester, SourcePage passes draft/StoredSource into Tester, presentation imports HTTP/XPath/JSONPath/charset packages, third-party parser node types escape adapters, or any JS runtime appears.
- [ ] **Step 5: Confirm exact branch HEAD and its GitHub CI run are the same SHA before claiming A1 complete.**
