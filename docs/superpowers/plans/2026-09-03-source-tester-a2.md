# Source Tester A2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independent persisted-source `bookDetail` test path to Source Tester while preserving all Source Tester A1 search behavior.

**Architecture:** Search and Book Detail keep separate request builders, result parsers, runners, and report models. Shared deterministic infrastructure is extracted only where A1 and A2 both require it: action request construction, parser selection, rule-pipeline evaluation, URL normalization, request/response diagnostics, and shared report tabs. Every refactor is performed under existing A1 regression tests before new A2 behavior is layered on top.

**Tech Stack:** Flutter 3.47.0, Dart 3.13.0, Riverpod, Drift/SQLite, `http`, `enough_convert`, `xpath_selector`, `xpath_selector_html_parser`, `json_path`, Flutter Test.

**Spec:** `docs/superpowers/specs/2026-09-03-source-tester-a2-design.md`

## Global Constraints

- Work on branch `revival/flutter-workbench`.
- `SourceDocument` raw JSON remains the source of truth; unknown fields must be preserved.
- Tester executes persisted `SourceRepository` state only; unsaved Workbench drafts must never be passed into a Runner.
- A2 supports `StandarReader`, `bookDetail`, GET, HTML/XPath, JSON legacy paths, JSONPath, UTF-8, GB2312/GBK, and declarative `||` pipelines only.
- A2 does not execute JavaScript, POST, WebView, cookies, retry, pagination, `sourceRegex`, `chapterList`, `chapterContent`, or Search -> Detail orchestration.
- Blank `bookDetail.requestInfo` is valid inheritance semantics; it uses `parentResult` and must not map to `requestInfoMissing`.
- `%@result` substitution is raw text substitution and must not be automatically percent encoded.
- A fixed `bookDetail.requestInfo` that does not contain `%@result` can run with an empty `parentResult`.
- No database migration, Reader table, test-history table, or new runtime dependency is allowed in A2.
- CI and tests must never call a live novel website.
- Existing A1 request, parser, runner, presentation, SQLite, and cleanliness behavior is a regression contract.
- Prefer Chinese production-code comments for new non-trivial code.
- OmniRoute is allowed only for narrowly-scoped deterministic presentation tasks with strict file allowlists; do not delegate request semantics, parser infrastructure, runners, or persistence boundaries.

---

## File Structure

### New production files

- `app/lib/features/sources/domain/source_book_detail_document.dart` — typed raw-JSON facade for persisted `bookDetail`.
- `app/lib/features/source_tester/application/source_action_request_builder.dart` — shared URL/header/GET construction after action-specific substitution.
- `app/lib/features/source_tester/application/search_book_request_builder.dart` — A1 Search-specific placeholders and request parameter encoding.
- `app/lib/features/source_tester/application/book_detail_request_builder.dart` — A2 inheritance and raw `%@result` substitution.
- `app/lib/features/source_tester/application/source_rule_pipeline_evaluator.dart` — shared execution of tokenized declarative pipeline stages and unsupported-JS partial semantics.
- `app/lib/features/source_tester/application/source_rule_value_text.dart` — shared conversion of `SourceRuleValue` to the first displayable scalar text.
- `app/lib/features/source_tester/application/source_rule_parser_registry.dart` — deterministic `responseFormatType` -> parser selection.
- `app/lib/features/source_tester/application/source_result_url.dart` — shared relative result-URL completion.
- `app/lib/features/source_tester/application/book_detail_result_parser.dart` — root-oriented parsing of six detail fields.
- `app/lib/features/source_tester/application/book_detail_test_runner.dart` — persisted-source A2 orchestration.
- `app/lib/features/source_tester/domain/book_detail_test_report.dart` — A2 input/result/parse/report models.
- `app/lib/features/source_tester/presentation/source_book_detail_input_panel.dart` — manual upper-level-result input.
- `app/lib/features/source_tester/presentation/source_tester_mode_selector.dart` — Search/Book Detail selector.
- `app/lib/features/source_tester/presentation/source_test_report_tabs.dart` — shared Request/Response/Trace tabs.
- `app/lib/features/source_tester/presentation/book_detail_test_report_view.dart` — six-field A2 Result view using shared tabs.

### Existing production files to modify

- `app/lib/features/sources/domain/source_document.dart`
- `app/lib/features/source_tester/application/search_book_result_parser.dart`
- `app/lib/features/source_tester/application/search_book_test_runner.dart`
- `app/lib/features/source_tester/application/source_tester_providers.dart`
- `app/lib/features/source_tester/domain/source_test_error.dart`
- `app/lib/features/source_tester/domain/source_test_report.dart`
- `app/lib/features/source_tester/presentation/source_tester_page.dart`
- `app/lib/features/source_tester/presentation/source_tester_report_view.dart`
- `.github/workflows/flutter-ci.yml` only for the final Source Tester-generic verification-step label if needed; do not alter dependency or test policy.

### Existing production file to retire after the request split

- `app/lib/features/source_tester/application/source_request_builder.dart` — replace with `source_action_request_builder.dart` + `search_book_request_builder.dart` after A1 regression is green.

### New/modified tests

- `app/test/features/sources/domain/source_book_detail_document_test.dart`
- `app/test/features/sources/domain/source_document_test.dart`
- `app/test/features/source_tester/application/search_book_request_builder_test.dart`
- `app/test/features/source_tester/application/book_detail_request_builder_test.dart`
- `app/test/features/source_tester/application/source_rule_pipeline_evaluator_test.dart`
- `app/test/features/source_tester/application/search_book_result_parser_test.dart`
- `app/test/features/source_tester/application/source_rule_parser_registry_test.dart`
- `app/test/features/source_tester/application/source_result_url_test.dart`
- `app/test/features/source_tester/application/book_detail_result_parser_test.dart`
- `app/test/features/source_tester/application/book_detail_test_runner_test.dart`
- `app/test/features/source_tester/application/search_book_test_runner_test.dart`
- `app/test/features/source_tester/application/source_tester_providers_test.dart`
- `app/test/features/source_tester/domain/source_test_report_test.dart`
- `app/test/features/source_tester/presentation/source_book_detail_input_panel_test.dart`
- `app/test/features/source_tester/presentation/source_tester_mode_selector_test.dart`
- `app/test/features/source_tester/presentation/source_tester_report_view_test.dart`
- `app/test/features/source_tester/presentation/book_detail_test_report_view_test.dart`
- `app/test/features/source_tester/presentation/source_tester_page_test.dart`
- `app/test/features/source_tester/presentation/source_tester_integration_test.dart`

---

### Task 1: Add the persisted `bookDetail` domain facade

**Files:**
- Create: `app/lib/features/sources/domain/source_book_detail_document.dart`
- Modify: `app/lib/features/sources/domain/source_document.dart`
- Create: `app/test/features/sources/domain/source_book_detail_document_test.dart`
- Modify: `app/test/features/sources/domain/source_document_test.dart`

**Interfaces:**
- Consumes: existing `SourceActionDocument`.
- Produces: `SourceBookDetailDocument`, `SourceDocument.bookDetail`.

- [ ] **Step 1: Write the failing domain tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:source_reader/features/sources/domain/source_book_detail_document.dart';

