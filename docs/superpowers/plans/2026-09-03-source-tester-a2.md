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

Create:

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

Instantiate:

```dart
final builder = SearchBookRequestBuilder(
  actionBuilder: const SourceActionRequestBuilder(),
);
```

Keep every existing assertion in the old `source_request_builder_test.dart`: UTF-8/GBK parameter encoding, known placeholder substitution, unknown placeholder rejection, relative URL resolution, global/action header parsing and override, invalid headers, and script request rejection.

- [ ] **Step 2: Run the request test and verify RED**

```bash
flutter test test/features/source_tester/application/search_book_request_builder_test.dart
```

Expected: FAIL because `SearchBookRequestBuilder` and `SourceActionRequestBuilder` do not exist.

- [ ] **Step 3: Extract shared URL/header code and isolate Search substitutions**

Move the current `_resolveRequestUri`, `_parseHeaders`, and `_mergeHeaders` implementations unchanged into `source_action_request_builder.dart`. The shared builder must expose:

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
    final unknownPlaceholder = RegExp(
      r'%@[A-Za-z_][A-Za-z0-9_]*',
    ).firstMatch(resolvedRequestInfo);
    if (unknownPlaceholder != null) {
      throw SourceTestException(
        SourceTestFailureReason.unknownPlaceholder,
        message: unknownPlaceholder.group(0),
      );
    }

    final uri = _resolveRequestUri(
      resolvedRequestInfo,
      source.document.sourceUrl,
    );
    final warnings = <String>[];
    final globalHeaders = _parseHeaders(
      source.document.toRaw()['httpHeaders'],
      warnings: warnings,
      scope: 'global',
    );
    final actionHeaders = _parseHeaders(
      actionHttpHeaders,
      warnings: warnings,
      scope: actionName,
    );

    return BuiltSourceActionRequest(
      request: SourceHttpRequest(
        uri: uri,
        method: SourceHttpMethod.get,
        headers: _mergeHeaders(globalHeaders, actionHeaders),
      ),
      warnings: warnings,
    );
  }
}
```

Create `SearchBookRequestBuilder` by retaining the current `SearchBookTestInput`, `BuiltSearchBookRequest`, `_RequestEncoding`, `_requestEncoding`, `_encodeParameter`, and `_isUnreserved` logic. The build method becomes:

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

Update Search runner/providers/tests to construct `SearchBookRequestBuilder(actionBuilder: const SourceActionRequestBuilder())`. Delete `source_request_builder.dart` only after the focused A1 suite compiles with the new files.

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

- [ ] **Step 1: Write failing tests for inheritance, raw substitution, fixed requests, and errors**

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

Add tests that assert `parentResultMissing` for blank request info or `%@result` with blank input, plus existing `unknownPlaceholder` and `unsupportedScriptRequest` behavior.

- [ ] **Step 2: Run the focused test and verify RED**

```bash
flutter test test/features/source_tester/application/book_detail_request_builder_test.dart
```

Expected: FAIL because A2 request types and new failure reasons do not exist.

- [ ] **Step 3: Implement Book Detail request selection**

Add once in `source_test_report.dart`:

```dart
enum SourceTestRequestOrigin {
  configuredRequestInfo,
  inheritedParentResult,
}
```

Add `bookDetailMissing` and `parentResultMissing` to `SourceTestFailureReason`.

Create:

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

Use this exact decision order:

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

final built = actionBuilder.build(
  source: source,
  resolvedRequestInfo: effective,
  actionHttpHeaders: bookDetail.toRaw()['httpHeaders'],
  actionName: 'bookDetail',
);
```

Return `BuiltBookDetailRequest` with the persisted raw `requestInfo`, selected origin, shared request, and warnings.

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

Expected: new evaluator test FAIL because the evaluator does not exist; existing Search parser tests remain green before production refactor.

