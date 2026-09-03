# Source Tester A1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a native Source Tester that reloads a persisted `StandarReader` source by database id, executes its saved `searchBook` GET request, decodes UTF-8/GBK responses, parses HTML XPath or JSON rules, and exposes request/response/result/trace diagnostics without executing JavaScript.

**Architecture:** Add an isolated `features/source_tester` feature. Source-owned request/response/report/parser interfaces sit above `package:http`, XPath, JSONPath, and charset libraries. `SearchBookTestRunner` is the orchestration boundary: it reloads `SourceRepository`, builds the request, executes HTTP, decodes the response, parses saved search rules, and returns one diagnostic report. Workbench only navigates by source id; unsaved editor draft state never enters the Tester.

**Tech Stack:** Flutter 3.47.0, Dart 3.13, Riverpod 3.4.2, Drift, `http ^1.6.0`, `enough_convert ^1.6.0`, `xpath_selector ^3.0.2`, `xpath_selector_html_parser ^3.0.1`, `json_path ^0.9.0`.

**Spec:** `docs/superpowers/specs/2026-09-03-source-tester-a1-design.md`

## Global Constraints

- Branch: `revival/flutter-workbench`; do not modify `main` during implementation.
- Tester executes only persisted SQLite state. Every run calls `SourceRepository.getSource(sourceId)` again.
- A1 supports only `platform == 'StandarReader'`, `searchBook`, and GET.
- Supported placeholders are `%@keyWord`, `%@pageIndex`, `%@offset`, `%@filter`; unknown `%@...` is an error.
- A1 never executes `@js:`, `%@js`, inline JavaScript, or `JSParser`.
- A1 supports parser formats only when persisted `responseFormatType` is exactly `html` or `json`.
- Missing `responseFormatType` follows the legacy default `str` and therefore produces `unsupportedResponseFormat`; do not infer HTML from `parserID=DOM`.
- Request encoding supports missing/`utf-8` and legacy GBK value `2147485234` only.
- Response encoding supports `utf-8`, `2147485232` (GB2312 via GBK-compatible decoder), and `2147485234` (GBK).
- No hidden User-Agent injection.
- HTTP policy: timeout 20 seconds, max redirects 5, max body 5 MiB, no automatic retry, 4xx/5xx retained as valid Tester responses.
- Parsed search results are capped at 500 with a warning.
- CI must not access live novel websites.
- Raw source JSON remains authoritative; do not normalize or rewrite source data as part of testing.
- New code comments should be Chinese where comments materially improve readability.
- OmniRoute may touch only explicitly allowlisted presentation files; request building, encodings, HTTP policy, parsers, pipeline, runner, providers, persisted semantics, and SQLite integration remain strong-model work.

---

## File Structure

Create these focused units:

```text
app/lib/features/source_tester/
  domain/
    source_http.dart
    source_test_error.dart
    source_test_report.dart
    source_rule_value.dart
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

Tests mirror the same responsibilities under `app/test/features/source_tester/`.

Do not create a Tester database table and do not add Tester methods to `SourceController`.

---

### Task 1: Dependency compatibility gate

**Files:**
- Modify: `app/pubspec.yaml`
- Test: `app/test/features/source_tester/dependency_smoke_test.dart`

**Interfaces:**
- Consumes: Flutter 3.47 / Dart 3.13 project toolchain.
- Produces: resolvable imports for `http`, `enough_convert`, `xpath_selector`, `xpath_selector_html_parser`, and `json_path`.

- [ ] **Step 1: Add a compile-only dependency smoke test**

Create `app/test/features/source_tester/dependency_smoke_test.dart`:

```dart
import 'package:enough_convert/enough_convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:json_path/json_path.dart';
import 'package:xpath_selector/xpath_selector.dart';
import 'package:xpath_selector_html_parser/xpath_selector_html_parser.dart';

void main() {
  test('Source Tester execution dependencies resolve together', () {
    expect(http.Client, isNotNull);
    expect(JsonPath, isNotNull);
    expect(XPath, isNotNull);
    expect(HtmlXpath, isNotNull);
    expect(gbk, isNotNull);
  });
}
```

If the exact `enough_convert` exported GBK symbol is not `gbk`, inspect the package API and replace only that assertion/import with the package's public GBK codec symbol; do not add a second charset package.

- [ ] **Step 2: Run the smoke test before changing `pubspec.yaml`**

Run from `app/`:

```bash
flutter test test/features/source_tester/dependency_smoke_test.dart
```

Expected: FAIL because the new packages are not dependencies yet.

- [ ] **Step 3: Add exact dependency floors**

Add under `dependencies:` in `app/pubspec.yaml`:

```yaml
  http: ^1.6.0
  enough_convert: ^1.6.0
  xpath_selector: ^3.0.2
  xpath_selector_html_parser: ^3.0.1
  json_path: ^0.9.0
```

Do not remove or upgrade unrelated dependencies in this task.

- [ ] **Step 4: Verify the dependency gate**

Run:

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test test/features/source_tester/dependency_smoke_test.dart
flutter test
```