void main() {
  test('bookDetail exposes known fields and preserves unknown raw fields', () {
    final detail = SourceBookDetailDocument.fromRaw(<String, Object?>{
      'actionID': 'bookDetail',
      'parserID': 'DOM',
      'requestInfo': '/book/%@result',
      'cover': '//img/@src',
      'desc': '//div[@id="desc"]/text()',
      'cat': '//span[@class="cat"]/text()',
      'status': '//span[@class="status"]/text()',
      'wordCount': '//span[@class="words"]/text()',
      'lastChapterTitle': '//a[@class="latest"]/text()',
      'futureField': <String, Object?>{'keep': true},
    });

    expect(detail.action.actionId, 'bookDetail');
    expect(detail.cover, '//img/@src');
    expect(detail.desc, '//div[@id="desc"]/text()');
    expect(detail.cat, '//span[@class="cat"]/text()');
    expect(detail.status, '//span[@class="status"]/text()');
    expect(detail.wordCount, '//span[@class="words"]/text()');
    expect(detail.lastChapterTitle, '//a[@class="latest"]/text()');
    expect(detail.toRaw()['futureField'], <String, Object?>{'keep': true});
  });
}
```

Add to `source_document_test.dart`:

```dart
test('bookDetail returns typed facade only for a string-keyed map', () {
  final valid = SourceDocument.fromRaw(<String, Object?>{
    'bookDetail': <String, Object?>{'actionID': 'bookDetail', 'cover': '//img/@src'},
  });
  expect(valid.bookDetail?.cover, '//img/@src');

  final invalid = SourceDocument.fromRaw(<String, Object?>{'bookDetail': 'legacy-invalid'});
  expect(invalid.bookDetail, isNull);
  expect(invalid.toRaw()['bookDetail'], 'legacy-invalid');
});
```

- [ ] **Step 2: Run the focused tests and verify RED**

Run from `app/`:

```bash
flutter test test/features/sources/domain/source_book_detail_document_test.dart test/features/sources/domain/source_document_test.dart
```

Expected: FAIL because `SourceBookDetailDocument` and `SourceDocument.bookDetail` do not exist.

- [ ] **Step 3: Implement the typed facade and accessor**

Create the facade with this shape:

```dart
import 'package:source_reader/features/sources/domain/source_action_document.dart';

final class SourceBookDetailDocument {
  SourceBookDetailDocument._(this._raw);

  factory SourceBookDetailDocument.fromRaw(Map<String, Object?> raw) {
    return SourceBookDetailDocument._(Map<String, Object?>.from(raw));
  }

  final Map<String, Object?> _raw;

  SourceActionDocument get action => SourceActionDocument.fromRaw(_raw);
  String? get cover => _stringValue('cover');
  String? get desc => _stringValue('desc');
  String? get cat => _stringValue('cat');
  String? get status => _stringValue('status');
  String? get wordCount => _stringValue('wordCount');
  String? get lastChapterTitle => _stringValue('lastChapterTitle');

  Map<String, Object?> toRaw() => Map<String, Object?>.from(_raw);

  String? _stringValue(String key) {
    final value = _raw[key];
    return value is String ? value : null;
  }
}
```

Add to `SourceDocument` using the same safe map conversion pattern as `searchBook`:

```dart
SourceBookDetailDocument? get bookDetail {
  final value = _raw['bookDetail'];
  if (value is! Map) return null;

  final converted = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    converted[entry.key as String] = entry.value;
  }
  return SourceBookDetailDocument.fromRaw(converted);
}
```

- [ ] **Step 4: Run focused and Sources-domain regression tests**

```bash
flutter test test/features/sources/domain
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/sources/domain/source_book_detail_document.dart app/lib/features/sources/domain/source_document.dart app/test/features/sources/domain/source_book_detail_document_test.dart app/test/features/sources/domain/source_document_test.dart
git commit -m "feat: add book detail source domain facade"
```

---

### Task 2: Split shared action request construction from A1 Search semantics

**Files:**
- Create: `app/lib/features/source_tester/application/source_action_request_builder.dart`
- Create: `app/lib/features/source_tester/application/search_book_request_builder.dart`
- Retire: `app/lib/features/source_tester/application/source_request_builder.dart`
- Modify: `app/lib/features/source_tester/application/search_book_test_runner.dart`
- Modify: `app/lib/features/source_tester/application/source_tester_providers.dart`
- Replace test path: `app/test/features/source_tester/application/source_request_builder_test.dart` -> `app/test/features/source_tester/application/search_book_request_builder_test.dart`
- Modify A1 call-site tests that instantiate `SourceRequestBuilder`.

**Interfaces:**
- Produces: `SourceActionRequestBuilder.build(...)`, `SearchBookRequestBuilder.build(...)`, existing `SearchBookTestInput`, `BuiltSearchBookRequest`.
- Observable A1 request behavior must remain byte-for-byte equivalent.

- [ ] **Step 1: Convert the A1 request test to the new class name before production code exists**

In the renamed test, instantiate:

```dart
final builder = SearchBookRequestBuilder(
  actionBuilder: const SourceActionRequestBuilder(),
);
```

Keep the existing assertions for UTF-8/GBK encoding, placeholders, relative URL resolution, header parsing/override, invalid headers, script requests, and unknown placeholders unchanged.

- [ ] **Step 2: Run the request test and verify RED**

```bash
flutter test test/features/source_tester/application/search_book_request_builder_test.dart
```

Expected: FAIL because `SearchBookRequestBuilder` and `SourceActionRequestBuilder` do not exist.

- [ ] **Step 3: Extract shared URL/header logic and keep Search substitutions isolated**

`source_action_request_builder.dart` must expose:

```dart
final class BuiltSourceActionRequest {
  BuiltSourceActionRequest({
    required this.request,
    required List<String> warnings,
  }) : warnings = List<String>.unmodifiable(warnings);

  final SourceHttpRequest request;
  final List<String> warnings;
}

final class SourceActionRequestBuilder {
  const SourceActionRequestBuilder();

  BuiltSourceActionRequest build({
    required StoredSource source,
    required String resolvedRequestInfo,
    required Object? actionHttpHeaders,
    required String actionName,
  }) {
    // 1. reject residual %@... placeholders
    // 2. resolve absolute/relative HTTP(S) URI against persisted sourceUrl
    // 3. parse global and action headers using A1 rules
    // 4. merge action headers over global headers case-insensitively
    // 5. return SourceHttpRequest(method: get)
  }
}
```

`search_book_request_builder.dart` must retain A1 inputs and parameter encoding:

```dart
final class SearchBookRequestBuilder {
  const SearchBookRequestBuilder({required this.actionBuilder});
  final SourceActionRequestBuilder actionBuilder;

  BuiltSearchBookRequest build({
    required StoredSource source,
    required SearchBookTestInput input,
  }) {
    final searchBook = source.document.searchBook;
    if (searchBook == null) {
      throw const SourceTestException(SourceTestFailureReason.searchBookMissing);
    }
    final original = searchBook.action.requestInfo;
    if (original == null || original.trim().isEmpty) {
      throw const SourceTestException(SourceTestFailureReason.requestInfoMissing);
    }
    final template = original.trim();
    if (template.startsWith('@js:') || template.contains('%@js')) {
      throw const SourceTestException(SourceTestFailureReason.unsupportedScriptRequest);
    }

    final encoding = _requestEncoding(searchBook.action.requestParamsEncode);
    final resolved = template
        .replaceAll('%@keyWord', _encodeParameter(input.keyWord, encoding))
        .replaceAll('%@filter', _encodeParameter(input.filter, encoding))
        .replaceAll('%@pageIndex', input.pageIndex.toString())
        .replaceAll('%@offset', input.offset.toString());

    final built = actionBuilder.build(
      source: source,
      resolvedRequestInfo: resolved,
      actionHttpHeaders: searchBook.toRaw()['httpHeaders'],
      actionName: 'searchBook',
    );
    return BuiltSearchBookRequest(
      originalRequestInfo: original,
      request: built.request,
      warnings: built.warnings,
    );
  }
}
```

Update Search runner/providers/tests to construct `SearchBookRequestBuilder(actionBuilder: const SourceActionRequestBuilder())`.

- [ ] **Step 4: Run the complete A1 request/runner/page regression set**

```bash
flutter test \
  test/features/source_tester/application/search_book_request_builder_test.dart \
  test/features/source_tester/application/search_book_test_runner_test.dart \
  test/features/source_tester/application/source_tester_providers_test.dart \
  test/features/source_tester/presentation/source_tester_page_test.dart \
  test/features/source_tester/presentation/source_tester_integration_test.dart
```

Expected: PASS with the same A1 request URIs and errors as before.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/application app/test/features/source_tester/application app/test/features/source_tester/presentation
git commit -m "refactor: split source tester request builders"
```

---

### Task 3: Add Book Detail request inheritance and raw `%@result` semantics