- [ ] **Step 3: Move the existing private pipeline implementation into a shared stateless service**

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
    List<SourceRulePipelineStage> pipeline;
    try {
      pipeline = tokenizeSourceRulePipeline(rule);
    } on SourceRulePipelineFormatException catch (error) {
      return SourceRulePipelineEvaluation(
        value: SourceRuleList(const <SourceRuleValue>[]),
        contexts: const <SourceRuleContext>[],
        stages: const <String>[],
        warnings: const <String>[],
        errors: <String>[error.message],
        partial: false,
        executedDeclarative: false,
      );
    }

    var contexts = <SourceRuleContext>[initialContext];
    SourceRuleValue value = SourceRuleList(const <SourceRuleValue>[]);
    final warnings = <String>[];
    final errors = <String>[];
    var partial = false;
    var executedDeclarative = false;

    for (final stage in pipeline) {
      if (stage.isJavaScript) {
        partial = true;
        warnings.add('JS 阶段未执行: ${stage.expression}');
        break;
      }
      executedDeclarative = true;
      if (contexts.isEmpty) {
        value = SourceRuleList(const <SourceRuleValue>[]);
        break;
      }

      final nextContexts = <SourceRuleContext>[];
      final nextValues = <Object?>[];
      for (final context in contexts) {
        try {
          final evaluation = parser.evaluate(
            context: context,
            expression: stage.expression,
          );
          nextContexts.addAll(evaluation.contexts);
          nextValues.addAll(_flattenValue(evaluation.value));
        } on SourceRuleEvaluationException catch (error) {
          errors.add(error.message);
        } catch (error) {
          errors.add('规则执行失败: $error');
        }
      }
      contexts = nextContexts;
      value = _valueFromObjects(nextValues);
    }

    return SourceRulePipelineEvaluation(
      value: value,
      contexts: contexts,
      stages: pipeline.map((stage) => stage.expression).toList(growable: false),
      warnings: warnings,
      errors: errors,
      partial: partial,
      executedDeclarative: executedDeclarative,
    );
  }
}
```

Move the current `_flattenValue` and `_valueFromObjects` implementations from `SearchBookResultParser` into this file as private helpers.

Create `source_rule_value_text.dart` by moving the current Search `_firstText` behavior into `sourceRuleValueFirstText(SourceRuleValue value)`, preserving string trimming, num/bool conversion, JSON encoding of structured values, and fallback `toString()`.

Change `SearchBookResultParser` to require a `SourceRulePipelineEvaluator` and use `sourceRuleValueFirstText`. Remove its duplicated private evaluator/value conversion only after Search tests compile against the shared service.

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

Also assert `str`, `xml`, `data`, `filePath`, and an unknown string are unsupported.

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
- Consumes: `SourceTestRequestOrigin` introduced once in Task 3.
- Produces: shared `SourceTestOutcome` and request snapshot `origin`.
- Keeps `SearchBookTestReport` concrete and Search-specific.

- [ ] **Step 1: Write failing shared-report tests**

```dart
test('request snapshot stores the existing shared request origin', () {
  final snapshot = SourceTestRequestSnapshot(
    originalRequestInfo: '/search',
    origin: SourceTestRequestOrigin.configuredRequestInfo,
    uri: Uri.parse('https://example.com/search'),
    method: SourceHttpMethod.get,
    headers: const <String, String>{},
  );
  expect(snapshot.origin, SourceTestRequestOrigin.configuredRequestInfo);
});