Expected: all commands PASS. If package resolution fails, stop this milestone and resolve the dependency conflict before writing Tester production code.

- [ ] **Step 5: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/test/features/source_tester/dependency_smoke_test.dart
git commit -m "build: add source tester dependencies"
```

---

### Task 2: Request/response domain contracts and structured errors

**Files:**
- Create: `app/lib/features/source_tester/domain/source_http.dart`
- Create: `app/lib/features/source_tester/domain/source_test_error.dart`
- Test: `app/test/features/source_tester/domain/source_http_test.dart`
- Test: `app/test/features/source_tester/domain/source_test_error_test.dart`

**Interfaces:**
- Consumes: Dart core types only.
- Produces:
  - `enum SourceHttpMethod { get }`
  - `SourceHttpRequest`
  - `SourceHttpResponse`
  - `abstract interface class SourceHttpExecutor`
  - `enum SourceTestFailureReason`
  - `final class SourceTestException implements Exception`

- [ ] **Step 1: Write RED tests for immutable HTTP snapshots and errors**

Tests must require these constructors/signatures:

```dart
final request = SourceHttpRequest(
  uri: Uri.parse('https://example.com/search?q=a'),
  method: SourceHttpMethod.get,
  headers: const {'Accept': 'text/html'},
);

final response = SourceHttpResponse(
  statusCode: 500,
  headers: const {'content-type': 'text/html; charset=utf-8'},
  bodyBytes: const [79, 75],
  finalUri: Uri.parse('https://example.com/final'),
  duration: const Duration(milliseconds: 120),
);
```

Require defensive copies/unmodifiable exposure for `headers` and `bodyBytes` so adapters cannot mutate reports after construction.

Require:

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
```

`SourceTestException` must expose `reason`, optional `message`, and optional `cause`.

- [ ] **Step 2: Run RED**

```bash
flutter test test/features/source_tester/domain/source_http_test.dart test/features/source_tester/domain/source_test_error_test.dart
```

Expected: FAIL because the domain files do not exist.

- [ ] **Step 3: Implement the minimal domain contracts**

Use `Map.unmodifiable(Map.of(...))` and `List.unmodifiable(...)` at construction boundaries. Define:

```dart
abstract interface class SourceHttpExecutor {
  Future<SourceHttpResponse> execute(SourceHttpRequest request);
}
```

Do not import `package:http` from domain files.

- [ ] **Step 4: Verify GREEN**

```bash
flutter analyze
flutter test test/features/source_tester/domain/
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/domain app/test/features/source_tester/domain
git commit -m "feat: add source tester HTTP contracts"
```

---

### Task 3: Persisted search request builder, placeholder encoding, and headers

**Files:**
- Create: `app/lib/features/source_tester/application/source_request_builder.dart`
- Test: `app/test/features/source_tester/application/source_request_builder_test.dart`

**Interfaces:**
- Consumes: `StoredSource`, `SourceDocument`, `SourceSearchBookDocument`, `SourceHttpRequest`, `SourceTestException`.
- Produces:

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

- [ ] **Step 1: Write RED tests for UTF-8 URL templates**

Fixture source:

```dart
SourceDocument.fromRaw({
  'sourceName': 'Fixture',
  'sourceUrl': 'https://example.com/base/',
  'searchBook': {
    'actionID': 'searchBook',
    'parserID': 'DOM',
    'requestInfo': '/search?q=%@keyWord&p=%@pageIndex&o=%@offset&f=%@filter',
  },
});
```

Assert keyword `三体` is UTF-8 percent-encoded, page/offset are decimal text, and relative URL resolves against saved `sourceUrl`.

- [ ] **Step 2: Add RED tests for GBK request encoding**

Set `requestParamsEncode: '2147485234'` and assert the exact GBK percent-encoded bytes produced by `enough_convert` for a Chinese fixture. Generate the expected literal once from the codec in the test setup or lock it as explicit `%XX` bytes; do not compare against the same production helper.

- [ ] **Step 3: Add RED tests for structured rejection**

Cover:

```text
requestInfo missing/blank -> requestInfoMissing
requestInfo begins @js: -> unsupportedScriptRequest
requestInfo contains %@unknown -> unknownPlaceholder
relative URL + missing/invalid sourceUrl -> invalidBaseUrl
unknown requestParamsEncode -> unsupportedRequestEncoding
```

No network executor is called in these tests.

- [ ] **Step 4: Add RED header tests**

Read header values from raw copies:

```dart
source.document.toRaw()['httpHeaders']
source.document.searchBook!.toRaw()['httpHeaders']
```

Require both Map and JSON-object String representations. SearchBook headers override top-level headers case-insensitively.

Examples:

```text
Global:     User-Agent = global, Accept = text/html
SearchBook: user-agent = local
Result:     user-agent/User-Agent semantic value = local, Accept = text/html
```

Rules:

- invalid JSON string or JSON non-object -> `invalidHeaders`
- Map/object with a non-string key or non-scalar/null value -> skip only that entry and append a warning
- scalar values `String/num/bool` stringify deterministically
- do not add an implicit User-Agent