**Files:**
- Create: `app/lib/features/source_tester/application/book_detail_request_builder.dart`
- Modify: `app/lib/features/source_tester/domain/source_test_error.dart`
- Modify: `app/lib/features/source_tester/domain/source_test_report.dart` only to introduce `SourceTestRequestOrigin` for builder/report handoff.
- Create: `app/test/features/source_tester/application/book_detail_request_builder_test.dart`

**Interfaces:**
- Consumes: `SourceBookDetailDocument`, `SourceActionRequestBuilder`.
- Produces: `BookDetailTestInput`, `BuiltBookDetailRequest`, `SourceTestRequestOrigin`.

- [ ] **Step 1: Write failing tests for all three request modes**

```dart
test('blank requestInfo inherits relative parentResult', () {
  final built = builder.build(
    source: _source(bookDetail: <String, Object?>{
      'actionID': 'bookDetail',
      'responseFormatType': 'html',
    }),
    input: const BookDetailTestInput(parentResult: '/book/123'),
  );
  expect(built.request.uri, Uri.parse('https://example.com/book/123'));
  expect(built.origin, SourceTestRequestOrigin.inheritedParentResult);
});

test('%@result is substituted without percent encoding', () {
  final built = builder.build(
    source: _source(bookDetail: <String, Object?>{
      'requestInfo': '/proxy?target=%@result',
    }),
    input: const BookDetailTestInput(
      parentResult: 'https://upstream.example/book/1?a=1',
    ),
  );
  expect(
    built.request.uri.toString(),
    'https://example.com/proxy?target=https://upstream.example/book/1?a=1',
  );
  expect(built.origin, SourceTestRequestOrigin.configuredRequestInfo);
});

test('fixed requestInfo does not require parentResult', () {
  final built = builder.build(
    source: _source(bookDetail: <String, Object?>{'requestInfo': '/fixed/detail'}),
    input: const BookDetailTestInput(parentResult: ''),
  );
  expect(built.request.uri, Uri.parse('https://example.com/fixed/detail'));
});
```

Add error tests that assert `parentResultMissing` for blank request info or `%@result` with blank input, and existing `unknownPlaceholder` / `unsupportedScriptRequest` for unsupported configured requests.

- [ ] **Step 2: Run the focused test and verify RED**

```bash
flutter test test/features/source_tester/application/book_detail_request_builder_test.dart
```

Expected: FAIL because A2 request types and new failure reason do not exist.

- [ ] **Step 3: Implement Book Detail request selection**

Use this exact decision order:

```dart
final class BookDetailTestInput {
  const BookDetailTestInput({required this.parentResult});
  final String parentResult;
}

final class BuiltBookDetailRequest {
  BuiltBookDetailRequest({
    required this.originalRequestInfo,
    required this.origin,
    required this.request,
    required List<String> warnings,
  }) : warnings = List<String>.unmodifiable(warnings);

  final String? originalRequestInfo;
  final SourceTestRequestOrigin origin;
  final SourceHttpRequest request;
  final List<String> warnings;
}
```

Builder logic:

```dart
final configured = bookDetail.action.requestInfo?.trim();
final parent = input.parentResult.trim();

late final String effective;
late final SourceTestRequestOrigin origin;

if (configured == null || configured.isEmpty) {
  if (parent.isEmpty) {
    throw const SourceTestException(SourceTestFailureReason.parentResultMissing);
  }
  effective = parent;
  origin = SourceTestRequestOrigin.inheritedParentResult;
} else {
  if (configured.startsWith('@js:') || configured.contains('%@js')) {
    throw const SourceTestException(SourceTestFailureReason.unsupportedScriptRequest);
  }
  if (configured.contains('%@result')) {
    if (parent.isEmpty) {
      throw const SourceTestException(SourceTestFailureReason.parentResultMissing);
    }
    effective = configured.replaceAll('%@result', parent);
  } else {
    effective = configured;
  }
  origin = SourceTestRequestOrigin.configuredRequestInfo;
}
```

Then call `SourceActionRequestBuilder` with `bookDetail.toRaw()['httpHeaders']` and `actionName: 'bookDetail'`.

Add `bookDetailMissing` and `parentResultMissing` to `SourceTestFailureReason`; only the latter is required by this task's builder.

- [ ] **Step 4: Run Book Detail request tests plus the A1 request suite**

```bash
flutter test \
  test/features/source_tester/application/book_detail_request_builder_test.dart \
  test/features/source_tester/application/search_book_request_builder_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/application/book_detail_request_builder.dart app/lib/features/source_tester/domain/source_test_error.dart app/lib/features/source_tester/domain/source_test_report.dart app/test/features/source_tester/application/book_detail_request_builder_test.dart
git commit -m "feat: add book detail request semantics"
```

---

### Task 4: Extract rule-pipeline execution from Search parser under A1 regression

**Files:**
- Create: `app/lib/features/source_tester/application/source_rule_pipeline_evaluator.dart`
- Create: `app/lib/features/source_tester/application/source_rule_value_text.dart`
- Modify: `app/lib/features/source_tester/application/search_book_result_parser.dart`
- Create: `app/test/features/source_tester/application/source_rule_pipeline_evaluator_test.dart`
- Modify: `app/test/features/source_tester/application/search_book_result_parser_test.dart`

**Interfaces:**
- Consumes: existing `tokenizeSourceRulePipeline`, `SourceRuleParser`, `SourceRuleValue`.
- Produces: `SourceRulePipelineEvaluator.evaluate(...)`, `SourceRulePipelineEvaluation`, `sourceRuleValueFirstText(...)`.

- [ ] **Step 1: Write failing evaluator tests for declarative and JS-partial execution**

```dart
test('executes declarative stages in order and stops before JS', () {
  final parser = _FakeParser();
  final result = const SourceRulePipelineEvaluator().evaluate(
    parser: parser,
    initialContext: const _FakeContext('root'),
    rule: 'stage-a || stage-b || @js: result',
  );

  expect(result.stages, <String>['stage-a', 'stage-b', '@js: result']);
  expect(result.executedDeclarative, isTrue);
  expect(result.partial, isTrue);
  expect(result.warnings.single, contains('JS 阶段未执行'));
});

test('JS-only rule is partial without declarative output', () {
  final result = const SourceRulePipelineEvaluator().evaluate(
    parser: _FakeParser(),
    initialContext: const _FakeContext('root'),
    rule: '@js: return result',
  );
  expect(result.executedDeclarative, isFalse);
  expect(result.partial, isTrue);
});
```

- [ ] **Step 2: Run evaluator + existing Search parser tests and verify RED**

```bash
flutter test \
  test/features/source_tester/application/source_rule_pipeline_evaluator_test.dart \
  test/features/source_tester/application/search_book_result_parser_test.dart
```

Expected: new evaluator test FAIL because the evaluator does not exist; existing Search parser tests still PASS before production refactor.

- [ ] **Step 3: Move `_evaluatePipeline` behavior into a stateless shared evaluator**

Expose:

```dart
final class SourceRulePipelineEvaluation {
  SourceRulePipelineEvaluation({
    required this.value,
    required List<SourceRuleContext> contexts,
    required List<String> stages,
    required List<String> warnings,
    required List<String> errors,
    required this.partial,
    required this.executedDeclarative,
  })  : contexts = List.unmodifiable(contexts),
        stages = List.unmodifiable(stages),
        warnings = List.unmodifiable(warnings),
        errors = List.unmodifiable(errors);

  final SourceRuleValue value;
  final List<SourceRuleContext> contexts;
  final List<String> stages;
  final List<String> warnings;
  final List<String> errors;
  final bool partial;
  final bool executedDeclarative;
}

final class SourceRulePipelineEvaluator {
  const SourceRulePipelineEvaluator();

  SourceRulePipelineEvaluation evaluate({
    required SourceRuleParser parser,
    required SourceRuleContext initialContext,
    required String rule,
  }) {
    // Copy A1 execution semantics exactly from SearchBookResultParser.
  }
}
```

Move first-scalar conversion into:

```dart
String? sourceRuleValueFirstText(SourceRuleValue value) {
  for (final raw in _flatten(value)) {
    if (raw == null) continue;
    if (raw is String) return raw.trim();
    if (raw is num || raw is bool) return raw.toString();
    try {
      return jsonEncode(raw);
    } catch (_) {
      return raw.toString();
    }
  }
  return null;
}
```

Change `SearchBookResultParser` to require a `SourceRulePipelineEvaluator` and replace all calls to its old private evaluator with `pipelineEvaluator.evaluate(...)`. Remove the duplicated private evaluator/value-flatten implementation only after the Search tests compile against the shared service.

- [ ] **Step 4: Run tokenizer, evaluator, and full Search parser tests**

```bash
flutter test \
  test/features/source_tester/application/source_rule_pipeline_test.dart \
  test/features/source_tester/application/source_rule_pipeline_evaluator_test.dart \
  test/features/source_tester/application/search_book_result_parser_test.dart
```

Expected: PASS, including existing quoted/nested `||`, item isolation, JS partial, and 500-item behaviors.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/application/source_rule_pipeline_evaluator.dart app/lib/features/source_tester/application/source_rule_value_text.dart app/lib/features/source_tester/application/search_book_result_parser.dart app/test/features/source_tester/application/source_rule_pipeline_evaluator_test.dart app/test/features/source_tester/application/search_book_result_parser_test.dart
git commit -m "refactor: share source rule pipeline evaluation"
```

---

### Task 5: Add deterministic parser registry and move A1 Runner onto it

**Files:**
- Create: `app/lib/features/source_tester/application/source_rule_parser_registry.dart`
- Modify: `app/lib/features/source_tester/application/search_book_test_runner.dart`
- Modify: `app/lib/features/source_tester/application/source_tester_providers.dart`
- Create: `app/test/features/source_tester/application/source_rule_parser_registry_test.dart`
- Modify: `app/test/features/source_tester/application/search_book_test_runner_test.dart`
- Modify: `app/test/features/source_tester/application/source_tester_providers_test.dart`

**Interfaces:**
- Produces: `SourceRuleParserRegistry.select(String? responseFormatType)`.
- Search Runner no longer accepts separate `htmlParser` and `jsonParser`; it accepts one registry.

- [ ] **Step 1: Write failing registry tests**

```dart
test('selects html and json parsers only', () {
  final html = _FakeParser();
  final json = _FakeParser();
  final registry = SourceRuleParserRegistry(htmlParser: html, jsonParser: json);

  expect(registry.select('html'), same(html));
  expect(registry.select('json'), same(json));
});

test('missing responseFormatType remains unsupported legacy str', () {
  final registry = SourceRuleParserRegistry(
    htmlParser: _FakeParser(),
    jsonParser: _FakeParser(),
  );
  expect(
    () => registry.select(null),
    throwsA(isA<SourceTestException>().having(
      (e) => e.reason,
      'reason',
      SourceTestFailureReason.unsupportedResponseFormat,
    )),
  );
});
```

Also cover `str`, `xml`, `data`, `filePath`, and an unknown string as unsupported.

- [ ] **Step 2: Run registry and Search Runner tests and verify RED**

```bash
flutter test \
  test/features/source_tester/application/source_rule_parser_registry_test.dart \
  test/features/source_tester/application/search_book_test_runner_test.dart
```

Expected: registry test FAIL because the registry does not exist.

- [ ] **Step 3: Implement registry and inject it into Search Runner**

```dart
final class SourceRuleParserRegistry {
  const SourceRuleParserRegistry({
    required this.htmlParser,
    required this.jsonParser,
  });

  final SourceRuleParser htmlParser;
  final SourceRuleParser jsonParser;

  SourceRuleParser select(String? responseFormatType) {
    return switch (responseFormatType?.trim()) {
      'html' => htmlParser,
      'json' => jsonParser,
      final unsupported => throw SourceTestException(
          SourceTestFailureReason.unsupportedResponseFormat,
          message: unsupported,
        ),
    };
  }
}
```

Change `SearchBookTestRunner` constructor to:

```dart
const SearchBookTestRunner({
  required this.repository,
  required this.requestBuilder,
  required this.httpExecutor,
  required this.responseDecoder,
  required this.parserRegistry,
  required this.resultParser,
});
```

and select with:

```dart
final parser = parserRegistry.select(searchBook.action.responseFormatType);
```

Update providers/tests to build one registry from the existing HTML and JSON parser providers.

- [ ] **Step 4: Run Search Runner/provider/page regression tests**

```bash
flutter test \
  test/features/source_tester/application/source_rule_parser_registry_test.dart \
  test/features/source_tester/application/search_book_test_runner_test.dart \
  test/features/source_tester/application/source_tester_providers_test.dart \
  test/features/source_tester/presentation/source_tester_page_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/application/source_rule_parser_registry.dart app/lib/features/source_tester/application/search_book_test_runner.dart app/lib/features/source_tester/application/source_tester_providers.dart app/test/features/source_tester/application/source_rule_parser_registry_test.dart app/test/features/source_tester/application/search_book_test_runner_test.dart app/test/features/source_tester/application/source_tester_providers_test.dart app/test/features/source_tester/presentation/source_tester_page_test.dart
git commit -m "refactor: centralize source tester parser selection"
```

---

### Task 6: Generalize shared report diagnostics without generic business reports

**Files:**
- Modify: `app/lib/features/source_tester/domain/source_test_report.dart`
- Modify: `app/lib/features/source_tester/application/search_book_test_runner.dart`
- Modify: `app/lib/features/source_tester/presentation/source_tester_report_view.dart`
- Create: `app/test/features/source_tester/domain/source_test_report_test.dart`
- Modify A1 tests that refer to `SearchBookTestOutcome` or construct `SourceTestRequestSnapshot`.

**Interfaces:**
- Produces: `SourceTestOutcome`, `SourceTestRequestOrigin`, request snapshot `origin`.
- Keeps `SearchBookTestReport` concrete and Search-specific.

- [ ] **Step 1: Write failing shared-report tests**

```dart
test('request snapshot records configured or inherited origin', () {
  final snapshot = SourceTestRequestSnapshot(
    originalRequestInfo: '/search',
    origin: SourceTestRequestOrigin.configuredRequestInfo,
    uri: Uri.parse('https://example.com/search'),
    method: SourceHttpMethod.get,
    headers: const <String, String>{},
  );
  expect(snapshot.origin, SourceTestRequestOrigin.configuredRequestInfo);
});

test('SourceTestOutcome is shared by Search report', () {
  expect(SourceTestOutcome.values, contains(SourceTestOutcome.success));
  expect(SourceTestOutcome.values, contains(SourceTestOutcome.completedWithWarnings));
});
```

- [ ] **Step 2: Run report-domain and A1 report-view tests and verify RED**

```bash
flutter test \
  test/features/source_tester/domain/source_test_report_test.dart \
  test/features/source_tester/presentation/source_tester_report_view_test.dart
```

Expected: FAIL because shared outcome/origin API is not yet present.

- [ ] **Step 3: Rename the outcome and make request origin explicit**

Use:

```dart
enum SourceTestOutcome { success, completedWithWarnings }

enum SourceTestRequestOrigin {
  configuredRequestInfo,
  inheritedParentResult,
}
```

Update `SourceTestRequestSnapshot`:

```dart
final SourceTestRequestOrigin origin;
```

Update A1 Runner to set:

```dart
origin: SourceTestRequestOrigin.configuredRequestInfo,
```

Replace every `SearchBookTestOutcome` reference with `SourceTestOutcome`, including `_outcomeText` in the current A1 report view.

- [ ] **Step 4: Run all Source Tester domain/application/presentation tests**

```bash
flutter test test/features/source_tester/domain test/features/source_tester/application test/features/source_tester/presentation
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester app/test/features/source_tester
git commit -m "refactor: share source tester report diagnostics"
```

---

### Task 7: Extract shared result URL completion under Search regression

**Files:**
- Create: `app/lib/features/source_tester/application/source_result_url.dart`
- Modify: `app/lib/features/source_tester/application/search_book_result_parser.dart`
- Create: `app/test/features/source_tester/application/source_result_url_test.dart`
- Modify: `app/test/features/source_tester/application/search_book_result_parser_test.dart`

**Interfaces:**
- Produces: `normalizeSourceResultUrl(...)` for Search `cover/detailUrl` and Book Detail `cover`.

- [ ] **Step 1: Write failing URL-normalization tests**

```dart
test('resolves relative result against final response URI first', () {
  expect(
    normalizeSourceResultUrl(
      '/cover/a.jpg',
      finalResponseUri: Uri.parse('https://redirect.example/book/1'),
      sourceUrl: 'https://source.example/',
    ),
    'https://redirect.example/cover/a.jpg',
  );
});