test('SourceTestOutcome replaces the Search-specific enum', () {
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

Expected: FAIL because `SourceTestRequestSnapshot` has no `origin` yet and `SourceTestOutcome` does not exist.

- [ ] **Step 3: Rename the outcome and wire the already-defined origin into snapshots**

Replace:

```dart
enum SearchBookTestOutcome { success, completedWithWarnings }
```

with:

```dart
enum SourceTestOutcome { success, completedWithWarnings }
```

Add to `SourceTestRequestSnapshot`:

```dart
required this.origin,
...
final SourceTestRequestOrigin origin;
```

Update A1 Runner request snapshot construction with:

```dart
origin: SourceTestRequestOrigin.configuredRequestInfo,
```

Replace every `SearchBookTestOutcome` reference with `SourceTestOutcome`, including `_outcomeText` in the current Search report view. Do not redeclare `SourceTestRequestOrigin`; Task 3 is the single definition site.

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
- Produces: `BookDetailTestInputSnapshot`, `BookDetailTestResult`, `BookDetailParseResult`, `BookDetailTestReport`.

- [ ] **Step 1: Write failing HTML/JSON/parser-isolation tests**

Use a real `HtmlXPathRuleParser` fixture:

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

Add concrete tests for: one malformed field leaves other values intact; `declarative || @js` retains declarative output with partial trace; JS-only field is null with partial trace; configured `JSParser` adds a warning; six blank rules produce an empty result plus `bookDetail 未配置可执行响应规则`; legacy JSON slash paths and `$` JSONPath work through `JsonRuleParser`.

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

final class BookDetailTestReport {
  BookDetailTestReport({
    required this.sourceId,
    required this.sourceName,
    required this.platform,
    required this.input,
    required this.request,
    required this.response,
    required this.result,
    required List<SourceRuleTrace> traces,
    required List<String> warnings,
    required this.outcome,
  })  : traces = List.unmodifiable(traces),
        warnings = List.unmodifiable(warnings);

  final int sourceId;
  final String? sourceName;
  final String platform;
  final BookDetailTestInputSnapshot input;
  final SourceTestRequestSnapshot request;
  final SourceTestResponseSnapshot response;
  final BookDetailTestResult result;
  final List<SourceRuleTrace> traces;
  final List<String> warnings;
  final SourceTestOutcome outcome;
}
```

`BookDetailResultParser` must create one root context and iterate this exact field table:

```dart
final fields = <(String, String?, bool)>[
  ('cover', bookDetail.cover, true),
  ('desc', bookDetail.desc, false),
  ('cat', bookDetail.cat, false),
  ('status', bookDetail.status, false),
  ('wordCount', bookDetail.wordCount, false),
  ('lastChapterTitle', bookDetail.lastChapterTitle, false),
];
```

For each non-blank rule, call `pipelineEvaluator.evaluate(...)`, convert output with `sourceRuleValueFirstText`, normalize only `cover`, and create one `SourceRuleTrace`. A field with evaluation errors returns null without stopping later fields.

If `parser.createRoot(responseText)` throws, convert it to:

```dart
SourceTestException(
  SourceTestFailureReason.responseParseFailure,
  message: 'bookDetail 响应无法创建解析上下文',
  cause: error,
)
```

If all six rules are blank, append `bookDetail 未配置可执行响应规则`. If `bookDetail.action.jsParser` is non-blank, append `bookDetail.JSParser 当前版本未执行`. Parse malformed/non-object `moreKeys` as diagnostics only; do not apply `skipCount`, pagination, or request filters.

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

Add concrete tests for `sourceNotFound`, `unsupportedPlatform`, `bookDetailMissing`, HTTP 404/500 retained with warnings, GBK decoding, and transport failures.

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

Core flow:

```dart
final source = await repository.getSource(sourceId);
if (source == null) {
  throw const SourceTestException(SourceTestFailureReason.sourceNotFound);
}
if (source.platform != 'StandarReader') {
  throw SourceTestException(
    SourceTestFailureReason.unsupportedPlatform,
    message: source.platform,
  );
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

final warnings = <String>[
  ...built.warnings,
  ...decoded.warnings,
  ...parsed.warnings,
];
if (response.statusCode < 200 || response.statusCode >= 300) {
  warnings.add('HTTP 状态码 ${response.statusCode}');
}
final hasTraceDiagnostics = parsed.traces.any(
  (trace) => trace.partial || trace.warnings.isNotEmpty || trace.errors.isNotEmpty,
);
final outcome = warnings.isEmpty && !hasTraceDiagnostics
    ? SourceTestOutcome.success
    : SourceTestOutcome.completedWithWarnings;
```

Return:

```dart
BookDetailTestReport(
  sourceId: source.id,
  sourceName: source.document.sourceName,
  platform: source.platform,
  input: BookDetailTestInputSnapshot(parentResult: input.parentResult),
  request: SourceTestRequestSnapshot(
    originalRequestInfo: built.originalRequestInfo ?? '',
    origin: built.origin,
    uri: built.request.uri,
    method: built.request.method,
    headers: built.request.headers,
  ),
  response: SourceTestResponseSnapshot(
    statusCode: response.statusCode,
    finalUri: response.finalUri,
    headers: response.headers,
    duration: response.duration,
    byteCount: response.bodyBytes.length,
    encoding: decoded.encoding.name,
    decodedBody: decoded.text,
  ),
  result: parsed.result,
  traces: parsed.traces,
  warnings: warnings,
  outcome: outcome,
);
```

Do not change `SourceTestRequestSnapshot.originalRequestInfo` to nullable in A2; use an empty string for inherited requests and rely on `origin` to explain why.

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

  expect(
    container.read(sourceRulePipelineEvaluatorProvider),
    isA<SourceRulePipelineEvaluator>(),
  );
  expect(
    container.read(sourceRuleParserRegistryProvider),
    isA<SourceRuleParserRegistry>(),
  );
  expect(container.read(bookDetailTestRunnerProvider), isA<BookDetailTestRunner>());
});
```

- [ ] **Step 2: Run provider tests and verify RED**

```bash
flutter test test/features/source_tester/application/source_tester_providers_test.dart
```

Expected: FAIL because new providers do not exist.

- [ ] **Step 3: Add provider wiring with one shared instance per provider graph**

```dart
final sourceActionRequestBuilderProvider = Provider<SourceActionRequestBuilder>((ref) {
  return const SourceActionRequestBuilder();
});

final searchBookRequestBuilderProvider = Provider<SearchBookRequestBuilder>((ref) {
  return SearchBookRequestBuilder(
    actionBuilder: ref.watch(sourceActionRequestBuilderProvider),
  );
});

final bookDetailRequestBuilderProvider = Provider<BookDetailRequestBuilder>((ref) {
  return BookDetailRequestBuilder(
    actionBuilder: ref.watch(sourceActionRequestBuilderProvider),
  );
});

final sourceRulePipelineEvaluatorProvider = Provider<SourceRulePipelineEvaluator>((ref) {
  return const SourceRulePipelineEvaluator();
});

final sourceRuleParserRegistryProvider = Provider<SourceRuleParserRegistry>((ref) {
  return SourceRuleParserRegistry(
    htmlParser: ref.watch(sourceHtmlParserProvider),
    jsonParser: ref.watch(sourceJsonParserProvider),
  );
});

final bookDetailResultParserProvider = Provider<BookDetailResultParser>((ref) {
  return BookDetailResultParser(
    pipelineEvaluator: ref.watch(sourceRulePipelineEvaluatorProvider),
  );
});

final bookDetailTestRunnerProvider = Provider<BookDetailTestRunner>((ref) {
  return BookDetailTestRunner(
    repository: ref.watch(sourceRepositoryProvider),
    requestBuilder: ref.watch(bookDetailRequestBuilderProvider),
    httpExecutor: ref.watch(sourceHttpExecutorProvider),
    responseDecoder: ref.watch(sourceResponseDecoderProvider),
    parserRegistry: ref.watch(sourceRuleParserRegistryProvider),
    resultParser: ref.watch(bookDetailResultParserProvider),
  );
});
```

Update Search providers to consume `searchBookRequestBuilderProvider`, `sourceRulePipelineEvaluatorProvider`, and `sourceRuleParserRegistryProvider` instead of constructing old request/parser dependencies directly.

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
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SourceBookDetailInputPanel(
        running: true,
        onRun: (_) {},
      ),
    ),
  ));
  final button = tester.widget<ButtonStyleButton>(
    find.byKey(const Key('source-tester-detail-run')),
  );
  expect(button.enabled, isFalse);
});
```

- [ ] **Step 2: Run the input-panel test and verify RED**

```bash
flutter test test/features/source_tester/presentation/source_book_detail_input_panel_test.dart
```

Expected: FAIL because the widget does not exist.

- [ ] **Step 3: Implement the input panel**

Use:

```dart
final class SourceBookDetailInput {
  const SourceBookDetailInput({required this.parentResult});
  final String parentResult;
}
```

The `TextField` key is `source-tester-detail-parent-result`, label is `上一级结果 URL`, helper text includes `通常填写 searchBook.detailUrl。requestInfo 为空或包含 %@result 时需要填写。`, and the run button key is `source-tester-detail-run` with text `运行详情测试`.

The button must call:

```dart
onRun(SourceBookDetailInput(parentResult: controller.text.trim()));
```

without required-field validation. Set `onPressed: null` while `running`.

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
testWidgets('switches from Search to Book Detail', (tester) async {
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

testWidgets('running selector cannot change mode', (tester) async {
  var selected = SourceTesterMode.search;
  await tester.pumpWidget(MaterialApp(
    home: SourceTesterModeSelector(
      value: selected,
      running: true,
      onChanged: (value) => selected = value,
    ),
  ));
  await tester.tap(find.byKey(const Key('source-tester-mode-book-detail')));
  expect(selected, SourceTesterMode.search);
});
```