- [ ] **Step 5: Run RED**

```bash
flutter test test/features/source_tester/application/source_request_builder_test.dart
```

Expected: FAIL because `SourceRequestBuilder` does not exist.

- [ ] **Step 6: Implement placeholder scanning without broad regex guessing**

Use an explicit known-token map and scan remaining `%@` identifiers after replacement. Percent-encode `keyWord` and `filter` from bytes. Keep `/`, `?`, `&`, `=` supplied by the template untouched.

- [ ] **Step 7: Implement deterministic header parsing/merging**

Keep header merge logic private to this file unless a second consumer appears. Preserve a warnings list in `BuiltSearchBookRequest`.

- [ ] **Step 8: Verify GREEN and regression**

```bash
flutter analyze
flutter test test/features/source_tester/application/source_request_builder_test.dart
flutter test
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/lib/features/source_tester/application/source_request_builder.dart app/test/features/source_tester/application/source_request_builder_test.dart
git commit -m "feat: build persisted search requests"
```

---

### Task 4: Response decoder and encoding diagnostics

**Files:**
- Create: `app/lib/features/source_tester/application/source_response_decoder.dart`
- Test: `app/test/features/source_tester/application/source_response_decoder_test.dart`

**Interfaces:**
- Consumes: `SourceHttpResponse`, persisted `SourceSearchBookDocument.action.responseEncode`.
- Produces:

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

- [ ] **Step 1: Write RED tests for explicit encodings**

Cover:

```text
utf-8 -> UTF-8 decoder
2147485232 -> GBK-compatible decoder
2147485234 -> GBK-compatible decoder
unknown explicit value -> unsupportedResponseEncoding
```

Use fixed Chinese byte fixtures for UTF-8 and GBK.

- [ ] **Step 2: Write RED tests for charset fallback**

When configured encoding is null/blank:

- `Content-Type: text/html; charset=gbk` -> GBK
- `charset=gb2312` -> GBK-compatible decoder
- `charset=utf-8` -> UTF-8
- missing or unknown charset -> UTF-8

Header lookup must be case-insensitive.

- [ ] **Step 3: Write RED malformed UTF-8 test**

Provide invalid UTF-8 bytes and require replacement decoding plus a warning indicating malformed UTF-8 was encountered.

- [ ] **Step 4: Run RED**

```bash
flutter test test/features/source_tester/application/source_response_decoder_test.dart
```

- [ ] **Step 5: Implement decoder**

Use `utf8.decode(bytes, allowMalformed: true)` and detect whether strict UTF-8 decoding would fail in order to append the warning. Use the public GBK codec from `enough_convert` for both legacy Chinese values.

- [ ] **Step 6: Verify GREEN**

```bash
flutter analyze
flutter test test/features/source_tester/application/source_response_decoder_test.dart
```

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/source_tester/application/source_response_decoder.dart app/test/features/source_tester/application/source_response_decoder_test.dart
git commit -m "feat: decode tester responses"
```

---

### Task 5: Rule values and safe `||` pipeline tokenization

**Files:**
- Create: `app/lib/features/source_tester/domain/source_rule_value.dart`
- Create: `app/lib/features/source_tester/application/source_rule_pipeline.dart`
- Test: `app/test/features/source_tester/application/source_rule_pipeline_test.dart`

**Interfaces:**
- Produces Source Reader-owned parser values; third-party parser node/match types must not escape adapters.

Define:

```dart
sealed class SourceRuleValue {
  const SourceRuleValue();
}

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
  const SourceRulePipelineStage({
    required this.expression,
    required this.isJavaScript,
  });
  final String expression;
  final bool isJavaScript;
}