test('keeps absolute URL unchanged', () {
  expect(
    normalizeSourceResultUrl(
      'https://cdn.example/a.jpg',
      finalResponseUri: Uri.parse('https://example.com/book/1'),
      sourceUrl: 'https://source.example/',
    ),
    'https://cdn.example/a.jpg',
  );
});
```

- [ ] **Step 2: Run URL and Search parser tests and verify RED**

```bash
flutter test \
  test/features/source_tester/application/source_result_url_test.dart \
  test/features/source_tester/application/search_book_result_parser_test.dart
```

Expected: new URL test FAIL because helper does not exist.

- [ ] **Step 3: Move A1 `_normalizeUrl` behavior into the shared helper**

```dart
String normalizeSourceResultUrl(
  String value, {
  required Uri finalResponseUri,
  required String? sourceUrl,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme) return trimmed;

  final finalBase = finalResponseUri.hasScheme ? finalResponseUri : null;
  final sourceBase = sourceUrl == null ? null : Uri.tryParse(sourceUrl.trim());
  final base = finalBase ?? (sourceBase?.hasScheme == true ? sourceBase : null);
  if (base == null) return trimmed;
  try {
    return base.resolve(trimmed).toString();
  } catch (_) {
    return trimmed;
  }
}
```

Replace Search parser's private normalization helper with this function for `cover` and `detailUrl`.

- [ ] **Step 4: Run focused tests**

```bash
flutter test \
  test/features/source_tester/application/source_result_url_test.dart \
  test/features/source_tester/application/search_book_result_parser_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/application/source_result_url.dart app/lib/features/source_tester/application/search_book_result_parser.dart app/test/features/source_tester/application/source_result_url_test.dart app/test/features/source_tester/application/search_book_result_parser_test.dart
git commit -m "refactor: share source result URL normalization"
```

---

### Task 8: Add Book Detail result/report models and root-oriented parser

**Files:**
- Create: `app/lib/features/source_tester/domain/book_detail_test_report.dart`
- Create: `app/lib/features/source_tester/application/book_detail_result_parser.dart`
- Create: `app/test/features/source_tester/application/book_detail_result_parser_test.dart`

**Interfaces:**
- Consumes: `SourceBookDetailDocument`, `SourceRuleParser`, `SourceRulePipelineEvaluator`, `sourceRuleValueFirstText`, `normalizeSourceResultUrl`.
- Produces: `BookDetailTestResult`, `BookDetailParseResult`, `BookDetailTestReport` types needed by the Runner.

- [ ] **Step 1: Write failing HTML/JSON/parser-isolation tests**

Use a real `HtmlXPathRuleParser` fixture for one test:

```dart
test('parses six HTML detail fields from root context', () {
  final parsed = BookDetailResultParser(
    pipelineEvaluator: const SourceRulePipelineEvaluator(),
  ).parse(
    bookDetail: SourceBookDetailDocument.fromRaw(<String, Object?>{
      'responseFormatType': 'html',
      'cover': '//img[@id="cover"]/@src',
      'desc': '//div[@id="desc"]/text()',
      'cat': '//span[@id="cat"]/text()',
      'status': '//span[@id="status"]/text()',
      'wordCount': '//span[@id="words"]/text()',
      'lastChapterTitle': '//a[@id="latest"]/text()',
    }),
    parser: HtmlXPathRuleParser(),
    responseText: _detailHtml,
    finalResponseUri: Uri.parse('https://example.com/book/1'),
    sourceUrl: 'https://example.com/',
  );

  expect(parsed.result.cover, 'https://example.com/images/cover.jpg');
  expect(parsed.result.desc, '简介内容');
  expect(parsed.result.cat, '玄幻');
  expect(parsed.result.status, '连载');
  expect(parsed.result.wordCount, '100万字');
  expect(parsed.result.lastChapterTitle, '第一百章');
});
```

Add tests for:

```dart
// one malformed field -> that field null, others still parsed
// "//div/text() || @js: result" -> supported prefix retained + partial trace
// JS-only field -> null + partial trace
// configured JSParser -> warning
// no configured fields -> empty result + warning, not exception
// JSON legacy slash path and $ JSONPath using JsonRuleParser
```

- [ ] **Step 2: Run the Book Detail parser test and verify RED**

```bash
flutter test test/features/source_tester/application/book_detail_result_parser_test.dart
```

Expected: FAIL because A2 report/parser types do not exist.

- [ ] **Step 3: Implement A2 report models and parser**

`book_detail_test_report.dart` must contain:

```dart
final class BookDetailTestInputSnapshot {
  const BookDetailTestInputSnapshot({required this.parentResult});
  final String parentResult;
}

final class BookDetailTestResult {
  const BookDetailTestResult({
    this.cover,
    this.desc,
    this.cat,
    this.status,
    this.wordCount,
    this.lastChapterTitle,
  });
  final String? cover;
  final String? desc;
  final String? cat;
  final String? status;
  final String? wordCount;
  final String? lastChapterTitle;
}

final class BookDetailParseResult {
  BookDetailParseResult({
    required this.result,
    required List<SourceRuleTrace> traces,
    required List<String> warnings,
  })  : traces = List.unmodifiable(traces),
        warnings = List.unmodifiable(warnings);
  final BookDetailTestResult result;
  final List<SourceRuleTrace> traces;
  final List<String> warnings;
}
```

The parser must create one root context, then evaluate each configured field independently with `pipelineEvaluator.evaluate(...)`. It must never require a list rule. For each configured rule, add one `SourceRuleTrace` with that field name. Normalize only `cover` using `normalizeSourceResultUrl`.

If `parser.createRoot(responseText)` itself fails, convert that failure to:

```dart
SourceTestException(
  SourceTestFailureReason.responseParseFailure,
  message: 'bookDetail 响应无法创建解析上下文',
  cause: error,
)
```

If all six rules are blank, append `bookDetail 未配置可执行响应规则` and return an empty `BookDetailTestResult`.

- [ ] **Step 4: Run Book Detail parser plus A1 Search parser regression**

```bash
flutter test \
  test/features/source_tester/application/book_detail_result_parser_test.dart \
  test/features/source_tester/application/search_book_result_parser_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/domain/book_detail_test_report.dart app/lib/features/source_tester/application/book_detail_result_parser.dart app/test/features/source_tester/application/book_detail_result_parser_test.dart