- [ ] **Step 2: Run the selector test and verify RED**

```bash
flutter test test/features/source_tester/presentation/source_tester_mode_selector_test.dart
```

Expected: FAIL because selector types do not exist.

- [ ] **Step 3: Implement the selector**

```dart
enum SourceTesterMode { search, bookDetail }
```

Use `SegmentedButton<SourceTesterMode>` with one selected value. Segment labels are `Text('搜索测试', key: Key('source-tester-mode-search'))` and `Text('书籍详情', key: Key('source-tester-mode-book-detail'))`. Set `onSelectionChanged: null` while `running`; otherwise call `onChanged(selection.single)`.

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
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: BookDetailTestReportView(report: _inheritedDetailReport())),
  ));
  await tester.tap(find.byKey(const Key('source-tester-tab-request')));
  await tester.pumpAndSettle();
  expect(find.textContaining('请求来源：继承上一级结果 URL'), findsOneWidget);
});
```

Keep existing Search report tests for result count, request/response tabs, JS partial diagnostics, and body truncation.

- [ ] **Step 2: Run both report-view tests and verify RED**

```bash
flutter test \
  test/features/source_tester/presentation/source_tester_report_view_test.dart \
  test/features/source_tester/presentation/book_detail_test_report_view_test.dart
```

Expected: A2 test FAIL because shared/detail views do not exist; existing A1 report test remains green before refactor.

- [ ] **Step 3: Extract only the diagnostic shell and keep business result views separate**

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

Keep these existing keys unchanged:

```text
source-tester-tab-results
source-tester-tab-request
source-tester-tab-response
source-tester-tab-traces
```

Move the existing Request/Response/Trace widgets and the 200000-character body display limit into this file. Request origin text is exactly:

```dart
String _originText(SourceTestRequestOrigin origin) => switch (origin) {
  SourceTestRequestOrigin.configuredRequestInfo => '配置的 requestInfo',
  SourceTestRequestOrigin.inheritedParentResult => '继承上一级结果 URL',
};
```

Request tab renders `请求来源：${_originText(request.origin)}` before method/final URL/original requestInfo/headers.

Refactor `SourceTesterReportView` so its Search-specific Result widget remains in `source_tester_report_view.dart`, then pass it plus the Search report diagnostics to `SourceTestReportTabs`.

`BookDetailTestReportView` passes a six-field result widget to the same shell. Render all six labels and `—` for null/blank values. Show outcome and report warnings above the fields.

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

Add a test that runs Search, switches to Detail and runs it, switches back, and still sees the original Search report without another Search HTTP call. Add a `Completer<SourceHttpResponse>` test proving mode cannot change while a run is pending.

- [ ] **Step 2: Run page tests and verify RED**

```bash
flutter test test/features/source_tester/presentation/source_tester_page_test.dart
```

Expected: new A2 assertions FAIL.

- [ ] **Step 3: Add independent page state and A2 error mapping**

State:

```dart
SourceTesterMode _mode = SourceTesterMode.search;
bool _running = false;
SearchBookTestReport? _searchReport;
BookDetailTestReport? _bookDetailReport;
String? _searchErrorText;
String? _bookDetailErrorText;
```

Rename the old `_run` to `_runSearch` without changing its behavior. Add:

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
  } catch (error) {
    if (mounted) setState(() => _bookDetailErrorText = '测试失败：$error');
  } finally {
    if (mounted) setState(() => _running = false);
  }
}
```