List<SourceRulePipelineStage> tokenizeSourceRulePipeline(String rule);
```

Adapters may use private context implementations containing HTML nodes or JSON values, but public reports receive only `SourceRuleValue` summaries.

- [ ] **Step 1: Write RED tokenizer tests**

Require these splits:

```text
//a/@href || @js: return result
=> [//a/@href] [@js: return result]

$.items[?(@.a == "x||y")].name || @js: return result
=> [$.items[?(@.a == "x||y")].name] [@js: return result]
```

Also cover single/double quoted strings, escaped quotes, `()`, `[]`, `{}`, and whitespace around separators.

- [ ] **Step 2: Write RED malformed pipeline tests**

Unbalanced quote/bracket input must not silently produce arbitrary stages. Throw a parser/configuration exception suitable for later trace capture.

- [ ] **Step 3: Run RED**

```bash
flutter test test/features/source_tester/application/source_rule_pipeline_test.dart
```

- [ ] **Step 4: Implement a character scanner**

Track quote mode, escape state, and nesting depths. Treat `||` as a separator only at top level outside quotes. Mark a stage as JavaScript when trimmed text begins with `@js:` or `%@js`.

- [ ] **Step 5: Verify GREEN**

```bash
flutter analyze
flutter test test/features/source_tester/application/source_rule_pipeline_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/source_tester/domain/source_rule_value.dart app/lib/features/source_tester/application/source_rule_pipeline.dart app/test/features/source_tester/application/source_rule_pipeline_test.dart
git commit -m "feat: add source rule pipeline"
```

---

### Task 6: Parser interface and JSON compatibility adapter

**Files:**
- Create: `app/lib/features/source_tester/application/source_rule_parser.dart`
- Create: `app/lib/features/source_tester/data/json_rule_parser.dart`
- Test: `app/test/features/source_tester/data/json_rule_parser_test.dart`

**Interfaces:**
- Consumes: decoded JSON text/value, pipeline stage expressions.
- Produces:

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

`JsonRuleParser` decides standard JSONPath when trimmed expression starts with `$`; otherwise it uses the legacy slash-path evaluator.

- [ ] **Step 1: Write RED legacy slash-path tests**

Use fixture:

```dart
{
  'items': [
    {'name': 'A', 'meta': {'author': '甲'}},
    {'name': 'B', 'meta': {'author': '乙'}},
  ],
}
```

Require:

```text
items -> list of two contexts
items[1]/name -> A
items[2]/name -> B
items[-1]/name -> B
items[-2]/name -> A
```

Positive indexes are one-based; negative indexes count from the end. Index zero and out-of-range values yield an empty result rather than crashing the whole parser.

- [ ] **Step 2: Add RED relative-context tests**

After `items` produces two contexts, evaluating `name` against each item context must yield `A` and `B`; it must not restart at the root.

- [ ] **Step 3: Add RED standard JSONPath tests**

Require `$.items[*].name` to return `A`, `B` through `json_path`, then convert matches immediately into Source Reader-owned values/contexts.

- [ ] **Step 4: Add RED invalid JSON/expression tests**

Invalid response JSON -> `responseParseFailure` at root creation. Invalid standard JSONPath or malformed legacy path must be represented by adapter exceptions that the later result parser can convert into field traces.

- [ ] **Step 5: Run RED**

```bash
flutter test test/features/source_tester/data/json_rule_parser_test.dart
```

- [ ] **Step 6: Implement legacy path parser and JSONPath adapter**

Do not expose `JsonPathMatch` outside `json_rule_parser.dart`.

- [ ] **Step 7: Verify GREEN**

```bash
flutter analyze
flutter test test/features/source_tester/data/json_rule_parser_test.dart
```

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/source_tester/application/source_rule_parser.dart app/lib/features/source_tester/data/json_rule_parser.dart app/test/features/source_tester/data/json_rule_parser_test.dart
git commit -m "feat: parse tester JSON rules"
```

---

### Task 7: HTML XPath compatibility adapter

**Files:**
- Create: `app/lib/features/source_tester/data/html_xpath_rule_parser.dart`
- Create: `app/test/features/source_tester/fixtures/search_fixture.html`
- Test: `app/test/features/source_tester/data/html_xpath_rule_parser_test.dart`

**Interfaces:**
- Consumes: `SourceRuleParser` contracts from Task 6.
- Produces: `HtmlXPathRuleParser implements SourceRuleParser` without exposing `html.Node` or XPath package types.

- [ ] **Step 1: Add a legacy-style HTML fixture**

Fixture must contain at least two table rows so these rules have deterministic distinct outputs:

```text
//table[@class='grid']//tr
//td[1]/a
//td[3]
//td[1]/a/@href
//td[2]/a/text()
```

Use different titles/authors/URLs per row to detect accidental document-root evaluation.

- [ ] **Step 2: Write RED root XPath tests**

Assert list XPath returns two contexts and attribute/text extraction works.

- [ ] **Step 3: Write RED list-relative compatibility test**

For each row context, evaluate legacy field rule `//td[1]/a` and require row-specific book names.

The adapter must implement the compatibility shim locally. If the XPath library treats `//` as absolute from the document when called on a node, normalize the field-stage query only for non-root item contexts so legacy `//td...` behaves relative to the current list item. Lock the chosen transformation with tests; do not rewrite persisted rule strings.

- [ ] **Step 4: Write RED empty/invalid XPath tests**

No match returns an empty value/context list; invalid XPath throws an adapter evaluation error for trace capture.

- [ ] **Step 5: Run RED**

```bash
flutter test test/features/source_tester/data/html_xpath_rule_parser_test.dart
```

- [ ] **Step 6: Implement the adapter**

Use `xpath_selector_html_parser` only inside this data file. Convert text, attribute, and node outputs into Source Reader-owned values and private contexts immediately.

- [ ] **Step 7: Verify GREEN**

```bash
flutter analyze
flutter test test/features/source_tester/data/html_xpath_rule_parser_test.dart
```

- [ ] **Step 8: Commit**

```bash
git add app/lib/features/source_tester/data/html_xpath_rule_parser.dart app/test/features/source_tester/data/html_xpath_rule_parser_test.dart app/test/features/source_tester/fixtures/search_fixture.html
git commit -m "feat: parse tester XPath rules"
```

---

### Task 8: SearchBook result parser, pipeline traces, URL normalization, and limits

**Files:**
- Create: `app/lib/features/source_tester/domain/source_test_report.dart`
- Create: `app/lib/features/source_tester/application/search_book_result_parser.dart`
- Test: `app/test/features/source_tester/application/search_book_result_parser_test.dart`

**Interfaces:**
- Consumes: saved `SourceSearchBookDocument`, `SourceRuleParser`, decoded response text, response URI, source URL.
- Produces:

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
  // nullable String fields listed above
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
  // Source Reader-owned diagnostic fields only
}