git commit -m "feat: parse book detail test results"
```

---

### Task 9: Add the persisted-source Book Detail Runner

**Files:**
- Create: `app/lib/features/source_tester/application/book_detail_test_runner.dart`
- Create: `app/test/features/source_tester/application/book_detail_test_runner_test.dart`

**Interfaces:**
- Consumes: repository, `BookDetailRequestBuilder`, HTTP executor, decoder, parser registry, `BookDetailResultParser`.
- Produces: `Future<BookDetailTestReport> run({required int sourceId, required BookDetailTestInput input})`.

- [ ] **Step 1: Write failing Runner tests for persistence, HTTP warnings, and encoding**

At minimum include:

```dart
test('reloads persisted source and returns parsed detail report', () async {
  final executor = _FakeExecutor(_detailResponse());
  final runner = _runner(
    repository: _FakeRepository(_storedBookDetailSource()),
    executor: executor,
  );

  final report = await runner.run(
    sourceId: 7,
    input: const BookDetailTestInput(parentResult: '/book/1'),
  );

  expect(executor.lastRequest?.uri, Uri.parse('https://example.com/book/1'));
  expect(report.result.status, '连载');
  expect(report.request.origin, SourceTestRequestOrigin.inheritedParentResult);
  expect(report.outcome, SourceTestOutcome.success);
});
```

Add focused tests for `sourceNotFound`, `unsupportedPlatform`, `bookDetailMissing`, HTTP 404/500 retained as reports with warnings, GBK decoding, and transport exception propagation/mapping.

- [ ] **Step 2: Run the Runner test and verify RED**

```bash
flutter test test/features/source_tester/application/book_detail_test_runner_test.dart
```

Expected: FAIL because `BookDetailTestRunner` does not exist.

- [ ] **Step 3: Implement the Runner in the spec-defined order**

Constructor:

```dart
const BookDetailTestRunner({
  required this.repository,
  required this.requestBuilder,
  required this.httpExecutor,
  required this.responseDecoder,
  required this.parserRegistry,
  required this.resultParser,
});
```

Run flow:

```dart
final source = await repository.getSource(sourceId);
if (source == null) throw const SourceTestException(SourceTestFailureReason.sourceNotFound);
if (source.platform != 'StandarReader') {
  throw SourceTestException(SourceTestFailureReason.unsupportedPlatform, message: source.platform);
}
final bookDetail = source.document.bookDetail;
if (bookDetail == null) {
  throw const SourceTestException(SourceTestFailureReason.bookDetailMissing);
}

final built = requestBuilder.build(source: source, input: input);
final response = await httpExecutor.execute(built.request);
final decoded = responseDecoder.decode(
  response: response,
  configuredEncoding: bookDetail.action.responseEncode,
);
final parser = parserRegistry.select(bookDetail.action.responseFormatType);
final parsed = resultParser.parse(
  bookDetail: bookDetail,
  parser: parser,
  responseText: decoded.text,
  finalResponseUri: response.finalUri,
  sourceUrl: source.document.sourceUrl,
);
```

Collect request warnings + decode warnings + parse warnings; append `HTTP 状态码 N` for non-2xx. Outcome is success only when warnings are empty and no trace is partial/has warnings/has errors.

Build `BookDetailTestReport` with input snapshot, request origin, response snapshot, result, traces, warnings, and shared outcome.

- [ ] **Step 4: Run Book Detail and Search Runner tests together**

```bash
flutter test \
  test/features/source_tester/application/book_detail_test_runner_test.dart \
  test/features/source_tester/application/search_book_test_runner_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/application/book_detail_test_runner.dart app/test/features/source_tester/application/book_detail_test_runner_test.dart
git commit -m "feat: run persisted book detail tests"
```

---

### Task 10: Wire shared/A2 services through Riverpod providers

**Files:**
- Modify: `app/lib/features/source_tester/application/source_tester_providers.dart`
- Modify: `app/test/features/source_tester/application/source_tester_providers_test.dart`

**Interfaces:**
- Produces providers for action/search/detail request builders, pipeline evaluator, parser registry, Book Detail parser, and Book Detail Runner.

- [ ] **Step 1: Add failing provider-container assertions**

```dart
test('provides Book Detail runner and shared evaluator/registry', () {
  final container = ProviderContainer(overrides: [
    sourceRepositoryProvider.overrideWithValue(_FakeRepository()),
    sourceHttpExecutorProvider.overrideWithValue(_FakeExecutor()),
  ]);
  addTearDown(container.dispose);

  expect(container.read(sourceRulePipelineEvaluatorProvider), isA<SourceRulePipelineEvaluator>());
  expect(container.read(sourceRuleParserRegistryProvider), isA<SourceRuleParserRegistry>());
  expect(container.read(bookDetailTestRunnerProvider), isA<BookDetailTestRunner>());
});
```

- [ ] **Step 2: Run provider tests and verify RED**

```bash
flutter test test/features/source_tester/application/source_tester_providers_test.dart
```

Expected: FAIL because new providers do not exist.

- [ ] **Step 3: Add provider wiring with one shared instance per provider graph**

Provide at least:

```dart
final sourceActionRequestBuilderProvider = Provider((ref) => const SourceActionRequestBuilder());
final searchBookRequestBuilderProvider = Provider((ref) => SearchBookRequestBuilder(
  actionBuilder: ref.watch(sourceActionRequestBuilderProvider),
));
final bookDetailRequestBuilderProvider = Provider((ref) => BookDetailRequestBuilder(
  actionBuilder: ref.watch(sourceActionRequestBuilderProvider),
));
final sourceRulePipelineEvaluatorProvider = Provider((ref) => const SourceRulePipelineEvaluator());
final sourceRuleParserRegistryProvider = Provider((ref) => SourceRuleParserRegistry(
  htmlParser: ref.watch(sourceHtmlParserProvider),
  jsonParser: ref.watch(sourceJsonParserProvider),
));
final bookDetailResultParserProvider = Provider((ref) => BookDetailResultParser(
  pipelineEvaluator: ref.watch(sourceRulePipelineEvaluatorProvider),
));
final bookDetailTestRunnerProvider = Provider((ref) => BookDetailTestRunner(
  repository: ref.watch(sourceRepositoryProvider),
  requestBuilder: ref.watch(bookDetailRequestBuilderProvider),
  httpExecutor: ref.watch(sourceHttpExecutorProvider),
  responseDecoder: ref.watch(sourceResponseDecoderProvider),
  parserRegistry: ref.watch(sourceRuleParserRegistryProvider),
  resultParser: ref.watch(bookDetailResultParserProvider),
));
```

Also update the Search providers to consume the new Search builder, shared evaluator, and parser registry.

- [ ] **Step 4: Run provider + both Runner tests**

```bash
flutter test \
  test/features/source_tester/application/source_tester_providers_test.dart \
  test/features/source_tester/application/search_book_test_runner_test.dart \
  test/features/source_tester/application/book_detail_test_runner_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/application/source_tester_providers.dart app/test/features/source_tester/application/source_tester_providers_test.dart
git commit -m "feat: wire book detail tester providers"
```

---

### Task 11: Add the Book Detail input panel

**Files:**
- Create: `app/lib/features/source_tester/presentation/source_book_detail_input_panel.dart`
- Create: `app/test/features/source_tester/presentation/source_book_detail_input_panel_test.dart`

**Interfaces:**
- Produces: `SourceBookDetailInput`, `SourceBookDetailInputPanel`.
- This task is eligible for OmniRoute only with these two files in the allowlist.

- [ ] **Step 1: Write failing widget tests**

```dart
testWidgets('allows blank parent result because Runner decides if it is required', (tester) async {
  SourceBookDetailInput? submitted;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SourceBookDetailInputPanel(
        running: false,
        onRun: (value) => submitted = value,
      ),
    ),
  ));

  expect(find.text('上一级结果 URL'), findsOneWidget);
  expect(find.textContaining('requestInfo 为空或包含 %@result 时需要填写'), findsOneWidget);
  await tester.tap(find.byKey(const Key('source-tester-detail-run')));
  expect(submitted?.parentResult, '');
});