Extend error mapping with:

```dart
SourceTestFailureReason.bookDetailMissing => '当前书源没有 bookDetail 规则',
SourceTestFailureReason.parentResultMissing => '当前详情请求需要上一级结果 URL',
```

Keep Search's `requestInfoMissing` message explicitly about `searchBook.requestInfo`.

Render `SourceTesterModeSelector(value: _mode, running: _running, onChanged: ...)` above the active input panel. Mode changes must only update `_mode`; do not clear either report. Render `_searchReport` only in Search mode and `_bookDetailReport` only in Book Detail mode.

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
- Optional create: `app/test/features/source_tester/fixtures/book_detail_fixture.html` only if the deterministic HTML is large enough that an inline string harms readability.

**Interfaces:**
- Verifies the real `Drift -> SqliteSourceRepository -> BookDetailTestRunner -> fake HTTP -> parser -> report` path.
- Verifies Workbench unsaved basic-field draft does not affect A2.

- [ ] **Step 1: Extend the persisted fixture source and add the integration regressions**

Persist:

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

The widget regression must execute these observable steps:

```text
1. Persist sourceUrl = https://saved.example/base/
2. Open Workbench and change sourceUrl to https://draft.example/base/ without saving
3. Open Tester
4. Switch to Book Detail
5. Enter /book/1
6. Run
7. Captured request URI must equal https://saved.example/book/1
8. Navigate back
9. Workbench sourceUrl field must still contain https://draft.example/base/
10. Repository sourceUrl must still equal https://saved.example/base/
```