final class SearchBookParseResult {
  const SearchBookParseResult({
    required this.items,
    required this.traces,
    required this.warnings,
  });
}

final class SearchBookResultParser {
  SearchBookParseResult parse({
    required SourceSearchBookDocument searchBook,
    required SourceRuleParser parser,
    required String responseText,
    required Uri responseUri,
    required String? sourceUrl,
  });
}
```

- [ ] **Step 1: Write RED list-required tests**

Missing/blank `list` or a list expression that cannot be evaluated at all -> `listRuleFailure`.

A valid list expression with zero matches is a successful empty result, not a configuration exception.

- [ ] **Step 2: Write RED field-isolation tests**

Configure `bookName` valid and `author` invalid. Require bookName results to survive while author is null and a field trace contains the author error.

- [ ] **Step 3: Write RED pipeline partial tests**

For a rule:

```text
//td[1]/a/@href || @js: return result
```

Require the XPath stage output to be retained, trace `partial == true`, and an `unsupportedJavaScriptStage` diagnostic. JavaScript-first rules produce no field value and an explicit unsupported trace.

A configured `JSParser` adds a report warning/trace but does not block declarative fields.

- [ ] **Step 4: Write RED URL normalization tests**

For `cover` and `detailUrl`:

- absolute URL stays unchanged
- relative URL resolves against final response URI
- if response URI cannot provide the intended base, persisted `sourceUrl` is fallback

Use `Uri.resolve` semantics rather than string concatenation.

- [ ] **Step 5: Write RED `skipCount` and 500-item limit tests**

Read `moreKeys` from either Map or JSON-string representation. Apply only integer `skipCount >= 0`. Ignore other `moreKeys` behaviors while adding diagnostic warnings when configured. After skip, cap displayed items at 500 and record truncation warning.

- [ ] **Step 6: Run RED**

```bash
flutter test test/features/source_tester/application/search_book_result_parser_test.dart
```

- [ ] **Step 7: Implement parser orchestration**

Field order is fixed for predictable traces:

```text
bookName, author, cover, desc, cat, status, wordCount, lastChapterTitle, detailUrl
```

Do not mutate the saved source document.

- [ ] **Step 8: Verify GREEN**

```bash
flutter analyze
flutter test test/features/source_tester/application/search_book_result_parser_test.dart
flutter test test/features/source_tester/data/
```

- [ ] **Step 9: Commit**

```bash
git add app/lib/features/source_tester/domain/source_test_report.dart app/lib/features/source_tester/application/search_book_result_parser.dart app/test/features/source_tester/application/search_book_result_parser_test.dart
git commit -m "feat: parse search book test results"
```

---

### Task 9: Production HTTP executor with timeout, redirects, and body limit

**Files:**
- Create: `app/lib/features/source_tester/data/package_http_source_executor.dart`
- Test: `app/test/features/source_tester/data/package_http_source_executor_test.dart`

**Interfaces:**
- Consumes: `SourceHttpRequest`.
- Produces: `PackageHttpSourceExecutor implements SourceHttpExecutor`.

Constructor must allow test injection:

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

- [ ] **Step 1: Write RED mapping tests using an injected fake/mock `http.Client`**

Verify method/URI/headers map to one GET request and response status/headers/body/final URI become `SourceHttpResponse`.

- [ ] **Step 2: Write RED 4xx/5xx tests**

A 404 and a 500 must return `SourceHttpResponse`, not throw `transportFailure`.

- [ ] **Step 3: Write RED timeout and transport tests**

Require timeout -> `SourceTestFailureReason.timeout`; client socket/transport-style exception -> `transportFailure` preserving cause.

- [ ] **Step 4: Write RED body-limit test**

Use a streamed response exceeding configured `maxBodyBytes` by one byte; executor must stop accumulation and throw `responseTooLarge` rather than allocate the entire response.

- [ ] **Step 5: Write RED redirect-policy test**

Use `http.Request.followRedirects = true` and `maxRedirects = 5` on the request passed through the client. Assert configured value on the captured request. A client's too-many-redirects failure maps to transport failure with cause.

- [ ] **Step 6: Run RED**

```bash
flutter test test/features/source_tester/data/package_http_source_executor_test.dart
```

- [ ] **Step 7: Implement streamed HTTP execution**

Use `http.Client.send` so body size is checked incrementally and the final response URL is retained from the HTTP response API when available. Close only a client owned by the executor; never close an injected shared client during `execute`.

- [ ] **Step 8: Verify GREEN**

```bash
flutter analyze
flutter test test/features/source_tester/data/package_http_source_executor_test.dart
```

- [ ] **Step 9: Commit**

```bash
git add app/lib/features/source_tester/data/package_http_source_executor.dart app/test/features/source_tester/data/package_http_source_executor_test.dart
git commit -m "feat: execute source tester HTTP requests"
```

---

### Task 10: SearchBookTestRunner and diagnostic report orchestration

**Files:**
- Modify: `app/lib/features/source_tester/domain/source_test_report.dart`
- Create: `app/lib/features/source_tester/application/search_book_test_runner.dart`
- Create: `app/lib/features/source_tester/application/source_tester_providers.dart`
- Test: `app/test/features/source_tester/application/search_book_test_runner_test.dart`
- Test: `app/test/features/source_tester/application/source_tester_providers_test.dart`

**Interfaces:**
- Consumes: `SourceRepository`, `SourceRequestBuilder`, `SourceHttpExecutor`, `SourceResponseDecoder`, `HtmlXPathRuleParser`, `JsonRuleParser`, `SearchBookResultParser`.
- Produces:

```dart
final class SearchBookTestRunner {
  Future<SearchBookTestReport> run({
    required int sourceId,
    required SearchBookTestInput input,
  });
}
```

Complete `SearchBookTestReport` with source identity, input, request snapshot, response snapshot, parsed items, traces, warnings, and outcome.

- [ ] **Step 1: Write RED persisted-state validation tests**

Runner must call repository `getSource(sourceId)` exactly once per run and reject:

```text
null -> sourceNotFound
platform != StandarReader -> unsupportedPlatform
searchBook missing -> searchBookMissing
requestInfo missing -> requestInfoMissing from builder
```

Never accept a `SourceDocument` or draft as a run parameter.

- [ ] **Step 2: Write RED successful HTML orchestration test**

Use fake repository + fake HTTP executor returning fixture HTML. Require report to include:

- persisted source id/name
- original and resolved request
- response status/final URI/headers/duration/byte count
- selected decoding
- parsed books
- traces and warnings

- [ ] **Step 3: Write RED successful JSON orchestration test**

Use persisted `responseFormatType: json` and fake response JSON. Require JSON adapter selection and parsed results.

- [ ] **Step 4: Write RED unsupported-format test**

Persist missing `responseFormatType`, `str`, `xml`, or another unsupported value and require `unsupportedResponseFormat`. `parserID=DOM` must not change this result.

- [ ] **Step 5: Write RED 500-response continuation test**

Fake HTTP response status 500 with parseable configured body. Require report to retain status 500 and parser outcome rather than treating status as transport failure.

- [ ] **Step 6: Run RED**

```bash
flutter test test/features/source_tester/application/search_book_test_runner_test.dart
```

- [ ] **Step 7: Implement runner**

Order is fixed:

```text
repository reload
-> persisted validation
-> request build
-> HTTP execute
-> response decode
-> parser selection by responseFormatType
-> search result parse
-> report assembly
```

- [ ] **Step 8: Add Riverpod providers**

In `source_tester_providers.dart`, define providers for executor, builder, decoder, both parser adapters, result parser, and runner. `SearchBookTestRunner` provider watches existing `sourceRepositoryProvider`; Sources must not import Tester.

Every side-effect boundary must be overrideable in widget/integration tests, especially `sourceHttpExecutorProvider` and `searchBookTestRunnerProvider`.

- [ ] **Step 9: Verify GREEN and full regression**

```bash
flutter analyze
flutter test test/features/source_tester/application/
flutter test
```

- [ ] **Step 10: Commit**

```bash
git add app/lib/features/source_tester/domain/source_test_report.dart app/lib/features/source_tester/application/search_book_test_runner.dart app/lib/features/source_tester/application/source_tester_providers.dart app/test/features/source_tester/application
git commit -m "feat: run persisted search book tests"
```

---

### Task 11: OR-007 pure Tester input panel

**Files:**
- Create: `docs/omniroute/OR-007-source-tester-input-panel.md`
- OmniRoute allowlist only:
  - Create: `app/lib/features/source_tester/presentation/source_tester_input_panel.dart`
  - Create: `app/test/features/source_tester/presentation/source_tester_input_panel_test.dart`

**Interfaces:**
- Consumes no Riverpod, Repository, runner, parser, HTTP, or domain persistence objects.
- Produces:

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

- [ ] **Step 1: Write OR-007 task document before delegation**

The document must state the two-file allowlist and forbid imports from Riverpod, sources/data, source_tester/application, `package:http`, parser packages, or platform APIs.

Required UI behavior:

- keyword text field required
- page default `1`, integer >= 1
- collapsed `高级参数`
- offset default `0`, integer >= 0
- filter default empty
- `运行搜索测试` disabled while `running == true`
- invalid numeric input prevents callback and shows field-local validation
- one tap produces exactly one callback with normalized values

- [ ] **Step 2: Let OmniRoute perform RED -> GREEN within only the allowlist**

Focused command:

```bash
flutter test test/features/source_tester/presentation/source_tester_input_panel_test.dart
```

Then require:

```bash
flutter analyze
flutter test
git diff --check <OR-007-base>..HEAD
git status --short
```

- [ ] **Step 3: Independently review OmniRoute output**

Verify actual diff contains only the two allowlisted implementation/test files after the OR task document commit. Reject any Riverpod/business dependency or hidden state beyond form controllers.

- [ ] **Step 4: Independently verify CI on the OmniRoute SHA**

Do not trust the worker's summary alone.

---

### Task 12: Tester report presentation and Tester page

**Files:**
- Create: `app/lib/features/source_tester/presentation/source_tester_report_view.dart`
- Create: `app/lib/features/source_tester/presentation/source_tester_page.dart`
- Test: `app/test/features/source_tester/presentation/source_tester_report_view_test.dart`
- Test: `app/test/features/source_tester/presentation/source_tester_page_test.dart`

**Interfaces:**
- Consumes: `SourceTesterInputPanel`, `SearchBookTestRunner`, `SearchBookTestReport`, `sourceRepositoryProvider` for persisted source header only.
- Produces: `SourceTesterPage(sourceId: int)`.

- [ ] **Step 1: Write RED report-view tests**

`SourceTesterReportView(report:)` exposes four tabs with stable keys:

```text
source-tester-tab-results
source-tester-tab-request
source-tester-tab-response
source-tester-tab-traces
```

Require:

- Results renders text metadata without fetching cover images
- Request renders resolved URI/method/headers
- Response renders status, final URI, duration, byte count, encoding, headers, and decoded body truncated to 200,000 characters with a visible truncation note
- Traces render field/rule/output/warnings/errors/partial state

- [ ] **Step 2: Write RED Tester page state tests**

Override repository and runner providers. Require:

- loading persisted source header
- `测试使用已保存版本` notice
- not-found and unsupported-platform page errors
- input callback starts one run and disables duplicate submit while running
- success installs report view
- `SourceTestException` maps to concise Chinese UI message
- unsupported JavaScript diagnostics remain visible in trace/report instead of becoming a generic failure

- [ ] **Step 3: Run RED**

```bash
flutter test test/features/source_tester/presentation/source_tester_report_view_test.dart test/features/source_tester/presentation/source_tester_page_test.dart
```

- [ ] **Step 4: Implement report view**

Use normal Flutter widgets; no syntax-highlighting dependency in A1. Keep large raw body text selectable if practical but do not add a code-editor package.

- [ ] **Step 5: Implement `SourceTesterPage`**

The page owns transient run state only. It never stores a `SourceDocument` for execution; runner receives only `sourceId` + normalized `SearchBookTestInput` so every run reloads persistence.

- [ ] **Step 6: Verify GREEN**

```bash
flutter analyze
flutter test test/features/source_tester/presentation/
```

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/source_tester/presentation/source_tester_report_view.dart app/lib/features/source_tester/presentation/source_tester_page.dart app/test/features/source_tester/presentation/source_tester_report_view_test.dart app/test/features/source_tester/presentation/source_tester_page_test.dart
git commit -m "feat: add source tester page"
```