testWidgets('disables run button while running', (tester) async {
  // Pump running: true and assert the FilledButton is disabled.
});
```

- [ ] **Step 2: Run the input-panel test and verify RED**

```bash
flutter test test/features/source_tester/presentation/source_book_detail_input_panel_test.dart
```

Expected: FAIL because the widget does not exist.

- [ ] **Step 3: Implement a minimal stateful input panel**

Use keys:

```text
source-tester-detail-parent-result
source-tester-detail-run
```

Submission model:

```dart
final class SourceBookDetailInput {
  const SourceBookDetailInput({required this.parentResult});
  final String parentResult;
}
```

The button must call `onRun(SourceBookDetailInput(parentResult: controller.text.trim()))` without UI-required validation.

- [ ] **Step 4: Run the widget test**

```bash
flutter test test/features/source_tester/presentation/source_book_detail_input_panel_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/presentation/source_book_detail_input_panel.dart app/test/features/source_tester/presentation/source_book_detail_input_panel_test.dart
git commit -m "feat: add book detail tester input panel"
```

---

### Task 12: Add a Search/Book Detail mode selector with running-state safety

**Files:**
- Create: `app/lib/features/source_tester/presentation/source_tester_mode_selector.dart`
- Create: `app/test/features/source_tester/presentation/source_tester_mode_selector_test.dart`

**Interfaces:**
- Produces: `SourceTesterMode.search`, `SourceTesterMode.bookDetail`, selector callback.
- This task is eligible for OmniRoute only with these two files in the allowlist.

- [ ] **Step 1: Write failing mode-selector tests**

```dart
testWidgets('defaults are rendered with stable Search and Detail keys', (tester) async {
  SourceTesterMode selected = SourceTesterMode.search;
  await tester.pumpWidget(MaterialApp(
    home: StatefulBuilder(builder: (context, setState) {
      return SourceTesterModeSelector(
        value: selected,
        running: false,
        onChanged: (value) => setState(() => selected = value),
      );
    }),
  ));

  expect(find.byKey(const Key('source-tester-mode-search')), findsOneWidget);
  expect(find.byKey(const Key('source-tester-mode-book-detail')), findsOneWidget);
  await tester.tap(find.byKey(const Key('source-tester-mode-book-detail')));
  await tester.pump();
  expect(selected, SourceTesterMode.bookDetail);
});
```

Add a second test that `running: true` prevents changing modes.

- [ ] **Step 2: Run the selector test and verify RED**

```bash
flutter test test/features/source_tester/presentation/source_tester_mode_selector_test.dart
```

Expected: FAIL because selector types do not exist.

- [ ] **Step 3: Implement the selector**

```dart
enum SourceTesterMode { search, bookDetail }
```

Use a `SegmentedButton<SourceTesterMode>` with two `ButtonSegment`s. Set `onSelectionChanged: null` while `running`; otherwise call `onChanged(selection.single)`.

Label segments `搜索测试` and `书籍详情` and keep stable keys on segment labels/content.

- [ ] **Step 4: Run the selector test**

```bash
flutter test test/features/source_tester/presentation/source_tester_mode_selector_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/presentation/source_tester_mode_selector.dart app/test/features/source_tester/presentation/source_tester_mode_selector_test.dart
git commit -m "feat: add source tester mode selector"
```

---

### Task 13: Extract shared report tabs and add the Book Detail result view

**Files:**
- Create: `app/lib/features/source_tester/presentation/source_test_report_tabs.dart`
- Create: `app/lib/features/source_tester/presentation/book_detail_test_report_view.dart`
- Modify: `app/lib/features/source_tester/presentation/source_tester_report_view.dart`
- Modify: `app/test/features/source_tester/presentation/source_tester_report_view_test.dart`
- Create: `app/test/features/source_tester/presentation/book_detail_test_report_view_test.dart`

**Interfaces:**
- Produces: `SourceTestReportTabs`, `BookDetailTestReportView`.
- Existing `SourceTesterReportView` remains the Search-specific public view and delegates shared diagnostic tabs.

- [ ] **Step 1: Write failing A2 report-view tests while preserving A1 assertions**

```dart
testWidgets('Book Detail result shows six fixed fields including missing values', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: BookDetailTestReportView(report: _detailReport())),
  ));

  expect(find.text('封面'), findsOneWidget);
  expect(find.text('简介'), findsOneWidget);
  expect(find.text('分类'), findsOneWidget);
  expect(find.text('状态'), findsOneWidget);
  expect(find.text('字数'), findsOneWidget);
  expect(find.text('最新章节'), findsOneWidget);
  expect(find.text('连载'), findsOneWidget);
});

testWidgets('Request tab displays inherited request origin', (tester) async {
  // Pump a detail report whose request origin is inheritedParentResult,
  // tap source-tester-tab-request, assert "请求来源：继承上一级结果 URL".
});
```

Keep existing Search report tests asserting result count, request/response tabs, JS partial diagnostics, and body truncation.

- [ ] **Step 2: Run both report-view tests and verify RED**

```bash
flutter test \
  test/features/source_tester/presentation/source_tester_report_view_test.dart \
  test/features/source_tester/presentation/book_detail_test_report_view_test.dart
```

Expected: A2 test FAIL because shared/detail views do not exist; existing A1 report test remains green before refactor.

- [ ] **Step 3: Extract only the diagnostic shell**

`SourceTestReportTabs` constructor:

```dart
const SourceTestReportTabs({
  super.key,
  required this.resultView,
  required this.request,
  required this.response,
  required this.traces,
});
```

It owns the existing four tab keys:

```text
source-tester-tab-results
source-tester-tab-request
source-tester-tab-response
source-tester-tab-traces
```

and the response body display limit of 200000 characters.

Request-origin text mapping:

```dart
String _originText(SourceTestRequestOrigin origin) => switch (origin) {
  SourceTestRequestOrigin.configuredRequestInfo => 'bookDetail.requestInfo / searchBook.requestInfo',
  SourceTestRequestOrigin.inheritedParentResult => '继承上一级结果 URL',
};
```

For Search, prefer presentation text `请求来源：配置的 requestInfo`; for Book Detail configured requests the same generic wording is sufficient. Do not infer action name inside the shared tab component.

Refactor `SourceTesterReportView` so only Search Result content remains Search-specific, then pass request/response/traces to `SourceTestReportTabs`.

`BookDetailTestReportView` passes a six-field result widget and the same diagnostics. Render `—` for missing values and warnings/outcome above the fields.

- [ ] **Step 4: Run report views plus A1 page test**

```bash
flutter test \
  test/features/source_tester/presentation/source_tester_report_view_test.dart \
  test/features/source_tester/presentation/book_detail_test_report_view_test.dart \
  test/features/source_tester/presentation/source_tester_page_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/presentation/source_test_report_tabs.dart app/lib/features/source_tester/presentation/book_detail_test_report_view.dart app/lib/features/source_tester/presentation/source_tester_report_view.dart app/test/features/source_tester/presentation/source_tester_report_view_test.dart app/test/features/source_tester/presentation/book_detail_test_report_view_test.dart
git commit -m "refactor: share source tester diagnostic tabs"
```

---

### Task 14: Integrate A2 into `SourceTesterPage` without losing A1 reports

**Files:**
- Modify: `app/lib/features/source_tester/presentation/source_tester_page.dart`
- Modify: `app/test/features/source_tester/presentation/source_tester_page_test.dart`

**Interfaces:**
- Consumes: both Runner providers, mode selector, both input panels, both report views.
- Produces: one page with independent Search and Book Detail report state.

- [ ] **Step 1: Add failing page tests for default mode, A2 run, preservation, and running safety**

Add tests equivalent to:

```dart
testWidgets('Search is default and Detail can run independently', (tester) async {
  await tester.pumpWidget(_app(repository: _FakeRepository(_storedSourceWithDetail())));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('source-tester-input-keyword')), findsOneWidget);
  expect(find.byKey(const Key('source-tester-detail-parent-result')), findsNothing);

  await tester.tap(find.byKey(const Key('source-tester-mode-book-detail')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('source-tester-detail-parent-result')), findsOneWidget);

  await tester.enterText(
    find.byKey(const Key('source-tester-detail-parent-result')),
    '/book/1',
  );
  await tester.tap(find.byKey(const Key('source-tester-detail-run')));
  await tester.pumpAndSettle();
  expect(find.text('连载'), findsOneWidget);
});
```

Add a test that runs Search, switches to Detail and runs it, then switches back and still sees the prior Search report without a second HTTP call.

Add a test using a `Completer<SourceHttpResponse>` that while one mode is running, tapping the other mode does not change the selected mode.

- [ ] **Step 2: Run page tests and verify RED**

```bash
flutter test test/features/source_tester/presentation/source_tester_page_test.dart
```

Expected: new A2 assertions FAIL.

- [ ] **Step 3: Add independent page state and A2 error mapping**

State shape:

```dart
SourceTesterMode _mode = SourceTesterMode.search;
bool _running = false;
SearchBookTestReport? _searchReport;
BookDetailTestReport? _bookDetailReport;
String? _searchErrorText;
String? _bookDetailErrorText;
```

Keep `_runSearch(SourceTesterInput input)` for A1 and add:

```dart
Future<void> _runBookDetail(SourceBookDetailInput input) async {
  if (_running) return;
  setState(() {
    _running = true;
    _bookDetailReport = null;
    _bookDetailErrorText = null;
  });
  try {
    final report = await ref.read(bookDetailTestRunnerProvider).run(
      sourceId: widget.sourceId,
      input: BookDetailTestInput(parentResult: input.parentResult),
    );
    if (mounted) setState(() => _bookDetailReport = report);
  } on SourceTestException catch (error) {
    if (mounted) setState(() => _bookDetailErrorText = _formatSourceTestError(error));
  } finally {
    if (mounted) setState(() => _running = false);
  }
}
```

Extend `_formatSourceTestError`:

```dart
SourceTestFailureReason.bookDetailMissing => '当前书源没有 bookDetail 规则',
SourceTestFailureReason.parentResultMissing => '当前详情请求需要上一级结果 URL',
```

Keep Search's `requestInfoMissing` message explicitly about `searchBook.requestInfo`.

Render the mode selector above the active input panel. Use `_searchReport` only in Search mode and `_bookDetailReport` only in Book Detail mode. Changing mode must not clear either report. Disable mode switching while `_running`.

- [ ] **Step 4: Run all presentation tests**

```bash
flutter test test/features/source_tester/presentation
```

Expected: PASS, including existing Workbench navigation and persisted-version notice.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/source_tester/presentation/source_tester_page.dart app/test/features/source_tester/presentation/source_tester_page_test.dart
git commit -m "feat: add book detail mode to source tester"
```