Add a separate non-widget test constructing the real `SqliteSourceRepository` and `BookDetailTestRunner` with fake HTTP, then assert parsed status/latest-chapter values from the fixture.

- [ ] **Step 2: Run the integration test immediately**

```bash
flutter test test/features/source_tester/presentation/source_tester_integration_test.dart
```

Expected: PASS if Tasks 1-14 correctly preserved the persisted-state boundary. If it fails, the failure must identify a real integration defect; do not change production code merely to manufacture a RED phase for this final regression task.

- [ ] **Step 3: Fix only real integration defects revealed by Step 2**

Allowed fixes are limited to production wiring already specified by Tasks 1-14. Do not pass a `SourceDocument`, editor Draft, or unsaved field value directly into `BookDetailTestRunner`; every run must continue through `repository.getSource(sourceId)`.

- [ ] **Step 4: Run the integration test plus full Source Tester suite**

```bash
flutter test test/features/source_tester
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/test/features/source_tester/presentation/source_tester_integration_test.dart app/test/features/source_tester/fixtures app/lib/features/source_tester
git commit -m "test: cover persisted book detail tester integration"
```

If Step 2 already passes and no production fix is needed, commit only the new/updated tests and fixture.

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

Keep these commands unchanged:

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

If formatting check fails, run `dart format lib test`, commit only the formatting changes required by Dart formatter, then rerun all three commands. Do not weaken the check.

- [ ] **Step 3: Run repository cleanliness checks from repo root**

```bash
git diff --check 32f9a5a826f78b0609073f9141c4226daee271cf..HEAD
git diff --check
git diff --exit-code
test -z "$(git status --porcelain)"
```

Expected: exit 0.

- [ ] **Step 4: Audit the final diff against the A2 scope**

```bash
git diff --name-only 07570b12890c299e54eb6c33044ab7ceb910ecc5..HEAD
```

The diff must contain none of these:

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

The final test count may be higher than A1's 240 tests; do not hard-code a total, only require zero failures.

---

## Plan Self-Review Checklist

Spec coverage is explicit:

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

Type consistency checks:

- `SourceTestRequestOrigin` is introduced exactly once in Task 3, consumed by Tasks 6, 9, and 13.
- `SourceTestOutcome` is introduced exactly once in Task 6 and used by Search and Book Detail reports/runners thereafter.
- `SearchBookRequestBuilder` replaces `SourceRequestBuilder` in Task 2; all later tasks use the new name.
- `SourceRulePipelineEvaluator` is introduced in Task 4; providers/parsers use the same constructor/signature thereafter.
- `SourceRuleParserRegistry.select(String?)` is introduced in Task 5 and both runners use it.
- `BookDetailTestInput` is introduced in Task 3 and is the only application input passed to `BookDetailTestRunner`.
- `SourceBookDetailInput` is presentation-only and is converted to `BookDetailTestInput` inside `SourceTesterPage`.

No task introduces a database migration, Reader table, live-site test, JavaScript runtime, POST, WebView, or Book Detail editor.