---

### Task 13: Workbench navigation into Tester

**Files:**
- Modify: `app/lib/features/sources/presentation/source_page.dart`
- Test: `app/test/features/sources/presentation/source_page_test.dart`
- Test: `app/test/features/source_tester/presentation/source_tester_navigation_test.dart`

**Interfaces:**
- Consumes: `SourceTesterPage(sourceId: selectedId)`.
- Produces: AppBar `测试` action enabled only when a source id is selected.

- [ ] **Step 1: Write RED SourcePage action tests**

Require a stable key such as:

```dart
const Key('source-test-action')
```

No selection -> visible but disabled. Selected source -> enabled.

- [ ] **Step 2: Write RED navigation test**

Select database id `2`, tap `测试`, and assert pushed `SourceTesterPage` receives exactly source id `2`. Do not pass the selected `StoredSource` or draft.

- [ ] **Step 3: Run RED**

```bash
flutter test test/features/sources/presentation/source_page_test.dart test/features/source_tester/presentation/source_tester_navigation_test.dart
```

- [ ] **Step 4: Implement minimal Navigator push**

Add an `IconButton` to the existing SourcePage AppBar near import/export:

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

- [ ] **Step 5: Verify GREEN and Workbench regression**

```bash
flutter analyze
flutter test test/features/sources/presentation/source_page_test.dart test/features/source_tester/presentation/source_tester_navigation_test.dart
flutter test
```

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/sources/presentation/source_page.dart app/test/features/sources/presentation/source_page_test.dart app/test/features/source_tester/presentation/source_tester_navigation_test.dart
git commit -m "feat: open source tester from workbench"
```

---

### Task 14: Real SQLite persisted-draft regression

**Files:**
- Create: `app/test/features/source_tester/presentation/source_tester_integration_test.dart`

**Interfaces:**
- Consumes: real `AppDatabase`, `SqliteSourceRepository`, Workbench `SourcePage`, Tester page/runner, fake `SourceHttpExecutor`.
- Produces: end-to-end proof that unsaved Workbench draft never affects Tester execution.

- [ ] **Step 1: Write integration test for persisted-vs-draft semantics**

Arrange real SQLite record:

```text
sourceName = Saved Source
searchBook.requestInfo = https://saved.example/search?q=%@keyWord
responseFormatType = html
list/bookName rules = valid fixture rules
```

Open `SourcePage`, select the source, edit source name and `searchBook.requestInfo` to different draft values without saving, then tap `测试`.

Fake HTTP executor captures `SourceHttpRequest` and returns fixture HTML.

Assert:

- captured request uses `https://saved.example/...`, not draft URL
- Tester header/source identity comes from persisted record
- parsed fixture result succeeds
- navigating back leaves the Workbench unsaved name/request draft unchanged