---

### Task 15: Add real SQLite A2 persistence and unsaved-draft regressions

**Files:**
- Modify: `app/test/features/source_tester/presentation/source_tester_integration_test.dart`
- Optional fixture create: `app/test/features/source_tester/fixtures/book_detail_fixture.html` if an inline deterministic fixture would make the test harder to read.

**Interfaces:**
- Verifies the real `Drift -> SqliteSourceRepository -> BookDetailTestRunner -> fake HTTP -> parser -> report` path.
- Verifies Workbench unsaved basic-field draft does not affect A2.

- [ ] **Step 1: Extend the persisted fixture source with `bookDetail` and write the failing integration test**

Add persisted data:

```dart
'bookDetail': <String, Object?>{
  'actionID': 'bookDetail',
  'parserID': 'DOM',
  'responseEncode': 'utf-8',
  'responseFormatType': 'html',
  'cover': '//img[@id="cover"]/@src',
  'desc': '//div[@id="desc"]/text()',
  'status': '//span[@id="status"]/text()',
  'lastChapterTitle': '//a[@id="latest"]/text()',
},
```

Add a widget regression:

```text
1. Insert saved sourceUrl = https://saved.example/base/
2. Open Workbench and edit sourceUrl to https://draft.example/base/ without saving
3. Open Tester
4. Switch to Book Detail
5. Enter parentResult = /book/1
6. Run
7. Assert captured request = https://saved.example/book/1
8. Navigate back
9. Assert Workbench sourceUrl controller still contains https://draft.example/base/
10. Assert repository still contains https://saved.example/base/
```

Also add a non-widget real Runner test constructing `BookDetailTestRunner` from the real `SqliteSourceRepository` and the same fake HTTP executor.

- [ ] **Step 2: Run the integration test and verify RED**

```bash
flutter test test/features/source_tester/presentation/source_tester_integration_test.dart
```

Expected: new A2 assertions FAIL until page/runner wiring is complete; existing A1 integration cases must remain PASS.

- [ ] **Step 3: Make only fixture/harness adjustments needed for the real A2 chain**

Use the production providers/constructors created in earlier tasks. Do not introduce a test-only shortcut that passes a `SourceDocument` or draft directly into Book Detail Runner.

The fake executor must continue capturing the real `SourceHttpRequest` so the persisted URL assertion is made at the HTTP boundary.

- [ ] **Step 4: Run the integration test plus full Source Tester suite**

```bash
flutter test test/features/source_tester
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/test/features/source_tester/presentation/source_tester_integration_test.dart app/test/features/source_tester/fixtures
git commit -m "test: cover persisted book detail tester integration"
```

---

### Task 16: Final A2 regression, CI cleanliness, and architecture audit

**Files:**
- Modify only if required: `.github/workflows/flutter-ci.yml`
- No production behavior should be added in this task.

**Interfaces:**
- Produces: verified A2 completion against the approved spec.

- [ ] **Step 1: Rename only the stale A1-specific CI verification label if it is still present**

Change:

```yaml
- name: Verify clean worktree and A1 diff
```

to:

```yaml
- name: Verify clean worktree and Source Tester diff
```

Keep these commands unchanged unless the approved spec/plan explicitly requires otherwise:

```bash
git diff --check 32f9a5a826f78b0609073f9141c4226daee271cf..HEAD
git diff --check
git diff --exit-code
test -z "$(git status --porcelain)"
```

- [ ] **Step 2: Run formatter/analyzer and the complete test suite**

From `app/`:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Expected: formatting check exits 0, analyze reports `No issues found!`, all tests pass.

If code is intentionally not yet formatted, run `dart format lib test`, commit the formatting changes, then rerun the check above; do not weaken the check.

- [ ] **Step 3: Run repository cleanliness checks from repo root**

```bash
git diff --check 32f9a5a826f78b0609073f9141c4226daee271cf..HEAD
git diff --check
git diff --exit-code
test -z "$(git status --porcelain)"
```

Expected: exit 0.

- [ ] **Step 4: Audit the final diff against the A2 scope**

Run:

```bash
git diff --name-only 07570b12890c299e54eb6c33044ab7ceb910ecc5..HEAD
```

Verify the diff contains no:

```text
Reader books/chapters schema or migration
bookDetail editor/Draft UI
chapterList/chapterContent runtime
JavaScript runtime dependency
POST/WebView/cookie implementation
live-site test
Web release workaround
new third-party runtime dependency
```

Also verify production Sources -> Source Tester coupling remains presentation navigation by `sourceId`; Sources domain/application must not import Source Tester internals.

- [ ] **Step 5: Commit any final CI-label-only change and require green GitHub Actions**

```bash
git add .github/workflows/flutter-ci.yml
git commit -m "ci: generalize source tester verification label"
```

If the label was already generalized and there is nothing to commit, do not create an empty commit.

Acceptance requires the final branch HEAD GitHub Actions run to show:

```text
flutter pub get: success
build_runner: success
flutter analyze: success
flutter test: success
clean worktree / historical diff check: success
```

The final test count may be higher than A1's 240 tests; do not hard-code an expected total, only require zero failures.

---

## Plan Self-Review Checklist

Before execution, this plan has explicit tasks for every A2 design requirement:

- persisted `bookDetail` domain access -> Task 1
- A1-safe shared request extraction -> Task 2
- inheritance/raw `%@result`/fixed request semantics -> Task 3
- shared rule-pipeline evaluator with unsupported JS behavior -> Task 4
- deterministic parser registry -> Task 5
- shared outcome/request-origin diagnostics -> Task 6
- shared relative URL completion -> Task 7
- six-field root-oriented Book Detail parsing, field isolation, JS/no-rule warnings -> Task 8
- persisted Runner, HTTP/encoding/warning behavior -> Task 9
- Riverpod lifecycle/wiring -> Task 10
- manual upper-level-result input -> Task 11
- mode selector and running safety -> Task 12
- shared diagnostics + fixed detail result view -> Task 13
- Search-default page integration and per-mode report preservation -> Task 14
- real SQLite + unsaved-draft regression -> Task 15
- full regression, no-scope-creep audit, CI cleanliness -> Task 16

No Task introduces a database migration, Reader table, live-site test, JavaScript runtime, POST, WebView, or Book Detail editor.