- [ ] **Step 2: Add real persistence orchestration test**

Insert a `StandarReader` directly through real `SqliteSourceRepository`, create `SearchBookTestRunner` with real repository + fake HTTP, run by id, and assert:

```text
Drift -> SqliteSourceRepository -> runner -> request builder -> fake HTTP -> decoder -> parser -> report
```

- [ ] **Step 3: Run focused integration tests**

```bash
flutter test test/features/source_tester/presentation/source_tester_integration_test.dart
```

Expected: PASS.

- [ ] **Step 4: Run full regression**

```bash
flutter analyze
flutter test
```

- [ ] **Step 5: Commit**

```bash
git add app/test/features/source_tester/presentation/source_tester_integration_test.dart
git commit -m "test: verify persisted source tester flow"
```

---

### Task 15: Native network policy for real source testing

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/ios/Runner/Info.plist`
- Modify: `app/macos/Runner/Info.plist`
- Modify: `app/macos/Runner/DebugProfile.entitlements`
- Modify: `app/macos/Runner/Release.entitlements`
- Test: `app/test/features/source_tester/platform/source_tester_platform_config_test.dart`

**Interfaces:**
- Consumes: native Flutter runner configuration.
- Produces: native Android/iOS/macOS builds able to make outbound HTTPS and legacy HTTP source requests according to A1 scope.

- [ ] **Step 1: Write RED text/config assertions**

Create a Dart test that reads repository files with `File(...)` and asserts:

Android manifest contains:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

and the application explicitly permits cleartext traffic:

```xml
android:usesCleartextTraffic="true"
```

Both iOS and macOS Info.plist contain:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

Both macOS entitlements contain:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

Do not require `network.server` for Tester; preserve existing unrelated entitlements.

- [ ] **Step 2: Run RED**

```bash
flutter test test/features/source_tester/platform/source_tester_platform_config_test.dart
```

Expected: FAIL against current generated runner configuration.

- [ ] **Step 3: Apply minimum native policy changes**

Android:

- add INTERNET permission immediately under `<manifest>`
- add `android:usesCleartextTraffic="true"` on `<application>`

Apple:

- add the ATS dictionary above to iOS and macOS `Info.plist`
- add `com.apple.security.network.client` to both macOS entitlement files

Do not add localhost exceptions or broad unrelated capabilities.

- [ ] **Step 4: Verify platform config and full tests**

```bash
flutter analyze
flutter test test/features/source_tester/platform/source_tester_platform_config_test.dart
flutter test
```

If CI supports platform build commands cheaply, additionally run at least `flutter build apk --debug`; otherwise retain generated-runner syntax verification plus full Flutter test/analyze as the CI gate and perform native build locally before release packaging.

- [ ] **Step 5: Commit**

```bash
git add app/android/app/src/main/AndroidManifest.xml app/ios/Runner/Info.plist app/macos/Runner/Info.plist app/macos/Runner/DebugProfile.entitlements app/macos/Runner/Release.entitlements app/test/features/source_tester/platform/source_tester_platform_config_test.dart
git commit -m "build: enable native source tester networking"
```

---

### Task 16: Final acceptance and milestone review

**Files:**
- No production files unless verification identifies a defect.
- Review: all changes from the dependency-gate base commit through HEAD.

**Interfaces:**
- Consumes: complete A1 implementation.
- Produces: evidence-backed A1 acceptance.

- [ ] **Step 1: Run complete verification from `app/`**

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

Expected: all PASS with zero analyzer issues and zero failed tests.

- [ ] **Step 2: Run whitespace/status verification from repository root**

```bash
git diff --check <A1-implementation-base>..HEAD
git status --short
```

Expected: `git diff --check` exit 0 and clean status.

- [ ] **Step 3: Review scope against the spec**

Explicitly confirm:

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
no Tester database table         yes
no SourceController pollution    yes
```

- [ ] **Step 4: Inspect final diff for architecture leakage**

Reject completion if:

- `features/sources/domain` imports `source_tester`
- SourcePage passes `StoredSource`/draft into Tester instead of id
- presentation imports `package:http`, XPath, JSONPath, or charset packages
- third-party parser node types escape data adapters
- any JavaScript execution runtime was added

- [ ] **Step 5: Record final HEAD and CI evidence**

Confirm the workflow run is for the exact branch HEAD before declaring A1 complete.
